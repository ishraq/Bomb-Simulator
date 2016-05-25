.macro motor_init
    push tmp
    ldi tmp, 0b00010000
    out DDRE, tmp ; Bit 2 will function as OC3B.
    clr tmp
    out PORTE, tmp
    pop tmp
.endmacro

; set motor speed to value in 0..0xff
; by setting pwm duty cycle on ocr3b
.macro set_motor_speed
    push tmp
    push r17

    ;set motor
    ldi r17, @0
    cpi r17, 0
    breq set_motor_speed_done
        ldi r17, 0b00010000
    set_motor_speed_done:
    out PORTE, r17

    pop r17
    pop tmp
.endmacro

