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

    call _draw_bg
    call _draw_chessboard
    call _draw_valid_moves
    call _draw_pieces
    call _draw_promotion_menu
    call draw_endgame_popup

    mov rsp, rbp
    pop rbp
    ret
; ------------------------------------------------------------------------------
; draw_bg
; Clear the background.
; ------------------------------------------------------------------------------
_draw_bg:  
    push rbp
    mov rbp, rsp
    push rdi
    push rsi
    push rcx
    push rdx
    push r8
    push r9
    push r10
    ; grab screen details
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    xor rcx, rcx
    xor rdx, rdx
    mov r8d, [rel screen_w]
    mov r9d, [rel screen_h]
    mov r10d, COLOR_BG
    call draw_rectangle

    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rsi
    pop rdi
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

; ------------------------------------------------------------------------------
; _draw_promotion_menu
; Overlays the promotion menu onto the linear backbuffer.
; ------------------------------------------------------------------------------
_draw_promotion_menu:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14

    ; is there actually a promotion happening?
    cmp byte [rel promotion_pending], 1
    jne .done

    ; get coords
    movzx rax, byte [rel promotion_sq]
    mov rcx, rax
    and rcx, 0x0F
    imul rcx, SQUARE_SIZE
    add rcx, BOARD_START_X           ; RCX = screen c

    shr rax, 4
    imul rax, SQUARE_SIZE
    add rax, BOARD_START_Y           ; RAX = screen y
    
    mov r12, rcx                     ; R12 = copy of X
    mov r13, rax                     ; R13 = copy of Y

    ; draw a bkgd
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rcx, r12                    
    
    ; dwtermine background Y 
    ; (white goes down, black goes up)
    mov rdx, r13                     ; starting y
    cmp byte [rel current_color], 0
    je .draw_bg
    sub rdx, SQUARE_SIZE * 3
.draw_bg:
    mov r8, SQUARE_SIZE              ; width = 1 tile
    mov r9, SQUARE_SIZE * 4          ; height = 4 tiles
    mov r10d, COLOR_PROMOTION        
    call draw_rectangle

    mov r14, 4                    
    
    cmp byte [rel current_color], 0
    jne .setup_black_sprites
    
.setup_white_sprites:
    lea rbx, [rel promotion_lookup_w]
    mov r11, SQUARE_SIZE             ; step down (+)
    jmp .draw_sprites_loop

.setup_black_sprites:
    lea rbx, [rel promotion_lookup_b]
    mov r11, SQUARE_SIZE
    neg r11                          ; step up (-)

.draw_sprites_loop:
    movzx rax, byte [rbx]            ; RAX = piece ID
    
    lea r8, [rel piece_bitmaps]
    mov r8, [r8 + rax * 8]           ; R8 = address of BMP
    
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rcx, r12                     ; Screen X
    mov rdx, r13                     ; Screen Y
    
    push r11
    push rbx
    call draw_bitmap                 ; draw
    pop rbx
    pop r11
    
    add r13, r11                     
    inc rbx                          
    dec r14
    jnz .draw_sprites_loop

.done:
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    mov rsp, rbp
    pop rbp
    ret