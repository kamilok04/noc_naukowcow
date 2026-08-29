
; ------------------------------------------------------------------------------
; putc
; Outputs a single char from AL over COM1
; ------------------------------------------------------------------------------
putc:
    push rdx
    mov dx, 0x3F8
    out dx, al
    pop rdx
    ret


; ------------------------------------------------------------------------------
; puts
; Outputs a null-terminated string pointed to by RSI
; ------------------------------------------------------------------------------
puts:
    push rax
    push rsi
.loop:
    lodsb               ; AL = [RSI++]
    test al, al
    jz .done
    call putc
    jmp .loop
.done:
    pop rsi
    pop rax
    ret

; ------------------------------------------------------------------------------
; print_dec
; Prints a signed 64-bit integer in RAX as base-10 ASCII
; ------------------------------------------------------------------------------
print_dec:
    push rax
    push rbx
    push rcx
    push rdx

    test rax, rax
    jns .positive      
    
    ; Handle negative numbers
    push rax
    mov al, '-'
    call putc
    pop rax
    neg rax             

.positive:
    mov rcx, 0          ; counter
    mov rbx, 10         ; base-10

.div_loop:
    xor rdx, rdx        
    div rbx             ; RAX = RAX / 10, RDX = RAX % 10
    add dl, '0'         ; digit to ASCII
    push rdx            
    inc rcx            
    test rax, rax       
    jnz .div_loop       

.print_loop:
    pop rax            
    call putc
    loop .print_loop

    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ------------------------------------------------------------------------------
; printf
; Minimal implementation of printf. For now, only %s and %d params are supported.
; Inputs:
;   RCX - Pointer to format string
;   RDX - arg1
;   R8  - arg2
;   R9  - arg3
;   Stack - args...
; ------------------------------------------------------------------------------
printf:
    push rbp
    mov rbp, rsp
    
    ; This is a vararg method.
    ; For sanity, keep the arg in a continuous block,
    mov [rbp + 24], rdx  ; arg1
    mov [rbp + 32], r8   ; arg2
    mov [rbp + 40], r9   ; arg3
    ; this is the MS x64 ABI
    ; everything else is aleady on the stack ([rbp + 48], [rbp + 56], ...)

    push rsi
    push r12
    push rax

    mov rsi, rcx         ; RSI = fmt string
    lea r12, [rbp + 24]  ; R12 = *varargs

.parse_loop:
    lodsb               
    test al, al
    jz .done             
    
    cmp al, '%'
    je .format
    
    call putc
    jmp .parse_loop

.format:
    lodsb                ; look at character after the '%'
    test al, al
    jz .done             ; handle trailing '%' sensibly
    
    cmp al, '%'
    je .print_percent
    
    cmp al, 's'
    je .print_str
    
    cmp al, 'd'
    je .print_int
    
    ; unknown specifier: print both the '%' and the character
    ; this differs from the spec a bit, in there, a '%%' outputs a single '%'.
    push rax
    mov al, '%'
    call putc
    pop rax
    call putc
    jmp .parse_loop

.print_percent:
    call putc
    jmp .parse_loop

.print_str:
    mov rax, [r12]       ;
    add r12, 8           ; next vararg
    
    push rsi            
    mov rsi, rax         ; *char
    call puts    ; print whatever's in there
    pop rsi              
    jmp .parse_loop

.print_int:
    mov rax, [r12]       
    add r12, 8           ; int = 8 bytes
    call print_dec
    jmp .parse_loop

.done:
    pop rax
    pop r12
    pop rsi
    pop rbp
    ret