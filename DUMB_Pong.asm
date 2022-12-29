;* --- Dumb Unless Made Better ---
;*
;* DUMB Pong v0.1
;*
;* An attempt to create a game from scratch, Pong is so simple it's the perfect pick for a first project 
;* By VinsCool 
;*
;* To build: 'mads DUMB_Pong.asm -l:ASSEMBLED/build.lst -o:ASSEMBLED/build.xex' 
;*----------------------------------------------------------------------------------------------

;* Memory addresses and other definitions

ZEROPAGE	equ $0000	; Zeropage
DUMBPONG	equ $1000	; Main program 
VLINE		equ 9		; 16 is the default according to Raster's example player 
RASTERBAR	equ $69		; $69 is a nice purpleish hue 

	OPT R- F-
	icl "atari.def"		; Missing or conflicting labels cause build errors, be extra careful! 
	
;-----------------

;//---------------------------------------------------------------------------------------------	

;* Most of the game variables will sit in the Zeropage, or be part of self-modifying code in subroutines 

	org ZEROPAGE+$80 
ZPGVAR
OLDVBI		org *+2		; Backup for VBI address 
DISPLAY 	org *+2		; Display List indirect memory address
MIS_P1_X	org *+1		; Player 1 X coordinate 
MIS_P1_Y	org *+1		; Player 1 Y coordinate
MIS_P2_X	org *+1		; Player 2 X coordinate
MIS_P2_Y	org *+1		; Player 2 Y coordinate
MIS_BALL_X	org *+1		; Ball X coordinate
MIS_BALL_X_OLD	org *+1		; Previous Ball X coordinate 
MIS_BALL_Y	org *+1		; Ball Y coordinate 
MIS_BALL_Y_OLD	org *+1		; Previous Ball Y coordinate 
BALL_H_VELOCITY	org *+1		; Horizontal velocity of the ball, -127 -> Left, +127 -> Right
BALL_V_VELOCITY	org *+1		; Horizontal velocity of the ball, -127 -> Up, +127 -> Down 
BALL_HITCOUNT	org *+1		; Keep track of the ball hits by the Players, and apply a velocity boost once 16 hits were counted 
BALL_FLAG	org *+1		; Status such as #$01 -> Collision, #$FF -> Pocketed, #$00 -> Active, Reset, etc 
BALL_KNOCKBACK	org *+1		; A bonus velocity value to add into the calculations, for better bouncing effects 
BLINKING_COLOUR	org *+1		; Apply this colour to anything that should be highlighted 
TMP0		org *+1		; Temporary values used for some calculations 
TMP1 		org *+1		; Use it as a target I guess 
TMP2		org *+1		; Use it as a timer I guess 
ZPGVAREND

;-----------------

;//---------------------------------------------------------------------------------------------

;* Initialisation, then loop infinitely unless the program is told otherwise 

	org DUMBPONG 
start       
	ldx #0			; disable playfield and the black colour value
	stx SDMCTL		; write to Shadow Direct Memory Access Control address
	jsr wait_vblank		; wait for vblank before continuing
	stx COLOR4		; Shadow COLBK (background colour), black
	stx COLOR2		; Shadow COLPF2 (playfield colour 2), black 
	jsr clear_memory	; clear all the Zeropage variables and all the Screen memory before using it 
	mwa #dlist SDLSTL	; Start Address of the Display List 
	jsr detect_region 	; detect the machine region 
	dec play_skip 		; initialise the PAL/NTSC condition, player is skipped every 6th frame in NTSC 
	ldx #$2E		; DMA enable, normal playfield, Player and Missile enable, double line resolution 
	stx SDMCTL		; write to Shadow Direct Memory Access Control address
	jsr wait_vblank		; wait for vblank => 1 frame 
	jsr draw_playfield 	; draw the main screen 
	sei			; Set Interrupt Disable Status
	mwa VVBLKI OLDVBI       ; vbi address backup
	mwa #vbi VVBLKI		; write our own vbi address to it 
	mva #$40 NMIEN		; enable vbi interrupts 

;* initialise the playfield colours, missiles position and appearance on the screen, and whatever left to set before running 

	mva #>pm PMBASE		; player/missile base address
	ldx #3
	stx GRACTL 
	dex			; #3 -> #2
	stx SIZEP2
	stx SIZEP3
	dex			; #2 -> #1
	dex			; #1 -> #0
	stx GPRIOR		
	stx COLPM3		; invisible player for collisions detections
	stx COLPF1
	stx COLPF2
	stx COLPF3
	stx COLBK		; black background 
	ldx #15			; whiter white 	
	stx COLPF0		; main playfield graphics 
	stx COLPM0 		; Player 2's racket 
	stx COLPM1		; Player 1's racket 
	stx BLINKING_COLOUR 
	dex 
	dex 
	stx COLPM2		; Ball, slightly more gray 
	lda #%00000101		; Missile 0-1 -> medium size, Missile 2-3 -> small size 
;	lda #%11110101 
	sta SIZEM 
	lda #1
	sta BALL_FLAG		; initial state: Player 2 owns the ball, ready to play
	ldx #52			; initial vertical position for both Players 
	lda #60			; in the left corner, weighing in at 225lbs, standing upside down, undefeated heavyweight champion...
	sta HPOSM0		; ...the one and only Player 2, nicknamed "The Dense Brick Wall"! 
	sta MIS_P2_X		; initial horizontal position for Player 2 
	stx MIS_P2_Y 		; initial vertical position for Player 2 
	lda #192		; in the right corner, weighing in at 230lbs flat, always landing hits with sharp precision...
	sta HPOSM1		; ...the aspiring champion, Player 1, a brutal contender who rose to the top 3 insanely fast! 
	sta MIS_P1_X 		; initial horizontal position for Player 1 
	stx MIS_P1_Y 		; initial vertical position for Player 1 
	
wait_sync
	lda VCOUNT		; current scanline 
	cmp #VLINE		; will stabilise the timing if equal
	bcc wait_sync		; nope, repeat 

;//---------------------------------------------------------------------------------------------

;* Mainloop, anything that could run while the screen is drawing 

loop
	ldy #RASTERBAR			; custom rasterbar colour
acpapx1
	lda spap
	ldx #0
cku	equ *-1
	bne keepup
	lda VCOUNT			; vertical line counter synchro
	tax
	sub #VLINE
lastpap	equ *-1
	scs:adc #$ff
ppap	equ *-1
	sta dpap
	stx lastpap
	lda #0
spap	equ *-1
	sub #0
dpap	equ *-1
	sta spap
	bcs acpapx1
keepup
	adc #$ff
acpapx2	equ *-1
	sta spap
	ldx #0
	scs:inx
	stx cku
play_loop 
	sty WSYNC			; horizontal sync for timing purpose
;	sty COLBK			; background colour
;	sty COLPF2			; playfield colour 2
	jsr setpokeyfull		; update the POKEY registers first, for both the SFX and LZSS music driver 
	jsr play_sfx			; process the SFX data, if an index is queued and ready to play for this frame 
	ldy #0				; black colour value 
;	sty WSYNC			; horizontal sync for timing purpose
;	sty COLBK			; background colour
	sty COLPF2			; playfield colour 2	
	beq loop			; unconditional
	
;----------------- 

;//---------------------------------------------------------------------------------------------

;* VBI loop, run through all the code that is needed, then return with a RTI 

vbi 
	sta WSYNC			; horizontal sync, so we're always on the exact same spot, seems to help with timing stability 
;	ldy #56				; debug colour 
;	sty COLBK			; background colour
;	sty COLPF2			; playfield colour 2 
	ldx #0				; PAL/NTSC adjustment flag 
play_skip equ *-1
	bmi do_play_always		; #$FF -> PAL region was detected 
	beq dont_play_this_frame	; #0 -> NTSC region was detected, skip the player call for this frame 
	dex 				; decrement the counter for the next frame
	stx play_skip 			; and overwrite the value 
	bpl do_play_always		; unconditional, this frame will be played
dont_play_this_frame
	lda #5				; reset the counter 
	sta play_skip
	bpl return_from_vbi 		; and skip this frame 
	
do_play_always 
	;* process the remaining of game logic from this point onward until the end of VBI 

check_key_pressed 
	ldx SKSTAT			; Serial Port Status
	txa
	and #$04			; last key still pressed?
	bne continue			; if not, skip ahead, no input to check 
	lda KBCODE			; Keyboard Code  
	and #$3F			; clear the SHIFT and CTRL bits out of the key identifier for the next part
	tay
	txa
	and #$08			; SHIFT key being held?
	beq skip_held_key_check		; if yes, skip the held key flag check, else, verify if the last key is still being held
check_keys_always
	lda #0 				; was the last key pressed also held for at least 1 frame? This is a measure added to prevent accidental input spamming
	held_key_flag equ *-1
	bmi continue_b			; the held key flag was set if the value is negative! skip ahead immediately in this case 
skip_held_key_check
	jsr check_keys			; each 'menu' entry will process its action, and return with RTS, the 'held key flag' must then be set!
	ldx #$FF
	bmi continue_a			; skip ahead and set the held key flag! 
continue				; do everything else during VBI after the keyboard checks 
	ldx #0				; reset the held key flag! 
continue_a 				; a new held key flag is set when jumped directly here
	stx held_key_flag 
continue_b 				; a key was detected as held when jumped directly here 
	jsr check_ball_collision 	; check if players and ball have collided 
	jsr check_for_ball_pocketed	; has the ball been pocketed by 1 of the players? 
	jsr check_paddles 		; general input handler for both players 
	jsr check_ball_hitcount		; check how many times the ball was exchanged between the players 
	jsr set_ball_velocity 		; take the velocity variables, and apply them to the ball for its movements 
	jsr set_p1_position 		; draw all player/missiles on screen based on the coordinates last written in memory 
	jsr set_p2_position 
	jsr set_ball_position 
	jsr check_for_ownership 	; check which player is owning the ball, and update the colours accordingly 
	jsr set_blinking_colour		; process the blinking colour 
return_from_vbi	
	sta WSYNC			; horizontal sync, this seems to make the timing more stable
;	ldy #0				; clear debug colour 
;	sty COLBK			; background colour
;	sty COLPF2			; playfield colour 2
	pla				;* since we're in our own vbi routine, pulling all values manually is required! 
	tay
	pla
	tax
	pla
	rti				; return from interrupt, this ends the VBI time, whenever it actually is "finished" 

;-----------------

;//---------------------------------------------------------------------------------------------

;* Everything below this point is either stand alone subroutines that can be called at any time, and the display list 

;//---------------------------------------------------------------------------------------------

;* Wait for vblank subroutine

wait_vblank 
	lda RTCLOK+2		; load the real time frame counter to accumulator
wait        
	cmp RTCLOK+2		; compare to itself
	beq wait		; equal means it vblank hasn't began
	rts

;-----------------

; Print text from data tables, useful for many things 

printinfo 
	sty charbuffer
	ldy #0
do_printinfo
        lda $ffff,x
infosrc equ *-2
	sta (DISPLAY),y
	inx
	iny 
	cpy #0
charbuffer equ *-1
	bne do_printinfo 
	rts

;-----------------

; Stop and quit when execution jumps here

stop_and_exit
	jsr stop_pause_reset 
	mwa OLDVBI VVBLKI	; restore the old vbi address
	ldx #$00		; disable playfield 
	stx SDMCTL		; write to Direct Memory Access (DMA) Control register
	dex			; underflow to #$FF
	stx CH			; write to the CH register, #$FF means no key pressed
	cli			; this may be why it seems to crash on hardware... I forgot to clear the interrupt bit!
	jsr wait_vblank		; wait for vblank before continuing
	jmp (DOSVEC)		; return to DOS, or Self Test by default

;----------------- 

;* Seek tunes for the LZSS music driver, using the TUNES_NUM definition for indexing

/*
seek_next_tune
	ldx SongIdx
	inx
	cpx #TUNES_NUM
	bcc seek_tune_done
	ldx #0
	beq seek_tune_done
seek_previous_tune
	ldx SongIdx
	dex
	bpl seek_tune_done
	ldx #TUNES_NUM-1 
seek_tune_done
	stx SongIdx
	jmp SetNewSongPtrsFull	; end with a RTS!
*/

;-----------------

;* Detect the machine region subroutine

detect_region	
	lda VCOUNT
	beq check_region	; VCOUNT = 0, compare values
	tax			; backup the value in X 
	bne detect_region 	; repeat until VCOUNT = 0 
check_region
	lda #$9C		; PAL region timing (default) 
	sta acpapx2		; lines between each play
	cpx #$9B		; compare X to 155
	bmi set_ntsc		; negative result means the machine runs at 60hz 
	ldx #0			; roll over to #$FF, will always play 
	beq region_done		; unconditional 
set_ntsc 
	lda #$82 		; if NTSC is detected, adjust the speed from PAL to NTSC 
	ldx #6			; every 6th frame will be skipped to match the PAL timing 
region_done
	stx play_skip 		; set the flag for the VBI routines 
	sta ppap		; stability fix for screen synchronisation during mainloop 
	rts 

;-----------------

;* Initialise the SFX to play in memory once the joystick button is pressed, using the SFX index number

set_sfx_to_play
	lda #0
SfxIdx equ *-1
set_sfx_to_play_immediate
	asl @
	tax
	lda sfx_data,x
	sta sfx_src
	lda sfx_data+1,x
	sta sfx_src+1
	inc is_playing_sfx 
	lda #3 
	sta sfx_channel
	lda #0
	sta sfx_offset
	rts

;-----------------

;* Mute SFX with a toggle byte

mute_sfx
	lda is_mute_sfx
	eor #$FF
	sta is_mute_sfx
	rts

;-----------------

;* Play the SFX currently set in memory, one frame every VBI

play_sfx
	lda #0
is_mute_sfx equ *-1
	bmi play_sfx_done 
	lda #$FF		; #$00 -> Play SFX until it's ended, #$FF -> SFX has finished playing and is stopped
is_playing_sfx equ *-1
	bmi play_sfx_done
	lda #2			; 2 frames
	sta is_playing_sfx
	lda #0
sfx_offset equ *-1
	asl @
	tax
	inc sfx_offset
	lda #0
sfx_channel equ *-1
	asl @
	tay
	bpl begin_play_sfx
play_sfx_loop
	inx
	iny
begin_play_sfx
        lda $ffff,x
sfx_src equ *-2
	sta SDWPOK0,y
	dec is_playing_sfx
	bne play_sfx_loop
	lda SDWPOK0,y
	bne play_sfx_done
	dec is_playing_sfx
play_sfx_done
	rts

;-----------------

;* Process the Pong players score

inc_p1_score 
	lda p1_score
	sed
	clc
	adc #1
	cld
	sta p1_score 
	jsr draw_score_p1
	lda #8				; play sfx: game in_hole 
	jmp set_sfx_to_play_immediate	; end with a RTS!  
	
inc_p2_score
	lda p2_score
	sed
	clc
	adc #1
	cld
	sta p2_score 
	jsr draw_score_p2
	lda #3				; play sfx: menu code_rejected
	jmp set_sfx_to_play_immediate	; end with a RTS!  

reset_scores
	lda #0
	sta p1_score
	sta p2_score
	jsr draw_score_p1
	jsr draw_score_p2
	lda #6				; play sfx: game move_fox
	jmp set_sfx_to_play_immediate	; end with a RTS! 

;-----------------

;* Update the Pong players score on screen

draw_score_p1
	mwa #screen+7 DISPLAY 	; get the right screen position
	lda #0
p1_score equ *-1
	pha
	and #$0F
	jsr draw_score
	mwa #screen+6 DISPLAY 	; get the right screen position
	jmp draw_score_second_digit
draw_score_p2
	mwa #screen+3 DISPLAY 	; get the right screen position
	lda #0
p2_score equ *-1
	pha
	and #$0F
	jsr draw_score
	mwa #screen+2 DISPLAY 	; get the right screen position
draw_score_second_digit	
	pla
	:4 lsr @
draw_score
	asl @
	tay
	lda score_data,y 
	sta score_src
	lda score_data+1,y
	sta score_src+1
	ldx #4 
	ldy #0
draw_score_loop	
        lda $ffff,y
score_src equ *-2
	sta (DISPLAY),y
	lda DISPLAY		; current memory address used for the process
	add #9			; mode 6 uses 20 characters 
	sta DISPLAY		; adding 20 will move the pointer to the next line
	scc:inc DISPLAY+1	; in case the boundary is crossed, the pointer MSB will increment as well
	iny
	dex
	bpl draw_score_loop
	rts

;-----------------

;* check all keys that have a purpose here... 
;* this is the world's most cursed jumptable ever created!
;* regardless, this finally gets rid of all the spaghetti code I made previously!

check_keys 
	tya				; transfer to the accumulator to make a quick and dirty jump table
	asl @				; ASL only once, allowing a 2 bytes index, good enough for branching again immediately and unconditionally, 128 bytes needed sadly...
	sta k_index+1			; branch will now match the value of Y
k_index	bne * 
	rts:nop				; Y = 0 -> L key
	rts:nop
	rts:nop
	rts:nop
	rts:nop
	rts:nop
	rts:nop				; Y = 6 -> Atari 'Left' / '+' key
	rts:nop				; Y = 7 -> Atari 'Right' / '*' key 
	rts:nop				; bcc do_stop_toggle 		; Y = 8 -> 'O' key (not zero!!) 
	rts:nop
	rts:nop				; bcc do_play_pause_toggle	; Y = 10 -> 'P' key
	rts:nop
	rts:nop				; Y = 12 -> 'Enter' key
	rts:nop
	rts:nop
	rts:nop
	rts:nop
	rts:nop
	rts:nop		 		; Y = 18 -> 'C' key
	rts:nop
	rts:nop
	rts:nop
	rts:nop				; Y = 22 -> 'X' key
	rts:nop				; Y = 23 -> 'Z' key
	rts:nop				; Y = 24 -> '4' key
	rts:nop
	rts:nop				; Y = 26 -> '3' key
	rts:nop				; Y = 27 -> '6' key
	bcc do_exit			; Y = 28 -> 'Escape' key
	rts:nop				; Y = 29 -> '5' key
	bcc do_toggle_p1		; Y = 30 -> '2' key
	bcc do_toggle_p2 		; Y = 31 -> '1' key
	rts:nop
	rts:nop			 	; Y = 33 -> 'Spacebar' key
	rts:nop
	rts:nop
	rts:nop
	bcc do_mute_sfx			; Y = 37 -> 'M' key
	rts:nop
	rts:nop
	bcc do_reset_scores		; Y = 40 -> 'R' key
	rts:nop
	rts:nop
	rts:nop
	rts:nop
	rts:nop
	rts:nop				; Y = 46 -> 'W' key
	rts:nop
	rts:nop
	rts:nop
	rts:nop
	rts:nop				; Y = 51 -> '7' key
	rts:nop
	rts:nop				; Y = 53 -> '8' key
	rts:nop
	rts:nop
	rts:nop				; bcc do_trigger_fade_immediate	; Y = 56 -> 'F' key
	rts:nop				; Y = 57 -> 'H' key
	rts:nop				; Y = 58 -> 'D' key
	rts:nop
	rts:nop
	rts:nop
	rts:nop				; Y = 62 -> 'S' key
	rts:nop				; Y = 63 -> 'A' key

;-----------------

;* Jumptable from the branches above, long range in case things don't quite reach 

do_exit
	jmp stop_and_exit		; stop and exit to DOS 
	
do_reset_scores
	jmp reset_scores
	
do_mute_sfx
	jmp mute_sfx 

do_toggle_p1
	jmp toggle_p1
	
do_toggle_p2
	jmp toggle_p2 
	
;do_stop_toggle
;	jmp stop_toggle			; toggle stop flag
	
;do_play_pause_toggle	
;	jmp play_pause_toggle		; toggle play/pause flag

;do_trigger_fade_immediate
;	jmp trigger_fade_immediate	; immediately set the 'fadeout' flag then stop the player once finished
	
;do_seek_next_tune
;	jmp seek_next_tune

;do_seek_previous_tune
;	jmp seek_previous_tune

;do_inc_p1_score
;	jmp inc_p1_score
	
;do_inc_p2_score
;	jmp inc_p2_score

;-----------------

;* Paddles processing routine 
;* Human Players will use the values read from the Paddles POTs 
;* CPU Players however will use a different subroutine for updating their position on screen 

check_paddles  
	lda is_player_2				; human or cpu?
	bmi check_paddles_next			; if P2 is cpu, do not update the coordinate 

;* Check Paddle for Player 1 	

paddle_x 
	lda POT0				; paddle x
	eor #$FF	
	clc
	adc #17	
	lsr @
	sec
	sbc #17
	cmp #$10
	bcc paddle_x_min			; out of bounds -> too high above
	cmp #$58
	bcc paddle_x_good	
paddle_x_max
	lda #$57	
	bne paddle_x_good	
paddle_x_min
	lda #$10
paddle_x_good 
	sta MIS_P2_Y 	

check_paddles_next  	
	lda is_player_1				; human or cpu?
	bmi check_paddles_trigger		; if P1 is cpu, do not update the coordinate 

;* Check Paddle for Player 2 
	
paddle_y
	lda POT1				; paddle y
	eor #$FF
	clc
	adc #17	
	lsr @
	sec
	sbc #17 
	cmp #$10
	bcc paddle_y_min			; out of bounds -> too high above
	cmp #$58
	bcc paddle_y_good	
paddle_y_max
	lda #$57	
	bne paddle_y_good	
paddle_y_min
	lda #$10
paddle_y_good 
	sta MIS_P1_Y

;* Check the paddle trigger for throwing the Ball back after being pocketed 

check_paddles_trigger 
	ldy BALL_FLAG 				; which state is the ball currently set to? 
	beq paddles_done			; active state, ignore the check, there is nothing to do 
	bmi paddles_done			; pocketed ball, ignore the check, it's too early to process 
	
check_for_p2_owning_ball 	
	cpy #1					; owned by player 2?
	bne check_for_p1_owning_ball 
	ldx is_player_2 			; CPU or Player 2?
	beq p2_is_human_and_owning_ball 	; #0 -> Human player, #$FF -> very dumb CPU player
	jsr p2_is_cpu_and_owning_ball  		; let the cpu try to guess in what direction it should move first 
	beq p2_is_cpu_and_cheated_the_paddle_check
	
p2_is_human_and_owning_ball 
	lda PORTA				; controller port 0 
	and #$04				; paddle trigger 0
	bne paddles_done			; value != 0 is not pressed 
p2_is_cpu_and_cheated_the_paddle_check
	lda #$02				; initial velocity, going from left to right 
	bpl paddles_done_try_random 		; unconditional 
	
check_for_p1_owning_ball 
	ldx is_player_1 			; CPU or Player 1?
	beq p1_is_human_and_owning_ball 	; #0 -> Human player, #$FF -> very dumb CPU player
	jsr p1_is_cpu_and_owning_ball  		; let the cpu try to guess in what direction it should move first 
	beq p1_is_cpu_and_cheated_the_paddle_check

p1_is_human_and_owning_ball
	lda PORTA				; controller port 0 
	and #$08				; paddle trigger 0
	bne paddles_done			; value != not 0 is not pressed 
p1_is_cpu_and_cheated_the_paddle_check  
	lda #$82				; initial velocity, going from right to left 

paddles_done_try_random   
	sta BALL_H_VELOCITY			; initial horizontal velocity 
	ldy RANDOM 				; in which direction should the ball's vertical axis go? 
	bpl paddles_done_reset_ball		; if RANDOM ranges between #$00 and #$7F... keep the same direction 
	eor #$80				; there will be 1 chance out of 2 the value is inverted 

paddles_done_reset_ball 
	sta BALL_V_VELOCITY 			; initial vertical velocity 
;	inc BALL_V_VELOCITY			; slight vertical boost upon start 
	lda #0
	sta BALL_FLAG				; reset the ball flag to its active state once it's thrown back in game 
	sta BALL_HITCOUNT 			; reset the ball hitcount to 0 for the next exchange 
	
	lda #1
	sta BALL_KNOCKBACK			; give a slight velocity boost upon launching it  
	lda #5					; play sfx: ????
	jsr set_sfx_to_play_immediate 
	
paddles_done
	sta POTGO				; must be reset every time, else they won't work properly 
	rts
	
;-----------------

;* Generic Missile clear subroutines, X is used for the screen offset, and Y for the number of bytes to process
	
clear_p1 	
	ldy #24
clear_p1_loop
	lda mis,x 
	and #$F3
	sta mis,x
	inx	
	dey
	bpl clear_p1_loop
	rts

clear_p2 	
	ldy #24
clear_p2_loop
	lda mis,x 
	and #$FC
	sta mis,x
	inx	
	dey
	bpl clear_p2_loop
	rts

clear_ball
	ldy #1
clear_ball_loop
	lda #$00 
	sta sprites+$300,x
	sta sprites+$380,x
	inx	
	dey
	bpl clear_ball_loop
	rts

;* Generic Missile draw subroutine, X is used for the screen offset, and Y for the number of bytes to process

draw_p1
	ldy #24
draw_p1_loop
	lda mis,x
	ora #$0C
	sta mis,x
	inx	
	dey
	bpl draw_p1_loop
	rts
	
draw_p2
	ldy #24
draw_p2_loop
	lda mis,x
	ora #$03
	sta mis,x
	inx	
	dey
	bpl draw_p2_loop
	rts
	
draw_ball
	ldy #1
draw_ball_loop
	lda #$C0
	sta sprites+$300,x
	sta sprites+$380,x 
	inx	
	dey
	bpl draw_ball_loop
	rts

;-----------------

;* Update player 1 and 2, and ball missile sprites coordinates 
	
set_p1_position
	lda #$00 			; CPU or Player 1? #0 for Human Player, #$FF for CPU Player 
is_player_1 equ *-1
	beq p1_is_human			; #0 -> Human player, #$FF -> very dumb CPU player
	jsr p1_is_cpu 			; let the cpu try to guess in what direction it should move first 
p1_is_human
	lda MIS_P1_Y			; compare to the old value in memory 
	cmp #$FF
old_p1_pos_y equ *-1
	beq skip_p1_redraw		; if it is identical, skip it, there is no point redrawing the same memory over and over! 
	ldx old_p1_pos_y		; load the old offset before updating it first, so the missile could be redrawn elsewhere on the screen
	sta old_p1_pos_y
	jsr clear_p1
	ldx MIS_P1_Y 
	jsr draw_p1 
skip_p1_redraw
	rts

set_p2_position
	lda #$00 			; CPU or Player 2? #0 for Human Player, #$FF for CPU Player 
is_player_2 equ *-1
	beq p2_is_human			; #0 -> Human player, #$FF -> very dumb CPU player
	jsr p2_is_cpu 			; let the cpu try to guess in what direction it should move first 
p2_is_human 
	lda MIS_P2_Y			; compare to the old value in memory 
	cmp #$FF
old_p2_pos_y equ *-1
	beq skip_p2_redraw		; if it is identical, skip it, there is no point redrawing the same memory over and over! 
	ldx old_p2_pos_y		; load the old offset before updating it first, so the missile could be redrawn elsewhere on the screen
	sta old_p2_pos_y
	jsr clear_p2
	ldx MIS_P2_Y 
	jsr draw_p2 
skip_p2_redraw
	rts 
	
set_ball_position 
	ldx MIS_BALL_Y_OLD		; last ball position in the vertical axis
	jsr clear_ball			; clear the ball from the last position first 
	ldx MIS_BALL_Y 			; current ball Y coordinate 
	stx MIS_BALL_Y_OLD 		; update the old Y coordinate with the new one  
	jsr draw_ball 			; draw the ball on screen with the new position 
	lda MIS_BALL_X 			; current ball X coordinate 
	sta MIS_BALL_X_OLD 		; update the old X coordinate with the new one  
	sta HPOSP2			; update the horizontal position for the player used visually as a 'ball'
;	sub #2  			; FIXME: not perfect but this seems to work okay as a failsafe collision detection 
	sta HPOSP3			; update the offset invisible player used for better collisions detection accuracy  
ball_done
	rts

;-----------------

;* Process the collision detection between the ball and one of the players
;* First step: verify if the ball is owned by a Player, in order to prevent false positives! 
;* If nobody is owning the ball, the actual collisions could then be processed like normal 

check_ball_collision 
	lda BALL_FLAG			; has the ball been in a collision yet?
	bmi check_ball_collision_done	; #$FF is the pocketed state of the ball, process further! 
	beq check_ball_collision_a	; ball is active, update its position based on the velocity values 
check_for_ball_owned
	cmp #1				; ball reset and owned by p1?
	bne check_for_ball_owned_a	; neither players own the ball, flag unknown, ignore the other values 
	lda MIS_P2_X			; copy the P2 coordinates, so the ball follows the paddle until it is released
	add #4  
	sta MIS_BALL_X
	lda MIS_P2_Y
	sta MIS_BALL_Y
	rts
check_for_ball_owned_a	
	cmp #2				; ball reset and owned by p2? 
	bne check_ball_collision_done	; player 1 does not own the ball, check the player 2 
	lda MIS_P1_X			; copy the P1 coordinates, so the ball follows the paddle until it is released 
	sub #2
	sta MIS_BALL_X
	lda MIS_P1_Y
	sta MIS_BALL_Y
check_ball_collision_done 
	rts 
	
;----------------- 

;* Second step: verify if the ball had a collision with a Player, it's either one of them, or none of them 
;* If a collision was detected, the velocity variables must be inverted to "bounce" back to the other player 
;* If no collision was detected, the previous ball X coordinate will be compared to the current one as a failsafe 
;* That way, if a movement was too fast, and went past the hitbox, there is still a chance for it to be a "valid" collision 
;* In this case, the ball will behave exactly as intended, and bounce back to the other Player 

check_ball_collision_a
	lda M0PL			; was there a collision between the ball and Player 2?
	beq check_ball_collision_b	; no collision if 0 
	lda MIS_BALL_Y 
	sub #12
	cmp MIS_P2_Y
	beq bonus_add_h_velocity  
	bne check_ball_collision_c	; unconditional 
	
check_ball_collision_b
	lda M1PL			; was there a collision between the ball and Player 1?
	beq check_ball_collision_d	; no collision if 0 
	lda MIS_BALL_Y 
	sub #12
	cmp MIS_P1_Y
;	beq bonus_add_h_velocity  
	bne check_ball_collision_c	; unconditional 
	
bonus_add_h_velocity 
	lda #1				; play sfx: ??
	jsr set_sfx_to_play_immediate 
	lda #5 
	sta BALL_KNOCKBACK 		; give a slight velocity boost upon recoil 
	inc BALL_H_VELOCITY		; hit middle of the racket, the player is awarded an extra boost instantly! hell yes!!! 
	lda #0 
	sta BALL_HITCOUNT 
	beq invert_h_velocity_immediate 

check_ball_collision_c 
	lda #4 
	sta BALL_KNOCKBACK 		; give a slight velocity boost upon recoil 
	lda #7				; play sfx: game move_bunny
	jsr set_sfx_to_play_immediate	; end with a RTS! 
	inc BALL_HITCOUNT 		; increment the ball hitcount by 1 if either Player had collided with the ball 

invert_h_velocity_immediate
	lda BALL_H_VELOCITY 		; current horizontal ball velocity  
	eor #$80 			; inversion 
	sta BALL_H_VELOCITY 		; new horizontal velocity 
	rts

;* Third step, check for missed collisions, it is possible the ball was moving too fast and went through the hitbox undetected 
;* The horizontal movements are the most likely to be in this situation, but for our needs, both axises will be tested 
;* That should be good enough to accurately tell the difference between a miss and going through hitboxes undetected 
;* This is probably the reason why the previous attempt was so unpredictable, if a single unit went too far, it was never caught! 

check_ball_collision_d 
/* 
;* unfinished...

	lda MIS_BALL_X 			; first, load the current ball X coordinate to have an idea of where it was before 
	cmp MIS_BALL_X_OLD 		; compare it to the previous value, to identify the direction the ball was coming from 
;	bcs ball_came_from_left 	; if the current value is higher, the ball came from the left side 
	bcc ball_came_from_right 	; else, if the current value is lower, the ball came from the right side 
ball_came_from_left 
	cmp MIS_P1_X 			; where is the current ball X coordinate relative to the Player 1? 
;	bcs ball_came_from_left_missed	; if the ball went past it undetected, double check using the previous ball X coordinate 
	bcc check_collision_with_walls	; otherwise, this is most likely correct, walls collisions will be checked instead 	
ball_came_from_left_missed
	lda MIS_BALL_X_OLD
	cmp MIS_P1_X 
	bcs check_collision_with_walls 	; if the previous value is also past it, it's most likely correct, continue with walls checks 
;	bcc check_ball_collision_c 	; otherwise, it's very likely a collision was missed, and should be processed anyway 
	rts 				; todo: add vertical procedure 

ball_came_from_right 
	rts 
*/ 
	
;* Fourth step: test the walls boundaries, so the ball couldn't escape the playfield area 
;* There are both the Vertical walls and Horizontal walls to test, each with unique properties 
;* Horizontal walls (Y axis) are the easiest and fastest to test, so they get processed first 
;* Vertical walls (X axis) are a bit more complex, since they have an open space in the middle used for winning points 
;* The actual walls themselves are processed the same as the Horizontal walls, but the opening is a special case to handle 
;* If the ball goes beyond the opening boundaries, the ball flag is updated to "Pocketed", and either Player will win a point 
;* Then, the game is set to continue with the Player who pocketed the ball to throw it back in game, and so on until boredom 

check_collision_with_walls 
	lda MIS_BALL_Y			; verify the ball is within the horizontal walls boundaries 
	cmp #$10
	bcc ball_y_min			
	cmp #$6F
;	bcc ball_y_good	
	bcc check_collision_with_more_walls 
ball_y_max
	lda #$6E 			; out of bounds -> too low below 
	bne ball_y_invert_v_velocity
ball_y_min
	lda #$10			; out of bounds -> too high above 
ball_y_invert_v_velocity
	tay 
	lda BALL_V_VELOCITY 
	eor #$80
	sta BALL_V_VELOCITY 
	lda #2				; play sfx: menu keyclick
	jsr set_sfx_to_play_immediate	
	lda #1
	sta BALL_KNOCKBACK		; very tiny recoil boost added from a wall hit 

/*
mess_with_v_velocity	
	lda BALL_HITCOUNT 
	and #8 
	bne inc_v_velocity  
dec_v_velocity
	dec BALL_V_VELOCITY 
	lda BALL_V_VELOCITY 
	beq inc_v_velocity		; oops 
	cmp #$80 
	bne mess_with_v_velocity_done
inc_v_velocity
	inc BALL_V_VELOCITY 
mess_with_v_velocity_done 
*/ 

	tya
ball_y_good 
	sta MIS_BALL_Y 			; overwrite the coordinate to force it to remain in-bounds 

check_collision_with_more_walls
	lda MIS_BALL_X
	ldy MIS_BALL_Y
	cpy #$24 
	bcc ball_x_rebound		; hit the wall behind the player, not pocketed
	cpy #$5C
	bcs ball_x_rebound		; hit the wall behind the player, not pocketed 
ball_x_may_be_pocketed 
	cmp #$33 
	bcc ball_x_was_pocketed
	cmp #$CC
	bcc ball_x_good	
ball_x_was_pocketed
	dec BALL_FLAG			; #0 -> #$FF 
	jmp ball_x_good			; ball is pocketed by player 1 or player 2 
ball_x_rebound
	cmp #$34
	bcc ball_x_min 
	cmp #$CB
	bcc ball_x_good	
ball_x_max
	lda #$CA			; out of bounds -> too far right  
	bne ball_x_invert_h_velocity	
ball_x_min
	lda #$34 			; out of bounds -> too far left 
ball_x_invert_h_velocity
	tay 
	lda BALL_H_VELOCITY
	eor #$80 
	sta BALL_H_VELOCITY
	lda #2				; play sfx: menu keyclick
	jsr set_sfx_to_play_immediate
	lda #3 
	sta BALL_KNOCKBACK		; recoil boost added from a wall hit in this case! 

/*
mess_with_h_velocity	
	lda BALL_HITCOUNT 
	and #8 
	bne inc_h_velocity  
dec_h_velocity
	dec BALL_H_VELOCITY 
	lda BALL_H_VELOCITY 
	beq inc_h_velocity		; oops 
	cmp #$80 
	bne mess_with_h_velocity_done
inc_h_velocity
	inc BALL_H_VELOCITY 
mess_with_h_velocity_done 
*/

	tya
ball_x_good 
	sta MIS_BALL_X 
	rts 
	
;-----------------

;* Major difference: Velocity direction is assigned with Bit 7 only instead of being inverted 
;* This seems to be a lot more robust to prevent calculations errors from values being off by 1 
;* It's pretty much likely to be easier to process, while also being a lot simpler to understand 
;* A single AND instruction would be needed in order to "invert" the movements direction this time 

set_ball_velocity 
	ldx MIS_BALL_X 			; current ball X coordinate 
	ldy BALL_KNOCKBACK 		; verify there is also a knockback that could be applied 
	beq set_h_ball_velocity		; if the knockback is at 0, there won't be a boost added from it 
	dec BALL_KNOCKBACK 		; otherwise, decrement the knockback value by 1 
set_h_ball_velocity 
	lda BALL_H_VELOCITY		; horizontal ball velocity 
	bpl add_h_ball_velocity 
sub_h_ball_velocity 
	eor #$80 			; invert the value first 
	sta TMP0
	tya 
	add TMP0			; add the knockback value to the calculations as well 
	sta TMP0 
	txa 
	sub TMP0 			; subtract the velocity value to make it go in the right direction 
	bne update_ball_x_coordinate	; unconditional 
add_h_ball_velocity 
	sta TMP0
	tya
	add TMP0			; add the knockback value to the calculations as well 
	sta TMP0 
	txa 
	add TMP0	 		; the velocity value can then be added directly to it 
update_ball_x_coordinate 
	sta MIS_BALL_X 
	
set_ball_velocity_a   
	ldx MIS_BALL_Y 			; current ball Y coordinate 
set_v_ball_velocity 
	lda BALL_V_VELOCITY		; vertical ball velocity 
	bpl add_v_ball_velocity 
sub_v_ball_velocity 
	eor #$80 			; invert the value first 
	sta TMP0
	txa 
	sub TMP0 
	bne update_ball_y_coordinate	; unconditional 
add_v_ball_velocity 
	txa 
	add BALL_V_VELOCITY 		; the velocity value can be added directly in this case 
update_ball_y_coordinate 
	sta MIS_BALL_Y 
	rts 

;-----------------

;* Process the score based on if the ball managed to get pocketed by one of the players 

check_for_ball_pocketed 
	lda BALL_FLAG			; has the ball been pocketed yet?
	sta HITCLR			; clear collisions for this frame while we're here 
	bmi check_players_pocket	; #$FF is the pocketed state of the ball, process further! 
check_for_ball_done 
	rts	
check_players_pocket
	lda MIS_BALL_X 			; in which side has the ball gone to?
	ldy #0
	sty BALL_H_VELOCITY
	sty BALL_V_VELOCITY
check_p2_pocketed
	iny
	cmp #$33
	bcs check_p1_pocketed		; not pocketed by p1, verify it has been to the other side instead  
	sty BALL_FLAG			; #1 -> ball is in the reset state, owned by P1 
	jmp inc_p1_score		; end with a RTS!
check_p1_pocketed
	iny 
	cmp #$CC
	bcc check_for_ball_done		; not pocketed by p2, in this case, neither made a point (should not happen!) 
	sty BALL_FLAG			; #2 -> ball is in the reset state, owned by P2 
	jmp inc_p2_score		; end with a RTS!

;-----------------

;* DUMB CPU code used for Player 1, 
;* TODO?: add difficulty levels maybe? 

toggle_p1
	lda is_player_1 
	eor #$FF
	sta is_player_1 
	rts 
	
p1_is_cpu_and_owning_ball 
	lda TMP1
	bne p1_is_cpu_and_does_nothing 
	lda #30
	sta TMP2
p1_is_cpu_and_waits
	lda RANDOM 
	cmp #$10
	bcc p1_is_cpu_and_does_nothing	; out of bounds -> too high above
	cmp #$58
	bcs p1_is_cpu_and_does_nothing	; out of bounds -> too low below 	
	sta TMP1 
p1_is_cpu_and_does_nothing  
	lda MIS_P1_Y
	cmp TMP1
	beq p1_is_cpu_fake_paddle
	bcc p1_inc_tmp1
p1_dec_tmp1
	dec MIS_P1_Y
	rts 
p1_inc_tmp1 
	inc MIS_P1_Y
	rts 
p1_is_cpu_fake_paddle
	dec TMP2 
	lda TMP2 
	bne p1_is_cpu_fake_paddle_waiting 
	sta TMP1 
p1_is_cpu_fake_paddle_waiting 
	rts 
	
p1_is_cpu 
	lda MIS_BALL_X			; x coordinate of the ball object to "track" 
	cmp #$A0			; is the ball at coordinate #$A0 or higher? 
	bcs p1_will_move		; if yes, the cpu will move towards it, else, it won't move from its current position 
	rts 
p1_will_move 
;	ldy MIS_BALL_Y			; y coordinate of the ball object to "track" 
	lda BALL_FLAG 
	beq p1_will_move_freely 	; if no flag is set, let the CPU do its thing 
	rts 
p1_will_move_freely
	lda MIS_BALL_Y 
	sub #12				; adjustment, to make the player centered relative to the ball position 
	tay 
	lda RANDOM			; roll a die :D 
	and #%00001111 
	sta random_subtract_p1_cpu
	lsr @
	tax
	tya  
	sub #0
random_subtract_p1_cpu equ *-1
p1_cpu_try_again
	cmp MIS_P1_Y			; where is it relative to the current cpu position?
	beq p1_is_cpu_done
	bcc p1_cpu_move_up		; it is too low below, go catch it up
p1_cpu_move_down
	lda MIS_P1_Y
	clc
	adc #1
	bne p1_is_cpu_done
p1_cpu_move_up
	lda MIS_P1_Y
	sec
	sbc #1
p1_is_cpu_done 
	sta MIS_P1_Y
	tya
	dex
	bpl p1_cpu_try_again
p1_is_cpu_done_a	
	lda MIS_P1_Y
	cmp #$10
	bcc p1_cpu_x_min		; out of bounds -> too high above
	cmp #$58
	bcc p1_cpu_x_good	
p1_cpu_x_max				; out of bounds -> too low below 
	lda #$57	
	bne p1_cpu_x_good	
p1_cpu_x_min
	lda #$10
p1_cpu_x_good 
	sta MIS_P1_Y 
	rts

;-----------------

;* DUMB CPU code used for Player 2, 
;* TODO?: add difficulty levels maybe? 

toggle_p2 
	lda is_player_2 
	eor #$FF
	sta is_player_2 
	rts 

p2_is_cpu_and_owning_ball 
	lda TMP1
	bne p2_is_cpu_and_does_nothing 
	lda #30
	sta TMP2
p2_is_cpu_and_waits
	lda RANDOM 
	cmp #$10
	bcc p2_is_cpu_and_does_nothing	; out of bounds -> too high above
	cmp #$58
	bcs p2_is_cpu_and_does_nothing	; out of bounds -> too low below 	
	sta TMP1 
p2_is_cpu_and_does_nothing  
	lda MIS_P2_Y
	cmp TMP1
	beq p2_is_cpu_fake_paddle
	bcc p2_inc_tmp1
p2_dec_tmp1
	dec MIS_P2_Y
	rts 
p2_inc_tmp1 
	inc MIS_P2_Y
	rts 
p2_is_cpu_fake_paddle
	dec TMP2 
	lda TMP2 
	bne p2_is_cpu_fake_paddle_waiting 
	sta TMP1 
p2_is_cpu_fake_paddle_waiting 
	rts 
	
p2_is_cpu 
	lda MIS_BALL_X			; x coordinate of the ball object to "track" 
	cmp #$60			; is the ball at coordinate #$5F or lower? 
	bcc p2_will_move		; if yes, the cpu will move towards it, else, it won't move from its current position 
	rts 
p2_will_move	
;	ldy MIS_BALL_Y			; y coordinate of the ball object to "track" 
	lda BALL_FLAG 
	beq p2_will_move_freely 	; if no flag is set, let the CPU do its thing 
	rts 
p2_will_move_freely
	lda MIS_BALL_Y 
	sub #12				; adjustment, to make the player centered relative to the ball position 
	tay 
	lda RANDOM			; roll a die :D 
	and #%00001111 
	sta random_subtract_p2_cpu
	lsr @
	tax
	tya  
	sub #0
random_subtract_p2_cpu equ *-1
p2_cpu_try_again
	cmp MIS_P2_Y			; where is it relative to the current cpu position?
	beq p2_is_cpu_done
	bcc p2_cpu_move_up		; it is too low below, go catch it up
p2_cpu_move_down
	lda MIS_P2_Y
	clc
	adc #1
	bne p2_is_cpu_done
p2_cpu_move_up
	lda MIS_P2_Y
	sec
	sbc #1
p2_is_cpu_done 
	sta MIS_P2_Y
	tya
	dex
	bpl p2_cpu_try_again
p2_is_cpu_done_a	
	lda MIS_P2_Y
	cmp #$10
	bcc p2_cpu_x_min		; out of bounds -> too high above
	cmp #$58
	bcc p2_cpu_x_good	
p2_cpu_x_max				; out of bounds -> too low below 
	lda #$57	
	bne p2_cpu_x_good	
p2_cpu_x_min
	lda #$10
p2_cpu_x_good 
	sta MIS_P2_Y 
	rts

;-----------------	

;* a bunch of Self Modifying code to provide a "blinking" animation on player-missile sprites 

set_blinking_colour 
	lda BLINKING_COLOUR 
	tay
	iny				; INY is $C8 and DEY is $88
	missile_blinker equ *-1
	and #$F0
	sta TMP0
	tya
	and #$0F
	tay 
	beq revert_missile_blink
	ora TMP0 
	sta BLINKING_COLOUR   
	cpy #$0F
	bne apply_blinking_colour  
revert_missile_blink
	lda missile_blinker
	eor #$40
	sta missile_blinker 
apply_blinking_colour 
	rts 

;-----------------

;* THAT SUBROUTINE IS MORE PROBLEMS THAN I WAS HOPING, SCREW THAT 

/*
;* Call this subroutine to identify who is currently owning the ball 
;* Zero Flag -> Ball is in-game, no one is owner 
;* Negative Flag -> Ball is pocketed, no one is owner yet 
;* Carry Set -> Player 1 is owner
;* Carry Clear -> Player 2 is owner 

who_is_owner
	lda BALL_FLAG 			; which state is the ball currently set to? 
	beq who_is_owner_done		; active state, ignore the check, there is nothing to do 
	bmi who_is_owner_done		; pocketed ball, ignore the check, it's too early to process 
	cmp #2				; if Player 1 is owner, this should be equal, else, Player 2 is assumed 
	beq player_1_is_owner
player_2_is_owner 
	clc 				; clear carry to show Player 2 is owner 
	lda #3				; prevent a false positive by specifically clearing the zero flag before returning 
	bpl who_is_owner_done		; zero flag should not be set this time 
player_1_is_owner
	sec 				; set carry to show Player 1 is owner 
	lda #3				; prevent a false positive by specifically clearing the zero flag before returning 
who_is_owner_done 
	rts 
*/

;----------------- 

check_for_ownership 
	lda BALL_FLAG 			; which state is the ball currently set to? 
	beq no_one_is_owner		; active state, ignore the check, there is nothing to do 
	bmi no_one_is_owner		; pocketed ball, ignore the check, it's too early to process 
	ldx BLINKING_COLOUR		; currently blinking colour is constantly being updated, even when it is unused 
	cmp #2				; if Player 1 is owner, this should be equal, else, Player 2 is assumed 
	beq blink_player_1 
blink_player_2 
	stx COLPM0 			; Player 2 is the owner -> blink 
	rts 
blink_player_1 
	stx COLPM1 			; Player 1 is the owner -> blink 
	rts 
no_one_is_owner 
	lda #15				; whitest white 
	sta COLPM1 			; reset Player 1's colour 
	sta COLPM0 			; reset Player 2's colour 
	rts 

;----------------- 

;* Check how many times the ball was traded between players, apply a slight velocity boost upon the 16th hit detected 
;* Since we want the ball to go faster between players, only the Horizontal Velocity will get a boost 

check_ball_hitcount 
	lda BALL_HITCOUNT 
	beq check_ball_hitcount_done	; if the value is set to 0, it's too early to process, skip this subroutine 
	and #$0F			; was there at least 16 hits applied? 
	bne check_ball_hitcount_done	; if there was not enough hits counted yet, skip this subroutine 
	sta BALL_HITCOUNT 		; #0 sits in the accumulator otherwise, reset the ball hitcount using it 
	
;	lda BALL_H_VELOCITY 		; load the ball horizontal velocity to the accumulator first 
;	bmi ball_hitcount_dec_velocity	; for a negative value, decrement the velocity
;	bpl ball_hitcount_inc_velocity	; for a positive value, increment the velocity 
;ball_hitcount_dec_velocity 	
;	dec BALL_H_VELOCITY 		; decrement the velocity for 1 unit 
;	bmi check_ball_hitcount_done	; unconditional 
;ball_hitcount_inc_velocity 

	inc BALL_H_VELOCITY 		; increment the velocity for 1 unit 
check_ball_hitcount_done
	rts

;-----------------

;* Stop/Pause the player and reset the POKEY registers, a RTS will be found at the end of setpokeyfull further below 

stop_pause_reset
	lda #0				; default values
	ldy #8
stop_pause_reset_a 
	sta SDWPOK0,y			; clear the POKEY values in memory 
	dey 
	bpl stop_pause_reset_a		; repeat until all channels were cleared 

;----------------- 

;* Setpokey, intended for double buffering the decompressed LZSS bytes as fast as possible for timing and cosmetic purpose

setpokeyfull
	lda POKSKC0 
	sta $D20F 
	ldy POKCTL0
	lda POKF0
	ldx POKC0
	sta $D200
	stx $D201
	lda POKF1
	ldx POKC1
	sta $D202
	stx $D203
	lda POKF2
	ldx POKC2
	sta $D204
	stx $D205
	lda POKF3
	ldx POKC3
	sta $D206
	stx $D207
	sty $D208
	rts
	
;* Left POKEY is used by default if a Stereo setup is used 

SDWPOK0 
POKF0	dta $00
POKC0	dta $00
POKF1	dta $00
POKC1	dta $00
POKF2	dta $00
POKC2	dta $00
POKF3	dta $00
POKC3	dta $00
POKCTL0	dta $00
POKSKC0	dta $03	

;-----------------

clear_memory 
	lda #0 
	ldy #ZPGVAREND-ZPGVAR 
clear_zeropage_loop 
	sta ZPGVAR,y 
	dey 
	bpl clear_zeropage_loop 
	iny 				; Y = #$FF -> Y = #$00 
	mwa #SCREENMEM DISPLAY 
	tya 
clear_screen_loop 
	sta (DISPLAY),y 
	iny 
	bne clear_screen_loop 
	inc DISPLAY+1 
	ldx >SCREENMEMEND 
	cpx DISPLAY+1 
	bne clear_screen_loop 
	rts 
	
;-----------------

;* Draw the entire playfield before starting the game
;* TODO: Optimise this routine to waste less memory, CPU usage isn't a problem since this is part of initialisation 
;* Also, I must find a way to avoid playing a sound effect with the reset_scores subroutine 

draw_playfield
	jsr reset_scores 		; initialise the scoreboard on screen with 00 - 00 
;	jsr draw_score_p1		; draw the Player 1 score 00
;	jsr draw_score_p2		; draw the Player 2 score 00 

	lda #%01010101 			; '----' 
	
	sta screen_top 
	sta screen_top+9
	sta screen_bottom
	sta screen_bottom+9
	
	lda #%00000001 			; '   -' 
	
	sta screen+64 			; middle of the screen separation 
	sta screen+94
	sta screen+124
	sta screen+154
	sta screen+184 
	
	sta screen+9			; top-right
	sta screen+19
	sta screen+29
	sta screen+39
	sta screen+49
	
	sta screen+199			; bottom-right
	sta screen+209
	sta screen+219
	sta screen+229
	sta screen+239
	
	lda #%01000000			; '-   ' 

	sta screen			; top-left 
	sta screen+10
	sta screen+20
	sta screen+30
	sta screen+40
	
	sta screen+190			; bottom-left 
	sta screen+200
	sta screen+210
	sta screen+220
	sta screen+230 

	rts 

;//---------------------------------------------------------------------------------------------

;* Sound effects index  

sfx_data
	dta a(sfx_00)
	dta a(sfx_01)
	dta a(sfx_02)
	dta a(sfx_03)
	dta a(sfx_04)
	dta a(sfx_05)
	dta a(sfx_06)
	dta a(sfx_07)
	dta a(sfx_08)
	dta a(sfx_09)  

;* Sound effects data 

sfx_00	ins '/Bunny Hop SFX/menu-press.sfx'
sfx_01	ins '/Bunny Hop SFX/menu-movement.sfx'
sfx_02	ins '/Bunny Hop SFX/menu-keyclick.sfx'
sfx_03	ins '/Bunny Hop SFX/menu-code_rejected.sfx'
sfx_04	ins '/Bunny Hop SFX/menu-code_accepted.sfx'
sfx_05	ins '/Bunny Hop SFX/game-select_unselect.sfx'
sfx_06	ins '/Bunny Hop SFX/game-move_fox.sfx'
sfx_07	ins '/Bunny Hop SFX/game-move_bunny.sfx'
sfx_08	ins '/Bunny Hop SFX/game-in_hole.sfx'
sfx_09	ins '/Bunny Hop SFX/game-cannot_do.sfx' 

;-----------------

;* Mode 8 Bitmap graphics index 

score_data
	dta a(score_0) 
	dta a(score_1) 
	dta a(score_2) 
	dta a(score_3) 
	dta a(score_4) 
	dta a(score_5) 
	dta a(score_6) 
	dta a(score_7) 
	dta a(score_8) 
	dta a(score_9) 

;* Mode 8 Bitmap graphics data 

score_0	
	dta %00010101
	dta %00010001
	dta %00010001
	dta %00010001
	dta %00010101
score_1	
	dta %00000001
	dta %00000001
	dta %00000001
	dta %00000001
	dta %00000001	
score_2
	dta %00010101
	dta %00000001
	dta %00010101
	dta %00010000
	dta %00010101	
score_3
	dta %00010101
	dta %00000001
	dta %00010101
	dta %00000001
	dta %00010101	
score_4
	dta %00010001
	dta %00010001
	dta %00010101
	dta %00000001
	dta %00000001	
score_5
	dta %00010101
	dta %00010000
	dta %00010101
	dta %00000001
	dta %00010101
score_6
	dta %00010101
	dta %00010000
	dta %00010101
	dta %00010001
	dta %00010101	
score_7 
	dta %00010101
	dta %00000001
	dta %00000001
	dta %00000001
	dta %00000001	
score_8
	dta %00010101
	dta %00010001
	dta %00010101
	dta %00010001
	dta %00010101
score_9
	dta %00010101
	dta %00010001
	dta %00010101
	dta %00000001 
	dta %00010101

;-----------------

;* Display list 

dlist 
	:2 dta $70		; start with some empty lines
	dta $48			; ANTIC Mode 8 
	dta a(screen_top)	; the entire playfield
	:25 dta $08		; all the next Mode 8 lines underneath
	dta $41,a(dlist)	; Jump and wait for vblank, return to dlist 

;----------------- 

;* Screen memory 
	
;* pairs of bits as follow:
;* %01010101 -> COLPF0
;* %10101010 -> COLPF1
;* %11111111 -> COLPF2
;* %00000000 -> COLBK 

	.ALIGN $200		; otherwise hello screen corruption!!!
SCREENMEM
screen_top
	org *+10
screen 
	org *+240 
screen_bottom
	org *+10 
	
/*
	dta %01010101,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%01010101
screen	
	dta %01000000,%00000000,%00010101,%00010101,%00000000,%00000000,%00010101,%00010101,%00000000,%00000001
	dta %01000000,%00000000,%00010001,%00010001,%00000000,%00000000,%00010001,%00010001,%00000000,%00000001
	dta %01000000,%00000000,%00010001,%00010001,%00000000,%00000000,%00010001,%00010001,%00000000,%00000001
	dta %01000000,%00000000,%00010001,%00010001,%00000000,%00000000,%00010001,%00010001,%00000000,%00000001
	dta %01000000,%00000000,%00010101,%00010101,%00000000,%00000000,%00010101,%00010101,%00000000,%00000001
	dta %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000001,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000001,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000001,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000001,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %00000000,%00000000,%00000000,%00000000,%00000001,%00000000,%00000000,%00000000,%00000000,%00000000
	dta %01000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000001
	dta %01000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000001
	dta %01000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000001 
	dta %01000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000001
	dta %01000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000001
screen_bottom	
	dta %01010101,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000,%01010101
*/

;----------------- 

	.ALIGN $400		; otherwise hello screen corruption!!!
sprites
pm		
	org sprites+$180	; players
mis	
	org sprites+$200	; missiles
buffer
	org sprites+$400	; to make sure the space is cleared before use 
SCREENMEMEND
	run start 		; run address was put here for simplicity, so it come after everything else in memory 

;//---------------------------------------------------------------------------------------------

;* And that's all folks :D

;----------------- 

