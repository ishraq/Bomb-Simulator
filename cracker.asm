.include "m2560def.inc"

.def tmp = r16
.def stage = r2 ; what screen/stage it's at
.equ ticks_per_sec = 1000

.equ start_screen = 0
.equ start_countdown = 1
.equ reset_pot = 2
.equ find_pot = 3
.equ find_code = 4
.equ enter_code = 5
.equ game_complete = 6
.equ timeout = 7

.dseg
diff_time: .byte 1 ; num seconds on current difficulty timer

timer_cd: .byte 2 ; overflows till next second completed on timer
timer_cnt: .byte 1 ; seconds left on timer

.cseg
.org 0x00 ; reset interrupt
	rjmp reset
.org ovf0addr
	rjmp ovf0handler ; timer0 oflow
.org 0x3A ; ADC read complete interrupt
	rjmp pot_handler

; utilities
.include "lcd-util.asm"
.include "util.asm"
.include "pot-util.asm"

reset:
	; clear all registers
	clr zh
	clr zl
	clr yh
	clrreg:
		st z+, yh
		cpi zl, 29
		brne clrreg
	clr zl

	; init stack
	ldi tmp, high(ramend)
	out sph, tmp
	ldi tmp, low(ramend)
	out spl, tmp
	
	; init lcd
	lcd_init

	; init timer0
    ldi tmp, 0b00000000
    out tccr0a, tmp
    ldi tmp, 0b00000011 ;prescaling by 64
    out tccr0b, tmp
    ldi tmp, 1<<toie0
    sts timsk0, tmp

	; initially at start game screen
	ldi stage, start_screen
	ldi tmp, 20 ; default difficulty (easy)
	sts diff_time, tmp

	sei
	rjmp main

main:
	sleep
	rjmp main

ovf0handler:
	cpi stage, start_screen
	brne not_start_screen
		; display screen
		lcd_clear
		do_lcd_command '0'

		; start screen
		ispb1
		brne dontstart
			; pressed pb1
			ldi stage, reset_pot
			lds tmp, diff_time
			sts timer_cnt
		reti
	not_start_screen:

	cpi stage, reset_pot
	brne not_reset_pot
		; reset pot
		reti
	not_reset_pot:

	cpi stage, find_pot
	brne not_find_pot
		; find pot
		reti
	not_find_pot:

	cpi stage, find_code
	brne not_find_code
		; find code
		reti
	not_find_code:

	cpi stage, enter_code
	brne not_enter_code
		; enter code
		reti
	not_enter_code:

	cpi stage, game_complete
	brne not_game_complete
		; game complete
		reti
	not_game_complete:

	cpi stage, timeout
	brne not_timeout
		; timeout
		reti
	not_timeout:
	
	; this is bad
	rcall rip
