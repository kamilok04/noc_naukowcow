; ------------------------------------------------------------------------------
; set_max_resolution
; Iterates through all GOP modes and sets the highest available resolution.
; ------------------------------------------------------------------------------
set_max_resolution:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14

    mov rbx, [rel gop_ptr]           ; RBX = GOP Interface
    mov r12, [rbx + 24]              ; R12 = GOP->Mode struct
    
    mov r13d, dword [r12 + 0]        ; R13D = MaxMode (Total supported modes)
    xor r14d, r14d                   ; R14D = Loop Counter (Current Mode Index)
    mov qword [rel max_pixels], 0    ; reset max pixels

.query_loop:
    cmp r14d, r13d
    jge .set_mode                    ; everything has been seen

    ; ask for available video modes
    mov rcx, rbx
    mov edx, r14d
    lea r8, [rel info_size]
    lea r9, [rel info_ptr]
    
    sub rsp, 32
    call [rbx + 0]                   ; GOP->QueryMode
    add rsp, 32
    
    test rax, rax
    jnz .next_mode                   ; skip if mode unavailable for whatever reason

    mov rdi, [rel info_ptr]
    mov eax, dword [rdi + 4]         ; EAX = HorizontalResolution
    mov ecx, dword [rdi + 8]         ; ECX = VerticalResolution
    
    ; total pixels
    mov r10, rax
    imul r10, rcx                    ; R10 = EAX * ECX
    
    ; aspect ratio
    xor rdx, rdx                     
    mov rax, rdi                     
    mov eax, dword [rdi + 4]
    imul rax, 100
    div rcx                          ; RAX = ratio (*100, truncated to int)
    mov r11, rax                     ; 16:9 = 1,(7) -> 177
    
    ; prefer wide screens
    cmp r11d, dword [rel max_ratio]
    jb .free_info                    ; we want it  w i d e 
    ja .new_winner                   ;
    
    cmp r10, qword [rel max_pixels]
    jbe .free_info                   ; pick highest pixel count if in doubt
    
.new_winner:
    mov dword [rel max_ratio], r11d  
    mov qword [rel max_pixels], r10  
    mov dword [rel target_mode], r14d 
.free_info:
    ; don't leak memory
    mov rcx, [rel info_ptr]
    mov rdi, [rel boot_services_ptr]
    
    sub rsp, 32
    call [rdi + EFI_BOOT_SERVICES.FreePool]
    add rsp, 32

.next_mode:
    inc r14d
    jmp .query_loop

.set_mode:
    mov rcx, rbx
    mov edx, dword [rel target_mode]
    
    sub rsp, 32
    call [rbx + 8]                   ; GOP->SetMode
    add rsp, 32

    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; swap_buffers
; Copies the entire backbuffer to the visible GOP framebuffer.
; ------------------------------------------------------------------------------
swap_buffers:
    push rbp
    mov rbp, rsp
    push rsi
    push rdi
    push rcx

    mov rdi, [rel framebuffer_base]    ; dst: screen
    mov rsi, [rel backbuffer_ptr]      ; src: second buffer
    
    mov rcx, [rel backbuffer_size]     ; Total bytes to copy
    shr rcx, 3                         ; divide by 8 (grabbing 8 bytes at once)

    cld                                ; just in case
    rep movsq                          

    pop rcx
    pop rdi
    pop rsi
    pop rbp
    ret



; ------------------------------------------------------------------------------
; push_cursor_region
; Copies the cursor region from backbuffer to backup buffer
; Inputs: RCX = X, RDX = Y
; ------------------------------------------------------------------------------
push_cursor_region:
    push rbp
    mov rbp, rsp

    ; offset = (Y * pitch + X) * 4)
    mov rax, rdx
    mul qword [rel framebuffer_pitch]
    add rax, rcx
    shl rax, 2
    
    
    mov rsi, [rel backbuffer_ptr]
    add rsi, rax                         ; from backbuffer
    
    mov rdi, [rel framebuffer_base]
    add rdi, rax                         ; to screen

    mov r8, cursor_size                  
.push_row:
    mov rcx, cursor_size
    rep movsd
    
    mov rax, [rel framebuffer_pitch]
    shl rax, 2
    sub rax, (cursor_size * 4)
    add rsi, rax
    add rdi, rax
    
    dec r8
    jnz .push_row

    pop rbp
    ret