%ifndef VALIDITY_CHECKS
%include "validity_checks.asm"
%endif

; ------------------------------------------------------------------------------
; generate_moves_for_square
; Inputs: R8 - The 0x88 index of the selected piece
; ------------------------------------------------------------------------------
generate_moves_for_square:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rsi
    push r9
    
    ; clear previous moves
    mov byte [rel valid_moves_count], 0
    
    ; identify the piece
    lea rbx, [rel board_state]
    mov al, byte [rbx + r8]
    test al, al
    jz .done                 ; This should not happen 
    
    ; normalize IDs
    mov cl, al
    cmp cl, 7
    jl .is_white
    sub cl, 6                ; whiten a black piece temporarily
    ; CL now holds the piece type: 1=P, 2=N, 3=B, 4=R, 5=Q, 6=K
.is_white:
    ; dispatch
    cmp cl, 1
    je .handle_pawn
    cmp cl, 2
    je .handle_knight
    cmp cl, 3
    je .handle_bishop
    cmp cl, 4
    je .handle_rook
    cmp cl, 5
    je .handle_queen
    cmp cl, 6
    je .handle_king
    jmp .done

.handle_pawn:
    cmp al, 7
    jge .black_pawn
    call generate_white_pawn
    jmp .done
.black_pawn:
    call generate_black_pawn
    jmp .done

.handle_knight:
    mov rcx, 8               ; 8 possible directions
    lea rsi, [rel knight_offsets]
    jmp .offset_loop

.handle_bishop:
    mov rcx, 4
    lea rsi, [rel bishop_offsets]
    jmp .offset_loop

.handle_rook:
    mov rcx, 4
    lea rsi, [rel rook_offsets]
    jmp .offset_loop

.handle_queen:
.handle_king:
    mov rcx, 8
    lea rsi, [rel king_offsets]
    ; vvv falling vvv

.offset_loop:
    ; loop through direction tables
    test rcx, rcx
    jz .done
    
    movsx r9, byte [rsi]     ; get the offset
    
    push r8                  ; starting piece
    push rax                 ; original piece ID
    push rcx                 ; loop counter
    push rsi                 ; offset table pointer
    
    call check_steps         ; go!
    
    pop rsi
    pop rcx
    pop rax
    pop r8
    
    inc rsi                  ; next
    dec rcx                  ; decrement counter
    jmp .offset_loop

.done:
    pop r9
    pop rsi
    pop rcx
    pop rbx
    pop rbp
    ret