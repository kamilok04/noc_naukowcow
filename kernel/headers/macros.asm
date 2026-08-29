%macro LOG 1-4
    ; push for safety
    pushfq
    push rax
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11

    cld ; We would like our strings printed forwards, thank you

   jmp %%skip_str
    %%fmt_str: 
        db %1, 13, 10, 0    ; CRLF
%%skip_str:
    ; Push args onto stack
    %if %0 > 1
        push %2
    %endif
    %if %0 > 2
        push %3
    %endif
    %if %0 > 3
        push %4
    %endif

    %if %0 > 3
        pop r9
    %endif
    %if %0 > 2
        pop r8
    %endif
    %if %0 > 1
        pop rdx
    %endif
    
    ; assign fmt string pointer
    lea rcx, [rel %%fmt_str]


    sub rsp, 32
    call printf
    add rsp, 32

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax
    popfq
%endmacro