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
    sub rsp, 56                      

    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .done
    ;LOG "poll net"

    ; This is a real life fix
    ; connection is not perfect and packets will be dropped
    ; while TCP would handle this, it's unavailable

    ; instead, we're going to broadcast the last instruction manually
    ; until an ACK (0xDD,0xDD,0 == a move M13 -> M13) is sent back

    rdtsc                    
    shr rax, 30       ; about 1 second for 2 GHz clock
    cmp al, byte [rel snp_beacon_timer]
    je .protocol_check
    mov byte [rel snp_beacon_timer], al

    cmp byte [rel connection_status], CONNECTION_STATE_PENDING
    je .beacon_handshake
    
    cmp byte [rel connection_status], CONNECTION_STATE_CONNECTED
    je .beacon_active_game
    jmp .protocol_check

    ; check what to retransmit, as different states have different rules

.beacon_handshake:
    ; the Hello packet, which starts the first game.
    cmp byte [rel net_role], NET_ROLE_CLIENT
    jne .protocol_check
    mov byte [rel snp_tx_buffer + 14], 0xEE
    mov byte [rel snp_tx_buffer + 15], 0x00
    mov byte [rel snp_tx_buffer + 16], 0x00
    call broadcast_snp_packet
    jmp .protocol_check

.beacon_active_game:
    ; no active game, skip
    cmp byte [rel ack_pending], 0
    je .protocol_check               ;

    cmp byte [rel match_state], 0
    je .beacon_moves

    ; rematch has been offered, let the opponent know
    cmp byte [rel rematch_state], 1
    jne .beacon_draw
    mov cl, 0xBB
    mov dl, 0xBB
    xor r8b, r8b
    call send_network_move
    jmp .protocol_check

.beacon_draw:
    ; sending the rermatch offer, remember to update the UI
    cmp byte [rel match_state], 0
    jne .beacon_accept_draw
    cmp dword [rel ui_action_state], ACTION_STATE_DRAW
    jne .protocol_check
    mov cl, 0xCC
    mov dl, 0xCC
    xor r8b, r8b
    call send_network_move
    jmp .protocol_check

.beacon_accept_draw:
    ; draw accepted; let them know
    cmp byte [rel match_state], 3
    jne .beacon_surrender
    mov cl, 0xCD
    mov dl, 0xCD
    xor r8b, r8b
    call send_network_move
    jmp .protocol_check

.beacon_surrender:
    ; the player surrendered, keep sending that detail
    mov al, byte [rel local_color]
    inc al ; 0=playing as white, 1=playing as black -> 1=white wins, 2=black wins
    cmp byte [rel match_state], al
    jne .protocol_check ; game on or the opponent surrendered first
    mov cl, 0xCE
    mov dl, 0xCE
    xor r8b, r8b
    call send_network_move
    jmp .protocol_check

.beacon_moves:
    ; an actual move
    mov al, byte [rel current_color]
    cmp al, byte [rel local_color]
    je .protocol_check               ; no move made yet, nothing to retransmit

    cmp word [rel transcript_count], 0
    je .protocol_check               ; no move made ever, nothing to retransmit

    mov cl, byte [rel last_local_move + MOVE_PAYLOAD.Origin]
    mov dl, byte [rel last_local_move + MOVE_PAYLOAD.Destination]
    mov r8b, byte [rel last_local_move + MOVE_PAYLOAD.Promotion]
    call send_network_move           ; keep blasting that packet

.protocol_check:
    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .check_state                  

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

.drain_tx_ring:
    ; UEFI Standard, 24.1.12
    ; An SNP adapter has a limited buffer as to what it can transmit
    ; clearing means passing a non-null interrupt status
    ; and calling this method.
    ; A zero (success) code means something was pulled
    ; as we want to *drain* the queue,
    ; just call until something non-zero happens.

    mov qword [rel recycled_tx_buf], 0   
    
    lea rcx, [rel active_snp_ptrs]
    mov rcx, [rcx + r13 * 8]
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.GetStatus]
    
    lea rdx, [rel interrupt_status]      ; NULL will be written here if something is pulled
    lea r8, [rel recycled_tx_buf]        ; NULL will be written here if everything is pulled            
    
    sub rsp, 32
    call rax   
    add rsp, 32                          
                   
    lea rcx, [rel active_snp_ptrs]
    mov rcx, [rcx + r13 * 8]

    mov qword [rel snp_rx_size], 4096
    xor rdx, rdx                         ; HeaderSize = 0
    lea r8, [rel snp_rx_size]
    lea r9, [rel snp_rx_buffer]
    mov qword [rsp + 32], 0              ; SrcAddr = NULL
    mov qword [rsp + 40], 0              ; DestAddr = NULL
    mov qword [rsp + 48], 0              ; Protocol = NULL
    
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.Receive] 
    call rax
    test rax, rax
    jz .snp_got_packet               ; something acquired, read it
    
    inc r13                          ; nothing to read, proceed to the next adapter
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
    ; don't change the adapter yet
    jmp .drain_tx_ring

.process_payload:
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xAA
    je .sync_ok

    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xDD
    je .got_ack                      ; ACK received
    
    ; something else was received and that something needs an ACK
    ; unless it's a Hello, which is an ACK by itself
    mov byte [rel needs_ack], 1      
    jmp .check_hello

.got_ack:
    mov byte [rel ack_pending], 0    ; 
    jmp .update_remote_ui                  ; ACKed - nothing to process

.send_ack:
    ; ye, ye, I got it
    push rax
    push rcx
    push rdx
    push r8
    mov cl, 0xDD
    mov dl, 0xDD
    xor r8b, r8b
    call send_network_move
    pop r8
    pop rdx
    pop rcx
    pop rax

.check_hello:
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xEE
    jne .check_reset

    mov byte [rel needs_ack], 0 ; hello is an ACK by itself
    
    ; only the server should be allowed to answer a client hello
    cmp byte [rel net_role], NET_ROLE_SERVER
    jne .rearm_rx_silent
    
    cmp byte [rel connection_status], CONNECTION_STATE_PENDING
    je .set_connected
    
    ; if we're here, the server is in-game, but the client is not; resend the sync packet
    call send_sync_packet
    jmp .update_remote_ui

.check_reset:
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xBB
    jne .check_left

    ; ignore random rematch packets
    cmp byte [rel match_state], 0
    jne .remote_reset

    jmp .update_remote_ui
    

.check_left:

    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCF  ; opp left
    jne .check_draw

    ; it's impossible for anyone to leave while the game is ongoing.
    cmp byte [rel match_state], 0
    je .rearm_rx_silent
    
    jmp .remote_left

.check_draw:
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCC
    je .remote_offer_draw
    
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCD
    je .remote_accept_draw
    
    cmp byte [rel rx_data + MOVE_PAYLOAD.Origin], 0xCE
    je .remote_surrender

    mov al, byte [rel rx_data + MOVE_PAYLOAD.Origin]
    or al, byte [rel rx_data + MOVE_PAYLOAD.Destination]
    jz .rearm_rx_silent                    ;

    ; our turn, ignore incoming comms
    mov al, byte [rel current_color]
    cmp al, byte [rel local_color]
    je .rearm_rx_silent                  

    ; game over, ignore any moves
    cmp byte [rel match_state], 0
    jne .rearm_rx_silent                 


    mov al, byte [rel rx_data + MOVE_PAYLOAD.Origin]
    cmp al, byte [rel last_remote_move + MOVE_PAYLOAD.Origin]
    jne .accept_move
    mov al, byte [rel rx_data + MOVE_PAYLOAD.Destination]
    cmp al, byte [rel last_remote_move + MOVE_PAYLOAD.Destination]
    je .rearm_rx_silent

.accept_move:
    ; this is not a duplicate, accept
    mov al, byte [rel rx_data + MOVE_PAYLOAD.Origin]
    mov byte [rel last_remote_move + MOVE_PAYLOAD.Origin], al
    mov al, byte [rel rx_data + MOVE_PAYLOAD.Destination]
    mov byte [rel last_remote_move + MOVE_PAYLOAD.Destination], al

    ; all fine, proceed with making the move
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
    jne .update_remote_ui
    
    movzx rbx, byte [rel promotion_sq]
    mov al, byte [rel rx_data + MOVE_PAYLOAD.Promotion]
    lea rcx, [rel board]
    mov byte [rcx + rbx], al
    mov byte [rel promotion_pending], 0
    call promotion_interrupt_resolved
    jmp .update_remote_ui
.sync_ok:
    mov byte [rel connection_status], CONNECTION_STATE_CONNECTED

    mov byte [rel rematch_state], 0 ; reset the match state, you will never start in an endgame

    movzx rdi, word [rel rx_data + MOVE_PAYLOAD.Destination] 
    call generate_chess960_board     
    
    lea rsi, [rel initial_board]
    lea rdi, [rel board]
    mov rcx, 128
    rep movsb                        

    call calculate_board_layout                       
    mov byte [rel cursor_is_saved], 0     
    mov byte [rel in_menu], MENU_STATE_IN_GAME
    jmp .update_remote_ui

.remote_left:
    mov byte [rel rematch_state], 3  ; opponent left, you shall not click the button
                                     ; even if you do, you don't
    jmp .rearm_rx_silent

.remote_reset:
    ; C960 remote reset
    ; cmp byte [rel chess960_mode], 1
    ; jne .check_rematch_state
    cmp byte [rel net_role], NET_ROLE_CLIENT
    jne .check_rematch_state
    
    movzx rdi, byte [rel rx_data + MOVE_PAYLOAD.Promotion]
    shl rdi, 8                                        
    movzx rax, byte [rel rx_data + MOVE_PAYLOAD.Destination] 
    or rdi, rax                                          
    call generate_chess960_board

.check_rematch_state:
    cmp byte [rel rematch_state], 1
    je .remote_accepts               ; rematch accepted

    ; reamtch pending (on us)
    mov byte [rel rematch_state], 2
    jmp .update_remote_ui
    
.remote_accepts:
    xor byte [rel local_color], 1    
    call reset_game                 
    mov byte [rel cursor_is_saved], 0
    jmp .update_remote_ui
    
.skip_remote_regen:
    call reset_game
    mov byte [rel cursor_is_saved], 0
    jmp .update_remote_ui

.remote_offer_draw:
    mov dword [rel ui_action_state], ACTION_STATE_INCOMING_DRAW
    jmp .update_remote_ui

.remote_accept_draw:
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    mov byte [rel match_state], 3  
    jmp .update_remote_ui

.remote_surrender:
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    mov al, byte [rel local_color]
    inc al                           
    mov byte [rel match_state], al
    jmp .update_remote_ui

.update_remote_ui:
    ; UI changes detected, redraw
    ; cmp byte [rel in_menu], MENU_STATE_IN_GAME
    ; jne .rearm_rx_silent

    ; don't bother, the whole thing will get nuked anyway
    mov byte [rel cursor_is_saved], 0

    call render_playfield
    call draw_endgame_popup   
    call swap_buffers

.rearm_rx_silent:
    ; no heavy-handed UI reloading
    mov dword [rel rx_packet_data + 4], 3
    mov dword [rel rx_packet_data + 16], 3
    mov byte [rel is_remote_move], 0  
    mov byte [rel cursor_is_saved], 0
    call queue_network_rx
    jmp .drain_tx_ring



.done:
    cmp byte [rel needs_ack], 1
    jne .exit                        ; no need to send an ACK
    mov byte [rel needs_ack], 0    

    ; 10ms for the networking chip to actually process the packet
    mov rcx, 10000               
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + 248]             ; EFI_BOOT_SERVICES.Stall
    sub rsp, 32                      
    call rax
    add rsp, 32
    
    mov cl, 0xDD
    mov dl, 0xDD
    xor r8b, r8b
    call send_network_move           ; send a single ACK every frame
.exit:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret