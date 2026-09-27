; ------------------------------------------------------------------------------
; generate_chess960_board
; Generates a C960 starting position and updates initial_board.
; Inputs: RDI - Seed ID (0 to 959)
; ------------------------------------------------------------------------------
generate_chess960_board:
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
    
    ; ensure range
    mov rax, rdi
    mov rcx, 960
    xor rdx, rdx
    div rcx
    mov rdi, rdx             ; RDI = validated seed

    mov eax, edi
    lea rsi, [rel str_seed_display + 13] ; Point to the last digit slot
    mov ecx, 10
.itoa:
    xor edx, edx
    div ecx
    add dl, '0'
    mov byte [rsi], dl
    dec rsi
    test eax, eax
    jnz .itoa

    ; Pad remaining characters with spaces (cleans up old digits)
.pad_spaces:
    lea rcx, [rel str_seed_display + 11] 
    cmp rsi, rcx
    jl .done_itoa
    mov byte [rsi], ' '
    dec rsi
    jmp .pad_spaces
.done_itoa:
    mov rax, rdi

    ; white rank cache
    sub rsp, 8
    mov qword [rsp], 0
    mov r10, rsp

    ; 1. light-squared bishop
    mov rcx, 4
    xor rdx, rdx
    div rcx                  ; RAX = RAX / 4, RDX = RAX % 4
    mov rbx, rdx
    shl rbx, 1
    inc rbx                  ; RBX = RDX * 2 + 1 (1, 3, 5 or 7)
    mov byte [r10 + rbx], W_BISHOP

    ; 2. the other B
    xor rdx, rdx
    div rcx                  ; RAX = RAX / 4, RDX = RAX % 4
    mov rbx, rdx
    shl rbx, 1               ; RBX = RDX * 2 (0, 2, 4 or 6)
    mov byte [r10 + rbx], W_BISHOP

    ; 3. the queen
    mov rcx, 6
    xor rdx, rdx
    div rcx                  ; RAX = RAX / 6, RDX = RAX % 6
    mov r8b, dl
    call .place_nth_empty
    mov byte [r10 + rbx], W_QUEEN

    ; 4. the knigts
    ; RAX now holds 0-9. lookup the two sequential empty-square indices.
    lea r9, [rel knight_960_table]
    mov rsi, rax
    shl rsi, 1               ; RSI = RAX * 2 (2 bytes per entry)
    
    mov r8b, byte [r9 + rsi] ; first knight index
    call .place_nth_empty
    mov byte [rsp + rbx], W_KNIGHT
    
    mov r8b, byte [r9 + rsi + 1] ; second knight index
    call .place_nth_empty
    mov byte [rsp + rbx], W_KNIGHT

    ; 5. rooks & king
    ; grab the remaining empty squares
    ; first and third are rooks, second is king
    xor r8b, r8b
    call .place_nth_empty
    mov byte [rsp + rbx], W_ROOK
    mov byte [rel WRa_start], bl    
    add byte [rel WRa_start], 0x70   ; convert to 0x88 board notation

    call .place_nth_empty
    mov byte [rsp + rbx], W_KING
    mov byte [rel WK_start], bl      ; save king index
    add byte [rel WK_start], 0x70

    call .place_nth_empty
    mov byte [rsp + rbx], W_ROOK
    mov byte [rel WRh_start], bl     ; save h-side rook index
    add byte [rel WRh_start], 0x70
    
    ; write the changes
    lea rdi, [rel initial_board]
    mov rcx, 8
    xor rsi, rsi
.commit_loop:
    ; white back rank
    mov al, byte [rsp + rsi]
    mov byte [rdi + 0x70 + rsi], al
    
    ; black back rank (exact same, but ID + 6)
    add al, 6
    mov byte [rdi + rsi], al
    
    inc rsi
    dec rcx
    jnz .commit_loop
    
    ; mirror black position trackers
    mov al, byte [rel WK_start]
    sub al, 0x70
    mov byte [rel BK_start], al
    
    mov al, byte [rel WRa_start]
    sub al, 0x70
    mov byte [rel BRa_start], al
    
    mov al, byte [rel WRh_start]
    sub al, 0x70
    mov byte [rel BRh_start], al

    ; cleaning
    add rsp, 8
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

; helper: finds the n-th empty square in the [rsp] array
; Inputs: R8B = N (0-based)
; Outputs: RBX = index of the empty square (0-7)
.place_nth_empty:
    xor rbx, rbx
.empty_loop:
    cmp byte [r10 + rbx], 0  ; empty?
    jne .next_sq
    test r8b, r8b
    jz .found
    dec r8b
.next_sq:
    inc rbx
    jmp .empty_loop
.found:
    ret