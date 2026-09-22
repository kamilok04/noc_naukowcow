%ifndef FILEIO
%define FILEIO
%endif

; ------------------------------------------------------------------------------
; init_fs
; Locates the Simple File System Protocol and opens the root volume.
; Called once.
; ------------------------------------------------------------------------------
init_fs:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40
   ;  LOG "Calling initfs"

    mov rbx, [rel boot_services_ptr]

    ; Locate the file system protocol
    ; LOG "Locating image protocol"
    mov rcx, [rel image_handle]
    lea rdx, [rel GUID_LOADED_IMAGE]
    lea r8, [rel loaded_image_ptr]
    call [rbx + EFI_BOOT_SERVICES.HandleProtocol]
    test rax, rax
    jnz .fs_error

   ;  LOG "Locating fs protocol"
    mov rcx, [rel loaded_image_ptr]
    mov rcx, [rcx + EFI_LOADED_IMAGE_PROTOCOL.DeviceHandle]

    lea rdx, [rel GUID_SIMPLE_FILE_SYSTEM]
    lea r8, [rel simple_fs_ptr]
    call [rbx + EFI_BOOT_SERVICES.HandleProtocol]
    test rax, rax
    jnz .fs_error

    ; Open the root (\)
    ; LOG "Opening root"
    mov rcx, [rel simple_fs_ptr]
    lea rdx, [rel root_dir_ptr]
    mov rax, [rcx + EFI_SIMPLE_FILE_SYSTEM_PROTOCOL.OpenVolume]    
    call rax
    test rax, rax
    jnz .fs_error
    LOG "All done"
    jmp .done
.fs_error:
    LOG "fsinit error %x", rax
.done:
    add rsp, 40
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; fopen
; Inputs: RCX - Pointer to target filename (ASCII)
; Outputs: RAX - Pointer to allocated FILE struct (or 0 on error)
; ------------------------------------------------------------------------------
fopen:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    sub rsp, 48                      

    ; convert ASCII string to UTF-16 string (required by UEFI)
    mov rsi, rcx
    lea rdi, [rel path_utf16]
.ascii_to_utf16:
    lodsb
    stosb
    mov byte [rdi], 0                ; UTF-16 padding byte
    inc rdi
    test al, al
    jnz .ascii_to_utf16

    ; open the file via UEFI-provided driver
    mov rcx, [rel root_dir_ptr]      ; root volume handle
    lea rdx, [rel efi_file_handle]
    lea r8, [rel path_utf16]
    mov r9, 1                        ; EFI_FILE_MODE_READ
    mov qword [rsp + 32], 0          ; no special flags
    
    mov rax, [rcx + EFI_FILE_PROTOCOL.Open]
    call rax
    test rax, rax
    jnz .not_found

    ; get file size (run to the end of the file and back)
    mov rcx, [rel efi_file_handle]
    mov rdx, 0xFFFFFFFFFFFFFFFF      ; EOF
    mov rax, [rcx + EFI_FILE_PROTOCOL.SetPosition]
    call rax

    mov rcx, [rel efi_file_handle]
    lea rdx, [rel temp_file_size]
    mov rax, [rcx + EFI_FILE_PROTOCOL.GetPosition]    
    call rax

    mov rcx, [rel efi_file_handle]
    xor rdx, rdx                     ; 0
    mov rax, [rcx + EFI_FILE_PROTOCOL.SetPosition]    
    call rax

    ; allocate FILE struct (24 bytes)
    mov rcx, 2                       ; EfiLoaderData
    mov rdx, FILE_STRUCT_SIZE
    lea r8, [rel temp_struct_ptr]
    mov rbx, [rel boot_services_ptr]
    call [rbx + EFI_BOOT_SERVICES.AllocatePool]
    
    ; allocate memory buffer for file data
    mov rcx, 2
    mov rdx, [rel temp_file_size]
    lea r8, [rel temp_buffer_ptr]
    call [rbx + EFI_BOOT_SERVICES.AllocatePool]

    ; read the file into the buffer
    mov rcx, [rel efi_file_handle]
    lea rdx, [rel temp_file_size]    ; In/Out parameter
    mov r8, [rel temp_buffer_ptr]
    mov rax, [rcx + EFI_FILE_PROTOCOL.Read]   
    call rax

    ; close the UEFI file handle
    mov rcx, [rel efi_file_handle]
    mov rax, [rcx + EFI_FILE_PROTOCOL.Close]
    call rax

    ;populate struct andd run
    mov r12, [rel temp_struct_ptr]
    
    mov rax, [rel temp_buffer_ptr]
    mov [r12 + FILE.BufferPtr], rax
    
    mov rax, [rel temp_file_size]
    mov [r12 + FILE.FileSize], rax
    
    mov qword [r12 + FILE.Cursor], 0
    
    mov rax, r12                   
    jmp .done

.not_found:
    xor rax, rax                     ; Return NULL on failure
.done:
    add rsp, 48
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

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
    sub rax, [r8 + FILE.Cursor]   
    
    cmp rdx, rax
    cmova rdx, rax                
    test rdx, rdx
    jz .eof                       

    push rsi
    push rdi
    push rcx
    
    mov rsi, [r8 + FILE.BufferPtr]
    add rsi, [r8 + FILE.Cursor]   
    mov rdi, rcx                  
    mov rcx, rdx                  
    rep movsb                     

    pop rcx
    pop rdi
    pop rsi

    add [r8 + FILE.Cursor], rdx
    mov rax, rdx                  
    ret

.eof:
    xor rax, rax                  
    ret

; ------------------------------------------------------------------------------
; fclose
; releases both mempools (file data and the FILE struct) back to the firmware.
; ------------------------------------------------------------------------------
fclose:
    push rbp
    mov rbp, rsp
    push rbx
    push r12             
    sub rsp, 32          

    mov r12, rcx         
    mov rbx, [rel boot_services_ptr]

    ; free the file data buffer
    mov rcx, [r12 + FILE.BufferPtr]  
    call [rbx + EFI_BOOT_SERVICES.FreePool]

    ; free the FILE struct
    mov rcx, r12                     
    call [rbx + EFI_BOOT_SERVICES.FreePool]

    add rsp, 32
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret


