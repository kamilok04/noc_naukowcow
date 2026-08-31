init_assets:
    push rbp
    mov rbp, rsp

    lea rcx, [rel path_wpawn]        
    call fopen                       
    test rax, rax
    jz .load_error
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel piece_bitmaps + 1*8], rdx ; save to ID 1

    lea rcx, [rel path_wknight]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]
    mov [rel piece_bitmaps + 2*8], rdx

    lea rcx, [rel path_wbishop]        
    call fopen                       
    test rax, rax
    jz .load_error
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel piece_bitmaps + 3*8], rdx

    lea rcx, [rel path_wrook]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]
    mov [rel piece_bitmaps + 4*8], rdx
    
    lea rcx, [rel path_wqueen]        
    call fopen                       
    test rax, rax
    jz .load_error
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel piece_bitmaps + 5*8], rdx 

    lea rcx, [rel path_wking]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]
    mov [rel piece_bitmaps + 6*8], rdx

    ; now the darker friends

    lea rcx, [rel path_bpawn]        
    call fopen                       
    test rax, rax
    jz .load_error
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel piece_bitmaps + 7*8], rdx 

    lea rcx, [rel path_bknight]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]
    mov [rel piece_bitmaps + 8*8], rdx

    lea rcx, [rel path_bbishop]        
    call fopen                       
    test rax, rax
    jz .load_error
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel piece_bitmaps + 9*8], rdx

    lea rcx, [rel path_brook]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]
    mov [rel piece_bitmaps + 10*8], rdx
    
    lea rcx, [rel path_bqueen]        
    call fopen                       
    test rax, rax
    jz .load_error
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel piece_bitmaps + 11*8], rdx 

    lea rcx, [rel path_bking]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]
    mov [rel piece_bitmaps + 12*8], rdx
    jmp .done

.load_error:
    LOG "Failed to load the piece!"
.done:

    mov rsp, rbp
    pop rbp
    ret