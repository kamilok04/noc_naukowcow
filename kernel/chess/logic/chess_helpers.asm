; ------------------------------------------------------------------------------
; add_valid_move
; Inputs: RAX - The 0x88 index of the valid move
; ------------------------------------------------------------------------------
add_valid_move:
    push rbx
    push rcx
    movzx rcx, byte [rel valid_moves_count]
    lea rbx, [rel valid_moves_list]
    mov byte [rbx + rcx], al         
    inc rcx
    mov byte [rel valid_moves_count], cl ; bump the counter
    pop rcx
    pop rbx
    ret