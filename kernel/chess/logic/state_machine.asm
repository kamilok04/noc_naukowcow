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
    
    ; move the piece
    mov cl, byte [rbx + rdx]
    mov r10b, byte [rbx + r8]       ; r10b: target square's piece
    mov byte [rbx + r8], cl
    
    ; clear the square the piece just left
    mov byte [rbx + rdx], EMPTY


.castling_and_rights:

  

    ; consider castling
    push rcx 

    ; have we just castled?
    ; there are 4 possible layouts after a castling is done
    ; 1. WK @ G1, WRh @ F1
    ; 2. WK @ C1, WRa @ D1
    ; 3. BK @ G8, BRh @ F8
    ; 4. BK @ C8, BRa @ D8
    ; this is compatible with Chess960 too 
    cmp cl, W_KING
    je .check_WK_castle
    cmp cl, B_KING
    je .check_BK_castle
    jmp .check_WK

.check_WK_castle:
    movzx r9, byte [rel WRh_start]
    cmp r8b, r9b                     ; castling towards Rh (O-O)
    je .wk_kingside
    
    movzx r9, byte [rel WRa_start]
    cmp r8b, r9b                     ; castling towards Ra (O-O-O)
    je .wk_queenside
    
    jmp .revoke_all_rights_w            
    
.wk_kingside:
    ; clear wherever the king left from
    mov byte [rbx + r8], EMPTY       
    
    ; king must be on G1
    mov byte [rbx + 0x76], W_KING
    
    ; rook must be on F1
    mov byte [rbx + 0x75], W_ROOK       
    jmp .revoke_all_rights_w
.wk_queenside:
    mov byte[rbx + r8], EMPTY
    mov byte[rbx + 0x72], W_KING
    mov byte[rbx + 0x73], W_ROOK

.revoke_all_rights_w:
    mov byte [rel w_castle_k], 0
    mov byte [rel w_castle_q], 0
    jmp .is_capture

.check_BK_castle:
    movzx r9, byte [rel BRh_start]
    cmp r8b, r9b                     ; castling towards Rh (O-O)
    je .bk_kingside
    
    movzx r9, byte [rel BRa_start]
    cmp r8b, r9b                     ; castling towards Ra (O-O-O)
    je .bk_queenside
    
    jmp .revoke_all_rights_b           
    
.bk_kingside:
    ; clear wherever the king left from
    mov byte [rbx + r8], EMPTY       
    
    ; king must be on G8
    mov byte [rbx + 0x06], W_KING
    
    ; rook must be on F8
    mov byte [rbx + 0x05], W_ROOK       
    jmp .revoke_all_rights_b

.bk_queenside:
    mov byte[rbx + r8], EMPTY
    mov byte[rbx + 0x02], B_KING
    mov byte[rbx + 0x03], B_ROOK

.revoke_all_rights_b:
    mov byte [rel b_castle_k], 0
    mov byte [rel b_castle_q], 0
    jmp .is_capture

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

.check_WK:
    mov cl, byte [rel WK_start]
    cmp cl, dl
    jne .check_WRa
    ; it is, white can't castle
    mov byte [rel w_castle_k], 0
    mov byte [rel w_castle_q], 0
    jmp .is_capture

.check_WRa:
    mov cl, byte [rel WRa_start]
    cmp cl, dl
    je .revoke_WQ
    mov cl, byte [rel WRa_start]
    cmp cl, dl
    jne .check_WRh
.revoke_WQ:
    mov byte [rel w_castle_q], 0
    jmp .is_capture

.check_WRh:
    mov cl, byte [rel WRh_start]
    cmp cl, dl
    je .revoke_WK
    mov cl, byte [rel WRh_start]
    cmp cl, dl
    jne .check_BK
.revoke_WK:
    mov byte [rel w_castle_k], 0
    jmp .is_capture

.check_BK:
    cmp rdx, 0x04 ; E8
    jne .check_BRa
    mov byte [rel b_castle_k], 0
    mov byte [rel b_castle_q], 0
    jmp .is_capture

.check_BRa:
    mov cl, byte [rel BRa_start]
    cmp cl, dl
    je .revoke_BQ
    mov cl, byte [rel BRa_start]
    cmp cl, dl
    jne .check_BRh
.revoke_BQ:
    mov byte [rel b_castle_q], 0
    jmp .is_capture

.check_BRh:
    mov cl, byte [rel BRh_start]
    cmp cl, dl
    je .revoke_BK
    mov cl, byte [rel BRh_start]
    cmp cl, dl
    jne .is_capture

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

    ; update the EP target
    ; if it was a double push, EP_target = skipped square
    ; else EP_target = null

    ; double push happens when:
    ; - the moved piece is a pawn
    ; - the source is the destination +/- 0x20 (color-relative)
    ; then, EP_target is the source/destination +/- 0x10
    cmp cl, W_PAWN
    jne .check_black_ep
.white_pawn_set_ep:
    push rcx
    mov rcx, r8
    add rcx, 0x20
    cmp rcx, rdx
    jne .clear_ep
    sub rcx, 0x10
    ; EP target after a white move
    ; must be 0x50-0x57
    cmp rcx, 0x50
    jl .clear_ep
    cmp rcx, 0x57
    jg .clear_ep
    LOG "EP set to %x", rcx
    mov byte [rel en_passant_target], cl
    jmp promotion_interrupt_resolved.change_color

.check_black_ep:
    cmp cl, B_PAWN
    jne promotion_interrupt_resolved.change_color
.black_pawn_set_ep:
    push rcx
    mov rcx, r8
    sub rcx, 0x20
    cmp rcx, rdx
    jne .clear_ep
    add rcx, 0x10
    ; EP target after a black pawn move
    ; must be 0x20-0x27
    cmp cl, 0x20
    jl .clear_ep
    cmp cl, 0x27
    jg .clear_ep
    ; LOG "EP set to %x", rcx
    mov byte [rel en_passant_target], cl
    
    jmp promotion_interrupt_resolved.change_color
    

.clear_ep:
    pop rcx
    mov byte[rel en_passant_target], 0xff
    jmp .check_for_promotion         

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

  ; failsafe: logic should have been unpaused by now
    test byte[rel promotion_pending], 0 
    jne .invalid_processing
.invalid_processing:
    LOG "State machine is running without permission!!"
    ; fall through?


.change_color:
    ; flip the color byte
    xor byte [rel current_color], 1
    jmp .done


.done:
    pop r11
    pop r10
    mov rsp, rbp
    pop rbp
    ret