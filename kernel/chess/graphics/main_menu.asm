; ------------------------------------------------------------------------------
; render_main_menu
; Does the actual displaying of the menu.
; ------------------------------------------------------------------------------
render_main_menu:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    call _draw_bg

    ; grab starting Y for btns
    mov r15d, dword [rel screen_h]
    shr r15d, 1                      ; half of the display by default
    
    mov eax, r15d
    add eax, 350                     ; 350px required
    cmp eax, dword [rel screen_h]
    jle .btn_y_ok
    
    ; move up if not enough space on the bottpm
    mov r15d, dword [rel screen_h]
    sub r15d, 350
    
    ; but not too far up
    cmp r15d, 10
    jge .btn_y_ok
    mov r15d, 10                     
.btn_y_ok:

    ; draw the logo
    call draw_menu_logo

    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]

    ; draw btns

    ; host
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 150    
    ; mov edx, dword [rel screen_h]
    ; shr edx, 1
    ; sub edx, 100                 ; Y (centered)
    mov edx, r15d
    mov r8, 400                  ; W
    mov r9, 50                   ; H
    mov r10d, COLOR_BTN_BG
    call draw_rectangle
    
    ; draw join btn
    mov edx, r15d
    add edx, 100
    call draw_rectangle
    
    ; draw offline btn
    mov edx, r15d
    add edx, 200                 ; Y (+200)
    call draw_rectangle
    
    ; draw text
    lea r8, [rel str_menu_host]
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 130                 ; X padding
    mov edx, r15d
    add edx, 18                 ; Y padding inside button
    mov r10d, COLOR_WHITE
    mov r13, 2                   ; 16x16 res
    call draw_string
    
    ; join text
    lea r8, [rel str_menu_join]
    mov edx, r15d
    add edx, 118
    call draw_string
    
    ; offline text
    lea r8, [rel str_menu_offline]
    mov edx, r15d
    add edx, 218
    call draw_string

    ; chess960
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    sub ecx, 150                 ;
    mov edx, r15d
    add edx, 300                 
    mov r8, 32                   
    mov r9, 32                   
    
    cmp byte [rel chess960_mode], 1
    je .cb_active
    mov r10d, 0x00444444         ; Off = dark gray
    jmp .cb_draw
.cb_active:
    mov r10d, 0x0033AA33         ; On = green
.cb_draw:
    push rcx                     ; save coords for string
    push rdx
    call draw_rectangle
    pop rdx
    pop rcx

    ; draw the string depending on the toggle state
    cmp byte [rel chess960_mode], 1
    je .string_on
.string_off:
    lea r8, [rel str_c960_off]
    jmp .render_string
.string_on:
    lea r8, [rel str_c960_on]
.render_string:
    add ecx, 48                  ; x offset
    add edx, 8                   ; center text vertically
    mov r10d, COLOR_WHITE
    mov r13, 2                   ; 16x16 font
    call draw_string
    
    ; draw cursor, swap buffers
    call swap_buffers
    
    pop r15
    pop r14
    pop r13
    pop r12
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
    push r15

    call _draw_bg
    
    mov r15d, dword [rel screen_h]
    shr r15d, 1
    sub r15d, 60                  ; push slightly above center
    
    ; draw the logo
    call draw_menu_logo

    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]

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
    
    pop r15
    mov rsp, rbp
    pop rbp
    ret


; ------------------------------------------------------------------------------
; draw_menu_logo
; Draws a centered program logo w/o clipping into the rest of the UI.
; Accepts:
;   R15D: threshold X (top of text/btns)
; ------------------------------------------------------------------------------
draw_menu_logo:
    push rbp
    mov rbp, rsp
    push rax
    push rcx
    push rdx
    push r8
    push r12
    push r13
    push r14
    push rdi
    push rsi

    mov r8, [rel logo_ptr]
    mov r8, [r8 + FILE.BufferPtr]

    mov r12d, dword [r8 + 0x12]    ; R12D = bmp width
    mov r13d, dword [r8 + 0x16]    ; R13D = bmp height

    ; does the logo even fit?
    cmp dword [rel screen_w], r12d
    jl .skip_logo

    ; yes; compute Y
    mov r14d, dword [rel screen_h]
    shr r14d, 2                      ; 1/4 of the screen is the default
    
    mov eax, r14d
    add eax, r13d                    ; bottom = top + height
    cmp eax, r15d
    jl .draw_logo                    ; logo does not overlap btns, OK

    ; overlap, move the logo up 
    mov r14d, r15d
    sub r14d, r13d
    sub r14d, 16                     ; keep a decent margin

    ; cool, does the top fit too now?
    cmp r14d, 0
    jl .skip_logo                    ; it doesn't, skip

.draw_logo:
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov ecx, dword [rel screen_w]
    shr ecx, 1
    mov eax, r12d
    shr eax, 1
    sub ecx, eax    ; left = center - half of width
                    ; this centers the whole image    
    mov edx, r14d   ; computed Y
    call draw_bitmap

.skip_logo:
    pop rsi
    pop rdi
    pop r14
    pop r13
    pop r12
    pop r8
    pop rdx
    pop rcx
    pop rax
    mov rsp, rbp
    pop rbp
    ret