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
    
    ; ask the framebuffer what it knows
    mov rbx, [rel gop_ptr]   ; RBX = *GOP
    mov rbx, [rbx + 24]      ; RBX = GOP->Mode
    mov rdi, [rbx + 24]      ; RDI = RBX
    mov rcx, [rbx + 8]       ; RCX = Mode->Info
    mov esi, dword [rcx + 32]; RSI = PixelsPerScanLine (Pitch)
    
    
    mov rcx, 250
    mov rdx, 200
    mov r8, [rel test_file_handle]
    mov r8, [r8 + FILE.BufferPtr]
    cmp word [r8], 0x4D42
    jne .file_error          ; If it's not "BM", the disk read failed!
    
    call draw_bitmap
    
    ; Close the file when done to prevent memory leaks
    lea rcx, [rel test_file_handle]
    call fclose
    
    lea rsi, [rel msg_done]
    call puts
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

; Include our subroutines directly into the .text section
; %include "uefi_headers.asm"
%include "utils.asm"
%include "drawing_utils.asm"
%include "fileio.asm"
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

    ; GOP ptr
    gop_ptr dq 0



    ; GUIDs

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