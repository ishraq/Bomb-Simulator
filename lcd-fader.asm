.def is_lcd_off = r2

.cseg

.macro lcd_fade_init
    push tmp
	ldi tmp, 0xff ; init full on
    sts OCR1AH, tmp
    sts OCR1AL, tmp

	ldi tmp, 0
	mov is_lcd_off, tmp ; not off

	ldi tmp, 0b00000010
    sts TCCR1B, tmp
    ldi tmp, 0b00000000
    sts TCCR1A, tmp
	ldi tmp, (1<<toie1) | (1<<ocie1a)
	sts timsk1, tmp
	pop tmp
.endmacro

; sets lcd "brightness" level given by r16 (0 full , 0xff full on)
; if level is < 5 then we use a flag to disable the lcd
; as for low values it is not guaranteed the overflow interrupt will
; occur before the compare interrupt
set_lcd_level:
	push tmp
	cpi tmp, 5
	brsh use_cmp_val
		; just use flag
		ldi tmp, 1
		mov is_lcd_off, tmp
		pop tmp
		ret
	use_cmp_val:
		; use cmp interrupt
		sts ocr1ah, tmp
		ldi tmp, 0xff
		sts ocr1al, tmp
		ldi tmp, 0
		mov is_lcd_off, tmp ; not off
		pop tmp
		ret

oc1Ahandler:
	lcd_off
	reti

ovf1handler:
	push tmp
	ldi tmp, 1
	cp is_lcd_off, tmp
	breq dont_turn_lcd_on
		lcd_on
	dont_turn_lcd_on:
	pop tmp
	reti
