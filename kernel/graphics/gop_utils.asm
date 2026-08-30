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

    ; calculate resolution (x * y)
    mov rdi, [rel info_ptr]
    mov eax, dword [rdi + 4]         ; EAX = HorizontalResolution
    mov ecx, dword [rdi + 8]         ; ECX = VerticalResolution
    mul rcx                          ; RAX = EAX * ECX
    
    cmp rax, [rel max_pixels]
    jbe .free_info                   ; if smaller or equal, skip saving

    mov [rel max_pixels], rax
    mov [rel target_mode], r14d

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