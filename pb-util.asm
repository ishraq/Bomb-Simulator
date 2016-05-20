.cseg
; Z flag set iff pressed for ispb0 and ispb1
.macro ispb0
	in tmp, pind
	andi tmp, 1<<0
.endmacro
.macro ispb1
	in tmp, pind
	andi tmp, 1<<1
.endmacro
