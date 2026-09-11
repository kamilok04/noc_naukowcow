; ------------------------------------------------------------------------------
; create_network_events
; Allocates EFI_EVENTs and links them to TCP4 tokens.
; ------------------------------------------------------------------------------
create_network_events:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40                     

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
    lea r10, [rel token_handshake]
    mov [r10 + EFI_TCP4_COMPLETION_TOKEN.Event], rax
    mov [rel wait_event_array + 8], rax

    ; create TX token
    xor rcx, rcx                     ; type = 0 (Standard Polling)
    mov rdx, 4                       ; TPL_APPLICATION
    xor r8, r8                       ; NotifyFunction = NULL
    xor r9, r9                       ; NotifyContext = NULL
    
    lea rax, [rel tx_event]
    mov [rsp + 32], rax              
    mov rax, [rbx + EFI_BOOT_SERVICES.CreateEvent]
    call rax
    test rax, rax
    jnz .error

    ; link the new event to the TX Token
    mov rax, [rel tx_event]
    mov [rel token_tx + 0], rax      ; token_tx.Event = tx_event

    ; create RX token
    xor rcx, rcx                     ; type = 0 (Standard Polling)
    mov rdx, 4                       ; TPL_APPLICATION
    xor r8, r8                       ; NotifyFunction = NULL
    xor r9, r9                       ; NotifyContext = NULL

    lea rax, [rel rx_event]
    mov [rsp + 32], rax              
    mov rax, [rbx + EFI_BOOT_SERVICES.CreateEvent]
    call rax
    test rax, rax
    jnz .error

    ; link the new event to the RX Token
    mov rax, [rel rx_event]
    mov [rel token_rx + 0], rax      ; token_rx.Event = rx_event

    LOG "Event creation system OK."
    xor rax, rax
    jmp .done

.error:
    ; Handle CreateEvent failure here
    LOG "Failed"
    xor rax, rax
    inc rax

.done:
    add rsp, 40
    pop rbx
    pop rbp
    ret