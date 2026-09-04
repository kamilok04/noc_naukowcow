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

    lea rsi, [rel board]            
    lea rdi, [rel sandbox_board]    
    mov rcx, 16                     
    rep movsq                         ; clone board            

    ; make the move on the sandbox
    lea rbx, [rel sandbox_board]
    movzx rdx, al                    
    
    mov cl, byte [rbx + r8]         
    mov byte [rbx + rdx], cl        
    mov byte [rbx + r8], EMPTY       

    ; did it work?
    push rax
    call verify_king_safety
    cmp rax, 0
    pop rax
    je .done 

    ; it did!
    movzx rcx, byte [rel valid_moves_count]
    lea rbx, [rel valid_moves_list]
    mov byte [rbx + rcx], al         
    inc rcx
    mov byte [rel valid_moves_count], cl

.done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    mov rsp, rbp
    pop rbp
    ret