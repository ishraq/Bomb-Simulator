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
; @0:@1 -- (neither can be tmp/r16)
.macro dec_word
	push tmp
	clr tmp
	subi @1, 1
	sbc @0, tmp
	pop tmp
.endmacro
