.cseg
;takes in address to program memory in r17:r16
;prints string to lcd
print_string:
    ;pre
    push r16
    push zl
    push zh
    
    mov zl, r16
    mov zh, r17

    print_string_loop:
        lpm r16, z+
        cpi r16, 0
        breq print_string_loop_end
        do_lcd_data_r16
        rjmp print_string_loop
    print_string_loop_end:
            
    ;post
    pop zh
    pop zl
    pop r16

    ret
