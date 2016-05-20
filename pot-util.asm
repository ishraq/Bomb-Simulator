.dseg
pot: .byte 2 ; potentiometer val
potav: .byte 1 ; bool is there a new pot val

.cseg
; request pot read
pot_req:
	push tmp
	clr tmp
	sts potav, tmp
	ldi tmp, (3 << REFS0) | (0 << ADLAR) | (0 << MUX0)
	sts ADMUX, tmp
	ldi tmp, (1 << MUX5)
	sts ADCSRB, tmp
	ldi tmp, (1 << ADEN) | (1 << ADSC) | (1 << ADIE) | (5 << ADPS0)
	sts ADCSRA, tmp
	pop tmp
	ret

; r17:r16 is pot lev if available
; otherwise r17:r16 = 0xffff
pot_read:
	lds tmp, potav
	cpi tmp, 0
	breq nopot
		clr tmp
		sts potav, tmp
		readword r17, r16, pot
		ret
	nopot:
	ldi r16, 0xff
	ldi r17, 0xff
	ret

pot_handler:
	push tmp

	ldi tmp, 1
	sts potav, tmp

	lds tmp, adcl
	sts pot, tmp
	lds tmp, adch
	sts pot+1, tmp

	pop tmp
	reti
