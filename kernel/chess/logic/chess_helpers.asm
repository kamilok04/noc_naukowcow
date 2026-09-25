; ------------------------------------------------------------------------------
; See if a move is valid.
; This involves demo-ing the move and seeing if it results in something illegal
; add_valid_move
; Inputs: RAX - The 0x88 index of the valid move
; ------------------------------------------------------------------------------
add_valid_move:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11

    lea rbx, [rel board]
    movzx rdx, al                    ; RDX = target square
    
    mov cl, byte [rbx + r8]          ; CL = moving piece
    mov r9b, byte [rbx + rdx]        ; R9B = target piece
    
    ; make the move for a moment
    mov byte [rbx + rdx], cl        
    mov byte [rbx + r8], EMPTY      
    
    mov r10b, 0xFF                   ; R10B = flag for EP (0xFF = null)
    cmp al, byte [rel en_passant_target]
    jne .eval_king                   ; Not targeting EP square
    
    cmp cl, 1                        ; W_PAWN
    je .w_ep_capture
    cmp cl, 7                        ; B_PAWN
    je .b_ep_capture
    jmp .eval_king                   ; Not a pawn

.w_ep_capture:
    movzx r11, al
    add r11, 0x10
    mov r10b, byte [rbx + r11]       ; Backup captured piece (should be B_PAWN)
    mov byte [rbx + r11], EMPTY      ; Annihilate the capture piece
    jmp .eval_king

.b_ep_capture:
    movzx r11, al
    sub r11, 0x10
    mov r10b, byte [rbx + r11]       ; Backup captured piece (should be W_PAWN)
    mov byte [rbx + r11], EMPTY

.eval_king:
    ; is the move actually safe?
    push rax
    call verify_king_safety
    
    mov rdi, rax                     ; RDI = 1 (safe) or 0 (attacked)
    pop rax
    
    ; unwind the board
    mov byte [rbx + r8], cl
    mov byte [rbx + rdx], r9b

    cmp r10b, 0xFF
    je .check_result
    
    cmp cl, 1
    je .w_ep_restore

.b_ep_restore:
    movzx r11, al
    sub r11, 0x10
    mov byte [rbx + r11], r10b
    jmp .check_result

.w_ep_restore:
    movzx r11, al
    add r11, 0x10
    mov byte [rbx + r11], r10b

.check_result:
    test rdi, rdi                    
    jz .done                         ; If RDI was 0 (attacked), discard the move

    ; Move is safe, add it to the valid moves list
    movzx rcx, byte [rel valid_moves_count]
    push rbx
    lea rbx, [rel valid_moves_list]
    mov byte [rbx + rcx], al         
    inc rcx
    mov byte [rel valid_moves_count], cl
    pop rbx

.done:
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    mov rsp, rbp
    pop rbp
    ret