; ------------------------------------------------------------------------------
; render_playfield
; Rendering the board is a 3-step process:
; 1. Draw the board itself
; 2. Draw the higlighted squares, if any
; 3. Draw the pieces
; Execute those steps in order
;----------------------------------------------------------------------
render_playfield:
    push rbp
    mov rbp, rsp

    call _draw_chessboard
    call _draw_valid_moves
    call _draw_pieces

    mov rsp, rbp
    pop rbp
    ret
; ------------------------------------------------------------------------------
; draw_chessboard
; Renders the 8x8 grid to the backbuffer.
; ------------------------------------------------------------------------------
; as the 0x88 memory layout is used, square-index-based logic is much faster now
_draw_chessboard:
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
    
    ; get screen coords
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

.next_square:
    inc r12
    jmp _draw_chessboard.square_loop

.done:
    pop r12
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; draw_valid_moves
; Iterates through valid_moves_list and renders a green highlight for each.
; ------------------------------------------------------------------------------
_draw_valid_moves:
    ; LOG "Drawing valid moves."
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    movzx rcx, byte [rel valid_moves_count]
    test rcx, rcx
    jz .done                         ; if no valid moves, exit

    lea rsi, [rel valid_moves_list]

.highlight_loop:
    movzx eax, byte [rsi + rcx - 1]  ; suqare index

    mov rbx, rax
    and rbx, 7                       
    imul rbx, SQUARE_SIZE
    add rbx, BOARD_START_X           ; RBX = screen x

    mov rdx, rax
    shr rdx, 4                       ; row
    imul rdx, SQUARE_SIZE
    add rdx, BOARD_START_Y           ; RDX = screen y

    push rcx                         ; save the iteration counter
    push rsi                         ; and array pointer
    
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rcx, rbx                     
    ; RDX is already screen y
    mov r8, SQUARE_SIZE              ; wdt
    mov r9, SQUARE_SIZE              ; hgt
    mov r10d, COLOR_HIGHLIGHT        
    
    call draw_rectangle
    
    pop rsi
    pop rcx                          

    dec rcx
    jnz .highlight_loop

.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; draw_pieces
; Iterates through the board and draws the pieces.
; ------------------------------------------------------------------------------
_draw_pieces:
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
    
    ; get screen coords
    mov rcx, rdx
    imul rcx, SQUARE_SIZE
    add rcx, BOARD_START_X       ; rcx = screen x
    
    mov r8, rax
    imul r8, SQUARE_SIZE
    add r8, BOARD_START_Y        ; r8 = screen y
    
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
    jmp _draw_pieces.square_loop

.done:
    pop r12
    mov rsp, rbp
    pop rbp
    ret