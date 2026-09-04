; ------------------------------------------------------------------------------
; verify_king_safety
; Checks if the king is currently safe
; Outputs: RAX = 1 (Move is Safe), RAX = 0 (King is Attacked)
; ------------------------------------------------------------------------------
verify_king_safety:
    push rbx
    push rcx
    push rdx
    push r8

    ; which king?
    mov dl, byte [rel current_color] 
    mov cl, 6                        ; white
    test dl, dl
    jz .find_king
    mov cl, 12                       ; black

.find_king:
    xor r8, r8                       ; R8 = current square
    lea rbx, [rel sandbox_board]

.scan_loop:
    cmp byte [rbx + r8], cl          
    je .king_found
    
    inc r8
    mov rax, r8
    test rax, 0x88                   
    jz .next
    add r8, 7                        ; skip padding
.next:
    cmp r8, 0x78                     ; we done?
    jl .scan_loop
    
    mov rax, 1                       ; just in case...
    LOG "No king detected!"
    jmp .done

.king_found:
    LOG "Checking king safety."
    call is_square_attacked          
    xor rax, 1                     ; attacked = !safe

.done:
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret


; ------------------------------------------------------------------------------
; is_square_attacked
; The idea: cast pseudo-legal reverse moves from the destination into the board
; if those reverse moves hit an enemy, then there is an attack
;
; Inputs: R8 - The 0x88 index to check (a king should be there in most cases)
; Outputs: RAX = 1 if attacked, RAX = 0 if safe
; ------------------------------------------------------------------------------
is_square_attacked:
    push rbx
    push rcx
    push rdx
    push rsi
    push r9
    push r10
    push r11

    ; who's attacking us?
    mov al, byte [rel current_color]
    test al, al
    jnz .enemy_is_white

.enemy_is_black:
    mov r10b, 7          ; bpawn
    mov cl, 8            ; bknight
    jmp .check_knights

.enemy_is_white:
    mov r10b, 1          ; wpawn
    mov cl, 2            ; wknight

.check_knights:
    mov rdx, 8
    lea rsi, [rel knight_offsets]
.knight_loop:
    movsx r9, byte [rsi]
    mov rax, r8
    add rax, r9          ; checked square + enemy offset -> reverse move
    test rax, 0x88       ;
    jnz .next_knight
    
    lea rbx, [rel sandbox_board]
    cmp byte [rbx + rax], cl
    je .is_attacked      ; hit a knight
                         ; the cool part about this is that I need not care how many knights are on the board
                         ; this would be a problem with forward casts, given that promotion is a thing
    
.next_knight:
    inc rsi
    dec rdx
    jnz .knight_loop

    ; pawns don't use offsets and need to be considered separately
.check_pawns:
    lea rbx, [rel sandbox_board]
    mov al, byte [rel current_color]
    test al, al
    jnz .black_king_looking

.white_king_looking:
    ; white king looks up
    mov rax, r8
    sub rax, 0x0F
    test rax, 0x88
    jnz .wk_other_side
    cmp byte [rbx + rax], r10b
    je .is_attacked

.wk_other_side:
    mov rax, r8
    sub rax, 0x11
    test rax, 0x88
    jnz .done_pawns
    cmp byte [rbx + rax], r10b
    je .is_attacked
    jmp .done_pawns

.black_king_looking:
    ; black king looks down
    mov rax, r8
    add rax, 0x0F
    test rax, 0x88
    jnz .bk_other_side
    cmp byte [rbx + rax], r10b
    je .is_attacked

.bk_other_side:
    mov rax, r8
    add rax, 0x11
    test rax, 0x88
    jnz .done_pawns
    cmp byte [rbx + rax], r10b
    je .is_attacked

.done_pawns:
    ; this piece of code checks for threats against sliding pieces
    ; for convenience, the offset-loop approach won't be used
    ; instead, two orthogonal beams will be launched in two directions
    ; +, then x
.check_orthogonal:
    mov al, byte [rel current_color]
    test al, al
    jnz .ortho_enemy_is_white
    
.ortho_enemy_is_black:
    mov cl, 10               ; brook
    mov r11b, 11              ; bqueen
    jmp .ortho_loop_setup
.ortho_enemy_is_white:
    mov cl, 4                ; wrook
    mov r11b, 5               ; wqueen

.ortho_loop_setup:
    mov rdx, 4               ; 4 directions (po polsku 2 kierunki :)) 
    lea rsi, [rel rook_offsets]
    
.ortho_dir_loop:
    movsx r9, byte [rsi]     
    mov rax, r8              ; start
.ortho_ray_loop:
    add rax, r9              ; step
    test rax, 0x88
    jnz .next_ortho_dir      ; OOB, done
    
    lea rbx, [rel sandbox_board]
    mov r10b, byte [rbx + rax]
    test r10b, r10b
    jz .ortho_ray_loop       ; empty, keep going
    
    ; hit found, is this a relevant piece?
    cmp r10b, cl
    je .is_attacked
    ; this is not legal in x64
    ; instead, using legacy low-byte x86 registers is encouraged
    ; NASM manual, section 8.1
    ; cmp r10b, ch
    cmp r10b, r11b
    je .is_attacked
    
    ; no, this ray is done then
    jmp .next_ortho_dir

.next_ortho_dir:
    inc rsi
    dec rdx
    jnz .ortho_dir_loop

    ; same logic for diagonal moves
.check_diagonal:
    mov al, byte [rel current_color]
    test al, al
    jnz .diag_enemy_is_white
    
.diag_enemy_is_black:
    mov cl, 9                ; bbishop
    mov r11b, 11               ; bqueen
    jmp .diag_loop_setup
.diag_enemy_is_white:
    mov cl, 3                ; wbishop
    mov r11b, 5                ; wqueen

.diag_loop_setup:
    mov rdx, 4               
    lea rsi, [rel bishop_offsets]
    
.diag_dir_loop:
    movsx r9, byte [rsi]
    mov rax, r8
.diag_ray_loop:
    add rax, r9
    test rax, 0x88
    jnz .next_diag_dir
    
    lea rbx, [rel sandbox_board]
    mov r10b, byte [rbx + rax]
    test r10b, r10b
    jz .diag_ray_loop        ; analogous logic
    
    cmp r10b, cl             
    je .is_attacked
    ; cmp r10b, ch
    cmp r10b, r11b             
    je .is_attacked
    jmp .next_diag_dir       

.next_diag_dir:
    inc rsi
    dec rdx
    jnz .diag_dir_loop


    ; kings touching is also an illegal scenario.]
.check_enemy_king:
    mov al, byte [rel current_color]
    test al, al
    jnz .king_enemy_is_white
.king_enemy_is_black:
    mov cl, 12               ; bking
    jmp .king_loop_setup
.king_enemy_is_white:
    mov cl, 6                ; wking (occasionally pking :))

.king_loop_setup:
    mov rdx, 8               ; 8 directions
    lea rsi, [rel king_offsets]
    
.king_dir_loop:
    movsx r9, byte [rsi]
    mov rax, r8
    add rax, r9
    test rax, 0x88
    jnz .next_king_dir
    
    lea rbx, [rel sandbox_board]
    cmp byte [rbx + rax], cl
    je .is_attacked          ; "attacked" by the king
    
.next_king_dir:
    inc rsi
    dec rdx
    jnz .king_dir_loop

    xor rax, rax         ; no threats, 0
    jmp .exit

.is_attacked:
    LOG "sb: sqr atk!"
    mov rax, 1           

.exit:
    pop r11
    pop r10
    pop r9
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret