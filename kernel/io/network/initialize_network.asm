; ------------------------------------------------------------------------------
; init_network
; Queries UEFI for the TCP4 Service Binding Protocol.
; Returns:
;   RAX: 0 in success, 1 on failure
; ------------------------------------------------------------------------------
init_network:
    push rbp
    mov rbp, rsp
    sub rsp, 32                      
    
    mov rax, [rel boot_services_ptr]
    
    lea rcx, [rel GUID_TCP4_SERVICE_BINDING] 
    xor rdx, rdx                               
    lea r8, [rel tcp4_sb_ptr]                
    

    mov rax, [rax + EFI_BOOT_SERVICES.LocateProtocol] 
    call rax
    
    test rax, rax
    jnz .error
    
    LOG "TCP4 service binding OK."
    jmp .done
    
.error:
    LOG "Failed to locate TCP4 service binding; code: %x", rax
    LOG "Only local game will be available."
.done:
    add rsp, 32
    pop rbp
    ret

; ------------------------------------------------------------------------------
; setup_connection
; Spawns a TCP4 child, grabs the protocol, and configures the IP/subnet.
; ------------------------------------------------------------------------------
setup_connection:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 48   

    ; ServiceBinding->CreateChild(This, &ChildHandle)
    mov rcx, [rel tcp4_sb_ptr]
    lea rdx, [rel tcp4_handle]
    mov rax, [rcx + 0x00]            ; +0x00 = CreateChild
    call rax
    test rax, rax
    jnz .error

    ; BootServices->HandleProtocol(ChildHandle, GUID, &TCP4_Protocol)
    mov rcx, [rel tcp4_handle]
    lea rdx, [rel GUID_TCP4]
    lea r8, [rel tcp4_ptr]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.HandleProtocol]
    call rax
    test rax, rax
    jnz .error

    ; pick your config (1 = host, 2 = join)
    cmp byte [rel net_role], 1
    je .load_host
    lea rdx, [rel tcp4_config_join] ;stored in efi.asm
    jmp .configure
.load_host:
    lea rdx, [rel tcp4_config_host]

.configure:
    ; Call TCP4->Configure(This, &ConfigData)
    mov rcx, [rel tcp4_ptr]          
    mov rax, [rcx + 0x08]            ; +0x08 = Configure
    call rax
    test rax, rax
    jnz .error

    LOG "TCP4 setup OK"
    jmp .done

.error:
    LOG "TCP4 Setup Failed! Code: %x", rax

.done:
    add rsp, 48
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; start_handshake
; Instructs the TCP4 protocol to begin the async connect/accept
; ------------------------------------------------------------------------------
start_handshake:
    push rbp
    mov rbp, rsp
    sub rsp, 32                      

    mov rax, 0x8000000000000006      
    mov [rel token_handshake + 8], rax

    mov rcx, [rel tcp4_ptr]          ; TCP4 protocol interface
    lea rdx, [rel token_handshake]   ; completion token

    ; 1 = Host, 2 = Join
    cmp byte [rel net_role], NET_ROLE_SERVER
    je .host_accept

.client_connect:
    ; TCP4->Connect(This, ConnectionToken)
    LOG "Connecting to server."
    mov rax, [rcx + 0x18]            ; +0x18 is connect
    call rax
    jmp .check_status

.host_accept:
    ; TCP4->Accept(This, ListenToken)
    LOG "Accepting a client."
    mov rax, [rcx + 0x20]            ; +0x20 is accept
    call rax

.check_status:
    test rax, rax
    jnz .error                       ; queueing fiasco
    

    mov byte [rel connection_status], CONNECTION_STATE_PENDING
   ; LOG "Pending a client..."
    ; LOG "TCP handshake OK"
    jmp .done

.error:
    LOG "TCP4 Handshake Initialization Failed! Code: %x", rax
    mov byte [rel connection_status], CONNECTION_STATE_OFFLINE

.done:
    add rsp, 32
    pop rbp
    ret

; ------------------------------------------------------------------------------
; run_awaiting_connection
; Blocks the game logic while a connection is pending
; ------------------------------------------------------------------------------
run_awaiting_connection:
    push rbp
    mov rbp, rsp
    
    mov byte [rel in_menu], 2        ; set UI state to 'awaiting'
    call render_awaiting_screen
    call swap_buffers
    
.await_loop:
    ; cancelled?
    cmp byte [rel in_menu], MENU_STATE_MAIN
    je .done
    
    ; connected?
    cmp byte [rel connection_status], CONNECTION_STATE_CONNECTED
    je .connected
    
;     mov rcx, 1
;     cmp qword [rel wait_event_array + 8], 0 ; does the net event exist?
;     je .do_wait
;     inc rcx ; ye

; .do_wait:                     
;     lea rdx, [rel wait_event_array]     
;     lea r8, [rel event_index]            
;     mov rbx, [rel boot_services_ptr]
;     sub rsp, 32
;     call [rbx + EFI_BOOT_SERVICES.WaitForEvent]                     
;     add rsp, 32

;     test rax, rax
;     jnz .await_loop ; in case of failure, retry
    
    call process_mouse_input
    call poll_network_events         ; keep checking for connection
    
    jmp .await_loop
    
.connected:
    mov byte [rel in_menu], MENU_STATE_IN_GAME        ; drop into the game
.done:
    pop rbp
    ret

; ------------------------------------------------------------------------------
; transition_to_network
; Launch the network stack and change the game state if successful
; ------------------------------------------------------------------------------
transition_to_network:
    push rbp
    mov rbp, rsp
    
    LOG "Loading networking functionalities."
    call init_network
    test rax, rax
    jnz .net_failed
    
    call setup_connection
    call create_network_events
    call start_handshake
    
    mov byte [rel in_menu], MENU_STATE_AWAITING_CONNECTION
    jmp .done
    
.net_failed:
    LOG "Network initialization failed! Falling back to Main Menu."
    mov byte [rel in_menu], MENU_STATE_MAIN
.done:
    pop rbp
    ret


; ------------------------------------------------------------------------------
; send_sync_packet
; Queues a TCP4->Transmit command to send the initialization payload.
; ------------------------------------------------------------------------------
send_sync_packet:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; not ready yet!
    mov rax, 0x8000000000000006
    mov [rel token_tx + 8], rax

    ; grab the packet data
    lea rax, [rel tx_packet_data]
    mov [rel token_tx + 16], rax

    lea rax, [rel sync_payload]
    mov [rel tx_packet_data + 24], rax

    ; transmit
    mov rcx, [rel tcp4_ptr]
    lea rdx, [rel token_tx]
    mov rax, [rcx + 0x28]        
    call rax

    test rax, rax
    jnz .error

    LOG "Sync packet queued for transmission."
    jmp .done

.error:
    LOG "TX Initialization Failed! Code: %x", rax

.done:
    add rsp, 32
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; queue_network_rx
; Prepare the client for the sync packet.
; ------------------------------------------------------------------------------
queue_network_rx:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    ; EFI_NOT_READY
    mov rax, 0x8000000000000006
    mov [rel token_rx + 8], rax

    ; link the RX data
    lea rax, [rel rx_packet_data]
    mov [rel token_rx + 16], rax

    lea rax, [rel rx_data]
    mov [rel rx_packet_data + 24], rax


    ; TCP4->Receive (+0x30)
    mov rcx, [rel tcp4_ptr]
    lea rdx, [rel token_rx]
    mov rax, [rcx + 0x30]        
    call rax

    test rax, rax
    jnz .error

    LOG "Listening for incoming network data..."
    jmp .done

.error:
    LOG "RX queue failed! Code: %x", rax

.done:
    add rsp, 32
    pop rbp
    ret

; ------------------------------------------------------------------------------
; network_teardown
; Destroys whatever networking was created before; used for changing roles (client/server)
; ------------------------------------------------------------------------------
network_teardown:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .done

    ; wipe all tokens
    mov rcx, [rel tcp4_ptr]
    test rcx, rcx
    jz .kill_child
    xor rdx, rdx                     ; NULL config
    mov rax, [rcx + 0x08]            ; Configure
    call rax

.kill_child:
    ; DestroyChild(KillHandle)
    mov rcx, [rel tcp4_sb_ptr]
    mov rdx, [rel tcp4_handle]
    mov rax, [rcx + 0x08]            
    call rax

    ; set disconnect-like states within this system 
    mov byte [rel net_role], NET_ROLE_OFFLINE
    mov byte [rel connection_status], CONNECTION_STATE_OFFLINE
    mov qword [rel tcp4_ptr], 0
    mov qword [rel tcp4_handle], 0
    
    .done:
    add rsp, 32
    pop rbp
    ret
    
; ------------------------------------------------------------------------------
; send_network_move
; Sends a user-induced move over the network
; Inputs: CL = origin, DL = destination, R8B = promotion
; ------------------------------------------------------------------------------
send_network_move:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; load the move
    mov byte [rel move_payload + MOVE_PAYLOAD.Origin], cl
    mov byte [rel move_payload + MOVE_PAYLOAD.Destination], dl
    mov byte [rel move_payload + MOVE_PAYLOAD.Promotion], r8b


    movzx rcx, cx
    movzx rdx, dx
    LOG "Move queued for TX: %x -> %x", rcx, rdx
    
    ; we're not ready yet
    mov rax, 0x8000000000000006
    mov [rel token_tx + 8], rax

    ; point the sent token to the move data instead of the sync command
    lea rax, [rel move_payload]
    mov [rel tx_packet_data + 24], rax

    ; link the packet to the token
    lea rax, [rel tx_packet_data]
    mov [rel token_tx + 16], rax

    ; transmit (+0x28)
    mov rcx, [rel tcp4_ptr]
    lea rdx, [rel token_tx]
    mov rax, [rcx + 0x28]        
    call rax

    test rax, rax
    jnz .error

    jmp .done

.error:
    LOG "Move TX Failed! Code: %x", rax
.done:
    add rsp, 32
    pop rbp
    ret