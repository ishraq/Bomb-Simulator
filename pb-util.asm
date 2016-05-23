.cseg
; Z flag set iff pressed for ispb0 and ispb1 respectively
.macro ispb0
	in tmp, pind
	andi tmp, 1<<0
.endmacro
.macro ispb1
	in tmp, pind
	andi tmp, 1<<1
.endmacro

; Z flag set iff pb1 or keypad pressed
is_any_keys:
	push tmp

	ispb1
	breq return_key_press ; pb 1 pressed
	rcall read_key
	cpi tmp, '?'
	breq no_keys_pressed
		; keypad pressed
		cp tmp, tmp ; set Z flag
		rjmp return_key_press
	no_keys_pressed:
	cpi tmp, 'X' ; unset Z flag (tmp = '?' here)

	return_key_press:
	pop tmp
	ret
