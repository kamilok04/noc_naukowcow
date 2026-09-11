; ------------------------------------------------------------------------------
; poll_network_events
; Called once per frame in the main loop to check asynchronous network tasks.
; ------------------------------------------------------------------------------
poll_network_events:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40 ; 8-byte alignment     
    
    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .skip_poll   ; no networking in offline mode
    mov rcx, [rel tcp4_ptr]
    test rcx, rcx
    jz .skip_poll                  
    mov rax, [rcx + 0x48]        ; TCP4->Poll (unconditionally)
    call rax

.skip_poll:

    ; Only poll the handshake if it's currently expected
    ; LOG "Verifying the handshake"
    cmp byte [rel connection_status], CONNECTION_STATE_CONNECTED
    je .check_tx                    ; connected, skip
    cmp byte [rel connection_status], CONNECTION_STATE_PENDING
    jne .error


.check_handshake:
    ; BootServices->CheckEvent(handshake_event)
    mov rcx, [rel handshake_event]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.CheckEvent]
    call rax

    test rax, rax
    jnz .done                        ; EFI_NOT_READY

    ; got event, get its status
    mov rax, [rel token_handshake + EFI_TCP4_COMPLETION_TOKEN.Status] 
    test rax, rax
    jnz .error                       ; status != 0 => the connection aborted/failed

    ; we host?
    cmp byte [rel net_role], NET_ROLE_SERVER
    jne .set_connected               ; clients need not do anything yet

.host_extract_child:
    ; an accepted connection is a brand new handle
    mov rcx, [rel token_handshake + EFI_TCP4_LISTEN_TOKEN.NewChildHandle] 
    lea rdx, [rel GUID_TCP4]
    
    ; overwrite the embryonic connection with the complete one
    lea r8, [rel tcp4_ptr]    
    mov rax, [rel boot_services_ptr]       
    mov rax, [rax + EFI_BOOT_SERVICES.HandleProtocol]
    call rax
    test rax, rax
    jnz .error


.set_connected:
    LOG "TCP Hardware Connected."
    mov byte [rel connection_status], CONNECTION_STATE_CONNECTED
    
    cmp byte [rel net_role], NET_ROLE_SERVER
    je .server_init
    
.client_init:
    ; client expects a token and stays in the menu.
    LOG "Client ready, waiting for the init token."
    call queue_network_rx
    jmp .done
    
.server_init:
    ; servers spins everything up
    call calculate_board_layout           
    call render_playfield                 
    call swap_buffers                     
    mov byte [rel cursor_is_saved], 0     
    mov byte [rel in_menu], MENU_STATE_IN_GAME
    
    ; client is allowed in, the game's initialize 
    LOG "Attempting sync."
    call send_sync_packet
    jmp .done

.error:
    LOG "Connection failed! Code %x", rax
    mov byte [rel connection_status], CONNECTION_STATE_OFFLINE   ; cannot connect, stay offline then

.check_tx:
    ; no TX when disconnected
    cmp byte [rel connection_status], CONNECTION_STATE_CONNECTED
    jne .check_rx

    ; TX ready?
    mov rcx, [rel tx_event]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.CheckEvent]
    call rax

    test rax, rax
    jnz .check_rx                        ; EFI_NOT_READY (no TX yet)

    ; TX ready, did it get sent?
    mov rax, [rel token_tx + 8]          ; token_tx.Status
    test rax, rax
    jnz .tx_error

    LOG "TX OK"
    
    mov rax, 0x8000000000000006          ; EFI_NOT_READY
    mov [rel token_tx + 8], rax
    jmp .check_rx

.tx_error:
    LOG "async TX failure! Code: %x", rax
    jmp .check_rx

.check_rx:
    ; connected and in menu?
    cmp byte [rel connection_status], CONNECTION_STATE_CONNECTED
    jne .done
    cmp byte [rel in_menu], MENU_STATE_IN_GAME
    je .done ; in-game, don't reinitialize

    ; what arrived?
    mov rcx, [rel rx_event]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.CheckEvent]
    call rax

    test rax, rax
    jnz .done                        ; nothing

    ; something did, is it useful?
    mov rax, [rel token_rx + 8]      ; Status
    test rax, rax
    jnz .error

    ; is it the sync byte?
    cmp byte [rel rx_data], 0xAA
    je .sync_ok                       ; nah

    mov dword [rel rx_packet_data + 4], 1
    mov dword [rel rx_packet_data + 16], 1
    mov byte [rel rx_data], 0

    call queue_network_rx
    jmp .done

.sync_ok:
    LOG "Sync packet received! Entering game."
    
    call calculate_board_layout           
    call render_playfield                 
    call swap_buffers                     
    mov byte [rel cursor_is_saved], 0     
    mov byte [rel in_menu], MENU_STATE_IN_GAME
    
    ; actual chess move handling here

.done:
    add rsp, 40
    pop rbx
    pop rbp
    ret