; ------------------------------------------------------------------------------
; reset_game
; Restores the board and state tracking to turn 1.
; ------------------------------------------------------------------------------
reset_game:
    LOG "Restarting."
    push rax
    push rcx
    push rsi
    push rdi

    mov byte [rel rematch_state], 0 ; no rematch yet

    ; restore the board
    lea rsi, [rel initial_board]
    lea rdi, [rel board]
    mov rcx, 16
    rep movsq
    
    ; restore the game state
    mov byte [rel current_color], 0
    mov byte [rel match_state], 0
    mov byte [rel promotion_pending], 0
    mov byte [rel selected_square], 0xFF
    mov byte [rel en_passant_target], 0xFF
    mov byte [rel valid_moves_count], 0
    
    ; restore the castling rights
    mov byte [rel w_castle_k], 1
    mov byte [rel w_castle_q], 1
    mov byte [rel b_castle_k], 1
    mov byte [rel b_castle_q], 1

    ; wipe the transcript
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    mov word [rel transcript_count], 0
    mov word [rel transcript_scroll], 0
    
    ; wipe the buffer just in case
    lea rdi, [rel transcript_buffer]
    xor rax, rax
    mov rcx, 512                     
    rep stosq

    ; engage transcript auto-scroll again
    mov dword [rel ui_manual_scroll], -1

    ; clear dawr conditions
    mov qword [rel history_count], 0
    mov word [rel half_move_clock], 0
    
    call reset_start_trackers

    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret

; ------------------------------------------------------------------------------
; reset_start_trackers
; Reset the starting positions of king and rooks (for castling)
; ------------------------------------------------------------------------------
reset_start_trackers:
    push rbp
    mov rbp, rsp
    push rax
    push rcx
    push rbx
    push rdi
    mov rcx, 0x70
    xor rbx, rbx                     ; rook counter (0 = a-rook, 1 = h-rook)
    lea rdi, [rel initial_board]
.w_scan:
    mov al, byte [rdi + rcx]
    cmp al, W_KING
    jne .w_check_rook
    mov byte [rel WK_start], cl
    jmp .w_next
.w_check_rook:
    cmp al, W_ROOK
    jne .w_next
    test rbx, rbx
    jnz .w_h_rook
    mov byte [rel WRa_start], cl     ; first rook must be WQR
    inc rbx
    jmp .w_next
.w_h_rook:
    mov byte [rel WRh_start], cl     ; the other: WKR
.w_next:
    inc rcx
    cmp rcx, 0x78
    jl .w_scan

    mov rcx, 0x00
    xor rbx, rbx
.b_scan:
    mov al, byte [rdi + rcx]
    cmp al, B_KING
    jne .b_check_rook
    mov byte [rel BK_start], cl
    jmp .b_next
.b_check_rook:
    cmp al, B_ROOK
    jne .b_next
    test rbx, rbx
    jnz .b_h_rook
    mov byte [rel BRa_start], cl
    inc rbx
    jmp .b_next
.b_h_rook:
    mov byte [rel BRh_start], cl
.b_next:
    inc rcx
    cmp rcx, 0x08
    jl .b_scan

    pop rdi
    pop rbx
    pop rcx
    pop rax
    mov rsp, rbp
    pop rbp
    ret


