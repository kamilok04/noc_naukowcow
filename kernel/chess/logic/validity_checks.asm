%ifndef VALIDITY_CHECKS
%define VALIDITY_CHECKS
%endif
; ------------------------------------------------------------------------------
; is_on_board
; Inputs: RAX - board index
; Outputs: ZF set if piece is on board
; ------------------------------------------------------------------------------
is_on_board:
    test rax, 0x88     
    ret                

; ------------------------------------------------------------------------------
; is_friendly_fire
; Checks if you aren't about to crash into a piece of your color
; Inputs:
;   AL - Moving piece ID (1-12)
;   BL - Target square piece ID (0-12)
; Outputs: 
;   RAX = 0 if blocked by friendly piece, 1 otherwise
; Trashes:
;   CL, DL
; ------------------------------------------------------------------------------
is_friendly_fire:
    xor rax, rax
    test bl, bl
    jz .valid             

    ; white: 1-6
    ; black: 7-12
    cmp al, 7
    setae cl               

    cmp bl, 7
    setae dl   

    cmp cl, dl
    jne .valid            ; If colors match, it's friendly fire
.invalid:
    inc rax
.valid:
    ret

; ------------------------------------------------------------------------------
; check_steps
; For a regular piece, check if next move is:
; - in bounds 
; - hitting a friendly piece
; - hitting an enemy piece
; For a sliding piece, check the above for any subsequent step.
; Inputs:
;   R8  - Starting square index (0x00 to 0x77)
;   AL  - Moving piece ID
;   R9  - Directional offset (e.g., -16 for Up)
; ------------------------------------------------------------------------------
check_steps:
    mov r10l, al
.step_loop:
    add r8, r9
    
    mov rax, r8
    call is_on_board
    jnz .ray_done           ; ZF = 0 -> out of bounds
    
    ; what is on the target square?
    lea rbx, [rel board_state]
    mov bl, byte [rbx + r8] ; BL = target piece ID
    
    push rax
    call is_friendly_fire   ; RAX = 1 if friendly fire
    cmp rax, 1
    pop rax
    je .ray_done            ; friendly fired
    
    ; at this point the move is legal*
    ; (checks, pins, etc. aside)
    ; LOG "Valid move found at index %x", r8
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax
    
    ; is an enemy hit?
    test bl, bl
    jnz .ray_done           ; valid, but blocks path
    
    ; empty field
    ; if the piece slides, repeat
    mov bl, byte[rel is_sliding + r10l]
    test bl, bl
    jnz .step_loop

.ray_done:
    ret

; ------------------------------------------------------------------------------
; check_white_pawn
; For a white pawn, launuch a 3-step process to determine the move validity
; 1. is a single forward move legal?
; 2. is a double forward move legal?
; 3. is a capture legal?

; Inputs
; R8 =  board position of the pawn
; ------------------------------------------------------------------------------
check_white_pawn:
    ; Assume R8 is the pawn's current 0x88 index
    
    ; 1. single move forward
    mov rax, r8
    sub rax, 0x10
    call is_on_board
    jnz .check_captures       ; If off board, skip forward moves
    
    lea rbx, [rel board_state]
    mov bl, byte [rbx + rax]
    test bl, bl
    jnz .check_captures       ; If occupied, skip forward moves
    
    ; LOG "Valid Single Push at %x -> %x", r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax
    
    ; 2. double move forward
    ; check if we're on the 2nd (logically 6th) rank
    mov rcx, r8
    and rcx, 0xF0             ; mask out the column
    cmp rcx, 0x60
    jne .check_captures       ; not on starting rank
    
    mov rax, r8
    sub rax, 0x20
    lea rbx, [rel board_state]
    mov bl, byte [rbx + rax]
    test bl, bl
    jnz .check_captures       ; Must be empty
    
    ; LOG "Valid Double Push at %x -> %x", r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax

.check_captures:
    ; check capturing to the right first
    ; order doesn't really matter
    mov rax, r8
    sub rax, 0x0F
    call is_on_board
    jnz .capture_left        ; ZF: an attack would go out-of-bounds

    cmp al, byte [rel en_passant_target] ; there can never be a valid capture and a valid EP capture in the same direction
    je .ep_right_valid

    lea rbx, [rel board_state]
    mov cl, byte [rbx + rax] ; CL = target piece ID
    
    test cl, cl
    jz .capture_left         ; square is empty, no capture
    
    cmp cl, 7
    jl .capture_left         ; ids 1-6 are friendly fire, skip
    
    ; LOG "Valid Capture Right at %x -> %x", r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax

    jmp .capture_left

.ep_right_valid:
    ; LOG "Valid EP Capture Right at %x -> %x", r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax
.capture_left:
    ; check the left side
    mov rax, r8
    sub rax, 0x11
    call is_on_board    ; LOG "Valid Capture Left at %x -> %x",r8, rax
    jnz .done                ; out of bounds

    cmp al, byte [rel en_passant_target]
    je .ep_left_valid

    lea rbx, [rel board_state]
    mov cl, byte [rbx + rax]
    
    test cl, cl
    jz .done                 ; empty
    
    cmp cl, 7
    jl .done                 ; friendly
    
    ; LOG "Valid Capture Left at %x -> %x",r8, rax

    push rax
    mov rax, r8          
    call add_valid_move
    pop rax
    jmp .done
.ep_left_valid:
    ; LOG "Valid EP Capture Left at %x -> %x", r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax

.done:
    ret

; ------------------------------------------------------------------------------
; check_black_pawn
; For a black pawn, launuch a 3-step process to determine the move validity
; 1. is a single forward move legal?
; 2. is a double forward move legal?
; 3. is a capture legal?

; Inputs
; R8 =  board position of the pawn
; ------------------------------------------------------------------------------
check_black_pawn:
        mov rax, r8
    add rax, 0x10
    call is_on_board
    jnz .check_captures       
    
    lea rbx, [rel board_state]
    mov cl, byte [rbx + rax]
    test cl, cl
    jnz .check_captures       ;
    
   ;  LOG "Valid Single Push at %x -> %x",r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax
    
    mov rcx, r8
    and rcx, 0xF0          
    cmp rcx, 0x10
    jne .check_captures      
    
    mov rax, r8
    add rax, 0x20
    lea rbx, [rel board_state]
    mov cl, byte [rbx + rax]
    test cl, cl
    jnz .check_captures       ; occupied
    
   ; LOG "Valid Double Push at %x -> %x",r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax

.check_captures:
    mov rax, r8
    add rax, 0x0F
    call is_on_board
    jnz .capture_next      

    ; EP
    cmp al, byte [rel en_passant_target]
    je .ep_0F_valid

    lea rbx, [rel board_state]
    mov cl, byte [rbx + rax]
    test cl, cl
    jz .capture_next         
    cmp cl, 7
    jge .capture_next        ; ids >= 7 are friendly fire, skip
    
    ;LOG "Valid Capture B Left at %x -> %x",r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax
    jmp .capture_next

.ep_0F_valid:
    ;LOG "Valid En Passant B Left at %x -> %x",r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax

.capture_next:
    ; --- 4. Check Capture (+0x11) ---
    mov rax, r8
    add rax, 0x11
    call is_on_board
    jnz .done         

    ; Check En Passant First
    cmp al, byte [rel en_passant_target]
    je .ep_11_valid

    ; Standard Capture Check
    lea rbx, [rel board_state]
    mov cl, byte [rbx + rax]
    test cl, cl
    jz .done                 
    cmp cl, 7
    jge .done               
    
  ;  LOG "Valid Capture B Right at %x -> %x",r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax
    jmp .done

.ep_11_valid:
   ; LOG "Valid En Passant B Right at %x -> %x",r8, rax
    push rax
    mov rax, r8          
    call add_valid_move
    pop rax

.done:
    ret

