; read word from @2 to @0:@1
.macro readword
	lds @1, @2
	lds @0, @2+1
.endmacro
; write word @1:@2 to @0
.macro writeword
	sts @0, @2
	sts @0+1, @1
.endmacro
