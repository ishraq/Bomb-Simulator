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

.macro print_tmp_word
	push r16
	mov r16, tmp_wordh
	rcall print_int
	mov r16, tmp_wordl
	do_lcd_data ' '
	rcall print_int
	pop r16
.endmacro

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
.equ DELAY_100NS = F_CPU / 4 / 10000 - 4
; 4 cycles per iteration - setup/call-return overhead
sleep_1ms:
    push r24
    push r25
    ldi r25, high(DELAY_1MS)
    ldi r24, low(DELAY_1MS)
delayloop_1ms:
    sbiw r25:r24, 1
    brne delayloop_1ms
    pop r25
    pop r24
    ret
sleep_5ms:
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    rcall sleep_1ms
    ret

sleep_100ns:
    push r24
    push r25
    ldi r25, high(DELAY_100NS)
    ldi r24, low(DELAY_100NS)
delayloop_100ns:
    sbiw r25:r24, 1
    brne delayloop_100ns
    pop r25
    pop r24
    ret
