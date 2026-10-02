; ------------------------------------------------------------------------------
; init_zobrist
; Fills the Zobrist boards with pseudo-random keys
; ------------------------------------------------------------------------------
init_zobrist:
    push rbx
    push rcx
    mov rax, 0x123456789ABCDEF0      ; initial seed
    
    ; board and piece combos (13 * 64 = 832)
    ; "this piece on that square" will get its own unique
    lea rbx, [rel zobrist_pieces]
    mov rcx, 832
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
    
    ; network state has 128 fields
    ; hashing has 64
    ; convert
    mov r8, rcx
    mov r9, rcx
    and r8, 7                        ; R8 = column
    shr r9, 4                        ; R9 = row (0-7)
    shl r9, 3                        ; R9 = 8*row
    add r8, r9                       ; R8 = square index
    
    
    mov r9, rdx                      ; R9 = ID 
    shl r9, 6                        ; R9 = ID * 64 "move id to square"
    add r8, r9                       ; R8 = compressed index
    
    ; update the state
    lea rbx, [rel zobrist_pieces]
    xor rax, qword [rbx + r8 * 8]
    

.next_sq:
    inc rcx
    cmp rcx, 64
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