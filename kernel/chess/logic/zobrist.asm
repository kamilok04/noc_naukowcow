; ------------------------------------------------------------------------------
; init_zobrist
; Fills the Zobrist boards with pseudo-random keys
; ------------------------------------------------------------------------------
init_zobrist:
    push rbx
    push rcx
    mov rax, 0x123456789ABCDEF0      ; initial seed
    
    ; board and piece combos (13 * 64 * 2 = 1664)
    ; "this piece on that square" will get its own unique
    lea rbx, [rel zobrist_pieces]
    mov rcx, 1664
.fill_pieces:
    call .xorshift
    mov [rbx], rax
    add rbx, 8
    dec rcx
    jnz .fill_pieces
    
    ; compute initial values
    call .xorshift
    mov [rel zobrist_color], rax
    
    ; 4 types of castling right
    lea rbx, [rel zobrist_castling]
    mov rcx, 4
.fill_castle:
    call .xorshift
    mov [rbx], rax
    add rbx, 8
    dec rcx
    jnz .fill_castle
    
    ; 8 types of EP
    lea rbx, [rel zobrist_ep]
    mov rcx, 8
.fill_ep:
    call .xorshift
    mov [rbx], rax
    add rbx, 8
    dec rcx
    jnz .fill_ep
    
    pop rcx
    pop rbx
    ret


.xorshift:
    ; xorshift64
    ; a=13, b=7, c=17
    mov r8, rax
    shl r8, 13
    xor rax, r8
    mov r8, rax
    shr r8, 7
    xor rax, r8
    mov r8, rax
    shl r8, 17
    xor rax, r8
    ret

; ------------------------------------------------------------------------------
; compute_zobrist
; Outputs: RAX: hash of current state
; ------------------------------------------------------------------------------
compute_zobrist:
    push rbx
    push rcx
    push rdx
    push rsi
    xor rax, rax                     ; hash 
    
    ; pieces on fields
    xor rcx, rcx                     
.piece_loop:
    test rcx, 0x88
    jnz .next_sq
    
    lea rbx, [rel board]
    movzx rdx, byte [rbx + rcx]
    test rdx, rdx
    jz .next_sq
    
    mov r8, rcx                      ; R8 = direct 0x88 square index (0 to 0x77)
    mov r9, rdx                      ; R9 = piece ID 
    shl r9, 7                        ; R9 = id * 128 
    add r8, r9                       ; R8 = piece_type * 128 + square_index
    
    ; update the state
    lea rbx, [rel zobrist_pieces]
    xor rax, qword [rbx + r8 * 8]
    

.next_sq:
    inc rcx
    cmp rcx, 0x78
    jl .piece_loop
    
    ; color matters for repetition
    cmp byte [rel current_color], 1
    jne .check_castle
    xor rax, qword [rel zobrist_color]
    
    ; so do castling rights
.check_castle:
    lea rbx, [rel zobrist_castling]
    cmp byte [rel w_castle_k], 1
    jne .w_q
    xor rax, qword [rbx + 0]
.w_q:
    cmp byte [rel w_castle_q], 1
    jne .b_k
    xor rax, qword [rbx + 8]
.b_k:
    cmp byte [rel b_castle_k], 1
    jne .b_q
    xor rax, qword [rbx + 16]
.b_q:
    cmp byte [rel b_castle_q], 1
    jne .check_ep
    xor rax, qword [rbx + 24]
    
    ; and EP rights
.check_ep:
    movzx rcx, byte [rel en_passant_target]
    cmp rcx, 0xFF
    je .done
    
    and rcx, 7                       
    lea rbx, [rel zobrist_ep]
    xor rax, qword [rbx + rcx * 8]
    
.done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret