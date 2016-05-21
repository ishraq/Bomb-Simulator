.include "m2560def.inc"

.def tmp = r16
.def do_display = r22 ; should screen be refreshed
.def stage = r23 ; what screen/stage it's at
.def tmp_wordl = r24
.def tmp_wordh = r25
.equ ticks_per_sec = 1000

.equ pot_eps = 5 ; pot reading < pot_eps is 0

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

pot_cd: .byte 2 ; overflows till pot is held for long enough
pot_targ: .byte 2 ; target for find pot

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
.include "pb-util.asm"
.include "print-string.asm"
.include "rand.asm"
.include "led-util.asm"
.include "pot-util.asm"
.include "motor-util.asm"
.include "keypad-util.asm"

; constants
start_str1: defstring "2121 16s1"
start_str2: defstring "Safe Cracker"

start_cd_str1: defstring "2121 16s1"
start_cd_str2: defstring "Starting in "
start_cd_str3: defstring "..."

reset_pot_str: defstring "Reset POT to 0"
find_pot_str: defstring "Find POT Pos"
remaining_str: defstring "Remaining: "

found_pot_str: defstring "Position found!"
scan_str: defstring "Scan for number"

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

	; setup portc (LEDs)
	ser tmp
	out ddrc, tmp ; all output
	
	; setup portg (2 high LEDs, AUDIO:ASD)
	ser tmp
	out ddrg, tmp

	; clear leds
	set_led 0

	; init pot by issuing request
	rcall pot_req

	; setup portd (PB0 and PB1)
    clr tmp
    out ddrd, tmp ; all input
    ser tmp
    out portd, tmp ; pull ups

	; init motor
	motor_init

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
			puts start_str1
			lcd_row2
			puts start_str2
		dont_display_start_screen:

		; check if continue to next screen
		ispb1
		brne dontstart
			; pressed pb1
			ldi stage, start_countdown ; next stage
			
			; init 3 second countdown
			ldi tmp, 3
			sts timer_cnt, tmp
			write_const_word timer_cd, ticks_per_sec
			
			ldi do_display, 1 ; should display
		dontstart:
		reti
	not_start_screen:

	ldi tmp, start_countdown
	cpse stage, tmp
	jmp not_start_countdown
		; start countdown

		; display
		cpi do_display, 1
		brne dont_display_start_cd
			clr do_display
			lcd_clear
			puts start_cd_str1
			lcd_row2
			puts start_cd_str2
			lds tmp, timer_cnt
			rcall print_int
			puts start_cd_str3
		dont_display_start_cd:

		; decrement timer countdown
		read_word tmp_wordh, tmp_wordl, timer_cd
		dec_word tmp_wordh, tmp_wordl
		write_word timer_cd, tmp_wordh, tmp_wordl
		brne fin_start_countdown
			ldi do_display, 1 ; activity occurs, need to refresh screen next cycle
		
			; timer countdown is 0, on to next second
			lds tmp, timer_cnt
			subi tmp, 1
			brne countdown_not_fin
				; countdown finished, on to next screen
				ldi stage, reset_pot

				; init diff_time second countdown
				lds tmp, diff_time
				sts timer_cnt, tmp
				write_const_word timer_cd, ticks_per_sec

				; init pot hold .5s countdown
				write_const_word pot_cd, ticks_per_sec/2

				ldi do_display, 1 ; should display
				rjmp fin_start_countdown
			countdown_not_fin:
			; timer second not 0, restart countdown
			sts timer_cnt, tmp
			write_const_word timer_cd, ticks_per_sec
		fin_start_countdown:
		reti
	not_start_countdown:

	cpi stage, find_pot+1
	brsh no_timeout_cd
		; reset pot or find pot screen
		; decrement timer countdown
		read_word tmp_wordh, tmp_wordl, timer_cd
		dec_word tmp_wordh, tmp_wordl
		write_word timer_cd, tmp_wordh, tmp_wordl
		brne no_timeout_cd
			ldi do_display, 1 ; activity occurs, need to refresh screen next cycle
			; timer countdown is 0, on to next second
			lds tmp, timer_cnt
			subi tmp, 1
			brne timeout_countdown_not_fin
				; countdown finished, TIMEOUT
				ldi stage, timeout
				set_led 0 ; clear led
				ldi do_display, 1 ; should display
				rjmp no_timeout_cd
			timeout_countdown_not_fin:
			; timer second not 0, restart countdown
			sts timer_cnt, tmp
			write_const_word timer_cd, ticks_per_sec
	no_timeout_cd:

	ldi tmp, reset_pot
	cpse stage, tmp
	jmp not_reset_pot
		; reset pot

		;display
		cpi do_display, 1
		brne dont_display_reset_pot
			clr do_display
			lcd_clear
			puts reset_pot_str
			lcd_row2
			puts remaining_str
			lds tmp, timer_cnt
			rcall print_int
		dont_display_reset_pot:

		; assume pot is at 0, if not when pot_read succeeds pot_cd will be reset to .5s
		read_word tmp_wordh, tmp_wordl, pot_cd
		dec_word tmp_wordh, tmp_wordl
		write_word pot_cd, tmp_wordh, tmp_wordl
		brne not_reset_pot_done
			; pot held at 0 for .5s
			; move to find pot screen
			ldi stage, find_pot

			; need to hold pot for 1s at correct reading
			write_const_word pot_cd, ticks_per_sec
			
			; init random value for find pot
			rcall rand
			andi tmp, 3 ; high byte of pot read only has 2 bits
			mov tmp_wordh, r16
			rcall rand
			mov tmp_wordl, r16

			write_word pot_targ, tmp_wordh, tmp_wordl

			ldi do_display, 1 ; should display
			rjmp done_reset_pot_read
		not_reset_pot_done:

		rcall pot_read ; see if pot reading available
		cpi r17, 0xff
		breq done_reset_pot_read
			; pot reading available
			ldi tmp_wordh, high(pot_eps)
			ldi tmp_wordl, low(pot_eps)
			cp r16, tmp_wordl
			cpc r17, tmp_wordh
			brlt done_reset_pot_read
				; pot is not 0
				write_const_word pot_cd, ticks_per_sec/2 ; need to hold pot for .5s at 0
		done_reset_pot_read:

		reti
	not_reset_pot:

	ldi tmp, find_pot
	cpse stage, tmp
	jmp not_find_pot
		; find pot

		; display
		cpi do_display, 1
		brne dont_display_find_pot
			clr do_display
			lcd_clear
			puts find_pot_str
			lcd_row2
			puts remaining_str
			lds tmp, timer_cnt
			rcall print_int
		dont_display_find_pot:

		; assume pot is at targ, if not when pot_read succeeds pot_cd will be reset to 1s
		read_word tmp_wordh, tmp_wordl, pot_cd
		dec_word tmp_wordh, tmp_wordl
		write_word pot_cd, tmp_wordh, tmp_wordl
		brne not_find_pot_done
			; pot held at targ for 1s
			; move to find code screen
			ldi stage, find_code

			; clear leds
			set_led 0

			; init random value for find code TODO			

			ldi do_display, 1 ; should display
			rjmp done_find_pot_read
		not_find_pot_done:

		rcall pot_read ; see if pot reading available
		cpi r17, 0xff
		brne pot_read_avail
		jmp done_find_pot_read
		pot_read_avail:
			; pot reading available
			read_word tmp_wordh, tmp_wordl, pot_targ

			adiw tmp_wordh:tmp_wordl, 1
			cp r16, tmp_wordl
			cpc r17, tmp_wordh
			brlt pot_not_over
				; pot >= target+1, go back to reset pot
				ldi stage, reset_pot
				; init pot hold .5s countdown
				write_const_word pot_cd, ticks_per_sec/2
				; clear leds
				set_led 0
				ldi do_display, 1 ; should display
				rjmp done_find_pot_read
			pot_not_over:

			subi_word tmp_wordh, tmp_wordl, 17
			cp r16, tmp_wordl
			cpc r17, tmp_wordh
			brlt pot_not_16
				; pot >= target-16 - all leds
				set_led 0b1000000000
				rjmp done_find_pot_read
			pot_not_16:

			; not within 16, reset hold timer
			write_const_word pot_cd, ticks_per_sec

			subi_word tmp_wordh, tmp_wordl, 16
			cp r16, tmp_wordl
			cpc r17, tmp_wordh
			brlt pot_not_32
				; pot >= target-32 - all but top leds
				set_led 0b0100000000
				rjmp done_find_pot_read
			pot_not_32:

			subi_word tmp_wordh, tmp_wordl, 16
			cp r16, tmp_wordl
			cpc r17, tmp_wordh
			brlt pot_not_48
				; pot >= target-48 - bottom 8 leds
				set_led 0b0010000000
				rjmp done_find_pot_read
			pot_not_48:

			; clear leds
			set_led 0
		done_find_pot_read:

		reti
	not_find_pot:

	cpi stage, find_code
	brne not_find_code
		; find code
		; display
		cpi do_display, 1
		brne dont_display_find_code
			clr do_display
			lcd_clear
			puts found_pot_str
			lcd_row2
			puts scan_str

			set_motor_speed 0x4A
		dont_display_find_code:
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
		lcd_clear
		do_lcd_data '&'
		reti
	not_timeout:
	
	; this is bad
	rcall rip
