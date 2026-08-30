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


    LOG "Entering interactive mode."
    call init_mouse

    mov rcx, [rel mouse_ptr]
    mov rdi, [rcx + 24]
    ; Log the X and Y hardware resolutions
    mov eax, dword [rdi + 0]     ; Mode->ResolutionX
    mov edx, dword [rdi + 8]     ; Mode->ResolutionY
    LOG "Hardware Mouse X Resolution: %d", rax
    LOG "Hardware Mouse Y Resolution: %d", rdx

    mov rax, [rcx + EFI_SIMPLE_POINTER_PROTOCOL.WaitForInput]
    mov [rel mouse_event_array], rax


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
    jz .drain_queue 
    LOG "FATAL: WaitForEvent Error: %x", rax
    cli
    hlt

.drain_queue:
    xor r15, r15                         

.read_loop:
    call update_mouse
    test rax, rax
    jnz .check_draw                      
    mov r15, 1                          
    jmp .read_loop                

.check_draw:
    test r15, r15
    jz .main_loop                        ;

    ; ; we have new coords, log them
    ; movzx r8, dword [rel mouse_x]
    ; movzx r9, dword [rel mouse_y]
    ; LOG "Mouse X: %d, Y: %d", r8, r9

    ; draw bg
    mov rdi, [rel backbuffer_ptr]        
    mov rsi, [rel framebuffer_pitch]
    mov rcx, 200                        
    mov rdx, 200                         
    mov r8, [rel test_file_handle]
    mov r8, [r8 + FILE.BufferPtr] 
    call draw_bitmap
    
    ; draw cursor and swap buffers
    call draw_cursor
    call swap_buffers

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
; Pad .text to exactly 4096 bytes
align 4096, db 0
text_raw_size equ $ - text_raw_ptr
text_vsize equ text_raw_size
text_size equ text_vsize

; ==============================================================================
; SECTION .data
; ==============================================================================
data_raw_ptr equ $ - DOS_HEADER
data_rva equ text_rva + text_vsize

    ; Serial Logs
    msg_printf_test db "This is a dynamically loaded string.",  0
    msg_gop_ok db "Graphics Output Protocol located.", 13, 10, 0
    msg_iso_reading_file db "Attempting a file read...", 13, 10, 0
    msg_iso_read_failed db "Reading failure!", 13, 10, 0
    test_file db "TEST.TXT;1", 0
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
    file_buffer    dq 0
    file_lba       dq 0
    file_size      dq 0
    file_read_size dq 0

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

    ; double buffering 
    backbuffer_ptr  dq 0
    backbuffer_size dq 0

    
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
    

; Pad .data to exactly 4096 bytes
align 4096, db 0
data_raw_size equ $ - data_raw_ptr
data_vsize equ data_raw_size
data_size equ data_vsize

_end_of_image:
image_size equ _end_of_image - DOS_HEADER