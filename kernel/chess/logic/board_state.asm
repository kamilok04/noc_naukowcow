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
   
    B_PAWN      equ 7      ; black = white + 6
    B_KNIGHT    equ 8
    B_BISHOP    equ 9  
    B_ROOK      equ 10
    B_QUEEN     equ 11  
    B_KING      equ 12

; removed in favour of dynamic UI computation

; SQUARE_SIZE    equ 80            ; 80x80 pixels per square
; BOARD_START_X  equ 100           ; margin of 100
; BOARD_START_Y  equ 100           ; margin of 100

COLOR_LIGHT    equ 0x00F0D9B5    ; light wood-ish
COLOR_DARK     equ 0x00B58863    ; dark wood-ish
COLOR_HIGHLIGHT equ 0x007FA650   ; g r e e n
COLOR_PROMOTION equ 0x00D3D3D3   ; grey
COLOR_RED       equ 0x00ff0000
COLOR_GREEN     equ 0x0000ff00
COLOR_BLUE      equ 0x000000ff
COLOR_BG        equ 0x008ab4f8    ; light blue
COLOR_WHITE     equ 0x00ffffff

; 0 = blank square
; 1-6 = white (PNBRQK in this order)
; 7-12 = black (PNBRQK in this order)
board:
    db 10,  8,  9, 11, 12,  9,  8, 10, 0, 0, 0, 0, 0, 0, 0, 0  ; black 
    db  7,  7,  7,  7,  7,  7,  7,  7, 0, 0, 0, 0, 0, 0, 0, 0  ;
    times 64 db 0 
    db  1,  1,  1,  1,  1,  1,  1,  1, 0, 0, 0, 0, 0, 0, 0, 0  ; 
    db  4,  2,  3,  5,  6,  3,  2,  4, 0, 0, 0, 0, 0, 0, 0, 0  ; white

; Niektóre pola to komendy.
; np. ruch 0xAA -> 0xAA (J-2 -> J-2) przeładowuje assety na komputerze docelowym,
; 0xBB -> 0xBB (K-3 -> K-3) resetuje stan gry.

; board:
;     db 9, 11, 8, 8, 10, 12, 10, 9, 0, 0, 0, 0, 0, 0, 0, 0
;     db 7, 7, 7, 7, 7, 7, 7, 7, 0, 0, 0, 0, 0, 0, 0, 0
;     times 64 db 0
;     db 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0
;     db 3, 5, 2, 2, 4, 6, 4, 3, 0, 0, 0, 0, 0, 0, 0, 0

sandbox_board: times 128 db 0 ; for actual move detection

; Array to hold the memory addresses of the loaded BMP files (Index 0 is unused)
piece_bitmaps: times 13 dq 0

; File paths for the assets
path_wpawn   db "ASSETS\CHESS\WPAWN.BMP", 0
path_wknight db "ASSETS\CHESS\WKNIGHT.BMP", 0
path_wking   db "ASSETS\CHESS\PKING.BMP", 0
path_wqueen  db "ASSETS\CHESS\WQUEEN.BMP", 0
path_wrook   db "ASSETS\CHESS\WROOK.BMP", 0
path_wbishop db "ASSETS\CHESS\WBISHOP.BMP", 0

path_bpawn   db "ASSETS\CHESS\BPAWN.BMP", 0
path_bknight db "ASSETS\CHESS\BKNIGHT.BMP", 0
path_bking   db "ASSETS\CHESS\BKING.BMP", 0
path_bqueen  db "ASSETS\CHESS\BQUEEN.BMP", 0
path_brook   db "ASSETS\CHESS\BROOK.BMP", 0
path_bbishop db "ASSETS\CHESS\BBISHOP.BMP", 0

path_btn_giveup   db "ASSETS\CHESS\GIVEUP.BMP", 0
path_btn_draw     db "ASSETS\CHESS\DRAW.BMP", 0
path_btn_ok       db "ASSETS\CHESS\OK.BMP", 0
path_btn_no       db "ASSETS\CHESS\NO.BMP", 0
path_btn_back     db "ASSETS\CHESS\BACK.BMP", 0
path_btn_forward  db "ASSETS\CHESS\FORWARD.BMP", 0


; Valid movements
; Knight:

;        --|++
;        21012
;     
; (-32)   o+o
; (-16)  o | o
; (  0)  +-X-+
; ( 16)  o | o
; ( 32)   o+o
;

knight_offsets db -33, -31, -18, -14,  14,  18,  31,  33
king_offsets   db -17, -16, -15,  -1,   1,  15,  16,  17
rook_offsets   db -16,  -1,   1,  16
bishop_offsets db -17, -15,  15,  17
is_sliding     db 0, 0, 0, 1, 1, 1, 0, 0, 0
               db 1, 1, 1, 0
; queen offsets are king offsets, but sliding

en_passant_target db 0xFF ; initialize to none
valid_moves_count db 0
valid_moves_list  times 27 db 0 ; 27 is exactly enough, check for yourself!
current_color db 0 ; 0 is white
selected_square db 0xff

; castling
; 4 possible castlings, keeping track of all of them
; 1 = allowed, 0 = illegal
w_castle_k db 1      ; white O-O
w_castle_q db 1      ; white O-O-O
b_castle_k db 1      ; black O-O
b_castle_q db 1      ; black O-O-O

; starting positions
; this will be important if Chess960 ever becomes a concern
; default to Chess960 position 518
; (the exact same as in regular chess)
WK_start db 0x74
WRa_start db 0x70
WRh_start db 0x77

BK_start db 0x04
BRa_start db 0x00
BRh_start db 0x07
; WK_start db 0x75
; WRa_start db 0x74
; WRh_start db 0x76

; BK_start db 0x05
; BRa_start db 0x04
; BRh_start db 0x06

; promotion logic
promotion_pending db 0       ; 1 when waiting for user input
promotion_sq      db 0       ; index of a square to promote into

; QRBN
promotion_lookup_w db 5, 4, 3, 2
promotion_lookup_b db 11, 10, 9, 8

; general game state
; 0 = active, 1 = white wins, 2 = black wins, 3 = stalemate
match_state db 0
is_in_check db 0 ; 1 if the last move triggered a check. Used for transcripts.

; endgame GUI
POPUP_W         equ 300
POPUP_H         equ 240

; removed in favor of runtime calculation
; POPUP_X         equ BOARD_START_X + (4 * SQUARE_SIZE) - (POPUP_W / 2)
; POPUP_Y         equ BOARD_START_Y + (4 * SQUARE_SIZE) - (POPUP_H / 2)
; BTN_X           equ POPUP_X + (POPUP_W / 2) - (BTN_W / 2)
; BTN_Y           equ POPUP_Y + 160
; BTN_TEXT_W      equ 16 * (popup_btn_str - stalemate_str)
; BTN_TEXT_H      equ 16
; BTN_W           equ 140
; BTN_H           equ 50


POPUP_TEXT_H    equ 50


popup_x dd 0
popup_y dd 0
btn_x   dd 0
btn_y   dd 0
popup_w    dd 0
popup_h    dd 0
btn_w      dd 0
btn_h      dd 0

text_scale dd 3

COLOR_POPUP_BG  equ 0x00222222   ; Dark Slate
COLOR_BTN_BG    equ 0x0055AA55   ; Restart Button Green

; --- PRISTINE BOARD STATE ---
initial_board:
    db 10,  8,  9, 11, 12,  9,  8, 10, 0, 0, 0, 0, 0, 0, 0, 0  ; black 
    db  7,  7,  7,  7,  7,  7,  7,  7, 0, 0, 0, 0, 0, 0, 0, 0  ;
    times 64 db 0 
    db  1,  1,  1,  1,  1,  1,  1,  1, 0, 0, 0, 0, 0, 0, 0, 0  ; 
    db  4,  2,  3,  5,  6,  3,  2,  4, 0, 0, 0, 0, 0, 0, 0, 0  ; white

black_wins_str db "Czarne wygrywają!", 0
white_wins_str db "Białe wygrywają!", 0
stalemate_str db "Remis.", 0
popup_btn_str db "Rewanż!", 0

; GUI

ACTION_STATE_DEFAULT equ 0
ACTION_STATE_SURRENDER equ 1 ; there is no "incoming surrendder", as it doesn't requires the opponent's consent
ACTION_STATE_DRAW equ 2
ACTION_STATE_INCOMING_DRAW equ 3

ui_action_state dd 0      
ui_manual_scroll dd -1    ; -1 = Auto-scroll, >=0 = Manual offset

; bounding boxes for buttons
btn_back_box     dd 0, 0, 0, 0
btn_forward_box  dd 0, 0, 0, 0
btn_draw_box     dd 0, 0, 0, 0
btn_giveup_box   dd 0, 0, 0, 0

; gui bmp ptrs
bmp_btn_back  dq 0       ; "<"
bmp_btn_forward   dq 0       ; ">"
bmp_btn_draw  dq 0       ; "1/2"
bmp_btn_giveup  dq 0       ; "flag"
bmp_btn_ok dq 0       ; "checkmark"
bmp_btn_no dq 0       ; "X"

; chess960
chess960_mode   db 0
rng_seed        dq 0
temp_rank       times 8 db 0

str_c960_off    db "Chess960: NIE", 0
str_c960_on     db "Chess960: TAK", 0

; c960 knights' possible positions
; everything else is decided by this
; see: Schnargl's algorithm
knight_960_table db 0,0, 0,1, 0,2, 0,3, 1,1, 1,2, 1,3, 2,2, 2,3, 3,3

current_seed dd 0
str_seed_display db "Plansza nr    ", 0