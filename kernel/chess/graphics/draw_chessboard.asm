; ------------------------------------------------------------------------------
; draw_chessboard
; Renders the 8x8 grid to the backbuffer.
; ------------------------------------------------------------------------------

; as the 0x88 memory layout is used, square-index-based logic is much faster now
draw_chessboard:
    push rbp
    mov rbp, rsp
    push r12            ; R12 = square index (0-0x77)
    
    xor r12, r12
.square_loop:
    cmp r12, 0x78       ; 0x77 is the last valid square on the board
    jge .done

    test r12, 0x88      
    jnz .next_square    ; out of bounds

    mov rax, r12
    shr rax, 4          ; row = index/16
    
    mov rdx, r12
    and rdx, 7          ; col = index%7
    
    ; get screen coors
    mov rcx, rdx
    imul rcx, SQUARE_SIZE
    add rcx, BOARD_START_X       ; rcx = screen x
    
    mov r8, rax
    imul r8, SQUARE_SIZE
    add r8, BOARD_START_Y        ; r8 = screen y
    
    mov r9, rax
    add r9, rdx
    and r9, 1                    ; 0 = white, 1 = black
    
    mov r10d, COLOR_LIGHT
    test r9, r9
    jz .draw_bg
    mov r10d, COLOR_DARK
    
.draw_bg:
    push rcx
    push r8
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rdx, r8                  ; top padding of the whole board
    mov r8, SQUARE_SIZE          ; width
    mov r9, SQUARE_SIZE          ; height
    call draw_rectangle          
    pop r8
    pop rcx
    
    lea rbx, [rel board]
    movzx r9, byte [rbx + r12]   ; yank straight outta the board
    
    test r9, r9
    jz .next_square              ; 0 -> empty square
    
    lea rbx, [rel piece_bitmaps]
    mov r10, [rbx + r9 * 8]      ; R10 = pointer to bitmap
    
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rdx, r8                  
    mov r8, r10                  
    call draw_bitmap             
    
.next_square:
    inc r12
    jmp .square_loop

.done:
    pop r12
    pop rbp
    ret