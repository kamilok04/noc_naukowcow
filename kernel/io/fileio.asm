%ifndef FILEIO
%define FILEIO
%endif
%include "iso_parser.asm"
%include "iso_reader.asm"
%include "malloc.asm"

; ------------------------------------------------------------------------------
; fopen
; Inputs: RCX - Pointer to target filename (e.g., "LOGO.BMP;1")
; Outputs: RAX - Pointer to allocated FILE struct (or 0 on error)
; ------------------------------------------------------------------------------
fopen:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    mov rbx, [rel boot_services_ptr]

    ; 1. Search for the file in the Root Directory
    ; TODO: nested dirs, obviously
    mov rdi, [rel sector_buffer]
    mov rsi, rcx
    mov rcx, 2048
    call find_iso_file
    test rax, rax
    jz .not_found



    mov r13, rax                  ; R13 = file LBA
    mov r12, rdx                  ; R12 = filesize

    mov rax, r12
    call malloc
    test rax, rax
    jz .allocation_failed
    mov [rel temp_buffer_ptr], rax
    
    ; read the file into memory
    mov r8, r13
    mov r9, r12                   ; R9 = Exact File Size
    add r9, 2047                  ; round up to the nearest
    and r9, ~2047                 ; 2KB boundary
    mov r10, [rel temp_buffer_ptr]
    call read_sectors
    test rax, rax                 ; Check if EFI_SUCCESS
    jnz .not_found

    ; allocate memory for the FILE struct (24 bytes)
    mov rcx, 2
    mov rdx, FILE_STRUCT_SIZE
    lea r8, [rel temp_struct_ptr]

    sub rsp, 32 ; shadow spacing                                 
    call [rbx + EFI_BOOT_SERVICES.AllocatePool]
    add rsp, 32                                 

    ; populate the FILE struct
    mov rax, [rel temp_struct_ptr]
    mov rcx, [rel temp_buffer_ptr]
    mov [rax + FILE.BufferPtr], rcx  ; save data pointer
    mov [rax + FILE.FileSize], r12   ; save exact file size
    mov qword [rax + FILE.Cursor], 0 ; Initialize cursor to 0

    jmp .done

.allocation_failed:
    LOG "Unable to allocate."
    xor rax, rax
    jmp .done

.not_found:
    LOG "Unable to find file: %s", rcx
    xor rax, rax                  ; Return NULL
    jmp .done
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

temp_buffer_ptr dq 0
temp_struct_ptr dq 0

; ------------------------------------------------------------------------------
; fread
; Inputs:
;   RCX - Destination buffer pointer
;   RDX - Number of bytes to read
;   R8  - Pointer to FILE struct
; Outputs: RAX - Number of bytes actually read
; ------------------------------------------------------------------------------
fread:
    mov rax, [r8 + FILE.FileSize]
    sub rax, [r8 + FILE.Cursor]   ; RAX = remaining bytes in file
    
    cmp rdx, rax
    cmova rdx, rax                ; if requested > remaining, only read remaining
    test rdx, rdx
    jz .eof                       ; nothing to read

    ; Copy memory
    push rsi
    push rdi
    push rcx
    
    mov rsi, [r8 + FILE.BufferPtr]
    add rsi, [r8 + FILE.Cursor]   ; source = buffer + cursor
    mov rdi, rcx                  ; destination = user buffer
    mov rcx, rdx                  ; bytes to read
    rep movsb                     

    pop rcx
    pop rdi
    pop rsi

    ; Update Cursor
    add [r8 + FILE.Cursor], rdx
    mov rax, rdx                  ; bytes read
    ret

.eof:
    xor rax, rax                  ; NULL
    ret

; ------------------------------------------------------------------------------
; fclose
; Frees the file data buffer (FreePages) and the FILE struct memory (FreePool).
; Inputs:
;   RCX - Pointer to FILE struct
; ------------------------------------------------------------------------------
fclose:
    push rbp
    mov rbp, rsp
    
    push rbx
    push r12             
    
    sub rsp, 32          

    mov r12, rcx         
    mov rbx, [rel boot_services_ptr]

    ; free the buffer, this needs the page count again
    mov rax, [r12 + FILE.FileSize]
    add rax, 4095
    shr rax, 12                      ; RAX = page count

    ; Setup arguments for FreePages
    mov rdx, rax                     ; page count
    mov rcx, [r12 + FILE.BufferPtr]  ; starting address
    
    call [rbx + EFI_BOOT_SERVICES.FreePages]

    ; free the file struct
    mov rcx, r12                     
    
    call [rbx + EFI_BOOT_SERVICES.FreePool]

    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

struc FILE
    .BufferPtr resq 1
    .FileSize  resq 1  
    .Cursor    resq 1 ; where are we?
endstruc
FILE_STRUCT_SIZE equ 24