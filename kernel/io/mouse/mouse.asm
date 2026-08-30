; ------------------------------------------------------------------------------
; init_mouse
; Locates and resets the EFI_SIMPLE_POINTER_PROTOCOL
; ------------------------------------------------------------------------------
init_mouse:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32

    mov rbx, [rel boot_services_ptr]

    ; 1. Locate Protocol
    lea rcx, [rel GUID_SIMPLE_POINTER]
    xor rdx, rdx
    lea r8, [rel mouse_ptr]
    call [rbx + EFI_BOOT_SERVICES.LocateProtocol]
    
    test rax, rax
    jnz .error

    ; 2. Reset Mouse
    mov rcx, [rel mouse_ptr]
    xor rdx, rdx                 ; ExtendedVerification = FALSE (0)
    mov rax, [rcx + EFI_SIMPLE_POINTER_PROTOCOL.Reset]
    call rax

.error:
    add rsp, 32
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; update_mouse
; Polls the mouse state and updates absolute coordinates.
; ------------------------------------------------------------------------------
update_mouse:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov rcx, [rel mouse_ptr]
    test rcx, rcx
    jz .no_mouse                 ; Safety check if mouse isn't loaded

    lea rdx, [rel mouse_state]
    mov rax, [rcx + EFI_SIMPLE_POINTER_PROTOCOL.GetState]
    call rax
    
    test rax, rax            ; EFI_SUCCESS (0)?
    jnz .done                ; If not 0 (e.g., EFI_NOT_READY), no movement happened

    ; get deltas
    lea rbx, [rel mouse_state]
    mov eax, dword [rbx + EFI_SIMPLE_POINTER_STATE.RelativeMovementX]
    mov edx, dword [rbx + EFI_SIMPLE_POINTER_STATE.RelativeMovementY]

    mov ecx, dword [rel mouse_x]
    add ecx, eax               ; Apply delta

    ; Clamp < 0
    test ecx, ecx
    jns .check_x_max
    xor ecx, ecx               ; Force to 0 if negative
    jmp .save_x

.check_x_max:
    mov edi, dword [rel screen_w]
    sub edi, 10                ; Subtract cursor width (10px) so it doesn't clip
    cmp ecx, edi
    jle .save_x
    mov ecx, edi               ; Clamp to max width

.save_x:
    mov dword [rel mouse_x], ecx


    mov ecx, dword [rel mouse_y]
    add ecx, edx               ; Apply delta

    ; Clamp < 0
    test ecx, ecx
    jns .check_y_max
    xor ecx, ecx               ; Force to 0 if negative
    jmp .save_y

.check_y_max:
    mov edi, dword [rel screen_h]
    sub edi, 10                ; Subtract cursor height (10px)
    cmp ecx, edi
    jle .save_y
    mov ecx, edi               ; Clamp to max height

.save_y:
    mov dword [rel mouse_y], ecx

.no_mouse:
    LOG "No mouse has been detected!"
.done:
    add rsp, 32
    pop rbp
    ret