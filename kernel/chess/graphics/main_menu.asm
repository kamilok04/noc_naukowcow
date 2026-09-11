; ------------------------------------------------------------------------------
; render_main_menu
; Does the actual displaying of the menu.
; ------------------------------------------------------------------------------
render_main_menu:
    push rbp
    mov rbp, rsp

    call _draw_bg

    ; draw the logo
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 250    
    mov edx, dword [rel screen_h]
    shr edx, 2
    mov r8, [rel logo_ptr]
    mov r8, [r8 + FILE.BufferPtr]
    call draw_bitmap

    
    
    ; draw host btn
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 150    
    mov edx, dword [rel screen_h]
    shr edx, 1
    ; sub edx, 100                 ; Y (centered)
    mov r8, 400                  ; W
    mov r9, 50                   ; H
    mov r10d, COLOR_BTN_BG
    call draw_rectangle
    
    ; draw join btn
    mov edx, dword [rel screen_h]
    shr edx, 1                   ; Y (+100)
    add edx, 100
    call draw_rectangle
    
    ; draw offline btn
    mov edx, dword [rel screen_h]
    shr edx, 1
    add edx, 200                 ; Y (+200)
    call draw_rectangle
    
    ; draw text
    lea r8, [rel str_menu_host]
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 130                 ; X padding
    mov edx, dword [rel screen_h]
    shr edx, 1
    add edx, 18                 ; Y padding inside button
    mov r10d, COLOR_WHITE
    mov r13, 2                   ; 16x16 res
    call draw_string
    
    ; join text
    lea r8, [rel str_menu_join]
    mov edx, dword [rel screen_h]
    shr edx, 1
    add edx, 118
    call draw_string
    
    ; offline text
    lea r8, [rel str_menu_offline]
    mov edx, dword [rel screen_h]
    shr edx, 1
    add edx, 218
    call draw_string
    
    ; draw cursor, swap buffers
    call draw_cursor
    call swap_buffers
    
    mov rsp, rbp
    pop rbp
    ret



; ------------------------------------------------------------------------------
; render_awaiting_screen
; Draws the waiting text and the cancel button
; ------------------------------------------------------------------------------
render_awaiting_screen:
    push rbp
    mov rbp, rsp
    call _draw_bg

    ; draw the logo
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 250    
    mov edx, dword [rel screen_h]
    shr edx, 2
    mov r8, [rel logo_ptr]
    mov r8, [r8 + FILE.BufferPtr]
    call draw_bitmap
    
    lea r8, [rel str_awaiting]
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 220                 ; center text horizontally
    mov edx, dword [rel screen_h]
    shr edx, 1
    sub edx, 60                  ; push slightly above center
    mov r10d, COLOR_WHITE
    mov r13, 2
    call draw_string
    
    ; draw cancel btn background
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 100                 
    mov edx, dword [rel screen_h]
    shr edx, 1
    add edx, 150                
    mov r8, 200                  
    mov r9, 50                   
    mov r10d, COLOR_BTN_BG
    call draw_rectangle
    
    ; Draw Cancel Button Text
    lea r8, [rel str_cancel]
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 48                  
    mov edx, dword [rel screen_h]
    shr edx, 1
    add edx, 168                 ;
    mov r10d, COLOR_WHITE
    mov r13, 2
    call draw_string
    
    pop rbp
    ret