.macro do_lcd_command
    push r16
	ldi r16, @0
    rcall lcd_command
    rcall lcd_wait
	pop r16
.endmacro
.macro do_lcd_data_r16
    push r16
    push r24
    push r25
    rcall lcd_data
    rcall lcd_wait
    pop r25
    pop r24
    pop r16
.endmacro
.macro do_lcd_data
    push r16
    ldi r16, @0
    do_lcd_data_r16
    pop r16
.endmacro
.macro lcd_row2
	do_lcd_command 0b11000000
.endmacro
.macro lcd_clear
 	do_lcd_command 0b00000001
.endmacro

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4
.macro lcd_set
    sbi PORTA, @0
.endmacro
.macro lcd_clr
    cbi PORTA, @0
.endmacro
.macro lcd_init
    push r16
	ser r16
    out DDRF, r16
    out DDRA, r16
    clr r16
    out PORTF, r16
    out PORTA, r16
    do_lcd_command 0b00111000 ; 2x5x7
    rcall sleep_5ms
    do_lcd_command 0b00111000 ; 2x5x7
    rcall sleep_1ms
    do_lcd_command 0b00111000 ; 2x5x7
    do_lcd_command 0b00111000 ; 2x5x7
    do_lcd_command 0b00001000 ; display off?
    do_lcd_command 0b00000001 ; clear display
    do_lcd_command 0b00000110 ; increment, no display shift
    do_lcd_command 0b00001100 ; Cursor on, bar, no blink
    pop r16
.endmacro

rip:
	lcd_clear
	do_lcd_command '*'
	riphalt: rjmp riphalt

;print r16  
print_int:
    push r16
    push r17
    push r18
    push r19
	push r0
	push r1
    clr r19
    mov r18, r16
	;hundreds
    ldi r17, 100
    rcall divide
    cpi r16, 0
    breq hundone
        ser r19
        subi r16, -'0'
        do_lcd_data_r16
        subi r16, '0'
        ;remove hundreds
        mul r16, r17
        mov r16, r0
        sub r18, r16
    hundone:
    
    mov r16, r18
    ldi r17, 10
    rcall divide
    cpi r16, 0
    breq notens
        ser r19
    notens:
    cpi r19, 0xff
    brne tendone
        subi r16, -'0'
        do_lcd_data_r16
        subi r16, '0'
        ;remove tens
        mul r16, r17
        mov r16, r0
        sub r18, r16
    tendone:
    mov r16, r18
    subi r16, -'0'
    do_lcd_data_r16
	pop r1
	pop r0
    pop r19
    pop r18
    pop r17
    pop r16
    ret

; divides r16 by r17
divide:
    push r17
    push r18
    cpi r17, 0
    brne doDivide
        rjmp divideDone
    doDivide:
    ldi r18, 0
    divideLoop:
        cp r16, r17
        brlo divideLoopDone
        sub r16, r17
        inc r18
        rjmp divideLoop
    divideLoopDone:
    mov r16, r18
    divideDone:
    pop r18
    pop r17
    ret

; Send a command to the LCD (r16)
lcd_command:
    out PORTF, r16
    rcall sleep_1ms
    lcd_set LCD_E
    rcall sleep_1ms
    lcd_clr LCD_E
    rcall sleep_1ms
    ret
lcd_data:
    out PORTF, r16
    lcd_set LCD_RS
    rcall sleep_1ms
    lcd_set LCD_E
    rcall sleep_1ms
    lcd_clr LCD_E
    rcall sleep_1ms
    lcd_clr LCD_RS
    ret
lcd_wait:
    push r16
    clr r16
    out DDRF, r16
    out PORTF, r16
    lcd_set LCD_RW
lcd_wait_loop:
    rcall sleep_1ms
    lcd_set LCD_E
    rcall sleep_1ms
    in r16, PINF
    lcd_clr LCD_E
    sbrc r16, 7
    rjmp lcd_wait_loop
    lcd_clr LCD_RW
    ser r16
    out DDRF, r16
    pop r16
    ret
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
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
