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
    jmp .done

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
    
.is_capture:
    ; a move is a capture 
    ; when the target square contains an enemy piece
    cmp r10b, 6
    jg .target_black
.target_white:
    test r10b, r10b 
    jz .capture_check_done
    movzx r11, byte[rel current_color]
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

    ; pawn capture
    cmp cl, W_PAWN
    je .white_ep_square_check
    cmp cl, B_PAWN
    jne .black_ep_square_check
    cmp r11b, 1
    jne .ep_check_done

    ; is the target piece directly in front/back of target
    cmp byte[rel current_color], 0 ; is white?
    jne .black_ep_square_check
.white_ep_square_check:
    push rcx
    push rdx 
    movzx rcx, byte[rel en_passant_target]
    ; remove whatever is 0x10 over the target
    mov rdx, rcx
    add rdx, 0x10
    cmp cl, r8b
    je .is_ep
    pop rdx
    pop rcx
    jmp .ep_check_done
.black_ep_square_check:
    push rcx 
    push rdx
    movzx rcx, byte[rel en_passant_target]
    ; remove whatever is 0x10 below the target
    mov rdx, rcx
    sub rdx, 0x10 ; will never set ZF due to EP clamping 
    cmp cl, r8b
    je .is_ep
    pop rdx
    pop rcx

    jmp .ep_check_done
.is_ep:
    ; cl is computed square, clear it
    LOG "This was an EP capture."
    mov byte[rbx + rdx], EMPTY
    pop rdx
    pop rcx
    ; an EP cannot be both used and set, skip
    ; jmp .clear_ep
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
    jmp .change_color

.check_black_ep:
    cmp cl, B_PAWN
    jne .change_color
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
    
    jmp .change_color
    

.clear_ep:
    pop rcx
    ; LOG "EP unset R8 = %x, RDX = %x.", r8, rdx
    mov byte[rel en_passant_target], 0xff
.change_color:
    ; flip the color byte
    xor byte [rel current_color], 1
    jmp .done

.off_board:
.cancel_selection:
    mov byte [rel selected_square], 0xFF
    mov byte [rel valid_moves_count], 0

.done:
    pop r11
    pop r10
    mov rsp, rbp
    pop rbp
    ret