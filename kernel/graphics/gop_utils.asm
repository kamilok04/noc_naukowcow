; ------------------------------------------------------------------------------
; interactive_resolution_picker
; Caches all GOP modes and enters an interactive keyboard polling loop.
; Displays a dynamic countdown and awaits confirmation before proceeding.
; ------------------------------------------------------------------------------
interactive_resolution_picker:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 40

    mov rbx, [rel gop_ptr]           
    mov r12, [rbx + 24]              
    mov r13d, dword [r12 + 0]        ; MaxMode
    mov r15d, dword [r12 + 4]        ; CurrentMode
    
    mov dword [rel gop_modes_count], 0
    xor r14d, r14d                   

; save all available modes
.query_loop:
    cmp r14d, r13d
    jge .find_current

    mov rcx, rbx
    mov edx, r14d
    lea r8, [rel info_size]
    lea r9, [rel info_ptr]
    
    sub rsp, 32
    call [rbx + 0]                   ; GOP->QueryMode
    add rsp, 32
    
    test rax, rax
    js .next_mode                    

    mov rcx, [rel gop_modes_count]
    cmp rcx, 64                     ; don't overfill
                                    ; no real board comes with 64 GOP modes anyway
    jge .free_info                   

    lea r9, [rel gop_modes_array]   ; save the current mode
    mov [r9 + rcx * 4], r14d         

    inc rcx
    mov [rel gop_modes_count], rcx

.free_info:
    mov rcx, [rel info_ptr]
    mov rdi, [rel boot_services_ptr]
    sub rsp, 32
    call [rdi + EFI_BOOT_SERVICES.FreePool]
    add rsp, 32

.next_mode:
    inc r14d
    jmp .query_loop

; display parameters of currently active mode
.find_current:
    xor rcx, rcx
.find_loop:
    cmp ecx, dword [rel gop_modes_count]
    jge .trigger_change              
    lea r9, [rel gop_modes_array]
    cmp dword [r9 + rcx * 4], r15d
    je .found_current
    inc rcx
    jmp .find_loop
    
.found_current:
    mov dword [rel current_gop_idx], ecx
    mov dword [rel saved_gop_idx], ecx
    mov dword [rel res_confirm_timer], 0
    
    lea r9, [rel gop_modes_array]
    mov edx, dword [r9 + rcx * 4]
    mov dword [rel target_mode], edx
    jmp .draw_ui                     
    
.input_loop:
    ; 10ms CPU Debounce Stall
    mov rcx, 10000
    mov rdi, [rel boot_services_ptr]
    sub rsp, 32
    call [rdi + 248]                 ; BootServices->Stall
    add rsp, 32

    ; timer
    ; a 10 second countdown in case of an unsupported resolution, don't softlock
    ; that would be not really cool
    mov eax, dword [rel res_confirm_timer]
    test eax, eax
    jz .check_picked_draw            ; time's up, display 'picked'
    
    dec eax
    mov dword [rel res_confirm_timer], eax
    jnz .draw_timer_ui
    jmp .revert_mode                 ; and fallback

.draw_timer_ui:
    add eax, 99                      ; math for clean seconds (10 should linger on the screen for a sec, make it 10.99)
    mov ecx, 100
    xor edx, edx
    div ecx
    
    cmp eax, dword [rel last_drawn_sec]
    je .poll_keyboard                ; don't redraw if the second hasn't changed
    mov dword [rel last_drawn_sec], eax
    
    ; print strings
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_time_confirm]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    
    ; set yellow for timer
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    mov rdx, 0x0E                    
    sub rsp, 32
    call [rcx + 40]                  ; ConOut->SetAttribute
    add rsp, 32
    
    ; seconds
    mov eax, dword [rel last_drawn_sec]
    call uint_to_utf16
    mov rdx, rax
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    
    ; spaces (so 10 doesn't magically become 90)
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_spaces]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    
    ; white
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    mov rdx, 0x0F                    
    sub rsp, 32
    call [rcx + 40]
    add rsp, 32
    
    jmp .poll_keyboard
    
.check_picked_draw:
    cmp dword [rel last_drawn_sec], 0
    je .poll_keyboard
    mov dword [rel last_drawn_sec], 0
    
    ; do we draw 'picked'?
    ; the timer is gone, so ye
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_picked]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

.poll_keyboard:
    mov rdi, [rel system_table_ptr]
    mov rcx, [rdi + 48]              ; SystemTable->ConIn
    lea rdx, [rel input_key]
    mov rax, [rcx + 8]               ; ConIn->ReadKeyStroke
    
    sub rsp, 32
    call rax
    add rsp, 32
    
    test rax, rax
    jnz .input_loop                  ; nothing

    movzx eax, word [rel input_key]      
    movzx ecx, word [rel input_key + 2]  

    cmp cx, 0x0D                     ; ENTER
    je .confirm_or_launch

    cmp ax, 0x17                     ; ESC
    je .revert_mode

    cmp ax, 0x03                     ; ←
    je .prev_mode
    
    cmp ax, 0x04                     ; →
    je .forward_mode
    
    jmp .input_loop

.confirm_or_launch:
    mov eax, dword [rel res_confirm_timer]
    test eax, eax
    jz .finish_picker                ; enter and no timer, spin up the game
    
    ;enter and timer, say 'picked' and kill the clock
    mov dword [rel res_confirm_timer], 0
    mov eax, dword [rel current_gop_idx]
    mov dword [rel saved_gop_idx], eax
    jmp .input_loop

.revert_mode:
    mov eax, dword [rel saved_gop_idx]
    mov dword [rel current_gop_idx], eax
    mov dword [rel res_confirm_timer], 0
    jmp .apply_mode

.prev_mode:
    mov eax, dword [rel current_gop_idx]
    test eax, eax
    jz .input_loop                   
    dec eax
    jmp .trigger_change

.forward_mode:
    mov eax, dword [rel current_gop_idx]
    inc eax
    cmp eax, dword [rel gop_modes_count]
    jge .input_loop                  
    
.trigger_change:
    mov dword [rel current_gop_idx], eax
    mov dword [rel res_confirm_timer], 1000 ; 1000 * 10ms = 10 Seconds

.apply_mode:
    lea r9, [rel gop_modes_array]
    mov eax, dword [rel current_gop_idx]
    mov edx, dword [r9 + rax * 4]    ; what was picked?
    mov dword [rel target_mode], edx 
    
    mov rbx, [rel gop_ptr]
    mov rcx, rbx
    sub rsp, 32
    call [rbx + 8]                   ; GOP->SetMode
    add rsp, 32

.draw_ui:
    mov dword [rel last_drawn_sec], -1 ; redraw the UI
    
    ; wipe the screen
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]              
    sub rsp, 32
    call [rcx + 48]                  ; ConOut->ClearScreen
    add rsp, 32

    ; get mode data
    mov rbx, [rel gop_ptr]
    mov rcx, rbx
    mov edx, dword [rel target_mode]
    lea r8, [rel info_size]
    lea r9, [rel info_ptr]
    sub rsp, 32
    call [rbx + 0]                   ; GOP->QueryMode
    add rsp, 32

    mov rdi, [rel info_ptr]
    mov r12d, dword [rdi + 4]        ; Width
    mov r13d, dword [rdi + 8]        ; Height

    mov rcx, [rel info_ptr]
    mov rdi, [rel boot_services_ptr]
    sub rsp, 32
    call [rdi + EFI_BOOT_SERVICES.FreePool]
    add rsp, 32

    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]              
    lea rdx, [rel str_testing]
    sub rsp, 32
    call [rcx + 8]                   
    add rsp, 32

    ; print width 
    mov eax, r12d
    call uint_to_utf16
    mov rdx, rax                     
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; " x "
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_x]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; print height 
    mov eax, r13d
    call uint_to_utf16
    mov rdx, rax
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; print controls
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_prompt]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    jmp .input_loop

.finish_picker:
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]              
    sub rsp, 32
    call [rcx + 48]                  ; ConOut->ClearScreen
    add rsp, 32

    add rsp, 40
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret



; ------------------------------------------------------------------------------
; swap_buffers
; ------------------------------------------------------------------------------
swap_buffers:
    push rbp
    mov rbp, rsp
    push rsi
    push rdi
    push rcx

    mov rdi, [rel framebuffer_base]    
    mov rsi, [rel backbuffer_ptr]      
    
    mov rcx, [rel backbuffer_size]     
    shr rcx, 3                         
    cld                                
    rep movsq                          

    pop rcx
    pop rdi
    pop rsi
    pop rbp
    ret

; ------------------------------------------------------------------------------
; push_cursor_region
; ------------------------------------------------------------------------------
push_cursor_region:
    push rbp
    mov rbp, rsp
    push rsi
    push rdi
    push rcx

    mov rax, rdx
    mul qword [rel framebuffer_pitch]
    add rax, rcx
    shl rax, 2
    
    mov rsi, [rel backbuffer_ptr]
    add rsi, rax                         
    
    mov rdi, [rel framebuffer_base]
    add rdi, rax                         

    mov r8, cursor_size                  
.push_row:
    mov rcx, cursor_size / 2
    rep movsq
    
    mov rax, [rel framebuffer_pitch]
    shl rax, 2
    sub rax, (cursor_size * 4)
    add rsi, rax
    add rdi, rax
    
    dec r8
    jnz .push_row

    pop rcx
    pop rdi
    pop rsi
    pop rbp
    ret