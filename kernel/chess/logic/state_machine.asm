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
    lea rbx, [rel board]
    movzx rdx, al                    ; rdx: starting square

    ; copy to be sent over the network
    mov byte [rel last_local_move + MOVE_PAYLOAD.Origin], dl
    mov byte [rel last_local_move + MOVE_PAYLOAD.Destination], r8b
    mov byte [rel last_local_move + MOVE_PAYLOAD.Promotion], 0
    
    ; move the piece
    mov cl, byte [rbx + rdx]
    mov r10b, byte [rbx + r8]       ; r10b: target square's piece
    mov byte [rbx + r8], cl
    
    ; clear the square the piece just left
    mov byte [rbx + rdx], EMPTY


.castling_and_rights:
    push rcx                       

    cmp cl, W_KING
    je .handle_white_king
    cmp cl, B_KING
    je .handle_black_king
    
    ; not a king
    jmp .check_rook_violations       

.handle_white_king:
    cmp r8b, 0x76                    ; WK -> G1?
    je .wk_kingside
    cmp r8b, 0x72                    ; WK -> C1?
    je .wk_queenside
    jmp .revoke_all_rights_w         ; regular WK move

.wk_kingside:
    movzx r9, byte [rel WRh_start]
    mov byte [rbx + r9], EMPTY       ; clear WRh starting square
    mov byte [rbx + 0x75], W_ROOK    ; WRh -> F1
    mov byte [rbx + 0x76], W_KING    ; WK -> G1 (Chess960 edge case)
    jmp .revoke_all_rights_w

.wk_queenside:
    movzx r9, byte [rel WRa_start]
    mov byte [rbx + r9], EMPTY
    mov byte [rbx + 0x73], W_ROOK    ; WRa -> D1
    mov byte [rbx + 0x72], W_KING    ; WK -> C1
    jmp .revoke_all_rights_w

.revoke_all_rights_w:
    mov byte [rel w_castle_k], 0
    mov byte [rel w_castle_q], 0
    jmp .is_capture

.handle_black_king:
    cmp r8b, 0x06                    ; BK -> G8?
    je .bk_kingside
    cmp r8b, 0x02                    ; BK -> C8?
    je .bk_queenside
    jmp .revoke_all_rights_b

.bk_kingside:
    movzx r9, byte [rel BRh_start]
    mov byte [rbx + r9], EMPTY
    mov byte [rbx + 0x05], B_ROOK    ; BRh -> F8
    mov byte [rbx + 0x06], B_KING    ; BK -> G8
    jmp .revoke_all_rights_b

.bk_queenside:
    movzx r9, byte [rel BRa_start]
    mov byte [rbx + r9], EMPTY
    mov byte [rbx + 0x03], B_ROOK    ; BRa -> D8
    mov byte [rbx + 0x02], B_KING    ; BK -> C8
    jmp .revoke_all_rights_b

.revoke_all_rights_b:
    mov byte [rel b_castle_k], 0
    mov byte [rel b_castle_q], 0
    jmp .is_capture

.check_rook_violations:

    ; check for rights violations
    ; 12 possible castling-right-voiding scenarios:
    ; - WK/BK moves
    ; - WRa/BRa moves
    ; - WRh/BRh moves
    ; - any of the 4 rooks is captured
    ; - B/W already castled

    ; there are also temporary blocks:
    ; - path occupied
    ; - path under attack
    ; - currently in check

    cmp dl, byte [rel WRa_start]     ; did WRa move?
    je .revoke_WQ
    cmp r8b, byte [rel WRa_start]    ; was WRa captured?
    je .revoke_WQ
    jmp .check_WRh

.revoke_WQ:
    mov byte [rel w_castle_q], 0

.check_WRh:
    cmp dl, byte [rel WRh_start]
    je .revoke_WK
    cmp r8b, byte [rel WRh_start]
    je .revoke_WK
    jmp .check_BRa

.revoke_WK:
    mov byte [rel w_castle_k], 0

.check_BRa:
    cmp dl, byte [rel BRa_start]
    je .revoke_BQ
    cmp r8b, byte [rel BRa_start]
    je .revoke_BQ
    jmp .check_BRh

.revoke_BQ:
    mov byte [rel b_castle_q], 0

.check_BRh:
    cmp dl, byte [rel BRh_start]
    je .revoke_BK
    cmp r8b, byte [rel BRh_start]
    je .revoke_BK
    jmp .is_capture

.revoke_BK:
    mov byte [rel b_castle_k], 0
    jmp .is_capture

    
.is_capture:
    ; a move is a capture 
    ; when the target square contains an enemy piece

    pop rcx ; from castling 

    cmp r10b, 6
    jg .target_black
.target_white:
    test r10b, r10b 
    jz .capture_check_done
    movzx r11, byte[rel current_color]
    jmp .capture_check_done
.target_black:
    cmp r10b, 12
    jg .invalid_capture
    movzx r11, byte[rel current_color]
    not r11
    and r11, 1
    jmp .capture_check_done
.invalid_capture:
    and r10, 0xff
    LOG "An invalid capture of piece ID %d was attempted.", r10
    jmp .cancel_selection

.capture_check_done:

    ; if the move was EP, clear the EP target
    ; EP happens when:
    ; 1. EP target is not null
    ; 2. a pawn capture just occurred
    ; 3. moved pawn is now directly in front/back of the EP_target (color-relative)
    ; 3. holds because a double push must skip an empty square
.ep_check:
    cmp byte [rel en_passant_target], 0xff
    je .ep_check_done

    cmp r8b, byte [rel en_passant_target]
    jne .ep_check_done

    cmp cl, W_PAWN
    je .white_is_ep
    cmp cl, B_PAWN
    je .black_is_ep
    jmp .ep_check_done

.white_is_ep:
    ; white pawn moving up
    ; the captured black pawn is 0x10 below the target.
    movzx rdx, r8b
    add rdx, 0x10
    mov byte [rbx + rdx], EMPTY
    jmp .ep_check_done

.black_is_ep:
    ; black pawn moving down
    ; the captured white pawn is 0x10 above the target.
    movzx rdx, r8b
    sub rdx, 0x10
    mov byte [rbx + rdx], EMPTY
.ep_check_done:    
    ; reset selection
    mov byte [rel selected_square], 0xFF
    mov byte [rel valid_moves_count], 0

    ; only a double push can set the EP
    cmp cl, W_PAWN
    je .check_white_double_push
    cmp cl, B_PAWN
    je .check_black_double_push
    jmp .clear_ep                    ; any non-pawn move MUST clear the EP target

.check_white_double_push:
    mov rax, r8                      ; copy target square
    add rax, 0x20
    cmp rax, rdx                     ; target + 0x20 == source?
    jne .clear_ep                    ; if not, clear the EP
    
    mov rax, r8
    add rax, 0x10
    mov byte [rel en_passant_target], al
    jmp .check_for_promotion         ; don't clear EP target, is was just set

.check_black_double_push:
    mov rax, r8
    sub rax, 0x20
    cmp rax, rdx                     ; target - 0x20 == source?
    jne .clear_ep
    
    mov rax, r8
    sub rax, 0x10
    mov byte [rel en_passant_target], al
    jmp .check_for_promotion        

.clear_ep:
    mov byte [rel en_passant_target], 0xFF 

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

    jmp .done


.done:
    pop r11
    pop r10
    mov rsp, rbp
    pop rbp
    ret