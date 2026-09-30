; ------------------------------------------------------------------------------
; draw_endgame_popup
; Renders the result modal if match_state != 0.
; ------------------------------------------------------------------------------
draw_endgame_popup:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r13
    push rdi
    push rsi
    
    cmp byte [rel match_state], 0
    je .done

    ; get popup text width
    mov eax, dword [rel popup_w]
    sub eax, dword [rel tile_size]
    xor edx, edx
    mov ecx, 144                 ; 144 = 18 * 8 = max string length * minimum char size
    div ecx                      ; EAX = safe scale
    
    cmp eax, 1
    jge .save_scale
    mov eax, 1                

.save_scale:
    ; draw the bgd
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov ecx, dword [rel popup_x]
    mov edx, dword [rel popup_y]
    mov r8d, dword [rel popup_w]
    mov r9d, dword [rel popup_h]
    mov r10d, COLOR_POPUP_BG
    call draw_rectangle
    
    ; draw the btn
    mov ecx, dword [rel btn_x]
    mov edx, dword [rel btn_y]
    mov r8d, dword [rel btn_w]
    mov r9d, dword [rel btn_h]
    mov r10d, COLOR_BTN_BG
    call draw_rectangle

    mov ecx, dword [rel btn2_x]
    mov edx, dword [rel btn2_y]
    mov r8d, dword [rel btn2_w]
    mov r9d, dword [rel btn2_h]
    mov r10d, COLOR_BTN_BG
    call draw_rectangle
    
    ; draw the king
    mov al, byte [rel match_state]
    cmp al, 1
    je .white_wins
    cmp al, 2
    je .black_wins
    jmp .stalemate                    ; only draw wins

.white_wins:
    mov rax, W_KING   
    lea r9, [rel white_wins_str]               
    jmp .get_bitmap

.black_wins:
    mov rax, B_KING   
    lea r9, [rel black_wins_str]   
    jmp .get_bitmap
.stalemate:
    lea r9, [rel stalemate_str]
    jmp .draw_text            

.get_bitmap:
    ; grab the pointer for the bmp
    lea r8, [rel piece_bitmaps]
    mov r8, [r8 + rax * 8]       ; R8 = address of the BMP
    
    ; Piece X = popup_x + 0.25 * tile_size 
    mov ecx, dword [rel tile_size]
    shr ecx, 2
    add ecx, dword [rel popup_x]
    
    ; center vertically
    mov edx, dword [rel tile_size]
    shr edx, 1
    add edx, dword [rel popup_y]
    call draw_bitmap_scaled    
    
.draw_text:
    ; get centered X
    mov eax, 136                 ; 136px is a good-enough average value
    imul eax, dword [rel popup_text_scale]
    mov ebx, dword [rel popup_w]
    sub ebx, dword [rel tile_size]
    sub ebx, eax                 ; whatever space to the right is left
    shr ebx, 1                   ; halve that

    ; X = popup_x + tile_size (right)
    mov ecx, dword [rel tile_size]
    add ecx, dword [rel popup_x]
    add ecx, ebx

    ; Y = popup_y + 0.5 * tile_size
    mov edx, dword [rel tile_size]
    shr edx, 1
    add edx, dword [rel popup_y]
    
    mov r8, r9
    mov r10d, COLOR_HIGHLIGHT
    mov r13d, dword [rel popup_text_scale]
    call draw_string

    mov ecx, dword [rel btn2_x]
    mov ebx, dword [rel btn_w]
    shr ebx, 1
    add ecx, ebx
    mov eax, 56                  ; "Rewanż!" = 7 * 8px = 56px
    imul eax, dword [rel popup_text_scale]
    shr eax, 1                   
    sub ecx, eax                 ; center horizontally
    
    mov edx, dword [rel btn_y]
    mov ebx, dword [rel btn_h]
    shr ebx, 1
    add edx, ebx
    mov eax, 4                   ; Half of 8px base height
    imul eax, dword [rel popup_text_scale]
    sub edx, eax                 ; center vertically

    lea r8, [rel popup_btn_str]
    mov r10d, COLOR_WHITE
    mov r13d, dword [rel popup_text_scale]
    call draw_string

    ; menu btn 
    mov ecx, dword [rel btn2_x]
    mov ebx, dword [rel btn2_w]
    shr ebx, 1
    add ecx, ebx
    mov eax, 56                  ; 7 znaków * 8px
    imul eax, dword [rel popup_text_scale]
    shr eax, 1                   
    sub ecx, eax                 
    
    mov edx, dword [rel btn2_y]
    mov ebx, dword [rel btn2_h]
    shr ebx, 1
    add edx, ebx
    mov eax, 4                   
    imul eax, dword [rel popup_text_scale]
    sub edx, eax                 

    lea r8, [rel str_menu_exit]
    mov r10d, COLOR_WHITE
    mov r13d, dword [rel popup_text_scale]
    call draw_string

.done:
    pop rsi
    pop rdi
    pop r13
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    pop rax
    mov rsp, rbp
    pop rbp
    ret