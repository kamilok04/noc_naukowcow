; ------------------------------------------------------------------------------
; check_castling
; Checks castling eligibility.
;
; Inputs: 
;   R8 - The 0x88 index of the king (0x74 for WK, 0x04 for BK)
;   Any other value of R8 will make this routine a no-op.
; ------------------------------------------------------------------------------
; A digression about rules of the game:
; 1. Draws by repetition
;    A draw may be claimed if a position 
;    is repeated 3 times    (and it's a forced draw 
;                           on 5 repeats)
;    However, any two positions with
;    identical piece setup are different
;    if their castling rights state differs.
;    GMs get caught by that sometimes too
;    https://www.chessgames.com/perl/chessgame?gid=1068512
; 2. Castling when under attack
;    You cannot castle when your king is attacked.
;    Your king cannot cross an attacked square 
;    during castling.
;    None of that applies to the rook.
;    GMs getting caught:
;    https://www.chessgames.com/perl/chessgame?gid=1067831
; 3. Handicaps
;    This is less relevant here, but still fun
;    On occasion, the board would be setup with WRa missing,
;    giving Black an advantage. (mostly XIX-century games)
;    There has never been an agreement 
;    on K-side castling remaining legal

;    there's an absolute banger of a quote on that
;       "No, you don’t, you can’t castle without a castle"
;    more: https://www.chesshistory.com/winter/extra/castling.html

;    Castling, if allowed, would then be
;    x. Kc1 ...
;    (old notation for reference)
;    x. K-K-QKtsq ...
; -----------------------------------------------------------------------
check_castling:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9                  
    push r10                 

    ; ensure R8 actually contains a king
    cmp r8b, byte [rel WK_start]
    je .source_ok
    cmp r8b, byte [rel BK_start]
    je .source_ok
    jmp .done
    
.source_ok:
    ; clone board for threat detection
    lea rsi, [rel board]
    lea rdi, [rel sandbox_board]
    mov rcx, 16
    rep movsq

    ; Cannot castle out of a check
    call is_square_attacked
    test rax, rax
    jnz .done               

    mov al, byte [rel current_color]
    test al, al
    jnz .check_black

.check_white:
    ; O-O
    cmp byte [rel w_castle_k], 1
    jne .white_queenside
    
    ; left edge: min(WK_start, 0x75)
    ; this is guaranteed because the kingside rook
    ; must be on the kingside (!)
    ; and no further then 0x75, as th
    ; Regardless of starting setup, king must be between rooks.
    mov r9b, byte [rel WK_start]
    cmp r9b, 0x75
    jl .wk_min_set
    mov r9b, 0x75
.wk_min_set:
    
    ; right edge: max(WRh_start, 0x76)
    mov r10b, byte [rel WRh_start]
    cmp r10b, 0x76
    jg .wk_max_set
    mov r10b, 0x76
.wk_max_set:

    ; scan interval [r9b, r10b]
.wk_empty_loop:
    cmp r9b, r10b
    jg .wk_empty_ok
    cmp r9b, byte [rel WK_start]     ; ignore the king
    je .wk_empty_next
    cmp r9b, byte [rel WRh_start]   ; ignore the rook
    je .wk_empty_next
    lea rbx, [rel board]                 ; empty?
    movzx r11, r9b
    cmp byte [rbx + r11], EMPTY
    jne .white_queenside                 ; no
.wk_empty_next:
    inc r9b
    jmp .wk_empty_loop

.wk_empty_ok:
    ; validate path towards king's rook
    mov r9b, byte [rel WK_start]
.wk_atk_loop:
    cmp r9b, 0x76
    jg .wk_safe
    movzx r8, r9b
    call is_square_attacked
    test rax, rax
    jnz .white_queenside                 ; attack on the path 
    inc r9b
    jmp .wk_atk_loop

.wk_safe:
    mov rax, 0x76
    movzx r8, byte [rel WK_start]
    push rax
    call add_valid_move
    pop rax


.white_queenside:
    ; o-o-o
    cmp byte [rel w_castle_q], 1
    jne .check_black
    
    ; same idea with edge detection
    mov r9b, byte [rel WRa_start]
    cmp r9b, 0x72
    jl .wq_min_set
    mov r9b, 0x72
.wq_min_set:
    
    mov r10b, byte [rel WK_start]
    cmp r10b, 0x73
    jg .wq_max_set
    mov r10b, 0x73
.wq_max_set:

.wq_empty_loop:
    cmp r9b, r10b
    jg .wq_empty_ok
    cmp r9b, byte [rel WK_start]
    je .wq_empty_next
    cmp r9b, byte [rel WRa_start]
    je .wq_empty_next
    lea rbx, [rel board]
    movzx r11, r9b
    cmp byte [rbx + r11], EMPTY
    jne .check_black
.wq_empty_next:
    inc r9b
    jmp .wq_empty_loop

.wq_empty_ok:
    mov r9b, byte [rel WK_start]
    mov r10b, 0x72
    cmp r9b, r10b
    jle .wq_atk_set
    xchg r9b, r10b                       ; swap the borders, as we're moving left
.wq_atk_set:
.wq_atk_loop:
    cmp r9b, r10b
    jg .wq_safe
    movzx r8, r9b
    call is_square_attacked
    test rax, rax
    jnz .check_black
    inc r9b
    jmp .wq_atk_loop

.wq_safe:
    mov rax, 0x72
    movzx r8, byte [rel WK_start]
    push rax
    call add_valid_move
    pop rax
    jmp .done

; analogous logic for black castling
.check_black:
    ; o-o
    cmp byte [rel b_castle_k], 1
    jne .black_queenside
    
    mov r9b, byte [rel BK_start]
    cmp r9b, 0x05
    jl .bk_min_set
    mov r9b, 0x05
.bk_min_set:
    
    mov r10b, byte [rel BRh_start]
    cmp r10b, 0x06
    jg .bk_max_set
    mov r10b, 0x06
.bk_max_set:

.bk_empty_loop:
    cmp r9b, r10b
    jg .bk_empty_ok
    cmp r9b, byte [rel BK_start]
    je .bk_empty_next
    cmp r9b, byte [rel BRh_start]
    je .bk_empty_next
    lea rbx, [rel board]
    movzx r11, r9b
    cmp byte [rbx + r11], EMPTY
    jne .black_queenside
.bk_empty_next:
    inc r9b
    jmp .bk_empty_loop

.bk_empty_ok:
    mov r9b, byte [rel BK_start]
.bk_atk_loop:
    cmp r9b, 0x06
    jg .bk_safe
    movzx r8, r9b
    call is_square_attacked
    test rax, rax
    jnz .black_queenside
    inc r9b
    jmp .bk_atk_loop

.bk_safe:
    mov rax, 0x06
    movzx r8, byte [rel BK_start]
    push rax
    call add_valid_move
    pop rax

.black_queenside:
    ; o-o-o
    cmp byte [rel b_castle_q], 1
    jne .done
    
    mov r9b, byte [rel BRa_start]
    cmp r9b, 0x02
    jl .bq_min_set
    mov r9b, 0x02
.bq_min_set:
    
    mov r10b, byte [rel BK_start]
    cmp r10b, 0x03
    jg .bq_max_set
    mov r10b, 0x03
.bq_max_set:

.bq_empty_loop:
    cmp r9b, r10b
    jg .bq_empty_ok
    cmp r9b, byte [rel BK_start]
    je .bq_empty_next
    cmp r9b, byte [rel BRa_start]
    je .bq_empty_next
    lea rbx, [rel board]
    movzx r11, r9b
    cmp byte [rbx + r11], EMPTY
    jne .done
.bq_empty_next:
    inc r9b
    jmp .bq_empty_loop

.bq_empty_ok:
    mov r9b, byte [rel BK_start]
    mov r10b, 0x02
    cmp r9b, r10b
    jle .bq_atk_set
    xchg r9b, r10b
.bq_atk_set:
.bq_atk_loop:
    cmp r9b, r10b
    jg .bq_safe
    movzx r8, r9b
    call is_square_attacked
    test rax, rax
    jnz .done
    inc r9b
    jmp .bq_atk_loop

.bq_safe:
    mov rax, 0x02
    movzx r8, byte [rel BK_start]
    push rax
    call add_valid_move
    pop rax

.done:
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    mov rsp, rbp
    pop rbp
    ret