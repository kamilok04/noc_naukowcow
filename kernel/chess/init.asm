; ------------------------------------------------------------------------------
; init_chess_board
; Populates the 128-byte array with the standard starting pieces.
; ------------------------------------------------------------------------------
init_chess_board:
    lea rbx, [rel board]

    ; białe (0x00-0x07)
    mov byte [rbx + 0x00], W_ROOK
    mov byte [rbx + 0x01], W_KNIGHT
    mov byte [rbx + 0x02], W_BISHOP
    mov byte [rbx + 0x03], W_QUEEN
    mov byte [rbx + 0x04], W_KING
    mov byte [rbx + 0x05], W_BISHOP
    mov byte [rbx + 0x06], W_KNIGHT
    mov byte [rbx + 0x07], W_ROOK

    ; czarne (0x70-0x77)
    mov byte [rbx + 0x70], B_ROOK
    mov byte [rbx + 0x71], B_KNIGHT
    mov byte [rbx + 0x72], B_BISHOP
    mov byte [rbx + 0x73], B_QUEEN
    mov byte [rbx + 0x74], B_KING
    mov byte [rbx + 0x75], B_BISHOP
    mov byte [rbx + 0x76], B_KNIGHT
    mov byte [rbx + 0x77], B_ROOK

    ; piony
    mov rcx, 8
    xor rdi, rdi
.pawn_loop:
    mov byte [rbx + 0x10 + rdi], W_PAWN
    mov byte [rbx + 0x60 + rdi], B_PAWN
    inc rdi
    loop .pawn_loop

    ret