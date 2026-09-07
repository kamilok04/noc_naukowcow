; ------------------------------------------------------------------------------
; poll_network_events
; Called once per frame in the main loop to check asynchronous network tasks.
; ------------------------------------------------------------------------------
poll_network_events:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 32                      

    ; Only poll the handshake if it's currently expected
    cmp byte [rel connection_status], 1
    jne .check_rx                    ; connected, skip

.check_handshake:
    ; BootServices->CheckEvent(handshake_event)
    mov rcx, [rel handshake_event]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.CheckEvent]
    call rax

    test rax, rax
    jnz .done                        ; EFI_NOT_READY

    ; got event, get its status
    mov rax, [rel token_handshake + EFI_TCP4_COMPLETION_TOKEN.Status] 
    test rax, rax
    jnz .error                       ; status != 0 => the connection aborted/failed

    ; we host?
    cmp byte [rel net_role], 1
    jne .set_connected               ; clients need not do anything yet

.host_extract_child:
    ; an accepted connection is a brand new handle
    mov rcx, [rel token_handshake + EFI_TCP4_LISTEN_TOKEN.NewChildHandle] 
    lea rdx, [rel GUID_TCP4]
    
    ; overwrite the embryonic connection with the complete one
    lea r8, [rel tcp4_ptr]           
    mov rax, [rbx + EFI_BOOT_SERVICES.HandleProtocol]
    call rax
    test rax, rax
    jnz .error

.set_connected:
    mov byte [rel connection_status], 2   
    ; TODO: tada.wav here
    jmp .done

.error:
    mov byte [rel connection_status], 0   ; cannot connect, stay offline then

.check_rx:
    ; Future: if connection_status == 2, check for incoming moves here

.done:
    add rsp, 32
    pop rbx
    pop rbp
    ret