; ------------------------------------------------------------------------------
; draw_endgame_popup
; Renders the result modal if match_state != 0.
; ------------------------------------------------------------------------------
draw_endgame_popup:
    push rbp
    mov rbp, rsp
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push rdi
    push rsi
    
    cmp byte [rel match_state], 0
    je .done


    ; draw the bgd
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rcx, POPUP_X
    mov rdx, POPUP_Y
    mov r8, POPUP_W
    mov r9, POPUP_H
    mov r10d, COLOR_POPUP_BG
    call draw_rectangle
    
    ; draw the btn
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rcx, BTN_X
    mov rdx, BTN_Y
    mov r8, BTN_W
    mov r9, BTN_H
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

    
    ; center horizontally in the popup: POPUP_X + (POPUP_W/2) - (SQUARE_SIZE/2)
    ; place vertically above the restart button: POPUP_Y + 20
    mov rcx, POPUP_X + (POPUP_W / 2) - (SQUARE_SIZE / 2)
    mov rdx, POPUP_Y + 20

    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    call draw_bitmap      
    
.draw_text:
    mov r8, r9
    mov rcx, POPUP_TEXT_X
    mov rdx, POPUP_TEXT_Y
    mov r10d, COLOR_HIGHLIGHT
    mov r13, 2
    call draw_string

    lea r8, [rel popup_btn_str]
    mov rcx, BTN_TEXT_X
    mov rdx, BTN_TEXT_Y
    mov r10d, COLOR_WHITE
    call draw_string

.done:
    pop rsi
    pop rdi
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbp
    ret