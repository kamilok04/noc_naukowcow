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
    
    lea rcx, [rel path_logo]
    call fopen
    mov [rel logo_ptr], rax

    ; GUI assets
   
    lea rcx, [rel path_btn_ok]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel bmp_btn_ok], rdx

    lea rcx, [rel path_btn_no]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel bmp_btn_no], rdx

    lea rcx, [rel path_btn_giveup]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel bmp_btn_giveup], rdx
    
    lea rcx, [rel path_btn_draw]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel bmp_btn_draw], rdx
    
    lea rcx, [rel path_btn_forward]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel bmp_btn_forward], rdx
    
    lea rcx, [rel path_btn_back]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]  
    mov [rel bmp_btn_back], rdx

    lea rcx, [rel path_cursor]
    call fopen
    mov rdx, [rax + FILE.BufferPtr]
    mov [rel bmp_cursor], rdx
    jmp .done


.load_error:
    LOG "Failed to load the piece!"
.done:

    mov rsp, rbp
    pop rbp
    ret