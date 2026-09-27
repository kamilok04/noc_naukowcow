; ------------------------------------------------------------------------------
; poll_network_events
; Poll for events over SNP and see if anything came over TCP
; ------------------------------------------------------------------------------
poll_network_events:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56                      ; 16-byte aligned, space for 7 UEFI arguments

    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .done

    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .check_state                  ; SNP requires no explicit driver poll

.poll_tcp4:
    mov rcx, [rel tcp4_ptr]
    test rcx, rcx
    jz .check_state
    mov rax, [rcx + EFI_TCP4_PROTOCOL.Poll]
    call rax

.check_state:
    cmp byte [rel connection_status], CONNECTION_STATE_CONNECTED
    je .check_tx
    cmp byte [rel connection_status], CONNECTION_STATE_PENDING
    je .check_handshake

    ; If offline but polling reached here, force net_role off to prevent an infinite loop
    jmp .error

.check_handshake:
    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .snp_handshake_poll           ;

    mov rcx, [rel handshake_event]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.CheckEvent]
    call rax
    test rax, rax
    jnz .done                        ; EFI_NOT_READY

    mov rax, [rel token_handshake + EFI_TCP4_COMPLETION_TOKEN.Status]
    test rax, rax
    jnz .error                       

    cmp byte [rel net_role], NET_ROLE_SERVER
    jne .set_connected

.host_extract_child:
    mov rcx, [rel token_handshake + EFI_TCP4_LISTEN_TOKEN.NewChildHandle]
    lea rdx, [rel GUID_TCP4]
    lea r8, [rel tcp4_ptr]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.HandleProtocol]
    call rax
    test rax, rax
    jnz .error
    jmp .set_connected

.snp_handshake_poll:

    cmp byte [rel net_role], NET_ROLE_CLIENT
    jne .jump_to_rx
    
    rdtsc
    
    shr eax, 26             
    cmp al, byte [rel snp_beacon_timer]
    je .jump_to_rx        ; whatever the clock speed is divided by 2^26
    
    mov byte [rel snp_beacon_timer], al 
    
    mov byte [rel snp_tx_buffer + 14], 0xEE
    mov byte [rel snp_tx_buffer + 15], 0x00
    mov byte [rel snp_tx_buffer + 16], 0x00
    call broadcast_snp_packet

.jump_to_rx:
    jmp .check_rx


.set_connected:
    LOG "Network Connected."
    mov byte [rel connection_status], CONNECTION_STATE_CONNECTED
    cmp byte [rel net_role], NET_ROLE_SERVER
    je .server_init

.client_init:
    LOG "Client ready."
    call queue_network_rx
    jmp .done

.server_init:
    LOG "Initializing game as host."
    movzx rdi, word [rel sync_payload + 1]
    call generate_chess960_board ; get your own board!
    
    lea rsi, [rel initial_board]
    lea rdi, [rel board]
    mov rcx, 128
    rep movsb

    call calculate_board_layout
    call render_playfield
    call swap_buffers
    mov byte [rel cursor_is_saved], 0
    mov byte [rel in_menu], MENU_STATE_IN_GAME

    LOG "Attempting sync."
    call send_sync_packet
    call queue_network_rx
    jmp .done

.error:
    mov byte [rel connection_status], CONNECTION_STATE_OFFLINE
    mov byte [rel net_role], NET_ROLE_OFFLINE
    jmp .done

.check_tx:
    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .check_rx    ; huh? synchronous protocol is polled and async is not?
                    ; this is alarming if you've ever done user-space networking
                    ; this, however, is not user-space networking

                    ; TCP is Expensive™ and this system is obviously single-threaded
                    ; This would normally be delegated to a background worker thread,
                    ; but we don't do any of that fancy stuff
                    ; polling is necessary so thtat the main loop sees the event

                    ; SNP, on the other hand, is almost trivial
                    ; it's a direct read from the networking chip
                    ; whatever is present gets copied, that's it, no processing

    mov rcx, [rel tx_event]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.CheckEvent]
    call rax
    test rax, rax
    jnz .check_rx

    mov rax, [rel token_tx + 8]
    test rax, rax
    jnz .tx_error

    mov rax, 0x8000000000000006      ; Rearm EFI_NOT_READY
    mov [rel token_tx + 8], rax
    jmp .check_rx

.tx_error:
    LOG "TCP: TX failure! Code: %x", rax
    jmp .check_rx

.check_rx:
    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .snp_rx

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

    jmp .process_payload

.snp_rx:
    mov r12, [rel active_snp_count]
    xor r13, r13
.snp_rx_loop:
    cmp r13, r12
    jge .done
    
    lea rcx, [rel active_snp_ptrs]
    mov rcx, [rcx + r13 * 8]

    mov qword [rel snp_rx_size], 1500
    xor rdx, rdx                     ; HeaderSize = 0
    lea r8, [rel snp_rx_size]
    lea r9, [rel snp_rx_buffer]
    mov qword [rsp + 32], 0          ; SrcAddr = NULL
    mov qword [rsp + 40], 0          ; DestAddr = NULL
    mov qword [rsp + 48], 0          ; Protocol = NULL
    
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.Receive] 
    call rax

    test rax, rax
    jz .snp_got_packet               
    inc r13
    jmp .snp_rx_loop

.snp_got_packet:
    ; is it the correct packet type?
    mov ax, word [rel snp_rx_buffer + 12]
    cmp ax, 0xB588 ; 0x88B5 is registered as an experimental ethertype 1
                   ; it is Guaranteed™ to be left alone
                   ; but any firewall on this planet should always drop packets of this type
                   ; https://doi.org/10.1109/IEEESTD.2014.6847097
                   ; https://www.iana.org/assignments/ieee-802-numbers#ieee-802-numbers-1

    jne .snp_ignore

    ; buffer also contains *sent* packets
    ; check if whatever got picked is not ours
    ; else, the host connects to itself and fun stuff happens
    mov al, byte [rel snp_rx_buffer + 17]
    cmp al, byte [rel net_role]
    je .snp_ignore

    ; good enough, grab the data
    mov al, byte [rel snp_rx_buffer + 14]
    mov byte [rel rx_data + MOVE_PAYLOAD.Origin], al
    mov al, byte [rel snp_rx_buffer + 15]
    mov byte [rel rx_data + MOVE_PAYLOAD.Destination], al
    mov al, byte [rel snp_rx_buffer + 16]
    mov byte [rel rx_data + MOVE_PAYLOAD.Promotion], al
    jmp .process_payload

.snp_ignore:
    inc r13
    jmp .snp_rx_loop

.process_payload:
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xAA
    je .sync_ok

.check_hello:
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xEE
    jne .check_reset
    
    ; only the server should be allowed to answer a client hello
    cmp byte [rel net_role], NET_ROLE_SERVER
    jne .rearm_rx
    
    cmp byte [rel connection_status], CONNECTION_STATE_PENDING
    je .set_connected
    
    ; if we're here, the server is in-game, but the client is not; resend the sync packet
    call send_sync_packet
    jmp .rearm_rx

.check_reset:
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xBB
    je .remote_reset

    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCC
    je .remote_offer_draw
    
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCD
    je .remote_accept_draw
    
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCE
    je .remote_surrender

    mov al, byte [rel rx_data + MOVE_PAYLOAD.Origin]
    or al, byte [rel rx_data + MOVE_PAYLOAD.Destination]
    jz .rearm_rx

    mov byte [rel is_remote_move], 1

    push rax
    push rbx
    push rcx
    movzx rax, byte [rel rx_data + MOVE_PAYLOAD.Origin]
    movzx rbx, byte [rel rx_data + MOVE_PAYLOAD.Destination]
    movzx rcx, byte [rel rx_data + MOVE_PAYLOAD.Promotion]
    pop rcx
    pop rbx
    pop rax

    movzx r8, byte [rel rx_data + MOVE_PAYLOAD.Origin]
    mov byte [rel selected_square], 0xFF
    call the_chess_state_machine

    movzx r8, byte [rel rx_data + MOVE_PAYLOAD.Destination]
    call the_chess_state_machine

    cmp byte [rel promotion_pending], 1
    jne .rearm_rx
    
    movzx rbx, byte [rel promotion_sq]
    mov al, byte [rel rx_data + MOVE_PAYLOAD.Promotion]
    lea rcx, [rel board]
    mov byte [rcx + rbx], al
    mov byte [rel promotion_pending], 0
    call promotion_interrupt_resolved
    jmp .rearm_rx
.sync_ok:
    mov byte [rel connection_status], CONNECTION_STATE_CONNECTED
    movzx rdi, word [rel rx_data + MOVE_PAYLOAD.Destination] 
    call generate_chess960_board     
    
    lea rsi, [rel initial_board]
    lea rdi, [rel board]
    mov rcx, 128
    rep movsb                        

    call calculate_board_layout           
    call render_playfield                 
    call swap_buffers                     
    mov byte [rel cursor_is_saved], 0     
    mov byte [rel in_menu], MENU_STATE_IN_GAME
    jmp .rearm_rx

.remote_reset:
    xor byte [rel local_color], 1    
    call reset_game                  
    call render_playfield
    call swap_buffers
    mov byte [rel cursor_is_saved], 0
    jmp .rearm_rx

.remote_offer_draw:
    mov dword [rel ui_action_state], ACTION_STATE_INCOMING_DRAW
    jmp .rearm_rx

.remote_accept_draw:
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    mov byte [rel match_state], 3        
    jmp .rearm_rx

.remote_surrender:
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    mov al, byte [rel local_color]
    inc al                           
    mov byte [rel match_state], al
    jmp .rearm_rx

.rearm_rx:
    mov byte [rel is_remote_move], 0         
    mov dword [rel rx_packet_data + 4], 3
    mov dword [rel rx_packet_data + 16], 3
    
    ; Do not draw the board if we are still waiting for the other player
    cmp byte [rel in_menu], MENU_STATE_IN_GAME
    jne .skip_draw
    call render_playfield
    call swap_buffers
.skip_draw:

    mov byte [rel cursor_is_saved], 0
    call queue_network_rx
    jmp .done

.done:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret