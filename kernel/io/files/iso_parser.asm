; ==============================================================================
; iso_parser.inc - ISO 9660 Directory Parsing
; ==============================================================================

; ------------------------------------------------------------------------------
; find_iso_file
; Iterates through an ISO 9660 directory extent to find a matching filename.
; Inputs:
;   RDI - Pointer to the loaded directory sector buffer
;   RSI - Pointer to null-terminated target filename (e.g., "LOGO.BMP;1")
;   RCX - Size of the directory buffer in bytes
; Outputs:
;   RAX - Starting LBA of the file (0 if not found)
;   RDX - Total size of the file in bytes (0 if not found)
; ------------------------------------------------------------------------------
find_iso_file:
    LOG "ISO9660: filename: %s", rsi
    LOG "ISO9660: dir ptr: %d", rdi
    LOG "ISO9660: dir size: %d", rcx
    push rbx
    push r12
    push r13

    mov r12, rdi       ; R12 = record pointer
    add rcx, rdi       ; RCX = end of buffer address

.next_record:
    cmp r12, rcx
    jge .not_found     ; buffer overrun?

    ; read RecordLength, 0 means no file
    movzx rbx, byte [r12 + ISO9660_DIR_RECORD.RecordLength]
    test rbx, rbx
    jz .not_found      


    mov al, byte [r12 + ISO9660_DIR_RECORD.FileFlags]
    test al, 0x02      ; 0 if dir
    jnz .skip          ; we only want files (for now)

    push rsi           ; target string pointer
    push r12           ; current record pointer
    
    movzx r13, byte [r12 + ISO9660_DIR_RECORD.FileNameLength]
    lea rdi, [r12 + ISO9660_DIR_RECORD.FileName]
    
.compare_loop:
    test r13, r13
    jz .check_match    ; filename checked
    
    mov al, byte [rsi]
    test al, al
    jz .mismatch       ; end of string
    
    mov ah, byte [rdi]
    cmp al, ah
    jne .mismatch      ; wrong string
    
    inc rsi
    inc rdi
    dec r13
    jmp .compare_loop
    
.check_match:
    ; ensure we're at the end of BOTH strings
    mov al, byte [rsi]
    test al, al
    jnz .mismatch
    
    ; done, extract data
    pop r12
    pop rsi
    
    mov eax, dword [r12 + ISO9660_DIR_RECORD.ExtentLocationLE]
    mov edx, dword [r12 + ISO9660_DIR_RECORD.DataLengthLE]
    jmp .done

.mismatch:

    pop r12
    pop rsi

.skip:
    LOG "ISO9660: Wrong file, looking for next one"
    add r12, rbx       ; next entry
    jmp .next_record

.not_found:
    LOG "ISO9660: File not found."
    xor rax, rax       ; NULL
    xor rdx, rdx
.done:
    pop r13
    pop r12
    pop rbx
    ret