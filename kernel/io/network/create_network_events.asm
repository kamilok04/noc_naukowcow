; ------------------------------------------------------------------------------
; create_network_events
; Allocates EFI_EVENTs and links them to TCP4 tokens.
; ------------------------------------------------------------------------------
create_network_events:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 48                      

    mov rbx, [rel boot_services_ptr]

    xor rcx, rcx                     ; type = 0 (Standard Polling Event)
    mov rdx, 4                       ; TPL_APPLICATION
    xor r8, r8                       ; NotifyFunction = NULL
    xor r9, r9                       ; NotifyContext = NULL
    
    lea rax, [rel handshake_event]
    mov [rsp + 32], rax              ; ptr to output event
    
    mov rax, [rbx + EFI_BOOT_SERVICES.CreateEvent]
    call rax
    test rax, rax
    jnz .error

    ; link to token
    mov rax, [rel handshake_event]
    lea rbx, [rel token_handshake]
    mov [rbx + EFI_TCP4_COMPLETION_TOKEN.Event], rax

    LOG "Event creation system OK."
    xor rax, rax
    jmp .done

.error:
    ; Handle CreateEvent failure here
    LOG "Failed"
    xor rax, rax
    inc rax

.done:
    add rsp, 48
    pop rbx
    pop rbp
    ret