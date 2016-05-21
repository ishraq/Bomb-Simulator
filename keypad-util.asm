.dseg
pressed_char: .byte 1
key_db: .byte 1 ; how many read_char_dbs which are != pressed_char till debounce is over

.equ key_db_val = 20 ; initialisation value for key_db

.cseg

.def pchar = r17
.def rwmsk = r18
.def clmsk = r19
.def mx = r20
.def my = r21

; init keypad
.macro keypad_init
	push tmp
    ldi tmp, 0b00001111 ; half input, half output
    sts ddrl, tmp
    ldi tmp, 0b11110000 ; pullups
    sts portl, tmp
	clr tmp
	sts pressed_char, tmp
	sts key_db, tmp
	pop tmp
.endmacro

; return character pressed in r16 (? if none pressed)
read_key:
	push pchar
	push rwmsk
	push clmsk
	push mx
	push my

    ldi pchar, '?'
    clr my
    ldi rwmsk, 1
    yloop:
        com rwmsk
        sts portl, rwmsk
        rcall sleep_100ns ; wait for keypad to respond to new rwmsk
        lds clmsk, pinl
        com clmsk
        andi clmsk, 0xF0
        com rwmsk
        clr mx
        xloop:
            mov tmp, clmsk
            andi tmp, 0x10
            breq notpress ; detect button pressed, store character in pchar (only works for digits)
				; convert my,mx -> char
                cpi mx, 3
                brne notletter
                    mov pchar, my
                    subi pchar, -'A'
                    rjmp endgl
                notletter:
                cpi my, 3
                brne not0
                    cpi mx, 0
                    brne notstar
                    ldi pchar, '*'
                    notstar:
                    cpi mx, 1
                    brne notzero
                    ldi pchar, '0'
                    notzero:
                    cpi mx, 2
                    brne nothash
                    ldi pchar, '#'
                    nothash:
                    rjmp endgl
                not0:
                    mov pchar, my
                    add pchar, my
                    add pchar, my
                    add pchar, mx
                    inc pchar
                    subi pchar, -'0'
                endgl:
            notpress:
            lsr clmsk
            inc mx
            cpi mx, 4
            brne xloop
        lsl rwmsk
        inc my
        cpi my, 4
        brne yloop
	mov r16, pchar ; return value
	pop my
	pop mx
	pop clmsk
	pop rwmsk
	pop pchar
	ret

; debounced read key (? if none pressed)
read_key_db:
	push r17
	push r18

	rcall read_key ; get the pressed char
	lds r17, key_db
	cpi r17, 0
	breq fin_debounce
		; need to debounce
		lds r18, pressed_char
		cpse r18, tmp
		dec r17 ; different to last ret, debounce cnt--
		sts key_db, r17
		ldi tmp, '?'
		rjmp done_read_db
	fin_debounce:
		; no debounce, we can return the pressed char
		cpi tmp, '?'
		breq done_read_db
			; non ? character, need to reinit debounce
			sts pressed_char, tmp
			ldi r17, key_db_val
			sts key_db, r17
	done_read_db:

	pop r18
	pop r17
	ret
