; ------------------------------------------------------------------------------
; resolve_promotion
; Inputs: RAX - whatever the user selected in the promotion menu (0=Q, 1=R, 2=B, 3=N)
; ------------------------------------------------------------------------------
resolve_promotion:
    push rbx
    push rcx
    push rdx

    ; pick the correct promo lookup table
    mov cl, byte [rel current_color]
    test cl, cl
    jnz .black_promo
    
.white_promo:
    lea rbx, [rel promotion_lookup_w]
    jmp .get_piece
    
.black_promo:
    lea rbx, [rel promotion_lookup_b]

.get_piece:
    ; get new piece
    mov dl, byte [rbx + rax]
    
    ; write to board
    movzx rcx, byte [rel promotion_sq]
    lea rbx, [rel board]
    mov byte [rbx + rcx], dl
    
    ; unpause game logic
    mov byte [rel promotion_pending], 0
    
    ; 5. Finalize the turn
    ; (Call whatever routine you use to toggle current_color and update highlights here)
    call promotion_interrupt_resolved
    pop rdx
    pop rcx
    pop rbx
    ret