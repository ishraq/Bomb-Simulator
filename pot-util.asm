.dseg
pot: .byte 2 ; potentiometer val
potav: .byte 1 ; bool is there a new pot val

; everything's fucked TODO REMOVE THIS

.cseg
; request pot read
pot_req:
	push tmp

	clr tmp
	sts potav, tmp ; no read available

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
		; new pot reading avail
		clr tmp
		sts potav, tmp
		read_word r17, r16, pot
		rcall pot_req ; ask for another pot reading
		ret
	nopot:
	ldi r16, 0xff
	ldi r17, 0xff
	ret

pot_handler:
	push tmp
	push r17

	ldi tmp, 1
	sts potav, tmp ; read available

	lds tmp, adcl
	lds r17, adch
	sts pot, tmp
	sts pot+1, r17

	pop r17
	pop tmp
	reti
