.include "m2560def.inc"

.def timer0_parity = r11  ; flips between 0 and 1 every timer0 oflow
.def fade_dir = r12		  ; delta to brightness every second timer0 oflow (-1, 0, 1) (restuls in a fade over 512 oflows ~= .5 seconds)
.def lcd_brightness = r13 ; lcd brightness
.def cur_code_char = r14 ; which character is being entered in the Enter Code screen
.def game_iter = r15 ; how many games have been won so far in current round
.def tmp = r16
.def do_display = r22 ; should screen be refreshed
.def stage = r23 ; what screen/stage it's at
.def tmp_wordl = r24
.def tmp_wordh = r25

.equ ticks_per_sec = 1000 ; oflows of timer0 in 1 sec
.equ lcd_fade_time = 5*ticks_per_sec ; oflows till lcd starts turning off

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
diff_level: .byte 1 ; difficulty level as a character

timer_cd: .byte 2 ; overflows till next second completed on timer
timer_cnt: .byte 1 ; seconds left on timer

pot_cd: .byte 2 ; overflows till pot is held for long enough
pot_targ: .byte 2 ; target for find pot

key_targ: .byte 1 ; target for find code
key_cd: .byte 2 ; overflows till key is held for long enough

key_code: .byte 3 ; the 3 letter code

strobe_cd: .byte 1 ; the countdown to toggle the strobe

lcd_off_cd: .byte 2 ; the countdown to begin turning off the lcd

random_timer: .byte 1 ; a basically random value

.cseg
.org 0x00 ; reset interrupt
	rjmp reset
.org ovf0addr
	rjmp ovf0handler ; timer0 oflow
.org ovf1addr
	rjmp ovf1handler ; timer1 oflow
.org oc1Aaddr
	rjmp oc1ahandler ; timer1 compare match
.org ADCCaddr
	rjmp pot_handler ; ADC read complete interrupt

; utilities
.include "util.asm"
.include "lcd-util.asm"
.include "pb-util.asm"
.include "print-string.asm"
.include "rand.asm"
.include "led-util.asm"
.include "pot-util.asm"
.include "motor-util.asm"
.include "keypad-util.asm"
.include "lcd-fader.asm"
.include "speaker-util.asm"

; re-enter cseg after includes
.cseg

; constants
start_str1: defstring "2121 16s1"
start_str2: defstring "Safe Cracker"

diff_strA: defstring " (A)"
diff_strB: defstring " (B)"
diff_strC: defstring " (C)"
diff_strD: defstring " (D)"

start_cd_str1: defstring "2121 16s1"
start_cd_str2: defstring "Starting in "
start_cd_str3: defstring "..."

reset_pot_str: defstring "Reset POT to 0"
find_pot_str: defstring "Find POT Pos"
remaining_str: defstring "Remaining: "

found_pot_str: defstring "Position found!"
scan_str: defstring "Scan for number"

enter_code_str: defstring "Enter Code"

game_complete_str: defstring "Game complete"
win_str: defstring "You Win!"

game_over_str: defstring "Game over"
lose_str: defstring "You Lose!"

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
	
	; init lcd (also sets the strobe light pin (A2) as output)
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

	; init keypad
	keypad_init

	; init lcd fade
	lcd_fade_init
	write_const_word lcd_off_cd, lcd_fade_time
	ldi tmp, 0xff
	mov lcd_brightness, tmp
	clr fade_dir

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
	ldi tmp, 'A' ; default difficulty level char
	sts diff_level, tmp
	ldi do_display, 1 ; should display

	; init speaker
	speaker_init

	sei
	rjmp main

main:
	sleep
	rjmp main

restart:
	cli ; disable interrupts
	rjmp reset

ovf0handler:
	ldi tmp, 1
	eor timer0_parity, tmp ; flip parity

	; make sound
	speaker_speak

	; update random timer
	lds tmp, random_timer
	inc tmp
	sts random_timer, tmp

	ispb0
	brne dont_restart_pb0
		rcall restart ; restart if pb0 pressed
	dont_restart_pb0:

	; lcd fade handling
	cpi stage, start_screen
	breq fade_proc
	cpi stage, game_complete
	breq fade_proc
	cpi stage, timeout
	breq fade_proc
		; not a screen which supports fading, set screen to full on and fade_dir = 0
		ldi tmp, 0xff
		mov lcd_brightness, tmp
		clr fade_dir
		write_const_word lcd_off_cd, lcd_fade_time
	fade_proc:
		; need to handle fade logic
		read_word tmp_wordh, tmp_wordl, lcd_off_cd
		rcall is_any_keys
		brne dont_reset_lcd_off_cd
			; something is pressed so reset lcd off cd and set fade dir to +1
			ldi tmp_wordh, high(lcd_fade_time)
			ldi tmp_wordl, low(lcd_fade_time)
			ldi tmp, 1
			mov fade_dir, tmp
			rjmp end_fade_proc
		dont_reset_lcd_off_cd:

		clr tmp
		cp tmp_wordl, tmp
		cpc tmp_wordh, tmp
		brne not_lcd_fading
			; cd is 0, set dir to -1
			ldi tmp, -1
			mov fade_dir, tmp
			rjmp end_fade_proc
		not_lcd_fading:
			; cd not 0, decrement cd
			dec_word tmp_wordh, tmp_wordl
	end_fade_proc:
	write_word lcd_off_cd, tmp_wordh, tmp_wordl

	clr tmp
	cp timer0_parity, tmp
	brne dont_delta_brightness
		ldi tmp, 1
		cp fade_dir, tmp
		ldi tmp, 0xff
		cpc lcd_brightness, tmp
		breq dont_delta_brightness ; don't +1 when max brightness

		ldi tmp, -1
		cp fade_dir, tmp
		ldi tmp, 0
		cpc lcd_brightness, tmp
		breq dont_delta_brightness ; don't -1 when min brightness

		add lcd_brightness, fade_dir ; add delta to brightness
	dont_delta_brightness:

	mov tmp, lcd_brightness
	;rcall print_int
	rcall set_lcd_level

	cpi stage, start_screen
	breq dont_jmp_not_start_screen
		jmp not_start_screen
	dont_jmp_not_start_screen:
		; start screen

		; display
		cpi do_display, 1
		brne dont_display_start_screen
			clr do_display
			lcd_clear
			puts start_str1
			lcd_row2
			puts start_str2
			
			; display difficulty level
			lds tmp, diff_level
			cpi tmp, 'A'
			brne print_diff_isnt_A
				puts diff_strA
			print_diff_isnt_A:
			cpi tmp, 'B'
			brne print_diff_isnt_B
				puts diff_strB
			print_diff_isnt_B:
			cpi tmp, 'C'
			brne print_diff_isnt_C
				puts diff_strC
			print_diff_isnt_C:
			cpi tmp, 'D'
			brne print_diff_isnt_D
				puts diff_strD
			print_diff_isnt_D:
		dont_display_start_screen:

		; set difficulty
		rcall read_key_db
		cpi tmp, 'A'
		brlt dont_set_difficulty
		cpi tmp, 'D'+1
		brge dont_set_difficulty
			; do display
			ldi do_display, 1

			; set difficulty level character
			sts diff_level, tmp

			; set difficulty time
			cpi tmp, 'A'
			brne set_diff_isnt_A
				ldi tmp, 20
				sts diff_time, tmp
				rjmp set_diff_done
			set_diff_isnt_A:
			cpi tmp, 'B'
			brne set_diff_isnt_B
				ldi tmp, 15
				sts diff_time, tmp
				rjmp set_diff_done
			set_diff_isnt_B:
			cpi tmp, 'C'
			brne set_diff_isnt_C
				ldi tmp, 10
				sts diff_time, tmp
				rjmp set_diff_done
			set_diff_isnt_C:
			cpi tmp, 'D'
			brne set_diff_isnt_D
				ldi tmp, 6
				sts diff_time, tmp
				rjmp set_diff_done
			set_diff_isnt_D:
			set_diff_done:
		dont_set_difficulty:

		; check if continue to next screen
		ispb1
		brne dontstart
			; pressed pb1
			ldi stage, start_countdown ; next stage

			; beep for 250ms
			speaker_set_len ticks_per_sec/4

			; seed random
			lds tmp, random_timer
			srand
			
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
		breq skip_fin_start_countdown
			jmp fin_start_countdown
		skip_fin_start_countdown:
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

				; beep for 500ms
				speaker_set_len ticks_per_sec/2

				ldi do_display, 1 ; should display
				rjmp fin_start_countdown
			countdown_not_fin:
				; timer second not 0, restart countdown
				sts timer_cnt, tmp
				write_const_word timer_cd, ticks_per_sec

				; beep for 250ms
				speaker_set_len ticks_per_sec/4
		fin_start_countdown:
		reti
	not_start_countdown:

	cpi stage, find_pot+1
	brlo no_jmp_to_no_timeout_cd
		jmp no_timeout_cd
	no_jmp_to_no_timeout_cd:
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
				
				; beep for 500ms
				speaker_set_len ticks_per_sec/2
			timeout_countdown_not_fin:
				; timer second not 0, restart countdown
				sts timer_cnt, tmp
				write_const_word timer_cd, ticks_per_sec

				; beep for 250ms
				speaker_set_len ticks_per_sec/4
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

			; init random value for find code
			rcall rand_char
			sts key_targ, tmp
			
			; key must be held for 1s to complete stage
			write_const_word key_cd, ticks_per_sec

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

			subi_word tmp_wordh, tmp_wordl, 33 ; should be 17 and change the 3 bitmasks below
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

	ldi tmp, find_code
	cpse stage, tmp
	jmp not_find_code
		; find code

		; display
		cpi do_display, 1
		brne dont_display_find_code
			clr do_display
			lcd_clear
			puts found_pot_str
			lcd_row2
			puts scan_str
		dont_display_find_code:

		rcall read_key
		lds r17, key_targ
		cpse r16, r17
		jmp not_correct_key
			; correct key pressed
			set_motor_speed 0x4A
			read_word tmp_wordh, tmp_wordl, key_cd
			dec_word tmp_wordh, tmp_wordl
			write_word key_cd, tmp_wordh, tmp_wordl
			breq key_held_1s
			jmp done_check_key
			key_held_1s:
				; correct key held for 1s
				set_motor_speed 0 ; turn off motor

				; add character to key_code
				ldi xl, low(key_code)
				ldi xh, high(key_code)
				add xl, game_iter
				clr tmp
				adc xh, tmp
				st x, r17
				
				; beep for 500ms
				speaker_set_len ticks_per_sec/2

				inc game_iter
				ldi tmp, 3
				cp game_iter, tmp
				brne next_game_iter
					; finished 3 games, go to enter code
					ldi stage, enter_code
					clr cur_code_char
					ldi do_display, 1
					rjmp done_check_key
				next_game_iter:
					; back to reset pot for next round
					ldi stage, reset_pot

					; init diff_time second countdown
					lds tmp, diff_time
					sts timer_cnt, tmp
					write_const_word timer_cd, ticks_per_sec

					; init pot hold .5s countdown
					write_const_word pot_cd, ticks_per_sec/2

					ldi do_display, 1 ; should display
					rjmp done_check_key
		not_correct_key:
			; incorrect/no key pressed
			set_motor_speed 0x00
			write_const_word key_cd, ticks_per_sec ; must hold key for 1s to complete
		done_check_key:

		reti
	not_find_code:

	cpi stage, enter_code
	brne not_enter_code
		; enter code

		; display
		cpi do_display, 1
		brne dont_display_enter_code
			clr do_display
			lcd_clear
			puts enter_code_str
			lcd_row2
			mov tmp, cur_code_char
			print_asterisks:
				cpi tmp, 0
				breq dont_display_enter_code
				do_lcd_data '*'
				dec tmp
				rjmp print_asterisks
		dont_display_enter_code:
		
		rcall read_key_db
		cpi tmp, '?'
		breq no_code_char
			; event occured, need to display next cycle
			ldi do_display, 1

			ldi xl, low(key_code)
			ldi xh, high(key_code)
			add xl, cur_code_char
			clr r17
			adc xh, r17
			ld r17, x

			cp tmp, r17
			brne wrong_char
				; correct char
				inc cur_code_char
				ldi tmp, 3
				cp cur_code_char, tmp
				brne no_code_char
					; entered full code correctly
					ldi stage, game_complete
					rjmp no_code_char
			wrong_char:
				; wrong char, reset entered char count
				clr cur_code_char
		no_code_char:
		reti
	not_enter_code:

	; on an end screen, handle restart conditions
	ispb1
	brne dont_restart_pb1
		rcall restart ; restart if pb1 pressed
	dont_restart_pb1:
	rcall read_key_db
	ldi r17, '?'
	cpse tmp, r17
		rcall restart ; restart if key pressed

	cpi stage, game_complete
	brne not_game_complete
		; game complete

		; display
		cpi do_display, 1
		brne dont_display_game_complete
			clr do_display
			lcd_clear
			puts game_complete_str
			lcd_row2
			puts win_str
			
			; beep for 1 second
			speaker_set_len ticks_per_sec
		dont_display_game_complete:

		lds tmp, strobe_cd
		cpi tmp, 0
		brne dont_toggle
			; toggle the state of the strobe led
			in tmp, porta
			ldi r17, 1<<1 ; strobe bit
			eor tmp, r17 ; toggle bit
			out porta, tmp

			; reinit countdown
			ldi tmp, ticks_per_sec/4 ; 4 toggles a second <=> 2 cycles a second <=> flash at 2Hz
			sts strobe_cd, tmp
		dont_toggle:
		dec tmp
		sts strobe_cd, tmp
		reti
	not_game_complete:

	cpi stage, timeout
	brne not_timeout
		; timeout

		; display
		cpi do_display, 1
		brne dont_display_timeout
			clr do_display
			lcd_clear
			puts game_over_str
			lcd_row2
			puts lose_str

			; beep for 1 second
			speaker_set_len ticks_per_sec
		dont_display_timeout:
		reti
		
		
	not_timeout:
	
	; this is bad
	rcall rip

