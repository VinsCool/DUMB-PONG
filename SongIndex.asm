;* Songs index always begin with the "intro" section, followed by the "loop" section, when applicable 
;* Index list must end with the dummy tune address to mark the end of each list properly 
;* Make sure to define the total number of tunes that could be indexed in code using it to avoid garbage data being loaded 

SongsIndexStart	
;	dta a(S_0) 
;	dta a(S_1) 
;	dta a(S_2) 
;	dta a(S_3) 
;	dta a(S_4) 
;	dta a(S_5) 
;	dta a(S_6) 
	dta a(S_DUMMY) 
SongsIndexEnd	

;-----------------
		
;//---------------------------------------------------------------------------------------------

LoopsIndexStart
;	dta a(L_0) 
;	dta a(L_1) 
;	dta a(L_2) 
;	dta a(L_3) 
;	dta a(L_4) 
;	dta a(L_5) 
;	dta a(L_6) 
	dta a(L_DUMMY) 
LoopsIndexEnd 

;-----------------			

;//---------------------------------------------------------------------------------------------

;* Intro subtunes index, this is the part of a tune that will play before a loop point 
;* If the intro and loop are identical, or close enough to sound seamless, the intro could be replaced by a dummy to save space
;* IMPORTANT: due to technical reasons, every indexes MUST end with a dummy subtune! Otherwise the entire thing will break apart!

;-----------------

;//---------------------------------------------------------------------------------------------

S_0
;	ins	'/RANDOM3/IO INTRO.lzss'  
S_1
;	ins	'/RANDOM3/01 - SKETCH_71_TUNE_1.lzss' 
S_2
		; dummy
S_3
		; dummy
S_4
;	ins	'/RANDOM3/04 - SKETCH_73.lzss'
S_5
;	ins	'/RANDOM3/SKETCH 76 INTRO.lzss'
S_6
		; dummy
S_DUMMY

;-----------------
		
;//---------------------------------------------------------------------------------------------

;* Looped subtunes index, if a dummy is inserted, the tune has a definite end and won't loop and/or fadeout!

L_0
;	ins	'/RANDOM3/IO LOOP.lzss'  
L_1
;	ins	'/RANDOM3/01 - SKETCH_71_TUNE_1_LOOP.lzss' 
L_2
;	ins 	'/RANDOM3/02 - SKETCH_71_TUNE_2_LOOP.lzss'
L_3
;	ins	'/RANDOM3/03 - SKETCH_72_LOOP.lzss'
L_4
;	ins	'/RANDOM3/04 - SKETCH_73_LOOP.lzss'
L_5
;	ins	'/RANDOM3/SKETCH 76 LOOP.lzss'
L_6
;	ins	'/RANDOM3/SKETCH 78 LOOP.lzss'
L_DUMMY 

;-----------------
		
;//--------------------------------------------------------------------------------------------- 

