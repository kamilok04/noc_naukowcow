; ==============================================================================
; iso_reader.inc 
; ==============================================================================

; ------------------------------------------------------------------------------
; init_block_io
; Locates the Block I/O Protocol and stores its pointer.
; Inputs: RBX - BootServices
; ------------------------------------------------------------------------------
init_block_io:
    push r12
    sub rsp, 32
    lea rcx, [rel GUID_BLOCK_IO]
    xor rdx, rdx
    lea r8, [rel block_io_ptr]
    call [rbx + EFI_BOOT_SERVICES.LocateProtocol]
    add rsp, 32
    pop r12
    ret

; ------------------------------------------------------------------------------
; read_sectors
; Reads raw disk sectors into a memory buffer.
; Inputs:
;   R8  - Target LBA
;   R9  - Byte Size (Must be multiple of BlockSize, e.g., 2048)
;   R10 - Destination Memory Buffer Pointer
; Outputs: RAX = EFI_STATUS (0 = Success)
; ------------------------------------------------------------------------------
read_sectors:
    push r12
    push r13
    sub rsp, 40

    mov r12, [rel block_io_ptr]
    mov r13, [r12 + EFI_BLOCK_IO_PROTOCOL.Media]
    
    mov rcx, r12                                   
    mov edx, dword [r13 + EFI_BLOCK_IO_MEDIA.MediaId] 
    ; r8, r9 are caller-set
    mov [rsp + 32], r10  

    call [r12 + EFI_BLOCK_IO_PROTOCOL.ReadBlocks]

    add rsp, 40
    pop r13
    pop r12
    ret