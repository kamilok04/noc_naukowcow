; include in the data section!
 
    ; piece definitions
    ; each square has 15 possible states
    EMPTY       equ 0
    W_PAWN      equ 1
    W_KNIGHT    equ 2
    W_BISHOP    equ 3
    W_ROOK      equ 4
    W_QUEEN     equ 5
    W_KING      equ 6
    
    B_PAWN      equ 9      ; black = white + 8
    B_KNIGHT    equ 10
    B_BISHOP    equ 11
    B_ROOK      equ 12
    B_QUEEN     equ 13
    B_KING      equ 14

SQUARE_SIZE    equ 80            ; 80x80 pixels per square
BOARD_START_X  equ 100           ; margin of 100
BOARD_START_Y  equ 100           ; margin of 100

COLOR_LIGHT    equ 0x00F0D9B5    ; light wood-ish
COLOR_DARK     equ 0x00B58863    ; dark wood-ish

; 0 = blank square
; 1-6 = white (PNBRQK in this order)
; 7-12 = black (PNBRQK in this order)
board:
    db 10,  8,  9, 11, 12,  9,  8, 10, 0, 0, 0, 0, 0, 0, 0, 0  ; black 
    db  7,  7,  7,  7,  7,  7,  7,  7, 0, 0, 0, 0, 0, 0, 0, 0  ;
    times 64 db 0 
    db  1,  1,  1,  1,  1,  1,  1,  1, 0, 0, 0, 0, 0, 0, 0, 0  ; 
    db  4,  2,  3,  5,  6,  3,  2,  4, 0, 0, 0, 0, 0, 0, 0, 0  ; white

; Array to hold the memory addresses of the loaded BMP files (Index 0 is unused)
piece_bitmaps: times 13 dq 0

; File paths for the assets
path_wpawn   db "ASSETS/CHESS/WPAWN.BMP;1", 0
path_wknight db "ASSETS/CHESS/WKNIGHT.BMP;1", 0
path_wking   db "ASSETS/CHESS/WKING.BMP;1", 0
path_wqueen  db "ASSETS/CHESS/WQUEEN.BMP;1", 0
path_wrook   db "ASSETS/CHESS/WROOK.BMP;1", 0
path_wbishop db "ASSETS/CHESS/WBISHOP.BMP;1", 0

path_bpawn   db "ASSETS/CHESS/BPAWN.BMP", 0
path_bknight db "ASSETS/CHESS/BKNIGHT.BMP;1", 0
path_bking   db "ASSETS/CHESS/BKING.BMP;1", 0
path_bqueen  db "ASSETS/CHESS/BQUEEN.BMP;1", 0
path_brook   db "ASSETS/CHESS/BROOK.BMP;1", 0
path_bbishop db "ASSETS/CHESS/BBISHOP.BMP;1", 0