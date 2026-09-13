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
    call _draw_transcript

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
    push r12
    push r13
    push r14
    push r15

    mov r13d, dword [rel tile_size]
    mov r14d, dword [rel board_x]
    mov r15d, dword [rel board_y]
    
    xor r12, r12
.square_loop:
    cmp r12, 0x78
    jge .done
    test r12, 0x88      
    jnz .next_square

    mov rax, r12
    shr rax, 4                   ; row = index/16
    mov rdx, r12
    and rdx, 7                   ; col = index&7 == index%8
    
    ; get dynamic screen coords
    mov rcx, rdx
    imul rcx, r13                ; col * tile_size
    add rcx, r14                 ; + board_x
    
    mov r8, rax
    imul r8, r13                 ; row * tile_size
    add r8, r15                  ; + board_y
    
    mov r9, rax
    add r9, rdx
    and r9, 1                    
    
    mov r10d, COLOR_LIGHT
    test r9, r9
    jz .draw_bg
    mov r10d, COLOR_DARK
    
.draw_bg:
    push rcx
    push r8
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rdx, r8                  
    mov r8, r13                  ; width = tile_size
    mov r9, r13                  ; height = tile_size
    call draw_rectangle          
    pop r8
    pop rcx         

.next_square:
    inc r12
    jmp _draw_chessboard.square_loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; draw_valid_moves
; Iterates through valid_moves_list and renders a green highlight for each.
; ------------------------------------------------------------------------------
_draw_valid_moves:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r13
    push r14
    push r15

    movzx rcx, byte [rel valid_moves_count]
    test rcx, rcx
    jz .done

    mov r13d, dword [rel tile_size]
    mov r14d, dword [rel board_x]
    mov r15d, dword [rel board_y]
    lea rsi, [rel valid_moves_list]

.highlight_loop:
    movzx eax, byte [rsi + rcx - 1]

    ; flip rendering perspective based on player's color
    cmp byte [rel local_color], 1
    jne .skip_flip_vm
    mov rbx, 0x77
    sub rbx, rax
    mov rax, rbx

.skip_flip_vm:

    mov rbx, rax
    and rbx, 7                       
    imul rbx, r13                    ; col * tile_size
    add rbx, r14                     ; + board_x

    mov rdx, rax
    shr rdx, 4                       
    imul rdx, r13                    ; row * tile_size
    add rdx, r15                     ; + board_y

    push rcx                         
    push rsi                         
    
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rcx, rbx                     
    mov r8, r13                      ; wdt = tile_size
    mov r9, r13                      ; hgt = tile_size
    mov r10d, COLOR_HIGHLIGHT        
    
    call draw_rectangle
    
    pop rsi
    pop rcx                          
    dec rcx
    jnz .highlight_loop

.done:
    pop r15
    pop r14
    pop r13
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
    push r12            ; R12 = logical square index (0-0x77)
    push r8
    push r9
    xor r12, r12
    
    .square_loop:
    cmp r12, 0x78       ; 0x77 is the last valid square on the board
    jge .done

    test r12, 0x88      
    jnz .next_square    ; out of bounds

    ; client-side logic
    ; flip all piece positions if playing as black
    ; R12 contains logical index, move calculation is based on that
    ; R11 contains visual index, this is what the player will see.

    ; for white, R11 == R12
    ; for black, R11 == 0x77 - R12

    mov r11, r12
    cmp byte [rel local_color], 1 ; 1 -> black
    jne .no_flip_p
    mov r11, 0x77
    sub r11, r12

.no_flip_p:

    mov rax, r11
    shr rax, 4          ;  (visual) row = index/16
    
    mov rdx, r11
    and rdx, 7          ; (visual) col = index%7
    
    ; get screen coords
    mov r8d, dword [rel tile_size]
    mov r9d, dword [rel board_x]
    mov rcx, rdx
    imul rcx, r8
    add rcx, r9       ; rcx = screen x
    
    mov r9d, dword [rel board_y]
    imul rax, r8
    mov r8, rax
    add r8, r9        ; r8 = screen y
    
    lea rbx, [rel board]
    movzx r9, byte [rbx + r12]   ; yank straight outta the board using the logical index
    
    test r9, r9
    jz .next_square              ; 0 -> empty square
    
    lea rbx, [rel piece_bitmaps]
    mov r10, [rbx + r9 * 8]      ; R10 = pointer to bitmap
    
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rdx, r8                  
    mov r8, r10                  
    call draw_bitmap_scaled       
    
.next_square:
    inc r12
    jmp _draw_pieces.square_loop

.done:
    pop r9
    pop r8
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
cmp byte [rel promotion_pending], 1
    jne .done

    mov r10d, dword [rel tile_size]  ; dynamic size

    ; client-based logic
    ; flip position of the menu based on the perspective

    movzx rax, byte [rel promotion_sq]
    cmp byte [rel local_color], 1
    jne .no_flip_promo
    mov rbx, 0x77
    sub rbx, rax
    mov rax, rbx

.no_flip_promo:

    ; get coords
    movzx rax, byte [rel promotion_sq]
    mov rcx, rax
    and rcx, 0x0F
    imul rcx, r10
    add ecx, dword [rel board_x]     ; RCX = screen x

    shr rax, 4
    imul rax, r10
    add eax, dword [rel board_y]     ; RAX = screen y
    
    mov r12, rcx                     ; R12 = copy of X
    mov r13, rax                     ; R13 = copy of Y

    ; which way should the menu go?
    mov r15b, byte [rel current_color]
    xor r15b, byte [rel local_color] ; 1: up, 0 : down

    ; draw a bkgd
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rcx, r12                    
    
    mov rdx, r13                     ; starting y
    cmp byte [rel current_color], 0
    je .draw_bg
    
    mov r11, r10
    imul r11, 3                      ; tile_size * 3
    sub rdx, r11                     ; white goes down, black goes up

.draw_bg:
    mov r8, r10                      ; width = 1 tile
    mov r9, r10
    imul r9, 4                       ; height = 4 tiles
    mov r10d, COLOR_PROMOTION        
    call draw_rectangle

    mov r14, 4                    
    mov r11d, dword [rel tile_size]  ; step size

    cmp r15b, 0
    je .pick_sprites
    neg r11
.pick_sprites:
    
    cmp byte [rel current_color], 0
    jne .setup_black_sprites
    
.setup_white_sprites:
    lea rbx, [rel promotion_lookup_w]
    jmp .draw_sprites_loop

.setup_black_sprites:
    lea rbx, [rel promotion_lookup_b]
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

; ------------------------------------------------------------------------------
; calculate_board_layout
; Computes dynamic tile sizes and offsets to center the board on the left half.
; ------------------------------------------------------------------------------
calculate_board_layout:
    push rax
    push rbx
    push rcx
    push rdx

    ; pick what will limit the size: min(Width / 2, Height)
    mov eax, dword [rel screen_w]
    shr eax, 1                       ; half
    mov ebx, dword [rel screen_h]
    
    cmp eax, ebx
    jl .width_is_limit               
    mov eax, ebx                     
.width_is_limit:

    ; pad
    sub eax, 32


    shr eax, 3                       ; 8 tiles of width must fit
    mov dword [rel tile_size], eax   ; save the size
    
    shl eax, 3                       ; avoid gaps

    ; center the board horizontally within the screen's left half
    mov ecx, dword [rel screen_w]
    shr ecx, 1                      
    sub ecx, eax                    
    shr ecx, 1                      
    mov dword [rel board_x], ecx    
    
    ; center vertically
    mov ecx, dword [rel screen_h]
    sub ecx, eax
    shr ecx, 1
    mov dword [rel board_y], ecx 
    
    mov eax, dword [rel tile_size]
    
    ; popup_w = 4 * tile_size
    mov ecx, eax
    shl ecx, 2
    mov dword [rel popup_w], ecx
    
    ; popup_h = 2 * tile_size
    mov ecx, eax
    shl ecx, 1
    mov dword [rel popup_h], ecx
    
    ; popup_x = board_x + (2 * tile_size) [Starts at column 3]
    mov ecx, eax
    shl ecx, 1
    add ecx, dword [rel board_x]
    mov dword [rel popup_x], ecx
    
    ; popup_y = board_y + (3 * tile_size) [Starts at row 4]
    mov ecx, eax
    imul ecx, 3
    add ecx, dword [rel board_y]
    mov dword [rel popup_y], ecx
    
    ; btn_w = 2 * tile_size
    mov ecx, eax
    shl ecx, 1
    mov dword [rel btn_w], ecx
    
    ; btn_h = 0.5 * tile_size
    mov ecx, eax
    shr ecx, 1
    mov dword [rel btn_h], ecx
    
    ; btn_x = popup_x + 1.5 * tile_size (Right-aligned under the text)
    mov ecx, dword [rel popup_x]
    add ecx, eax
    mov ebx, eax
    shr ebx, 1
    add ecx, ebx
    mov dword [rel btn_x], ecx
    
    ; btn_y = popup_y + 1.25 * tile_size
    mov ecx, dword [rel popup_y]
    add ecx, eax
    mov ebx, eax
    shr ebx, 2
    add ecx, ebx
    mov dword [rel btn_y], ecx
    

calculate_transcript_layout:
    ; find the right sides' width
    mov eax, dword [rel screen_w] 
    mov ebx, dword [rel board_x]
    mov ecx, [rel tile_size]
    shl ecx, 3
    add ebx, ecx
    sub eax, ebx                             ; EAX = total width of the right panel

    ; allocate space: 2/3 for transcript, 1/3 for future buttons
    mov ecx, 3
    xor edx, edx
    div ecx
    imul eax, 2                              ; EAX = max transcript width
    
    ; divide by 160 (5 + 8 + 7) * 8 -- row width
    mov ecx, 160
    xor edx, edx
    div ecx                                  ; EAX = proposed scale
    
    ; if a result is non-satisfactory, plug 1 in instead
    cmp eax, 1
    jge .set_scale
    mov eax, 1

.set_scale:
    
    mov dword [rel text_scale], eax

    ; starting x (right board edge + padding, hardcoded 24px here)
    add ebx, 24
    mov dword [rel transcript_x], ebx

    ; calculate row count
    ; Row height = (text_scale * 16) + 4px vertical padding
    mov ecx, eax
    shl ecx, 4
    add ecx, 4
    
    mov eax, dword [rel tile_size]
    shl eax, 3          
    xor edx, edx
    div ecx                                  ; line count = board hgt / row hgt
    mov dword [rel transcript_lines], eax    ; Save the row limit!   
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
; ------------------------------------------------------------------------------
; _draw_transcript
; Renders the transcript buffer in two fixed-width columns.
; ------------------------------------------------------------------------------
_draw_transcript:
    push rbp
    mov rbp, rsp
    push rbx

    movzx eax, word [rel transcript_count]
    test eax, eax
    jz .done

    ; auto-scrolling
    inc eax
    shr eax, 1                      
    mov ebx, dword [rel transcript_lines]
    cmp eax, ebx
    jle .no_scroll                  
    
    sub eax, ebx                    
    mov word [rel transcript_scroll], ax
    jmp .scroll_set
.no_scroll:
    mov word [rel transcript_scroll], 0
.scroll_set:

    ; initialize memory
    mov dword [rel tr_row], 0
    movzx eax, word [rel transcript_scroll]
    mov dword [rel tr_move], eax
    
.row_loop:
    mov eax, dword [rel tr_row]
    cmp eax, dword [rel transcript_lines]
    jge .done                               

    mov eax, dword [rel tr_move]
    shl eax, 1                              
    cmp ax, word [rel transcript_count]
    jge .done

    ; calculate y
    mov eax, dword [rel text_scale]
    shl eax, 4                              
    add eax, 4                              
    imul eax, dword [rel tr_row]
    add eax, dword [rel board_y]            
    mov dword [rel tr_y], eax                           

    ;  build the move no. string
    mov eax, dword [rel tr_move]
    inc eax                                 
    mov dword [rel move_num_str], 0x2E202020 
    mov byte [rel move_num_str + 4], 0
    lea rdi, [rel move_num_str + 2]         
    mov ecx, 10
.itoa:
    xor edx, edx
    div ecx
    add dl, '0'
    mov byte [rdi], dl
    dec rdi                                 
    test eax, eax
    jz .itoa_done
    lea r8, [rel move_num_str]
    cmp rdi, r8
    jge .itoa
.itoa_done:

    ; move no.
    mov ecx, dword [rel transcript_x]       
    mov edx, dword [rel tr_y]                           
    lea r8, [rel move_num_str]
    mov r10d, 0x00FFFFFF                    
    mov r13d, dword [rel text_scale]
    call draw_string                        

    ; white's move
    mov eax, dword [rel tr_move]
    shl eax, 4                              
    lea r8, [rel transcript_buffer]
    add r8, rax
    
    mov ecx, dword [rel text_scale]
    imul ecx, 40                            
    add ecx, dword [rel transcript_x]
    mov edx, dword [rel tr_y]
    mov r10d, 0x00FFFFFF                    
    mov r13d, dword [rel text_scale]
    call draw_string

    ; black's move
    mov eax, dword [rel tr_move]
    shl eax, 1
    inc eax                                 
    cmp ax, word [rel transcript_count]
    jge .next_row                           
    
    mov eax, dword [rel tr_move]
    shl eax, 4
    add eax, 8                              
    lea r8, [rel transcript_buffer]
    add r8, rax

    mov ecx, dword [rel text_scale]
    imul ecx, 104                           
    add ecx, dword [rel transcript_x]
    mov edx, dword [rel tr_y]
    mov r10d, 0x00FFFFFF                    
    mov r13d, dword [rel text_scale]
    call draw_string

.next_row:
    inc dword [rel tr_row]
    inc dword [rel tr_move]
    jmp .row_loop

.done:
    pop rbx
    mov rsp, rbp
    pop rbp
    ret