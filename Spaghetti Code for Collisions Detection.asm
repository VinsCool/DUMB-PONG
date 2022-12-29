;-----------------

;* Process the collision detection between the ball and one of the players
;* The collisions detection code is really mangled! A cleanup is needed! 

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

check_ball_collision_a
	ldy MIS_BALL_X			; needed for the relative ball coordinate to process collisions 
	ldx MIS_BALL_Y			; to calculate the velocity effects 
	
;-----------------
	
check_ball_collision_b	
	lda M0PL			;* Player 2 collision with the ball
	beq check_ball_collision_c	; no collision 
	inc BALL_HITCOUNT 		; increment the ball hitcount by 1 
	cpy #$3C
	bcs check_p2_racket_front
	
check_p2_racket_back
	cpy #$3A
	bcc check_p2_racket_front
	lda BALL_H_VELOCITY
	bpl apply_ball_velocity		; no direction change, ignore the collision and process like normal
	bmi ball_collided_invert_h_velocity_p2
	
check_p2_racket_front 
	cpy #$3E
	bcs check_p2_racket_back
	lda BALL_H_VELOCITY
	bmi apply_ball_velocity		; no direction change, ignore the collision and process like normal
	bpl ball_collided_invert_h_velocity_p2 

;-----------------

check_ball_collision_c
	lda M1PL			;* Player 1 collision with the ball
	beq apply_ball_velocity		; no collision 
	inc BALL_HITCOUNT 		; increment the ball hitcount by 1 
	cpy #$C2
	bcs check_p1_racket_back 
	
check_p1_racket_front
	cpy #$C0
	bcc check_p1_racket_back
	lda BALL_H_VELOCITY
	bpl apply_ball_velocity		; no direction change, ignore the collision and process like normal
	bmi ball_collided_invert_h_velocity_p1 
	
check_p1_racket_back
	cpy #$C4 
	bcs check_p1_racket_front
	lda BALL_H_VELOCITY
	bmi apply_ball_velocity		; no direction change, ignore the collision and process like normal
	bpl ball_collided_invert_h_velocity_p1

;-----------------
	
ball_collided_invert_h_velocity_p2
	txa
	add #12
	cmp MIS_P2_Y
	beq bonus_p2_add_velocity	; hell yes!!!
	lda #1
	sta TMP0
	bne ball_collided_invert_h_velocity
bonus_p2_add_velocity
	lda #$FF
	sta TMP0
	bne ball_collided_invert_h_velocity		; replace with a JMP maybe??? 

;-----------------

ball_collided_invert_h_velocity_p1	
	txa
	add #12
	cmp MIS_P1_Y
	beq bonus_p1_add_velocity	; hell yes!!!
	lda #1
	sta TMP0
	bne ball_collided_invert_h_velocity
bonus_p1_add_velocity
	lda #$FF
	sta TMP0 

;-----------------

ball_collided_invert_h_velocity 
	lda BALL_H_VELOCITY
;	bmi sub_bonus_velocity		; I dont't even remember what this was trying to achieve... 
add_bonus_velocity
	add TMP0
	bne invert_h_velocity_now
sub_bonus_velocity
	sub TMP0
invert_h_velocity_now	
	eor #$FF 
	bne velocity_inverted
	lda BALL_V_VELOCITY

velocity_inverted	
	sta BALL_H_VELOCITY
	lda #7				; play sfx: game move_bunny
	jsr set_sfx_to_play_immediate 	
apply_ball_velocity
	lda MIS_BALL_Y			; compare to the old value in memory 	
	add BALL_V_VELOCITY		; apply the vertical velocity for movements
	cmp #$10
	bcc ball_y_min			; out of bounds -> too high above
	cmp #$6F
	bcc ball_y_good	
ball_y_max
	lda #$6E	
	bne ball_y_invert_v_velocity	
ball_y_min
	lda #$10
ball_y_invert_v_velocity
	tay
	lda BALL_V_VELOCITY
	eor #$FF
	sta BALL_V_VELOCITY	
	lda #2				; play sfx: menu keyclick
	jsr set_sfx_to_play_immediate
	tya
ball_y_good 
	sta MIS_BALL_Y 			; FIXME: The only time the Y Ball coordinate is updated??
	
apply_ball_velocity_a
	lda MIS_BALL_X
	add BALL_H_VELOCITY		; apply the horizontal velocity for movements
	tax 
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
	bcc ball_x_min			; out of bounds -> too far left
	cmp #$CB
	bcc ball_x_good	
	
ball_x_max
	lda #$CA	
	bne ball_x_invert_h_velocity	
	
ball_x_min
	lda #$34
	
ball_x_invert_h_velocity
	tay 
	lda BALL_H_VELOCITY
	eor #$FF
	sta BALL_H_VELOCITY
	lda #2				; play sfx: menu keyclick
	jsr set_sfx_to_play_immediate
	tya
	
ball_x_good 
	sta MIS_BALL_X 			; FIXME: The only time the X Ball coordinate is updated??
	
	rts

;-----------------

