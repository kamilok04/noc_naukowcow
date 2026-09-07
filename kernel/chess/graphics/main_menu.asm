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
; run_main_menu
; Blocks the boot sequence until the user selects a game mode.
; ------------------------------------------------------------------------------
run_main_menu:
    push rbp
    mov rbp, rsp
    
    ; draw the menu immediately so it's on screen before the mouse moves
    call render_main_menu
    call swap_buffers
    
.menu_loop:
    ; button clicked, we're in-game. Leave this place.
    cmp byte [rel in_menu], 0
    je .done
    
    mov rcx, 1                           
    lea rdx, [rel mouse_event_array]     
    lea r8, [rel event_index]            
    mov rbx, [rel boot_services_ptr]
    sub rsp, 32
    call [rbx + EFI_BOOT_SERVICES.WaitForEvent]                     
    add rsp, 32
    
    call process_mouse_input
    jmp .menu_loop
    
.done:
    pop rbp
    ret