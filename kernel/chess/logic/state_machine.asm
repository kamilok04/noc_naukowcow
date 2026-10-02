; Handle movement in general.
; Inputs:
;   R8: target square
the_chess_state_machine:
    push rbp
    mov rbp, rsp
    push r10
    push r11    ; capture flag

    mov al, byte [rel selected_square]
    cmp al, 0xFF
    jne .action_phase
    
.selection_phase:
    ; immediately skip the promo click handler when possible
    ; an invalid click cannot possibly promote a pawn

    ; net logic: only control your color, ever
    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .skip_lock
    cmp byte [rel is_remote_move], 1
    je .skip_lock                    ; the engine itself is allowed, though
    
    mov bl, byte [rel current_color]
    cmp bl, byte [rel local_color]
    jne .cancel_selection

.skip_lock:

    lea rbx, [rel board]
    mov cl, byte [rbx + r8]          ; CL = piece ID
    test cl, cl
    jz .cancel_selection             ; you wouldn't download an empty square

    mov dl, byte [rel current_color]
    test dl, dl
    jnz .check_black_turn
    
.check_white_turn:
    cmp cl, 7
    jge .cancel_selection           ; don't move other player's pieces please
    jmp .make_selection

.check_black_turn:
    cmp cl, 7
    jl .cancel_selection             ; don't move other player's pieces please
    
.make_selection:
    ; this is a valid piece, pick it up
    ; LOG "Valid piece selected."
    mov byte [rel selected_square], r8b
    call generate_moves_for_square
    jmp promotion_interrupt_resolved.done

.action_phase:
    ; The user clicked a square while a piece is currently picked up (AL = selected square)
    ; check if that is a valid move
    movzx rcx, byte [rel valid_moves_count]
    test rcx, rcx
    jz .reselect                     ; no valid moves, don't bother
    
    lea rsi, [rel valid_moves_list]
.check_move_loop:
    cmp byte [rsi + rcx - 1], r8b
    je .execute_move                 ; do it
    dec rcx
    jnz .check_move_loop
    
.reselect:
    ; a click out-of-bounds happened in the action phase
    mov byte [rel selected_square], 0xFF
    mov byte [rel valid_moves_count], 0
    jmp .selection_phase

.execute_move:
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT ; move is made, deny whatever was done
    mov dword [rel ui_manual_scroll], -1 ; engage auto-scroll for current transcript
    ; al: starting square
    lea rbx, [rel board]
    movzx rdx, al

     ; copy to be sent over the network
    mov byte [rel last_local_move + MOVE_PAYLOAD.Origin], dl
    mov byte [rel last_local_move + MOVE_PAYLOAD.Destination], r8b
    mov byte [rel last_local_move + MOVE_PAYLOAD.Promotion], 0

    push rdx
    push r8

    mov cl, byte [rbx + rdx]         ; CL = moving piece ID
    mov r10b, byte [rbx + r8]        ; R10B = target piece ID

    ; 50-move clock
    cmp cl, 1                        ; w pawn?
    je .reset_clock
    cmp cl, 7                        ; b pawn?
    je .reset_clock
    test r10b, r10b                  ; capture?
    jnz .reset_clock                 ; note: this does NOT include en passant
                                     ; it's very much not a problem
                                     ; conveniently, EPs are exclusive to pawns
                                     ; either of the pawn clauses will catch EP
    
    inc word [rel half_move_clock]   ; neither, bump the clock
    jmp .clock_done
    
.reset_clock:
    mov word [rel half_move_clock], 0

.clock_done:
    push rdx
    push r8
    push rcx
    push r10
    call check_san_ambiguity
    pop r10
    pop rcx
    pop r8
    pop rdx

    mov cl, byte [rbx + rdx]
    mov r10b, byte [rbx + r8]
    call build_san_string

    pop r8
    pop rdx
    
    call make_move
    
    ; grab the moving piece to check for promotion
    lea rbx, [rel board]
    mov cl, byte [rbx + r8]
   

.check_for_promotion:
    cmp cl, 1                        ; White Pawn?
    je .check_white_promo
    cmp cl, 7                        ; Black Pawn?
    je .check_black_promo
    jmp promotion_interrupt_resolved.change_color

.check_white_promo:
    mov al, r8b
    and al, 0x70
    jnz promotion_interrupt_resolved.change_color  ; if not last rank, end turn
    jmp .trigger_promo

.check_black_promo:
    mov al, r8b
    and al, 0x70
    cmp al, 0x70
    jne promotion_interrupt_resolved.change_color  ; if not last rank, end turn
    
.trigger_promo:
    mov byte [rel promotion_pending], 1 
    mov byte [rel promotion_sq], r8b
    jmp promotion_interrupt_resolved.done          ; promotion, pause the logic


.off_board:
.cancel_selection:
    mov byte [rel selected_square], 0xFF
    mov byte [rel valid_moves_count], 0
    jmp promotion_interrupt_resolved.done
promotion_interrupt_resolved:
    push rbp
    mov rbp, rsp
    push r10
    push r11



.change_color:
    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .skip_tx
    cmp byte [rel is_remote_move], 1
    je .skip_tx                      ; DO NOT bounce network moves back!
    
    mov cl, byte [rel last_local_move + MOVE_PAYLOAD.Origin]
    mov dl, byte [rel last_local_move + MOVE_PAYLOAD.Destination]
    mov r8b, byte [rel last_local_move + MOVE_PAYLOAD.Promotion]
    call send_network_move
.skip_tx:
    ; flip the color byte
    xor byte [rel current_color], 1

.update_game_state:
    call update_match_state
    call append_san_evaluations
    call save_san_to_buffer

    jmp .done


.done:
    pop r11
    pop r10
    mov rsp, rbp
    pop rbp
    ret