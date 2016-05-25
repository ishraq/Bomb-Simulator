.macro motor_init
    push tmp
    ldi tmp, 0b00010000
    out DDRE, tmp
    clr tmp
    out PORTE, tmp
    pop tmp
.endmacro

; set motor speed to 0 or 1
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

