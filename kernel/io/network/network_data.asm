    ; networking
    tcp4_sb_ptr dq 0        ; binding ptr
    connection_ptr    dq 0  ; actual connection ptr
    tcp4_handle dq 0        ; holds the hand(le) for child connection
    tcp4_ptr    dq 0        ; protocol ptr
    NET_ROLE_OFFLINE equ 0
    NET_ROLE_SERVER equ 1
    NET_ROLE_CLIENT equ 2
    net_role    db NET_ROLE_OFFLINE    

    CONNECTION_STATE_OFFLINE equ 0
    CONNECTION_STATE_PENDING equ 1
    CONNECTION_STATE_CONNECTED equ 2
    connection_status db CONNECTION_STATE_OFFLINE     ; 0 = offline, 1 = pending handshake, 2 = connected

    align 8
    tcp4_config_host:
        istruc EFI_TCP4_CONFIG_DATA
            at .TypeOfService,     db 0
            at .TimeToLive,        db 255
            at .UseDefaultAddress, db 0
            at .StationAddress,    db 10, 244, 244, 1       ; 10.244.244.1/30
            at .SubnetMask,        db 255, 255, 255, 252
            at .StationPort,       dw 27015
            at .RemoteAddress,     db 0, 0, 0, 0
            at .RemotePort,        dw 0
            at .ActiveFlag,        db 0          ; LISTEN
            at .ControlOption,     dq 0
        iend

    align 8
    tcp4_config_join:
        istruc EFI_TCP4_CONFIG_DATA
            at EFI_TCP4_CONFIG_DATA.TypeOfService,     db 0
            at EFI_TCP4_CONFIG_DATA.TimeToLive,        db 255
            at EFI_TCP4_CONFIG_DATA.UseDefaultAddress, db 0
            at EFI_TCP4_CONFIG_DATA.StationAddress,    db 10, 244, 244, 2      ; 10.244.244.2/30
            at EFI_TCP4_CONFIG_DATA.SubnetMask,        db 255, 255, 255, 252
            at EFI_TCP4_CONFIG_DATA.StationPort,       dw 0
            at EFI_TCP4_CONFIG_DATA.RemoteAddress,     db 10, 244, 244, 1
            at EFI_TCP4_CONFIG_DATA.RemotePort,        dw 27015
            at EFI_TCP4_CONFIG_DATA.ActiveFlag,        db 1          ; CONNECT
            at EFI_TCP4_CONFIG_DATA.ControlOption,     dq 0
        iend

    handshake_event  dq 0        ; EFI_EVENT 

    ; SNP struc
    struc EFI_SIMPLE_NETWORK_PROTOCOL
    .Revision       resq 1 ; 0x00
    .Start          resq 1 ; 0x08
    .Stop           resq 1 ; 0x10
    .Initialize     resq 1 ; 0x18
    .Reset          resq 1 ; 0x20
    .Shutdown       resq 1 ; 0x28
    .ReceiveFilters resq 1 ; 0x30
    .StationAddress resq 1 ; 0x38
    .Statistics     resq 1 ; 0x40
    .MCastIpToMac   resq 1 ; 0x48
    .NvData         resq 1 ; 0x50
    .GetStatus      resq 1 ; 0x58
    .Transmit       resq 1 ; 0x60
    .Receive        resq 1 ; 0x68
    .WaitForPacket  resq 1 ; 0x70
    .Mode           resq 1 ; 0x78 (Pointer to EFI_SIMPLE_NETWORK_MODE)
    endstruc

    struc EFI_TCP4_SERVICE_BINDING_PROTOCOL
    .CreateChild  resq 1 ; 0x00
    .DestroyChild resq 1 ; 0x08
    endstruc

    struc EFI_TCP4_PROTOCOL
    .GetModeData  resq 1 ; 0x00
    .Configure    resq 1 ; 0x08
    .Routes       resq 1 ; 0x10
    .Connect      resq 1 ; 0x18
    .Accept       resq 1 ; 0x20
    .Transmit     resq 1 ; 0x28
    .Receive      resq 1 ; 0x30
    .Close        resq 1 ; 0x38
    .Cancel       resq 1 ; 0x40
    .Poll         resq 1 ; 0x48
    endstruc

    ; other network events
    rx_event dq 0
    tx_event dq 0

    ; tx data
    sync_payload db 0xAA, 0, 0

    struc MOVE_PAYLOAD
        .Origin resb 1
        .Destination resb 1
        .Promotion resb 1
    endstruc

    move_payload:
        istruc MOVE_PAYLOAD
            at .Origin, db 0
            at .Destination, db 0
            at .Promotion, db 0
        iend
    

    ; RX/TX tokens
    align 8
    token_rx times 64 db 0 
    token_tx times 64 db 0

    tx_packet_data:
        db 1 ; send NOW
        db 0 ; but not urgently
        dw 0 ; pad
        dd 3 ; 3 bytes of data (a move)
        dd 1 ; single fragment
        dd 0 ; pad
        dd 3 ; the first (and last) fragment is 3 byte long
        dd 0 ; pad
        dq sync_payload ; actual data, payload is the default, this will be changed

    align 8
    rx_packet_data:
    db 0 ; not urgent
    db 0, 0, 0 ; 3 bytes padding
    dd 3 
    dd 1 ; 1 fragment
    dd 0 ; pad
    dd 3
    dd 0 ; pad
    dq rx_data ; actual data buffer pointer

    ; rx data (sync/move)
    rx_buffer dq 0 
    rx_data:
        istruc MOVE_PAYLOAD
            at .Origin, db 0
            at .Destination, db 0
            at .Promotion, db 0
        iend

    is_remote_move db 0 ; 1 = over the net, 0 = made by the player present here

    last_local_move:
        istruc MOVE_PAYLOAD
            at .Origin,      db 0
            at .Destination, db 0
            at .Promotion,   db 0
        iend
    align 8
    last_remote_move: 
        istruc MOVE_PAYLOAD
            at .Origin,      db 0
            at .Destination, db 0
            at .Promotion,   db 0
        iend
    align 8
    token_handshake:
        istruc EFI_TCP4_LISTEN_TOKEN  ; large enough to act as a Connection Token
            at EFI_TCP4_LISTEN_TOKEN.CompletionToken, dq 0, 0
            at EFI_TCP4_LISTEN_TOKEN.NewChildHandle,  dq 0
        iend

    ; dual-stack networking
    PROTOCOL_NONE equ 0
    PROTOCOL_TCP4 equ 1
    PROTOCOL_SNP  equ 2
    PROTOCOL_AUTO equ 3
    active_protocol db PROTOCOL_AUTO

    ; multiple NICs
    snp_ptr dq 0
    active_snp_count dq 0
    active_snp_ptrs  times 16 dq 0

    ; we need to somehow work with L2 protocols
    ; imma just poll the opponent, maybe one day they'll pick up
    snp_beacon_timer db 0 

    align 8
    mac_broadcast db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
    mac_protocol  dw 0x88B5          

    ;  SNP Rx/Tx -
    align 8
    snp_tx_buffer:
        .DestMAC   times 6 db 0xFF   
        .SrcMAC    times 6 db 0x00  
        .EtherType dw 0xB588         
        .Payload   times 50 db 0x00  ; 
        align 8
    snp_rx_buffer times 4096 db 0    ; standard ethernet packet size to absorb incoming frames
    snp_rx_size   dq 4096            ; heard of big-packet attacks? this is the assumption these abuse
    recycled_tx_buf dq 0             ; TX buffers need to be actively cleared, otherwise they get full and don't TX anymore
    interrupt_status dd 0
    needs_ack db 0
    ; sync SNP
    ack_pending db 0