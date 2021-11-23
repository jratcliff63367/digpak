;----------------------------------------------------------------------------
; Program:  Secondary Screen Debugger
; Filename: ISSDEBUG.INC
; Author:   Scott E. Sindorf
; Language: Borland TASM Ideal mode
; Date:     30 Jul 93
;
; Copyright (c) 1993 by Scott E. Sindorf
;
;  MACRO D1 - displays string and register values followed by a carridge
;             return / linefeed pair.
;
;  MACRO D2 - displays string and register values followed by a space.
;
;  register values are denoted by a pound sign (#) followed by the desired
;  8 or 16 bit register.
;
;  USAGE: D1<AX = #ax> - displays the string followed by the value in AH
;                        and then a CR/LF.
;
;         D2<AX = #ax> - displays the string followed by the value in AX
;                        and then a space.
;
;----------------------------------------------------------------------------
MACRO  D1 		 text
	     LOCAL   string_buffer
			 LOCAL	 end_debug

ifndef NODEBUG
			 push 	 cs
	     push    OFFSET string_buffer
			 int		 85h
			 add		 sp, 4
			 jmp		 end_debug

LABEL 	string_buffer BYTE
				db		"&text&", 13, 10, 0
endif
end_debug:
       ENDM

;----------------------------------------------------------------------------

MACRO  D2 		 text
	     LOCAL   string_buffer
			 LOCAL	 end_debug

ifndef NODEBUG
			 push 	 cs
	     push    OFFSET string_buffer
			 int		 85h
			 add		 sp, 4
			 jmp		 end_debug

LABEL 	string_buffer BYTE
        db    "&text& ", 0
endif
end_debug:
       ENDM

