; ------------------------------------------------------------------------------
; init_network
; Queries UEFI for the TCP4 Service Binding Protocol.
; Returns:
;   RAX: 0 in success, 1 on failure
; ------------------------------------------------------------------------------
init_network:
    push rbp
    mov rbp, rsp
    sub rsp, 32                      
    
    mov rax, [rel boot_services_ptr]
    
    lea rcx, [rel GUID_TCP4_SERVICE_BINDING] 
    xor rdx, rdx                               
    lea r8, [rel tcp4_sb_ptr]                
    

    mov rax, [rax + EFI_BOOT_SERVICES.LocateProtocol] 
    call rax
    
    test rax, rax
    jnz .error
    
    LOG "TCP4 service binding OK."
    jmp .done
    
.error:
    LOG "Failed to locate TCP4 service binding; code: %x", rax
    LOG "Only local game will be available."
.done:
    add rsp, 32
    pop rbp
    ret

; ------------------------------------------------------------------------------
; setup_connection
; Spawns a TCP4 child, grabs the protocol, and configures the IP/subnet.
; ------------------------------------------------------------------------------
setup_connection:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 48   

    ; ServiceBinding->CreateChild(This, &ChildHandle)
    mov rcx, [rel tcp4_sb_ptr]
    lea rdx, [rel tcp4_handle]
    mov rax, [rcx + 0x00]            ; +0x00 = CreateChild
    call rax
    test rax, rax
    jnz .error

    ; BootServices->HandleProtocol(ChildHandle, GUID, &TCP4_Protocol)
    mov rcx, [rel tcp4_handle]
    lea rdx, [rel GUID_TCP4]
    lea r8, [rel tcp4_ptr]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.HandleProtocol]
    call rax
    test rax, rax
    jnz .error

    ; pick your config (1 = host, 2 = join)
    cmp byte [rel net_role], 1
    je .load_host
    lea rdx, [rel tcp4_config_join] ;stored in efi.asm
    jmp .configure
.load_host:
    lea rdx, [rel tcp4_config_host]

.configure:
    ; Call TCP4->Configure(This, &ConfigData)
    mov rcx, [rel tcp4_ptr]          
    mov rax, [rcx + 0x08]            ; +0x08 = Configure
    call rax
    test rax, rax
    jnz .error

    LOG "TCP4 setup OK"
    jmp .done

.error:
    LOG "TCP4 Setup Failed! Code: %x", rax

.done:
    add rsp, 48
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; start_handshake
; Instructs the TCP4 protocol to begin the async connect/accept
; ------------------------------------------------------------------------------
start_handshake:
    push rbp
    mov rbp, rsp
    sub rsp, 32                      

    mov rcx, [rel tcp4_ptr]          ; TCP4 protocol interface
    lea rdx, [rel token_handshake]   ; completion token

    ; 1 = Host, 2 = Join
    cmp byte [rel net_role], 1
    je .host_accept

.client_connect:
    ; TCP4->Connect(This, ConnectionToken)
    mov rax, [rcx + 0x18]            ; +0x18 is connect
    call rax
    jmp .check_status

.host_accept:
    ; Call TCP4->Accept(This, ListenToken)
    mov rax, [rcx + 0x20]            ; +0x20 is accept
    call rax

.check_status:
    test rax, rax
    jnz .error                       ; queueing fiasco
    

    mov byte [rel connection_status], 1  ; 1 = handshake is pending
    LOG "Pending a client..."
    jmp .done

.error:
    LOG "TCP4 Handshake Initialization Failed! Code: %x", rax

.done:
    add rsp, 32
    pop rbp
    ret