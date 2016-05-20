.include "m2560def.inc"

.def tmp = r16
.def do_display = r24 ; should screen be refreshed
.def stage = r23 ; what screen/stage it's at
.def tmp_wordl = r24
.def tmp_wordh = r25
.equ ticks_per_sec = 1000

.equ start_screen = 0
.equ start_countdown = 1
.equ reset_pot = 2
.equ find_pot = 3
.equ find_code = 4
.equ enter_code = 5
.equ game_complete = 6
.equ timeout = 7

; initialise timer_cd to be a 1 second timer
.macro init_timer_cd_1s
	ldi r17, high(ticks_per_sec)
	ldi r16, low(ticks_per_sec)
	write_word timer_cd, r17, r16
.endmacro

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
.include "pb-util.asm"

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

	;setup portd (PB0 and PB1)
    clr tmp
    out ddrd, tmp ; input port
    ser tmp
    out portd, tmp ; pull ups

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
	ldi do_display, 1 ; should display

	sei
	rjmp main

main:
	sleep
	rjmp main

ovf0handler:
	cpi stage, start_screen
	brne not_start_screen
		; start screen

		; display
		cpi do_display, 1
		brne dont_display_start_screen
			clr do_display
			lcd_clear
			do_lcd_data '0'
		dont_display_start_screen:

		; check if continue to next screen
		ispb1
		brne dontstart
			; pressed pb1
			ldi stage, start_countdown ; next stage
			
			; init 3 second countdown
			ldi tmp, 3
			sts timer_cnt, tmp
			init_timer_cd_1s
			
			ldi do_display, 1 ; should display
		dontstart:
		reti
	not_start_screen:

	ldi tmp, start_countdown
	cpse stage, tmp
	jmp not_start_countdown
		; start countdown
		; display screen
		; display
		cpi do_display, 1
		brne dont_display_start_cd
			clr do_display
			lcd_clear
			do_lcd_data '1'
			lcd_row2
			lds tmp, timer_cnt
			rcall print_int
		dont_display_start_cd:

		; decrement timer countdown
		read_word tmp_wordh, tmp_wordl, timer_cd
		dec_word tmp_wordh, tmp_wordl
		write_word timer_cd, tmp_wordh, tmp_wordl
		brne fin_start_countdown
			ldi do_display, 1 ; activity occurs, need to refresh screen next cycle
			; timer countdown is 0, on to next second
			lds tmp, timer_cnt
			cpi tmp, 0
			brne countdown_not_fin
				; countdown finished, on to next screen
				ldi stage, reset_pot

				; init diff_time second countdown
				lds tmp, diff_time
				sts timer_cnt, tmp
				init_timer_cd_1s
				rjmp fin_start_countdown
			
			countdown_not_fin:
			; timer second not 0, second--, restart countdown
			dec tmp
			sts timer_cnt, tmp
			init_timer_cd_1s
		fin_start_countdown:
		reti
	not_start_countdown:

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
