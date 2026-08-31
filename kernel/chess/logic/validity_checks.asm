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