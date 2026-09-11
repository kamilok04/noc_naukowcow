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

    ; other network events
    rx_event dq 0
    tx_event dq 0

    ; tx data
    sync_payload db 0xAA, 0, 0


    ; RX/TX tokens
    align 8
    token_rx times 64 db 0 
    token_tx times 64 db 0

    tx_packet_data:
        db 1 ; send NOW
        db 0 ; but not urgently
        dw 0 ; pad
        dd 1 ; 1 byte of data
        dd 1 ; single fragment
        dd 0 ; pad
        dd 1 ; the first fragment is 1 byte long
        dd 0 ; pad
        dq sync_payload ; actual data

    align 8
    rx_packet_data:
    db 0 ; not urgent
    db 0, 0, 0 ; 3 bytes padding
    dd 1 ; 1 byte of data
    dd 1 ; 1 fragment
    dd 0 ; pad
    dd 1 ; the first fragment is 1 byte long
    dd 0 ; pad
    dq rx_data ; actual data buffer pointer

    ; RX buffer (for an incoming "sync" command)
    rx_buffer dq 0 
    rx_data   db 0
    

    align 8
    token_handshake:
        istruc EFI_TCP4_LISTEN_TOKEN  ; large enough to act as a Connection Token
            at EFI_TCP4_LISTEN_TOKEN.CompletionToken, dq 0, 0
            at EFI_TCP4_LISTEN_TOKEN.NewChildHandle,  dq 0
        iend
