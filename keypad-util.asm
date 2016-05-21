.cseg

.def pchar = r17
.def rwmsk = r18
.def clmsk = r19
.def mx = r20
.def my = r21

; return character pressed in r16
read_key:
	push tmp
	push rwmsk
	push clmsk
	push mx
	push my

    ldi pchar, -1
    clr my
    ldi rwmsk, 1
    yloop:
        com rwmsk
        sts portl, rwmsk
        rcall sleep_1ms
        lds clmsk, pinl
        com clmsk
        andi clmsk, 0xF0
        com rwmsk
        clr mx
        xloop:
            mov tmp, clmsk
            andi tmp, 0x10
            breq notpress ; detect button pressed, store character in pchar (only works for digits)
                ;out portc, rwmsk
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
	pop my
	pop mx
	pop clmsk
	pop rwmsk
	pop tmp
