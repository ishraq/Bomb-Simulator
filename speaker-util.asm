.dseg
speaker_what: .byte 1
speaker_len: .byte 2

.cseg
.macro speaker_init
	push tmp

	ldi tmp, 0b00000001
    out DDRB, tmp
	
	clr tmp
	sts speaker_what, tmp
	sts speaker_len, tmp
	sts speaker_len + 1, tmp

	pop tmp
.endmacro

.macro speaker_speak
	push r24
	push r25
	push r18
	
	lds r24, speaker_len
	lds r25, speaker_len + 1
	clr r18
	cpi r24, 0
	cpc r25, r18
	breq speaker_speak_done
		sbiw r25:r24, 1
		sts speaker_len, r24
		sts speaker_len + 1, r25

		lds r24, speaker_what
		cpi r24, 0
		breq speaker_speak_zero
			ldi r24, 0
			rjmp speaker_speak_end
		speaker_speak_zero:
			ldi r24, 1
		speaker_speak_end:
		out PORTB, r24
		sts speaker_what, r24
	speaker_speak_done:

	pop r18
	pop r25
	pop r24
.endmacro

.macro speaker_set_len
	push tmp

	ldi tmp, low(@0)
	sts speaker_len, tmp
	ldi tmp, high(@0)
	sts speaker_len + 1, tmp

	pop tmp
.endmacro


