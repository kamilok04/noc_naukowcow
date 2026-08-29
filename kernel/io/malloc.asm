; ------------------------------------------------------------------------------
; malloc (AllocatePages)
; Allocates a buffer of arbitrary size using UEFI page allocation.
; Inputs:
;   RAX - Requested size in bytes (e.g., 5000000 for ~5MB)
; Outputs:
;   RAX - Pointer to allocated memory (or 0 on error)
; ------------------------------------------------------------------------------
malloc:
    push rbp
    mov rbp, rsp
    push rcx
    push rdx
    push r8
    push r9
    
    ; calculate how many 4KB pages are needed
    ; pages = (bytes + 4095) / 4096
    add rax, 4095
    shr rax, 12           ; RAX = number of pages needed

    ; get them
    mov rcx, 0            ; AllocateAnyPages 
    mov rdx, 2            ; EfiLoaderData 
    mov r8, rax           ; count
    lea r9, [rel .temp_ptr] ; output pointer address
    
    mov rbx, [rel boot_services_ptr]
    sub rsp, 32
    call [rbx + EFI_BOOT_SERVICES.AllocatePages]
    add rsp, 32
    
    test rax, rax         
    jnz .error           

    ; return RAX := ptr
    mov rax, [rel .temp_ptr]
    jmp .done

.error:
    xor rax, rax          ; Return NULL on failure
.done:
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbp
    ret

; Local storage for the pointer
.temp_ptr dq 0