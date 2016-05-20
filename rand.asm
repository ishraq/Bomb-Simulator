
; numbers from https://en.wikipedia.org/wiki/Linear_congruential_generator

.equ rand_multiplier = low(lwrd(22695477))
.equ rand_increment = low(lwrd(1))

.dseg
rand_cur: .byte 1

.cseg
;returns a random 8-bit integer in r16
rand:
    ;pre
    push r17
    push xl
    push xh
    push r0
    push r1

    ldi xl, low(rand_cur)
    ldi xh, high(rand_cur)

    ld r16, x
    ldi r17, rand_multiplier
    mul r16, r17
    mov r16, r0
    subi r16, -rand_increment
    st x, r16

    ;post
    pop r1
    pop r0
    pop xh
    pop xl
    pop r17

    ret
    

