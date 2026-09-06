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
; In the future, this will hold a position tracker and some dynamic updates.
; For now, hardcode standard chess layout.
reset_start_trackers:
    push rbp
    mov rbp, rsp

    mov byte[rel WK_start],     0x74    
    mov byte[rel WRa_start],    0x70
    mov byte[rel WRh_start],    0x77
    mov byte[rel BK_start],     0x04
    mov byte[rel BRa_start],    0x00
    mov byte[rel BRh_start],    0x07

    mov rsp, rbp
    pop rbp
    ret



