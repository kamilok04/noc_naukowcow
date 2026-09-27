; ------------------------------------------------------------------------------
; init_network
; Attempts TCP4, then falls back to hunting for ALL active SNP interfaces.
; Returns: RAX = 0 (Success), RAX = 1 (Total Failure)
; ------------------------------------------------------------------------------
init_network:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 48                      
    
    mov qword [rel tcp4_sb_ptr], 0
    mov qword [rel active_snp_count], 0

    ; lea r8, [rel str_dbg_start]
    ; call gui_debug_stall

    ; LOG "Inicjalizacja TCP"
    ; mov rax, [rel boot_services_ptr]
    ; lea rcx, [rel GUID_TCP4_SERVICE_BINDING] 
    ; xor rdx, rdx                               
    ; lea r8, [rel tcp4_sb_ptr]                
    ; mov rax, [rax + EFI_BOOT_SERVICES.LocateProtocol] 
    ; call rax
    
    ; test rax, rax
    ; jnz .try_multi_snp
    
    ; lea r8, [rel str_dbg_tcp_ok]
    ; call gui_debug_stall
    ; mov byte [rel active_protocol], PROTOCOL_TCP4
    ; xor rax, rax
    ; jmp .done

.try_multi_snp:
    ; lea r8, [rel str_dbg_tcp_fail]
    ; call gui_debug_stall

    LOG "Inicjalizacja SNP"
    mov rcx, 2                       ; SearchType = ByProtocol (2)
    lea rdx, [rel GUID_SNP]
    xor r8, r8
    lea r9, [rel temp_file_size]
    lea rax, [rel temp_buffer_ptr]
    mov [rsp + 32], rax
    
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + 312]             ; EFI_BOOT_SERVICES.LocateHandleBuffer
    call rax
    test rax, rax
    jnz .error_no_snp
    
    ; lea r8, [rel str_dbg_hndl_ok]
    ; call gui_debug_stall

    mov r12, [rel temp_file_size]    ; R12 = liczba handli
    mov r13, [rel temp_buffer_ptr]   ; R13 = tablica handli
    xor r14, r14                     ; R14 = pętla

.snp_loop:
    cmp r14, r12
    jge .eval_snp
    
    ; lea r8, [rel str_dbg_testing]
    ; call gui_debug_stall

    LOG "Getting SNP handler"
    mov rcx, [r13 + r14 * 8]
    lea rdx, [rel GUID_SNP]
    lea r8, [rel snp_ptr]            
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.HandleProtocol]
    call rax
    test rax, rax
    jnz .proto_fail
    
    call setup_snp
    test rax, rax
    jnz .setup_fail                 

    LOG "SNP init OK"
    ; lea r8, [rel str_dbg_snp_ok]
    ; call gui_debug_stall

    mov rcx, [rel active_snp_count]
    mov rdx, [rel snp_ptr]
    lea r8, [rel active_snp_ptrs]
    mov [r8 + rcx * 8], rdx
    inc qword [rel active_snp_count]
    jmp .next_handle

.proto_fail:
    LOG "Failed to get SNP handler protocol"
    ; lea r8, [rel str_dbg_proto_err]
    ; call gui_debug_stall
    ; jmp .next_handle

.setup_fail:
    LOG "Failed to initialize SNP protocol"
    ; lea r8, [rel str_dbg_setup_er]
    ; call gui_debug_stall
    
.next_handle:
    inc r14
    jmp .snp_loop

.eval_snp:
    mov rcx, [rel temp_buffer_ptr]
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + 72]              ; FreePool
    call rax

    ; does anything work?
    cmp qword [rel active_snp_count], 0
    je .error
    
    ; lea r8, [rel str_dbg_eval_ok]
    ; call gui_debug_stall

    mov byte [rel active_protocol], PROTOCOL_SNP
    xor rax, rax
    jmp .done

.error_no_snp:
    ; lea r8, [rel str_dbg_no_hndl]
    ; call gui_debug_stall
    LOG "No SNP handlers found"
.error:
    ; lea r8, [rel str_dbg_fail_all]
    ; call gui_debug_stall
    LOG "No connectivity, only offline play available."

    mov byte [rel active_protocol], PROTOCOL_NONE
    mov rax, 1

.done:
    add rsp, 48
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret


; ; ------------------------------------------------------------------------------
; ; gui_debug_stall
; ; Draws a string to the screen and stalls for 1 second.
; ; Inputs: R8 - Pointer to string
; ; ------------------------------------------------------------------------------
; gui_debug_stall:
;     push rbp
;     mov rbp, rsp
;     push rbx
;     push rcx
;     push rdx
;     push r8
;     push r9
;     push r10
;     push r11
;     push r12
;     push r13
;     push r14
;     push r15
;     sub rsp, 40
;     xor rdx, rdx

;     mov rcx, 50                  ; X coordinate
;     add word [rel debug_y], 16
;     cmp word [rel debug_y], 700
;     jge .zero
;     jmp .ok
; .zero:
;     mov word [rel debug_y], 0
; .ok:
;     mov dx, word [rel debug_y] ;   Y coordinate
;     mov r10d, 0x00FF8C00         ; Color (Dark Orange)
;     mov r13, 2                   ; Text Scale
;     call draw_string
;     call swap_buffers

;     mov rcx, 1000000             ; 1,000,000 microseconds = 1 second
;     mov rbx, [rel boot_services_ptr]
;     mov rax, [rbx + 248]         ; EFI_BOOT_SERVICES.Stall
;     call rax

;     add rsp, 40
;     pop r15
;     pop r14
;     pop r13
;     pop r12
;     pop r11
;     pop r10
;     pop r9
;     pop r8
;     pop rdx
;     pop rcx
;     pop rbx
;     pop rbp
;     ret

; ; ------------------------------------------------------------------------------
; ; Debug Strings
; ; ------------------------------------------------------------------------------
; str_dbg_start    db "DBG: init_network started", 0
; str_dbg_tcp_ok   db "DBG: TCP4 successfully bound!", 0
; str_dbg_tcp_fail db "DBG: TCP4 failed, falling back to Multi-SNP", 0
; str_dbg_no_hndl  db "DBG: LocateHandleBuffer found 0 SNP handles", 0
; str_dbg_hndl_ok  db "DBG: LocateHandleBuffer found SNP handles", 0
; str_dbg_testing  db "DBG: Testing an SNP handle...", 0
; str_dbg_proto_er db "DBG: HandleProtocol failed for handle", 0
; str_dbg_setup_er db "DBG: setup_snp failed for handle", 0
; str_dbg_snp_start db "DBG: SNP->Start() passed", 0
; str_dbg_snp_retry db "DBG: PHY Link Down. Retrying Initialize...", 0
; str_dbg_snp_init  db "DBG: SNP->Initialize() passed", 0
; str_dbg_snp_init_f db "DBG: SNP->Initialize() FAILED", 0
; str_dbg_snp_filt  db "DBG: SNP->ReceiveFilters() passed", 0
; str_dbg_snp_filt_f db "DBG: SNP->ReceiveFilters() FAILED", 0
; str_dbg_snp_ok   db "DBG: Hardware NIC successfully added to array!", 0
; str_dbg_eval_ok  db "DBG: At least 1 NIC initialized successfully.", 0
; str_dbg_fail_all db "DBG: Total Multi-NIC Failure.", 0

; ------------------------------------------------------------------------------
; setup_connection
; ------------------------------------------------------------------------------
setup_connection:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40 

    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .bypass

    mov rcx, [rel tcp4_sb_ptr]
    lea rdx, [rel tcp4_handle]
    mov rax, [rcx + 0x00]            
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
    lea rdx, [rel tcp4_config_join] 
    jmp .configure
.load_host:
    lea rdx, [rel tcp4_config_host]

.configure:
    mov rcx, [rel tcp4_ptr]          
    mov rax, [rcx + EFI_TCP4_PROTOCOL.Configure]            
    call rax
    test rax, rax
    jnz .error

.bypass:
    xor rax, rax
    jmp .done

.error:
    mov rax, 1

.done:
    add rsp, 40
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; start_handshake
; ------------------------------------------------------------------------------
start_handshake:
    push rbp
    mov rbp, rsp
    sub rsp, 32                      

    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .bypass

    mov rax, 0x8000000000000006      
    mov [rel token_handshake + 8], rax

    mov rcx, [rel tcp4_ptr]          
    lea rdx, [rel token_handshake]   

    cmp byte [rel net_role], NET_ROLE_SERVER
    je .host_accept

.client_connect:
    mov rax, [rcx + EFI_TCP4_PROTOCOL.Connect]        
    call rax
    jmp .check_status

.host_accept:
    mov rax, [rcx + EFI_TCP4_PROTOCOL.Accept]           
    call rax

.check_status:
    test rax, rax
    jnz .error                       

.bypass:
    mov byte [rel connection_status], CONNECTION_STATE_PENDING
    xor rax, rax
    jmp .done

.error:
    mov byte [rel connection_status], CONNECTION_STATE_OFFLINE
    mov rax, 1

.done:
    add rsp, 32
    pop rbp
    ret

; ------------------------------------------------------------------------------
; transition_to_network
; ------------------------------------------------------------------------------
transition_to_network:
    push rbp
    mov rbp, rsp
    
    call init_network
    test rax, rax
    jnz .net_failed
    
    call setup_connection
    call create_network_events
    call start_handshake
    
    mov byte [rel in_menu], MENU_STATE_AWAITING_CONNECTION
    jmp .done
    
.net_failed:
    mov byte [rel in_menu], MENU_STATE_MAIN
.done:
    pop rbp
    ret

; ------------------------------------------------------------------------------
; broadcast_snp_packet
; Internal Multi-NIC routing helper
; ------------------------------------------------------------------------------
broadcast_snp_packet:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 56
    
    ; send the role within a packet
    ; without that, the SNP would be entirely content with connecting to itself
    ; which is Not Good™
    mov al, byte [rel net_role]
    mov byte [rel snp_tx_buffer + 17], al

    mov r12, [rel active_snp_count]
    xor r13, r13
.loop:
    cmp r13, r12
    jge .done
    
    lea rcx, [rel active_snp_ptrs]
    mov rcx, [rcx + r13 * 8]

    ; The MAC address of the device will be
    ; 02:21:37:04:20:XX
    ; where '02' means it's assigned by us (locally-administered MAC)
    ; and 'XX' is the role: 1 for server, 2 for client
    
    mov word [rel snp_tx_buffer + 6], 0x2102       
    mov dword [rel snp_tx_buffer + 8], 0x00200437 
    
    mov al, byte [rel net_role]
    mov byte [rel snp_tx_buffer + 11], al         
    
    xor rdx, rdx                     ; HeaderSize = 0 (Raw Frame)
    mov r8, 64                       ; BufferSize = 64 (bare minimum allowed)
    lea r9, [rel snp_tx_buffer]
    mov qword [rsp + 32], 0          ; SrcAddr
    mov qword [rsp + 40], 0          ; DestAddr
    mov qword [rsp + 48], 0          ; Protocol
    
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.Transmit]
    call rax
    
    inc r13
    jmp .loop
.done:
    add rsp, 56
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; send_sync_packet
; SNP is a UDP protocol. In order to ensure some sensible sync between client and server,
; occasional polling must happen.
; same goes for TCP, but it's a longer story
; ------------------------------------------------------------------------------
send_sync_packet:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .snp_tx

    mov rax, 0x8000000000000006
    mov [rel token_tx + 8], rax

    ; grab the packet data
    lea rax, [rel tx_packet_data]
    mov [rel token_tx + 16], rax
    lea rax, [rel sync_payload]
    mov [rel tx_packet_data + 24], rax

    mov rcx, [rel tcp4_ptr]
    lea rdx, [rel token_tx]
    mov rax, [rcx + EFI_TCP4_PROTOCOL.Transmit]
    call rax
    jmp .done

.snp_tx:
    mov al, byte [rel sync_payload]
    mov byte [rel snp_tx_buffer + 14], al
    mov al, byte [rel sync_payload + 1]
    mov byte [rel snp_tx_buffer + 15], al
    mov al, byte [rel sync_payload + 2]
    mov byte [rel snp_tx_buffer + 16], al
    call broadcast_snp_packet

.done:
    add rsp, 32
    pop rbp
    ret

; ------------------------------------------------------------------------------
; queue_network_rx
; ------------------------------------------------------------------------------
queue_network_rx:
    push rbp
    mov rbp, rsp
    sub rsp, 32

    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .done                         ; SNP receives continuously via polling

    mov rax, 0x8000000000000006
    mov [rel token_rx + 8], rax
    lea rax, [rel rx_packet_data]
    mov [rel token_rx + 16], rax
    lea rax, [rel rx_data]
    mov [rel rx_packet_data + 24], rax

    mov rcx, [rel tcp4_ptr]
    lea rdx, [rel token_rx]
    mov rax, [rcx + EFI_TCP4_PROTOCOL.Receive]
    call rax

.done:
    add rsp, 32
    pop rbp
    ret

; ------------------------------------------------------------------------------
; network_teardown
; ------------------------------------------------------------------------------
network_teardown:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 40

    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .snp_td
    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .done

    mov rcx, [rel tcp4_ptr]
    test rcx, rcx
    jz .kill_child
    xor rdx, rdx                     
    mov rax, [rcx + 0x08]            
    call rax

.kill_child:
    mov rcx, [rel tcp4_sb_ptr]
    mov rdx, [rel tcp4_handle]
    mov rax, [rcx + 0x08]            
    call rax
    jmp .done

.snp_td:
    mov r12, [rel active_snp_count]
    xor r13, r13
.td_loop:
    cmp r13, r12
    jge .done
    
    lea r8, [rel active_snp_ptrs]
    mov rcx, [r8 + r13 * 8]
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.Shutdown]          ; SNP->Shutdown
    call rax
    
    lea r8, [rel active_snp_ptrs]
    mov rcx, [r8 + r13 * 8]
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.Stop]            ; SNP->Stop
    call rax
    
    inc r13
    jmp .td_loop

.done:
    mov qword [rel active_snp_count], 0
    mov byte [rel active_protocol], PROTOCOL_NONE
    mov byte [rel connection_status], CONNECTION_STATE_OFFLINE
    mov byte [rel net_role], NET_ROLE_OFFLINE
    mov qword [rel tcp4_ptr], 0
    mov qword [rel tcp4_handle], 0
    
    add rsp, 40
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
    
; ------------------------------------------------------------------------------
; send_network_move
; ------------------------------------------------------------------------------
send_network_move:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    cmp byte [rel active_protocol], PROTOCOL_SNP
    je .snp_tx

    mov byte [rel move_payload + MOVE_PAYLOAD.Origin], cl
    mov byte [rel move_payload + MOVE_PAYLOAD.Destination], dl
    mov byte [rel move_payload + MOVE_PAYLOAD.Promotion], r8b


    movzx rcx, cx
    movzx rdx, dx
    LOG "Move queued for TX: %x -> %x", rcx, rdx
    
    ; we're not ready yet
    mov rax, 0x8000000000000006
    mov [rel token_tx + 8], rax

    ; point the sent token to the move data instead of the sync command
    lea rax, [rel move_payload]
    mov [rel tx_packet_data + 24], rax

    ; link the packet to the token
    lea rax, [rel tx_packet_data]
    mov [rel token_tx + 16], rax

    ; transmit (+0x28)
    mov rcx, [rel tcp4_ptr]
    lea rdx, [rel token_tx]
    mov rax, [rcx + 0x28]        
    call rax
    jmp .done

.snp_tx:
    mov byte [rel snp_tx_buffer + 14], cl
    mov byte [rel snp_tx_buffer + 15], dl
    mov byte [rel snp_tx_buffer + 16], r8b
    call broadcast_snp_packet

.done:
    add rsp, 32
    pop rbp
    ret
    ; ------------------------------------------------------------------------------
; setup_snp
; ------------------------------------------------------------------------------
setup_snp:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 48

    ; this is a fix for real life
    ; NIC's status is ambiguous after a PXE boot failed
    ; e. g. the firmware reports the NIC is up, but it's not
    ; instead of guerssing and praying, just reset the thing and force it up

    mov rcx, [rel snp_ptr]
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.Shutdown]
    call rax
    mov rcx, [rel snp_ptr]
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.Stop]
    call rax

    ; wakey wakey
    mov rcx, [rel snp_ptr]
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.Start]
    call rax

    ; lea r8, [rel str_dbg_snp_start]
    ; call gui_debug_stall

    mov r12, 4

.init_retry:
    mov rcx, [rel snp_ptr]
    xor rdx, rdx
    xor r8, r8
    mov rax, [rcx +EFI_SIMPLE_NETWORK_PROTOCOL.Initialize]
    call rax
    test rax, rax
    jz .init_ok

    ; lea r8, [rel str_dbg_snp_retry]
    ; call gui_debug_stall

    ; wait for a sec and try again, sometimes wakeup is slow
    mov rcx, 1000000
    mov rbx, [rel boot_services_ptr]
    mov rax, [rbx + 248]             ; EFI_BOOT_SERVICES.Stall
    call rax

    dec r12
    jnz .init_retry
    jmp .error_init

.init_ok:
    ; lea r8, [rel str_dbg_snp_init]
    ; call gui_debug_stall

    ; apply incoming packet filtering
    mov rcx, [rel snp_ptr]
    mov rdx, 0x05                    ; Unicast (0x01) | Broadcast (0x04)
    xor r8, r8
    xor r9, r9
    mov qword [rsp + 32], 0
    mov qword [rsp + 40], 0
    mov rax, [rcx + EFI_SIMPLE_NETWORK_PROTOCOL.ReceiveFilters]
    call rax
    
    test rax, rax
    jnz .error_filt_warn             ; don't die if something is wrong with the filters
                                     ; vendors often don't implement some or apply their defaults anyway

    ; lea r8, [rel str_dbg_snp_filt]
    ; call gui_debug_stall
    jmp .success

.error_filt_warn:

    ; This is an empty block because Life™
    ; OEM firmware often returns EFI_UNSUPPORTED but 
    ; still allows broadcasts by default. Keep goin'

.success:
    LOG "SNP initialization OK"
    xor rax, rax
    jmp .done

.error_init:
    LOG "Failed to initialize SNP!"
    ; lea r8, [rel str_dbg_snp_init_f]
    ; call gui_debug_stall
    mov rax, 1

.done:
    add rsp, 48
    pop r12
    pop rbx
    pop rbp
    ret