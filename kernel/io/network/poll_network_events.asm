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

    LOG "Listening for client data."
    call queue_network_rx

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
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xAA
    je .sync_ok                     ; nah

    ; is it the reset command?
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xBB
    je .remote_reset

    ; UI commands?
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCC
    je .remote_offer_draw
    
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCD
    je .remote_accept_draw
    
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCE
    je .remote_surrender

    ; Filter out ACKs
    ; 0x00 -> 0x00, which will never be a valid move
    mov al, byte [rel rx_data + MOVE_PAYLOAD.Origin]
    or al, byte [rel rx_data + MOVE_PAYLOAD.Destination]
    jz .rearm_rx

    ;LOG "Remote move incoming"
    mov byte [rel is_remote_move], 1


    ; this is the remote move logic
    ; the network-connected opponent set this phase

    push rax
    push rbx
    push rcx
    movzx rax, byte [rel rx_data + MOVE_PAYLOAD.Origin]
    movzx rbx, byte [rel rx_data + MOVE_PAYLOAD.Destination]
    movzx rcx, byte [rel rx_data + MOVE_PAYLOAD.Promotion]
    LOG "Incoming move: %x -> %x, promoting to %x", rax, rbx, rcx
    pop rcx
    pop rbx
    pop rax


    movzx r8, byte [rel rx_data + MOVE_PAYLOAD.Origin]
    mov byte [rel selected_square], 0xFF
    call the_chess_state_machine

    ; set the move
    movzx r8, byte [rel rx_data + MOVE_PAYLOAD.Destination]
    call the_chess_state_machine

    ; has there been a promotion?
    cmp byte [rel promotion_pending], 1
    jne .rearm_rx
    
    ; skip the UI (the user doesn't get a chance at trying to move the enemy piece)
    movzx rbx, byte [rel promotion_sq]
    mov al, byte [rel rx_data + MOVE_PAYLOAD.Promotion]
    lea rcx, [rel board]
    mov byte [rcx + rbx], al
    mov byte [rel promotion_pending], 0
    
    ; resume logic, check against vital stuff
    call promotion_interrupt_resolved 

.sync_ok:
    LOG "Sync packet received! Entering game."
    
    call calculate_board_layout           
    call render_playfield                 
    call swap_buffers                     
    mov byte [rel cursor_is_saved], 0     
    mov byte [rel in_menu], MENU_STATE_IN_GAME
    
    jmp .rearm_rx

.remote_reset:
    LOG "Resetting the game per remote request."
    xor byte [rel local_color], 1    ; swap visual perspective
    call reset_game                  ; reset the memory state
    
    ; force the UI to reflect the reset immediately
    call render_playfield
    call swap_buffers
    mov byte [rel cursor_is_saved], 0

    jmp .rearm_rx

.remote_offer_draw:
    LOG "Opponent offered a draw."
    mov dword [rel ui_action_state], ACTION_STATE_INCOMING_DRAW
    jmp .rearm_rx

.remote_accept_draw:
    LOG "Opponent accepted the draw."
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    mov byte [rel match_state], 3        ; 3 = Stalemate/Draw
    jmp .rearm_rx

.remote_surrender:
    LOG "Opponent surrendered."
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    
    ; white goes: 0, black goes: 1
    ; white wins: 1, black wins: 2
    ; just add 1!
    mov al, byte [rel local_color]
    inc al                           
    mov byte [rel match_state], al
    jmp .rearm_rx

.rearm_rx:
    mov byte [rel is_remote_move], 0         ; unlock TX
    mov dword [rel rx_packet_data + 4], 3
    mov dword [rel rx_packet_data + 16], 3
    ; mov byte [rel rx_data], 0

    call render_playfield
    call swap_buffers
    mov byte [rel cursor_is_saved], 0

    call queue_network_rx
    jmp .done

.done:
    add rsp, 40
    pop rbx
    pop rbp
    ret