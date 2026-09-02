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
    
    ; call set_max_resolution

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
    
    ; Close the file when done to prevent memory leaks
    ; lea rcx, [rel test_file_handle]
    ; call fclose
    call swap_buffers

    LOG "Loading assets..."
    call init_assets

    LOG "Entering interactive mode."
    call init_mouse
    
    mov rcx, [rel mouse_ptr]
    mov rax, [rcx + 16]                           ;
    mov [rel mouse_event_array], rax
    
    LOG "Initializing the game."
    call render_playfield
    
    call swap_buffers
    
    
    jmp .main_loop

.main_loop:

    mov rcx, 1                           
    lea rdx, [rel mouse_event_array]     
    lea r8, [rel event_index]            
    mov rbx, [rel boot_services_ptr]

    sub rsp, 32
    call [rbx + EFI_BOOT_SERVICES.WaitForEvent]                     
    add rsp, 32
    
    ; Trap wake-up errors
    test rax, rax
    ; let it try again
    jnz .main_loop

.drain_queue:
    xor r15, r15                         
    mov r14, 16                          ; ≤ 16 packets per frame please

.read_loop:
    call update_mouse
    test rax, rax
    jnz .check_draw                      
    
    mov r15, 1                           
    
    dec r14                              
    jz .flush_queue                      
    jmp .read_loop                       

.flush_queue:
    mov rcx, [rel mouse_ptr]
    xor rdx, rdx                         ; ExtendedVerification = FALSE
    mov rax, [rcx + 0]                   ; Offset 0 = Protocol->Reset
    sub rsp, 32
    call rax
    add rsp, 32            

.check_draw:
    test r15, r15
    jz .main_loop      
    
    movzx eax, byte [rel mouse_state + 12] ; AL = current LMB state
    movzx ebx, byte [rel prev_lmb_state]   ; BL = previous frame's LMB state

    cmp bl, 1
    jne .save_mouse_state
    cmp al, 0
    jne .save_mouse_state

    ; was 1, is 0, this is very much a click (or a drag, y'know)
    LOG "Click."
    call handle_mouse_click

    call render_playfield           
    call swap_buffers                
    mov byte [rel cursor_is_saved], 0;

.save_mouse_state:
    mov byte [rel prev_lmb_state], al
    ; copy background from below cursor
    call restore_cursor_background
    
    ; embed the new cursor into the back
    mov rcx, [rel saved_cursor_x]
    mov rdx, [rel saved_cursor_y]
    call push_cursor_region

    ; save the background below the cursor
    movzx rcx, dword [rel mouse_x]
    movzx rdx, dword [rel mouse_y]
    mov [rel saved_cursor_x], rcx
    mov [rel saved_cursor_y], rdx
    call save_cursor_background
    mov byte [rel cursor_is_saved], 1

    ; draw the cursor onto the backbuffer
    call draw_cursor 

    ; draw the new cursor to the physical screen
    movzx rcx, dword [rel mouse_x]
    movzx rdx, dword [rel mouse_y]
    call push_cursor_region

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
%include "move_generator.asm"

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
    

    ; Serial Logs
    msg_printf_test db "This is a dynamically loaded string.",  0
    msg_gop_ok db "Graphics Output Protocol located.", 13, 10, 0
    msg_iso_reading_file db "Attempting a file read...", 13, 10, 0
    msg_iso_read_failed db "Reading failure!", 13, 10, 0
    test_file db "ASSETS/FOLDER/TEST.TXT;1", 0
    target_file db "OK.BMP;1", 0
    msg_done   db "The bootloader is done.", 13, 10, 0

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

    ; mouse ptrs
    mouse_ptr dq 0
    mouse_x   dd 400    ; Starting X coordinate
    mouse_y   dd 300    ; Starting Y coordinate
    mouse_event_array dq 0
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
    
   

; Pad .data to 8KB
align 8192, db 0
data_raw_size equ $ - data_raw_ptr
data_vsize equ data_raw_size
data_size equ data_vsize

_end_of_image:
image_size equ _end_of_image - DOS_HEADER
