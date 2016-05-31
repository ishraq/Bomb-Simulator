.dseg
speaker_what: .byte 1
speaker_len: .byte 2

.cseg
.macro speaker_init
    push tmp
    push zl
    push zh

    ldi tmp, 0b00000001

    out DDRB, tmp
    
    clr tmp
    sts speaker_what, tmp
    ldi zl, low(speaker_len)
    ldi zh, high(speaker_len)
    st z, tmp
    std z+1, tmp

    pop zh
    pop zl
    pop tmp
.endmacro

.macro speaker_speak
    push r24
    push r25
    push r18
    push zl
    push zh
    
    ldi zl, low(speaker_len)
    ldi zh, high(speaker_len)
    ld r24, z
    ldd r25, z+1
    clr r18
    cpi r24, 0
    cpc r25, r18
    breq speaker_speak_done
        sbiw r25:r24, 1
        st z, r24
        std z+1, r25

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

    pop zh
    pop zl
    pop r18
    pop r25
    pop r24
.endmacro

.macro speaker_set_len
    push tmp
    push zl
    push zh

    ldi zl, low(speaker_len)
    ldi zh, high(speaker_len)
    ldi tmp, low(@0)
    ;rcall set_led_reg
    st z, tmp
    ldi tmp, high(@0)
    std z+1, tmp

    pop zh
    pop zl
    pop tmp
.endmacro


