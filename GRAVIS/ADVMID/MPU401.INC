;лллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
;лл                                                                        лл
;лл   MPU401.INC                                                           лл
;лл                                                                        лл
;лл   IBM Audio Interface Library -- Roland MPU-401 I/O routines           лл
;лл                                                                        лл
;лл   Version 1.00 of 27-Sep-91: Initial version for AIL V2.0 release      лл
;лл                                                                        лл
;лл   8086 ASM source compatible with Turbo Assembler v2.0 or later        лл
;лл   Author: John Miles                                                   лл
;лл                                                                        лл
;лллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл
;лл                                                                        лл
;лл   Copyright (C) 1991, 1992 Miles Design, Inc.                          лл
;лл                                                                        лл
;лл   Miles Design, Inc.                                                   лл
;лл   10926 Jollyville #308                                                лл
;лл   Austin, TX 78759                                                     лл
;лл   (512) 345-2642 / FAX (512) 338-9630 / BBS (512) 454-9990             лл
;лл                                                                        лл
;лллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллллл

                INCLUDE ultramid.inc

DATA_IO         dw ?                    ;IO_addr
STAT_COM        dw ?                    ;IO_addr+1

;****************************************************************************
set_IO_parms    PROC IO_ADDR,IRQ,DMA,DRQ
                USES ds,si,di

                mov ax,[IO_ADDR]
                mov DATA_IO,ax
                inc ax
                mov STAT_COM,ax

                ret
                ENDP

;****************************************************************************
detect_device   PROC H,IO_ADDR,IRQ,DMA,DRQ  ;Attempt to detect MPU-401 card
                USES ds,si,di    
                pushf
                cli

GF1_AIL_STR_SIZE	EQU		6
GF1_VECTORS		EQU		8
HOOK_STR_SIZE		EQU		8
		push	ds
		push	cs
		pop	ds
; Get the segment and offset for the GF1 hook calls
; Loop from vector 78 to 7f checking for the stamp.
; Set es to first vectors segment.
		mov	al,078h
		mov	cx,GF1_VECTORS
next_vector:
		mov	ah,035h
		int	21h
; es is segment of gf1 driver.
; di is Offset into GF1AIL.COM's vector stamp.
		mov	di,0103H

; ds:si is gf166.com string es:di is hook vectors'
		mov	si,offset chk_hook_str
		push	cx
		mov	cx,HOOK_STR_SIZE
		cld
		repe	cmpsb
		jcxz	vector_valid
; Setup for next vector check.
		pop	cx
		inc	al
		loop	next_vector
		jmp	gf1ail_not_found
vector_valid:
		pop	cx
		pop	ds

		mov	ah,035h
		int	21h
		mov     cs:hookoff, bx
		mov     cs:hookseg, es

		jmp	ok_detect

gf1ail_not_found:
		pop	ds
		mov	ax,0h
		jmp	bail_out

ok_detect:

                push DATA_IO              ;preserve current I/O address
                push STAT_COM

                call set_IO_parms C,[IO_ADDR],[IRQ],[DMA],[DRQ]

                call reset_interface      ;attempt to reset card

                pop STAT_COM
                pop DATA_IO

bail_out:
                POP_F                     ;return AX=0 if not found
                ret
                ENDP

;****************************************************************************
send_byte       PROC DataByte:BYTE

		mov ax,TSR_MIDI_OUT
		mov ch,0h
                mov cl,[DataByte]

		call    cs:gf1hook

                ret
                ENDP

;****************************************************************************
send_cmd        PROC CmdByte:BYTE

                pushf
                cli

		mov ax,1
		POP_F
                ret
                ENDP

;****************************************************************************
reset_interface PROC                    ;Returns 1 if MPU interface available
                USES ds,si,di
                pushf                   ;don't allow interruption
                cli

                call send_cmd C,0ffh    ;reset MPU-401 interface
                or ax,ax
                jne __exit_reset        ;(worked the first time)

                call send_cmd C,0ffh    ;try again in case UART mode active

__exit_reset:   POP_F
                ret
                ENDP

;****************************************************************************
init_interface  PROC                    ;Init MPU-401-compatible interface
                USES ds,si,di
                pushf                   ;don't allow interruption
                cli

                call send_cmd C,03fh    ;assert UART mode

                POP_F
                ret

;****************************************************************************
                ENDP
