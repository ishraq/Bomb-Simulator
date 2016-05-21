.macro motor_init
    push tmp
	ldi tmp, 0b00010000
    out DDRE, tmp ; Bit 2 will function as OC3B.
    clr tmp
    sts OCR3BH, tmp
    sts OCR3BL, tmp; ; initially off
    ; Set the Timer3 to Phase Correct PWM mode.
    ldi tmp, (1 << CS30)
    sts TCCR3B, tmp
    ldi tmp, (1<< WGM30)|(1<<COM3B1)
    sts TCCR3A, tmp
	pop tmp
.endmacro

; set motor speed to value in 0..0xff
; by setting pwm duty cycle on ocr3b
.macro set_motor_speed
	push tmp
	push r17

	;clr tmp
	;ldi r17, @0

    ;sts OCR3BH, tmp
    ;sts OCR3BL, r17

	; TODO: motor is screwed so we just use the leds for now
	set_led @0

	pop r17
	pop tmp
.endmacro
