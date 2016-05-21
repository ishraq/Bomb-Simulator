.cseg
; write low 10 bits of @0 to leds (1 is on, 0 is off)
.macro set_led
	push tmp
	push r17

	ldi r16, low(@0)
	ldi r17, high(@0)
	rcall set_led_reg

	pop r17
	pop tmp
.endmacro

; set led to r17:r16
set_led_reg:
	push tmp

	; write to leds
	out portc, tmp ; low 8 bits
	in tmp, portg
	andi tmp, ~0b11 ; clear the 2 leds
	or tmp, r17 ; set to new values
	out portg, tmp

	pop tmp
	ret
