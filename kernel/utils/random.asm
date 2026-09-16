; ------------------------------------------------------------------------------
; generate_random_seed
; Uses RDTSC to generate a 0-959 seed, stores it, formats the UI string
; Outputs: RDI = the generated seed
; ------------------------------------------------------------------------------
generate_random_seed:
    push rbp
    mov rbp, rsp
    push rax
    push rcx
    push rdx

    rdtsc                            ; EDX:EAX = CPU timestamp
    mov rcx, 960
    xor rdx, rdx
    div rcx                          ; RDX = EAX % 960
    
    mov dword [rel current_seed], edx
    mov edi, edx                     
    mov eax, edx

.done:
    pop rdx
    pop rcx
    pop rax
    mov rsp, rbp
    pop rbp
    ret