; read word from @2 to @0:@1
.macro read_word
	lds @1, @2
	lds @0, @2+1
.endmacro
; write word @1:@2 to @0
.macro write_word
	sts @0, @2
	sts @0+1, @1
.endmacro

; write word @1 to @0
.macro write_const_word
	push tmp_wordh
	push tmp_wordl
	ldi tmp_wordh, high(@1)
	ldi tmp_wordl, low(@1)
	write_word @0, tmp_wordh, tmp_wordl
	pop tmp_wordl
	pop tmp_wordh
.endmacro

; @0:@1 -= @2 (neither can be tmp/r16)
.macro subi_word
	push tmp
	clr tmp
	subi @1, @2
	sbc @0, tmp
	pop tmp
.endmacro

; @0:@1 -= 1 (neither can be tmp/r16)
.macro dec_word
	subi_word @0, @1, 1
.endmacro

; places string (@0) in program memory with correct padding
.macro defstring
	.if strlen(@0) & 1 ; odd length + null byte
		.db @0, 0
	.else ; even length + null byte, add padding byte
		.db @0, 0, 0
	.endif
.endmacro


.macro print_word
	push r16
	mov r16, r17
	rcall print_int
	pop r16
	do_lcd_data ' '
	rcall print_int
.endmacro
