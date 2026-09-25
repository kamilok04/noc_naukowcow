; ------------------------------------------------------------------------------
; run_perft_suite
; Runs the Perft on a few levels, then the Kiwipete Perft on a few levels.
; If all tests pass, returns 0 
; If any fails, creates a report and halts the system - there is no point in a chess system if a game is not chess.
; ------------------------------------------------------------------------------
run_perft_suite:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rdi                         
    push rsi
    sub rsp, 32

.run_standard:
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]              
    lea rdx, [rel str_perft_run]
    sub rsp, 32
    call [rcx + 8]                   
    add rsp, 32

    lea r14, [rel perft_depths]      ; R14 = address for expected nodes
    call .execute_depths

.run_kiwipete:
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]              
    lea rdx, [rel str_kiwipete_run]
    sub rsp, 32
    call [rcx + 8]                   
    add rsp, 32

    ; temporarily set Kiwipete
    lea rsi, [rel kiwipete_board]
    lea rdi, [rel board]
    mov rcx, 128
    cld
    rep movsb

    ; wipe global state
    mov byte [rel current_color], 0
    mov byte [rel en_passant_target], 0xFF
    mov byte [rel w_castle_k], 1
    mov byte [rel w_castle_q], 1
    mov byte [rel b_castle_k], 1
    mov byte [rel b_castle_q], 1

    lea r14, [rel kiwipete_depths]   ; R14 = address for Kiwipete expected nodes
    call .execute_depths

.done:
    add rsp, 32
    pop rsi
    pop rdi
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

.execute_depths:
    mov r15, 1                       ; start at depth 1

.main_perft_loop: 
    ; output the depth via TUI
    mov al, r15b
    add al, '0'                    
    mov byte [rel str_pertf_depth + 14], al 

    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]              
    lea rdx, [rel str_pertf_depth]
    sub rsp, 32
    call [rcx + 8]                   
    add rsp, 32

    mov rcx, r15
    call perft_recursive
    mov r12, rax                     ; R12 = computed nodes

    mov r13, r15                     
    dec r13                          
    mov r13, [r14 + r13 * 8]         ; R13 = expected nodes

    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_nodes]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; # computed -> TUI
    mov eax, r12d
    call uint_to_utf16
    mov rdx, rax
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    cmp r12, r13
    jne .failed

.passed:
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_perft_pass]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    inc r15
    cmp r15, 3; 5 ; speed up the actual POST testing
    jle .main_perft_loop
    ret

.failed:
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_perft_fail]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    
    ; failed; let the user know
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_div_start]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; generate a report
    mov rcx, r15                     
    call divide_perft
    mov r12, rax                     

    ; "Nodes visited: "
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_nodes]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    mov eax, r12d
    call uint_to_utf16
    mov rdx, rax
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32
    
.halt:
    hlt                              ; kill the machine
  ; hcf  ; this needs separate access mode
         ; https://web.archive.org/web/20160305150047/http://www.cirsovius.de/Firmen/Uni-Chaos/FUN/opcodes.html
  ; eob  ; :)
    jmp .halt
; ------------------------------------------------------------------------------
; perft_recursive
; Inputs: RCX = current depth
; Outputs: RAX = total leaf nodes found
; ------------------------------------------------------------------------------
perft_recursive:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 216                     ; scratch board + padding

    mov r12, rcx                     ; R12 = current Ddpth
    xor r13, r13                     ; R13 = node ctr

    test r12, r12
    jnz .generate
    mov rax, 1                       ; if depth == 0, this is a leaf node
    jmp .exit

.generate:
    xor r14, r14                     ; R14 = square index (0x00 to 0x77)

.square_loop:
    cmp r14, 0x78
    jge .exit_generate

    ; is square on board?
    mov rax, r14
    test al, 0x88
    jnz .next_square

    ; does it have a correctly colored piece on it?
    lea rbx, [rel board]
    mov dl, byte [rbx + r14]
    test dl, dl
    jz .next_square

    mov al, byte [rel current_color]
    test al, al
    jnz .check_black

.check_white:
    cmp dl, 7
    jge .next_square
    jmp .gen_moves

.check_black:
    cmp dl, 7
    jl .next_square

.gen_moves:
    ; get pseudo-legal moves
    mov r8, r14
    call generate_moves_for_square

    movzx rcx, byte [rel valid_moves_count]
    test rcx, rcx
    jz .next_square
    lea rsi, [rel valid_moves_list]
    lea rdi, [rbp - 200]
    push rcx
    mov rcx, 27 ; maximum allowed # of moves
    cld
    rep movsb
    pop rcx

    lea rsi, [rbp - 200]

.move_loop:
    push rcx
    push rsi
    push r14

    ; wind up the board
    ; the tests execute on a real, actual board
    ; which is restricted to this routine
    ; or else.

    lea rsi, [rel board]
    lea rdi, [rbp - 168]             
    mov rcx, 128
    cld
    rep movsb

    ; wind up the castling rights + EP
    movzx r15, byte [rel en_passant_target]
    shl r15, 8
    mov r15b, byte [rel w_castle_k]
    shl r15, 8
    mov r15b, byte [rel w_castle_q]
    shl r15, 8
    mov r15b, byte [rel b_castle_k]
    shl r15, 8
    mov r15b, byte [rel b_castle_q]
    push r15                         

    mov rdx, [rsp + 8]               ; retrieve original R14 (Origin Square)
    mov rsi, [rsp + 16]              ; retrieve original RSI (Move List)
    mov rcx, [rsp + 24]              ; retrieve original RCX (Counter)
    movzx r8, byte [rsi + rcx - 1]   ; target square
    call make_move

; is the move legal?
    call verify_king_safety          
    test rax, rax
    jz .revert_move                  ; no; drop the node


    lea rbx, [rel board]
    mov cl, byte [rbx + r8]          
    
    cmp cl, 1                        ; W_PAWN
    je .check_w_promo
    cmp cl, 7                        ; B_PAWN
    je .check_b_promo
    jmp .normal_recurse

.check_w_promo:
    mov al, r8b
    and al, 0x70
    jz .do_promotion                 
    jmp .normal_recurse

.check_b_promo:
    mov al, r8b
    and al, 0x70
    cmp al, 0x70
    je .do_promotion                 ; rank 1
    jmp .normal_recurse

.do_promotion:
    mov r9b, 2                       ; WKn, WB, WR, WQ, in this order
    mov r10b, 5                      ; ... WQ
    cmp cl, 1
    je .promo_loop
    mov r9b, 8                       ; BKn ...
    mov r10b, 11                     ; ... BQ

.promo_loop:
    lea rbx, [rel board]
    mov byte [rbx + r8], r9b         ; change the peasant's gender

    xor byte [rel current_color], 1
    mov rcx, r12
    dec rcx
    
    push r8                        
    push r9
    push r10
    call perft_recursive
    pop r10
    pop r9
    pop r8                 
    
    add r13, rax                     ; accumulate valid nodes
    xor byte [rel current_color], 1

    inc r9b
    cmp r9b, r10b
    jle .promo_loop

    jmp .revert_move                 ; skip recursion

.normal_recurse:
    ; swap colors, keep going
    xor byte [rel current_color], 1
    
    mov rcx, r12
    dec rcx
    call perft_recursive
    add r13, rax                     ; accumulate valid nodes
    
    xor byte [rel current_color], 1

.revert_move:
    ; pop the global state
    pop r15
    mov byte [rel b_castle_q], r15b
    shr r15, 8
    mov byte [rel b_castle_k], r15b
    shr r15, 8
    mov byte [rel w_castle_q], r15b
    shr r15, 8
    mov byte [rel w_castle_k], r15b
    shr r15, 8
    mov byte [rel en_passant_target], r15b

    ; pop the board
    lea rsi, [rbp - 168]             
    lea rdi, [rel board]             
    mov rcx, 128
    cld
    rep movsb

    pop r14
    pop rsi
    pop rcx
    dec rcx
    jnz .move_loop

.next_square:
    inc r14
    jmp .square_loop

.exit_generate:
    mov rax, r13                     ; return accumulated nodes

.exit:
    add rsp, 216
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; print_divide_branch
; Prints "e2e4 - [NODES]" over ConOut.
; Inputs: R14 = Origin 0x88, R8 = Target 0x88, RAX = Node Count
; ------------------------------------------------------------------------------
print_divide_branch:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push rax

    ; format src file (column)
    mov r9, r14
    and r9, 7
    add r9, 'a'
    mov word [rel str_div_orig_f], r9w

    ; format src rank/row: '8' - (R14 >> 4)
    mov r9, r14
    shr r9, 4
    mov r10, '8'
    sub r10, r9
    mov word [rel str_div_orig_r], r10w

    ; src col: (R8 & 7) + 'a'
    mov r9, r8
    and r9, 7
    add r9, 'a'
    mov word [rel str_div_targ_f], r9w

    ; src row: '8' - (R8 >> 4)
    mov r9, r8
    shr r9, 4
    mov r10, '8'
    sub r10, r9
    mov word [rel str_div_targ_r], r10w

    ; write UCI of move
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]              
    lea rdx, [rel str_divide_fmt]
    sub rsp, 32
    call [rcx + 8]                   
    add rsp, 32

    ; print node #
    pop rax                          
    push rax                         
    call uint_to_utf16
    mov rdx, rax
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    ; \r\n
    mov rbx, [rel system_table_ptr]
    mov rcx, [rbx + 64]
    lea rdx, [rel str_newline]
    sub rsp, 32
    call [rcx + 8]
    add rsp, 32

    pop rax
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------------------
; divide_perft
; Generates a report of the perft run; executed only on failure
; Inputs: RCX = Target Depth (e.g., 4)
; Outputs: RAX = Total leaf nodes found
; ------------------------------------------------------------------------------
divide_perft:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 216

    mov r12, rcx                     
    xor r13, r13                   
    xor r14, r14                     

.square_loop:
    cmp r14, 0x78
    jge .exit_generate

    mov rax, r14
    test al, 0x88
    jnz .next_square

    lea rbx, [rel board]
    mov dl, byte [rbx + r14]
    test dl, dl
    jz .next_square

    mov al, byte [rel current_color]
    test al, al
    jnz .check_black

.check_white:
    cmp dl, 7
    jge .next_square
    jmp .gen_moves

.check_black:
    cmp dl, 7
    jl .next_square

.gen_moves:
    mov r8, r14
    call generate_moves_for_square

    movzx rcx, byte [rel valid_moves_count]
    test rcx, rcx
    jz .next_square
    
    lea rsi, [rel valid_moves_list]
    lea rdi, [rbp - 200]             
    push rcx                         
    mov rcx, 27
    cld
    rep movsb
    pop rcx                          
    
    lea rsi, [rbp - 200]             

.move_loop:
    push rcx
    push rsi
    push r14

    lea rsi, [rel board]
    lea rdi, [rbp - 168]             
    mov rcx, 128
    cld
    rep movsb

    movzx r15, byte [rel en_passant_target]
    shl r15, 8
    mov r15b, byte [rel w_castle_k]
    shl r15, 8
    mov r15b, byte [rel w_castle_q]
    shl r15, 8
    mov r15b, byte [rel b_castle_k]
    shl r15, 8
    mov r15b, byte [rel b_castle_q]
    push r15                         

    mov rdx, [rsp + 8]               
    mov rsi, [rsp + 16]              
    mov rcx, [rsp + 24]              
    movzx r8, byte [rsi + rcx - 1]   
    call make_move

    call verify_king_safety          
    test rax, rax
    jz .revert_move                  

    lea rbx, [rel board]
    mov cl, byte [rbx + r8]          
    
    cmp cl, W_PAWN
    je .check_w_promo_div
    cmp cl, B_PAWN
    je .check_b_promo_div
    jmp .normal_recurse_div

.check_w_promo_div:
    mov al, r8b
    and al, 0x70
    jz .do_promotion_div
    jmp .normal_recurse_div

.check_b_promo_div:
    mov al, r8b
    and al, 0x70
    cmp al, 0x70
    je .do_promotion_div
    jmp .normal_recurse_div

.do_promotion_div:
    mov r9b, W_KNIGHT
    mov r10b, W_QUEEN
    cmp cl, 1
    je .promo_loop_div
    mov r9b, B_KNIGHT
    mov r10b,  B_QUEEN

.promo_loop_div:
    lea rbx, [rel board]
    mov byte [rbx + r8], r9b        

    xor byte [rel current_color], 1
    mov rcx, r12
    dec rcx
    
    push r8
    push r9
    push r10
    call perft_recursive             
    pop r10
    pop r9
    pop r8
    
    add r13, rax                    ; add to total

    ; strdump for promotion
    mov r14, [rsp + 8]               
    mov rsi, [rsp + 16]              
    mov rcx, [rsp + 24]              
    push rax                       
    call print_divide_branch         
    pop rax
    
    xor byte [rel current_color], 1

    inc r9b
    cmp r9b, r10b
    jle .promo_loop_div
    jmp .revert_move    


.normal_recurse_div:
    xor byte [rel current_color], 1
    mov rcx, r12
    dec rcx
    call perft_recursive             
    
    add r13, rax                     
    
    mov r14, [rsp + 8]               
    mov rsi, [rsp + 16]              
    mov rcx, [rsp + 24]              
    ; r8 is already the target
    call print_divide_branch         
    
    xor byte [rel current_color], 1

    

.next_square:
    inc r14
    jmp .square_loop

.revert_move:
    ; pop the global state
    pop r15
    mov byte [rel b_castle_q], r15b
    shr r15, 8
    mov byte [rel b_castle_k], r15b
    shr r15, 8
    mov byte [rel w_castle_q], r15b
    shr r15, 8
    mov byte [rel w_castle_k], r15b
    shr r15, 8
    mov byte [rel en_passant_target], r15b

    ; pop the board
    lea rsi, [rbp - 168]             
    lea rdi, [rel board]             
    mov rcx, 128
    cld
    rep movsb

    pop r14
    pop rsi
    pop rcx
    dec rcx
    jnz .move_loop

.exit_generate:
    mov rax, r13                     

.exit:
    add rsp, 216                     
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret