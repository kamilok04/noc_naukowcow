%include "pe_headers.asm"

%include "uefi_headers.asm" ; a global header; will be available to this file and every file included below this line.
%include "iso9660.asm"
%include "gop_headers.asm"

; ==============================================================================
; MACROS
; ==============================================================================
%include "macros.asm"

; ==============================================================================
; SECTION .text
; ==============================================================================
text_raw_ptr equ $ - DOS_HEADER
text_rva equ 0x1000

efi_main:
    sub rsp, 40              ; allocate 32 bytes shadow space + 8 bytes alignment
    mov r12, rdx             ; save SystemTable to non-volatile register

    ; Log startup
    LOG "Booting."
    lea rax, [rel msg_printf_test]
    LOG "Printf test: %s", rax


    mov rbx, [r12 + 96]      ; RBX = SystemTable->BootServices
    mov [rel boot_services_ptr], rbx

    ; kill the watchdog
    ; UEFI Spec
    ; 3.1.2: there is a 5-minute timer present
    ;        if it expires, reboot
    ; 7.5.1: a boot image may disable the watchdog
    ;        if it wants to

    xor rcx, rcx                  ; no timeout
    xor rdx, rdx                  ; no error
    xor r8, r8                    ; nothing
    xor r9, r9                    ; die already
    
    mov rbx, [rel boot_services_ptr] 
    sub rsp, 32                      ; Allocate shadow space
    call [rbx + EFI_BOOT_SERVICES.SetWatchdogTimer]
    add rsp, 32                      ; Clean up shadow space

    ; load the root directory
    call init_block_io
    
    mov rcx, 2              ; PoolType: EfiLoaderData
    mov rdx, 2048           ; 1 sector
    lea r8, [rel sector_buffer]
    call [rbx + EFI_BOOT_SERVICES.AllocatePool]

    mov r8, 16
    mov r9, 2048
    mov r10, [rel sector_buffer]
    call read_sectors

    mov rdi, [rel sector_buffer]
    mov r8d, dword [rdi + ISO9660_PVD.RootDirectoryRecord + ISO9660_DIR_RECORD.ExtentLocationLE]
    mov [rel root_dir_lba], r8

    mov r9d, dword [rdi + ISO9660_PVD.RootDirectoryRecord + ISO9660_DIR_RECORD.DataLengthLE]
    mov [rel root_dir_size], r9
    
    mov r9, 2048
    mov r10, [rel sector_buffer]
    call read_sectors

    ; try to read a file
    lea rcx, [rel target_file]
    LOG "Attempting to read %s", rcx
    call fopen
    
    test rax, rax
    jz .file_error
    
    mov [rel test_file_handle], rax
    LOG "File opened successfully. File Size: %d", [rax + FILE.FileSize]

    mov rbx, [rel boot_services_ptr]
    lea rcx, [rel GUID_GOP]  ; protocol GUID
    xor rdx, rdx             ; registration (NULL)
    lea r8, [rel gop_ptr]    ; out ptr

    
    call [rbx + EFI_BOOT_SERVICES.LocateProtocol]
    
    test rax, rax            ; Check if EFI_SUCCESS (0)
    jnz .error_gop
    
    LOG "The GOP protocol located succesfully."
    
    call set_max_resolution

    ; ask the framebuffer what it knows
    mov rbx, [rel gop_ptr]   
    mov rbx, [rbx + 24]      ; RBX = GOP->Mode
    
    mov rdi, [rbx + 24]      ; RDI = FrameBufferBase
    mov [rel framebuffer_base], rdi

    mov rcx, [rbx + 8]       ; RCX = Mode->Info

    mov eax, dword [rcx + 4] ; HorizontalResolution
    mov dword [rel screen_w], eax
    
    mov eax, dword [rcx + 8] ; VerticalResolution
    mov dword [rel screen_h], eax
    mov esi, dword [rcx + 32]; RSI = PixelsPerScanLine (Pitch)
    mov [rel framebuffer_pitch], rsi
    
    
    LOG "Screen dimensions are %dx%d", rax, rsi

    mov eax, dword [rel framebuffer_pitch]
    mov ecx, dword [rel screen_h]
    mul rcx                            ; RAX = Pitch * Height
    shl rax, 2                         ; RAX * 4 (Bytes per pixel)
    mov [rel backbuffer_size], rax
    
    add rax, 4095
    shr rax, 12                        ; RAX = count of 4KB pages to allocate

    mov rcx, 0                         ; AllocateAnyPages
    mov rdx, 2                         ; EfiLoaderData
    mov r8, rax                        ; page count
    lea r9, [rel backbuffer_ptr]       
    
    mov rbx, [rel boot_services_ptr]
    sub rsp, 32
    call [rbx + 40]                    ; EFI_BOOT_SERVICES.AllocatePages
    add rsp, 32
    
    test rax, rax
    jnz .error_allocation              ; Handle failure if out of memory
    
    LOG "Double buffer allocated at: %x", [rel backbuffer_ptr]

    
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    mov rcx, 250
    mov rdx, 200
    mov r8, [rel test_file_handle]
    mov r8, [r8 + FILE.BufferPtr]
    cmp word [r8], 0x4D42
    jne .file_error          ; If it's not "BM", the disk read failed!

    call draw_bitmap

    LOG "Testing string output functionality."
    lea r8, [rel utf_test]
    mov rcx, 50
    xor rdx, rdx
    mov r10d, COLOR_HIGHLIGHT
    mov r13, 3
    call draw_string

    lea r8, [rel utf_red]
    mov rcx, 50
    mov rdx, 50
    mov r10d, COLOR_RED
    mov r13, 2
    call draw_string

    lea r8, [rel utf_green]
    mov rcx, 50
    mov rdx, 100
    mov r10d, COLOR_GREEN
    mov r13, 2
    call draw_string

    lea r8, [rel utf_blue]
    mov rcx, 50
    mov rdx, 150
    mov r10d, COLOR_BLUE
    mov r13, 2
    call draw_string

    lea r8, [rel utf_ex_1]
    mov rcx, 50
    mov rdx, 180
    mov r10d, COLOR_PROMOTION
    mov r13, 1
    call draw_string    
    
    lea r8, [rel utf_ex_2]
    mov rcx, 50
    mov rdx, 190
    mov r10d, COLOR_PROMOTION
    mov r13, 1
    call draw_string

    lea r8, [rel utf_ex_3]
    mov rcx, 50
    mov rdx, 200
    mov r10d, COLOR_PROMOTION
    mov r13, 1
    call draw_string
  
    call swap_buffers

    cmp byte [rel net_role], 0
    je .loading_assets
    LOG "Loading networking functionalities."
    
    call init_network                ; find the protocol
    test rax, rax
    jnz .loading_assets
    call setup_connection            ; apply /30 subnet
    test rax, rax
    jnz .loading_assets
    call create_network_events       ; create events
    test rax, rax
    jnz .loading_assets
    call start_handshake             ; trigger a connection

.loading_assets:
    LOG "Loading assets..."
    call init_assets

    LOG "Entering interactive mode."
    call init_mouse
    mov rcx, [rel mouse_ptr]
    mov rax, [rcx + 16]                 
    mov [rel wait_event_array], rax

    ; Set initial state and force the first frame draw
    mov byte [rel in_menu], MENU_STATE_MAIN
    call render_main_menu
    call swap_buffers

.main_loop:
;     ; how many events are pending?
;     mov rcx, 1           
;     cmp qword [rel wait_event_array + 8], 0
;     je .do_wait ; no network event, proceed
;     mov rcx, 2 ; two events incoming, expect both of them    
; .do_wait:            
;     lea rdx, [rel wait_event_array]     
;     lea r8, [rel event_index]            
;     mov rbx, [rel boot_services_ptr]
;     sub rsp, 32
;     call [rbx + EFI_BOOT_SERVICES.WaitForEvent]                     
;     add rsp, 32
    
;     test rax, rax
;     jnz .main_loop

    ; Give more control to the I/O handlers
    call process_mouse_input

    ; network polling (skip if offline)
    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .main_loop
    call poll_network_events

    jmp .main_loop 

.error_allocation:
    LOG "Failed to allocate memory."
    jmp .hang
    
.file_error:
    LOG "Unable to read the requested file: %s", rcx
    jmp .hang

.iso_dead:
    lea rsi, [rel msg_iso_read_failed]
    call puts
    jmp .hang


.hang:
    cli
    hlt
    jmp .hang

.error_gop:
    LOG "Failed to load the GOP protocol."
    jmp .hang

; include subroutines directly into the .text section
; %include "uefi_headers.asm"
%include "utils.asm"
%include "drawing_utils.asm"
%include "fileio.asm"
%include "mouse.asm"
%include "gop_utils.asm"
%include "draw_chessboard.asm"
%include "init_assets.asm"
%include "validity_checks.asm"
%include "chess_helpers.asm"
%include "state_machine.asm"
%include "move_generator.asm"
%include "king_safety.asm"
%include "check_castling.asm"
%include "promotion_handler.asm"
%include "update_match_state.asm"
%include "draw_endgame_popup.asm"
%include "reset_game.asm"
%include "create_network_events.asm"
%include "initialize_network.asm"
%include "poll_network_events.asm"
%include "main_menu.asm"
%include "san_generator.asm"

; Pad .text to 8KB
align 8192, db 0
text_raw_size equ $ - text_raw_ptr
text_vsize equ text_raw_size
text_size equ text_vsize

; ==============================================================================
; SECTION .data
; ==============================================================================
data_raw_ptr equ $ - DOS_HEADER
data_rva equ text_rva + text_vsize

    ; Chess!
    %include "board_state.asm"

    ; typeface
    %include "font.asm"
    

    ; Serial Logs
    utf_test db "ĄĘŚĆŻÓŁŃŹąęśćżółń123#", 0
    utf_red db "Czerwony.", 0
    utf_green db "Zielony.", 0
    utf_blue db "Niebieski.", 0
    utf_ex_1 db "1.   e4      e5", 0
    utf_ex_2 db "2.   Nc5     d5", 0
    utf_ex_3 db "69.  cxd8=N# 1-0", 0
    msg_printf_test db "This is a dynamically loaded string.",  0
    msg_gop_ok db "Graphics Output Protocol located.", 13, 10, 0
    msg_iso_reading_file db "Attempting a file read...", 13, 10, 0
    msg_iso_read_failed db "Reading failure!", 13, 10, 0
    test_file db "ASSETS/FOLDER/TEST.TXT;1", 0
    target_file db "OK.BMP;1", 0
    msg_done   db "The bootloader is done.", 13, 10, 0
    str_menu_host    db "Graj jako gospodarz", 0
    str_menu_join    db "Graj jako gość", 0
    str_menu_offline db "Graj offline", 0

    ; my ptrs
    test_file_handle dq 9
    test_file_buffer times 50 db 0

    ; boot services ptr, important for I/O
    boot_services_ptr dq 0 
    
    ; ISO reader ptrs
    block_io_ptr   dq 0
    pvd_buffer_ptr dq 0
    sector_buffer  dq 0
    push rcx
    push rdi
    push rsi
    file_buffer    dq 0
    file_lba       dq 0
    file_size      dq 0
    file_read_size dq 0
    path_token    times 64 db 0
    root_dir_lba  dq 0
    root_dir_size dq 0

    ; GOP ptrs
    max_ratio dd 0
    gop_ptr dq 0
    framebuffer_base  dq 0
    framebuffer_pitch dq 0
    screen_w dd 0
    screen_h dd 0
    target_mode dd 0
    max_pixels  dq 0
    info_size   dq 0
    info_ptr    dq 0
    COLOR_KEY      equ 0x00FF00FF    ; magenta

    ; chess graphics vars
    tile_size dd 0
    board_x dd 0
    board_y dd 0
    local_color dd 0 ; 0: white on bottom, 1: black on bottom

    ; async events
    align 8
    wait_event_array:
        dq 0 ; mouse
        dq 0 ; network

    ; mouse ptrs
    mouse_ptr dq 0
    mouse_x   dd 400    ; Starting X coordinate
    mouse_y   dd 300    ; Starting Y coordinate
    ; mouse_event_array dq 0
    event_index       dq 0

    ; handle detection
    handle_count  dq 0
    handle_buffer dq 0

    ; mouse state
    mouse_state times 32 db 0 
    prev_lmb_state db 0 ; 1 = pressed

    ; double buffering 
    backbuffer_ptr  dq 0
    backbuffer_size dq 0

    ; cursor buffer
    cursor_bg_buffer times 1024 db 0 
    saved_cursor_x   dq 0
    saved_cursor_y   dq 0
    cursor_is_saved  db 0           ; Flag: 0 = No, 1 = Yes
    cursor_size      equ 10         ; 32x32 area

    ; networking 
    %include "network_data.asm"

    ; main menu
    MENU_STATE_IN_GAME equ 0
    MENU_STATE_MAIN equ 1
    MENU_STATE_AWAITING_CONNECTION equ 2
    in_menu db MENU_STATE_MAIN ; 1: menu active, 0: in-game, 2: awaiting connection
    path_logo db "ASSETS/CHESS/LOGO.BMP;1", 0
    logo_ptr dq 0
    str_awaiting  db "Oczekiwanie na połączenie...", 0
    str_cancel    db "Anuluj", 0
   
    ; transcript
    transcript_x dd 0
    transcript_y dd 0
    transcript_w dd 0
    transcript_h dd 0
    transcript_lines dd 0       ; max # visible lines that fit on screen
    
    transcript_count dw 0       ; # of half-moves played
    transcript_scroll dw 0      ; logical offset
    
    ; assuming 256 full moves here
    ; this better be enough
    transcript_buffer times 4096 db 0

    ; SAN engine
    san_temp_str times 8 db 0x20   ; holds the string
    
    san_ambig_file db 0            ; 1 if another piece shares the origin file
    san_ambig_rank db 0            ; 1 if another piece shares the origin rank
    
    backup_moves_list times 128 db 0    ; keep the valid moves list separate
                                        ; we cannot use the engine-integrated version
                                        ; as then ambiguity resolution would mess with UI move detection
    backup_moves_count db 0
    backup_selected db 0
    move_num_str times 8 db 0 ; for the move number
    
    ; Piece ID - SAN type mapping
    ; panws don't get a letter
    san_letters db "  NBRQK NBRQK"

    ; keep the transcript data in memory
    tr_row dd 0
    tr_move dd 0
    tr_y dd 0

    
    ; GUIDs
    ; {8D59D32B-C655-4AE9-9B15-F25904992A43}
    GUID_ABSOLUTE_POINTER:
        dd 0x8d59d32b
        dw 0xc655, 0x4ae9
        db 0x9b, 0x15, 0xf2, 0x59, 0x04, 0x99, 0x2a, 0x43
    ; {31878C87-0B75-11D5-9A4F-0090273FC14D}
    GUID_SIMPLE_POINTER:
        dd 0x31878c87
        dw 0x0b75, 0x11d5
        db 0x9a, 0x4f, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d
    ; {9042A9DE-23DC-4A38-96FB-7ADED080516A}
    GUID_GOP:
        dd 0x9042a9de
        dw 0x23dc, 0x4a38
        db 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a
    
    GUID_BLOCK_IO:
        dd 0x964e5b21
        dw 0x6459, 0x11d2
        db 0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b

    ; {00720665-67EB-4a99-BAF7-D3C33A1C7CC9}
    GUID_TCP4_SERVICE_BINDING:
        dd 0x00720665
        dw 0x67EB, 0x4a99
        db 0xBA, 0xF7, 0xD3, 0xC3, 0x3A, 0x1C, 0x7C, 0xC9
    ; {65530BC7-A359-410f-B010-5AADC7EC2B62}
    GUID_TCP4:
        dd 0x65530bc7
        dw 0xa359, 0x410f
        db 0xb0, 0x10, 0x5a, 0xad, 0xc7, 0xec, 0x2b, 0x62




; Pad .data to 8KB
align 8192, db 0
data_raw_size equ $ - data_raw_ptr
data_vsize equ data_raw_size
data_size equ data_vsize

_end_of_image:
image_size equ _end_of_image - DOS_HEADER
