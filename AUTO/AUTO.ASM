        LOCALS                  ;; Enable local labels
        IDEAL                   ;; Use Turbo Assembler's IDEAL mode
	JUMPS
        INCLUDE "PROLOGUE.MAC"          ;; common prologue
	INCLUDE "SOUNDRV.INC"

ALLDRIVERS	equ	0	; true if building all sound drivers.

KINT		equ	66h
MAXDRIVER	equ	6500	; maximum number of bytes in a driver.

SEGMENT  _TEXT PARA PUBLIC 'CODE'
	 ENDS

	ASSUME	CS: _TEXT, DS: _TEXT, SS: NOTHING, ES: NOTHING


SEGMENT _TEXT
	org	100h
START:
	jmp	LoadSound		; Load the digitized sound driver
	db	"AUTO  ",0,13,10        ; Digitized Sound Package Identity String
IDENTIFIER:
	db	"AUTO LOADER       ",0,13,10
	db	"The Audio Solution, Copyright (c) 1994",0,13,10
	db	"Written by John W. Ratcliff",0,13,10
	org	200h		; Beginning address of jumps.
	jmp	InstallInterupt 	; Install the interupt vector.
	jmp	DeInstallInterupt	; De-install the interupt.

	ALIGN	16
LABEL	DRIVER	BYTE
	db	MAXDRIVER dup(?)     ; room for maximum sized sound driver.


LABEL	InstallDriver	DWORD
InstOff dw	0200h	; Offset of first jump.
InstSeg dw	?	; Segment of audio driver.
LABEL	DeInstallDriver DWORD
DeInstOff dw	0203h	; Offset of deinstall jump
DeInstSeg dw	?	; Segment of audio driver.

PROC	InitDP	near
	ARG	LOADADR:WORD
	PENTER	0
	PushCREGS

	mov	ax,[LOADADR] ; Save segment loaded at.
	mov	es,ax		; Into ES
	sub	ax,10h		; Less 10 paragraphs for the org 100h
;; Check Identity string 'DIGPAK' if not located starting 3 bytes into
;; the file loaded, then this is not a compatible digitized sound driver.
	cmp	[byte es:3],'D' ; D in DIGPAK?
	jne	@@FREE
	cmp	[byte es:4],'I' ; I in DIGPAK?
	jne	@@FREE
	cmp	[byte es:5],'G' ; G in DIGPAK?
	jne	@@FREE
	cmp	[byte es:6],'P' ; P in DIGPAK?
	jne	@@FREE
	cmp	[byte es:7],'A' ; A in DIGPAK?
	jne	@@FREE
	cmp	[byte es:8],'K' ; K in DIGPAK?
	jne	@@FREE
	mov	[cs:InstSeg],ax
	call	[cs:InstallDriver]	; Install the driver.
	or	ax,ax		; Installed ok?
	jz	@@OK1
@@FREE:
	xor	ax,ax
	jmp	short @@EXT	; Exit with error.
@@OK1:	mov	ax,1		; Success!
@@EXT:
	PopCREGS
	PLEAVE
	ret
	endp

PROC	DeInitDP	near
	ARG	ADDRESS:WORD
	PENTER	0

	mov	ax,[ADDRESS]
	sub	ax,10h
	mov	[cs:DeInstSeg],ax	; Set segment.
	call	[cs:DeInstallDriver]	   ; Do indirect call to deinstall the driver.

	PLEAVE
	ret
	endp

;; Data used by Kernel interupt
KJUMP	FARPTR	<>		; Address
OLDIN	FARPTR	<>		; Original interupt vector.
ID	db	'AUTO'          ; Interupt identifier string.
IND     db      'KR'            ; 4B52h indicates a kernel installed interupt.
Proc	SoundInterupt far
	xor	ax,ax
	iret
	endp

LABEL	SUICIDE byte		;; Where to delete ourselves from memory
hard	db	'$'
msg0	db	"Auto-Detect DIGPAK"
	db	" - Copyright (c) 1993, THE Audio Solution:v3.40",13,10,'$'
msg1	db	"DIGPAK Sound Driver is already resident.",13,10,'$'
msg1a	db	"DIGPAK Sound Driver is resident, through MIDPAK.",13,10,'$'
msg1b	db	"A Sound Driver cannot be loaded on top of MIDPAK.  Unload MIDPAK first.",13,10,'$'
msg2	db	"Unable to install Sound Driver interupt vector",13,10,'$'
msg3    db      "Invalid command line",13,10,'$'
msg4	db	"Sound Driver isn't in memory",13,10,'$'
msg5	db	"DIGPAK Sound Driver unloaded",13,10,'$'
msg5a	db	"Sound Driver can't be unloaded, unload MIDPAK first.",13,10,'$'
param   dw      4 dup(?)        ;; Used for parameter passing.
Installed	dw	0
Proc	LoadSound near
	mov	ax,cs			;;
	mov	ds,ax			;; establish data segment
	mov	es,ax			;; point ES to PSP
	call	CheckIn
	mov	[Installed],ax		;; Save in installed flag.
	call	ParseCommandLine	;; Build a command line.
	cmp	[_argc],0
	je	NoArg
	cmp	[_argc],1
	jne	@@BC
	mov	bx,[_argv]
	mov	al,[bx]
	cmp	al,'u'
	je	ULOAD
	cmp	al,'U'
	je	ULOAD
@@BC:
	Message msg3			;; Invalid command line
				DOSTerminate

ULOAD:	mov	ax,[Installed]
	or	ax,ax
	jnz	DOU
	Message msg4			;; wasn't loaded.
	DOSTerminate			;; Terminate with message.
DOU:	cmp	ax,2
	jne	@@OKU
	Message msg5a
	DOSTerminate
@@OKU:
	CALLF	DeInstallInterupt
	Message msg5			;; Display message
	DOSTerminate			;; terminate

NoArg:	or	ax,ax			;; Already loaded?
	jz	@@DOLO			;; no->load it.
	cmp	ax,2
	jne	@@TEMP
	Message msg1a
	DOSTerminate
@@TEMP: cmp	ax,3
	jne	@@TEMPA
	jmp short @@DOLO
	Message msg1b
	DOSTerminate
@@TEMPA:
	Message msg1			;; message
	DOSTerminate			;;
@@DOLO: CALLF	InstallInterupt
	or	ax,ax			;; Was there an error?
	jz	@@HOP1			;; no->continue
	Message msg2			;; display the error message
	Message hard	; Hardware error message if there is one.
	DOSTerminate			;; exit to dos
@@HOP1:
;;; The Kernel is now installed.
;;; Announce the Kernel's presence.
	Message msg0
				DosTSR  SUICIDE         ;; Terminate ourselves bud.
	endp

Proc	InstallInterupt 	far
	IN_TSR

	mov	[param],KINT		;; The interupt kernel is going into.
	mov	[param+2],offset SoundInterupt ;; offset of interupt routine
	mov	[param+4],cs		;; Our code segment.
	PushEA	param			;; push the address of the parameter list
	call	InstallInt		;; Install the interupt.
	add	sp,2			;; clean up stack

	call	HardwareInit	;; Initialize hardware.
	xor	ax,ax		;; always install.

	OUT_TSR
	ret
	endp

Proc	DeInstallInterupt	far
	IN_TSR

	mov	ax,68Fh ; Stop sound playback!
	int	KINT	; Invoke interrupt.
	WaitSound
	mov	ax,692h ; Deinstall hardware vectors.
	int	KINT

	mov	[param],KINT		;; Interupt requested to be unloaded.
	PushEA	param			;; pass parameter.
	call	UnLoad			;; Unload it
	add	sp,2			;; clean up stack

	call	CheckIn 	; if still considered 'installed'
	or	ax,ax		; if that was it, leave.
	jz	@@DONE
	mov	[param],KINT		;; Interupt requested to be unloaded.
	PushEA	param			;; pass parameter.
	call	UnLoad			;; Unload it
	add	sp,2			;; clean up stack
@@DONE:

	OUT_TSR
	ret
	endp


Proc	CheckIn near
	push	ds		; Save ds register.
	push	si

	mov	si,66h*4h	; get vector number
        xor     ax,ax           ; zero
        mov     ds,ax           ; point it there
	lds	si,[ds:si]	; get address of interupt vector
        or      si,si           ; zero?
	jz	@@CIOUT 	; exit if zero
        sub     si,6            ; point back to identifier

	cmp	[word si],'IM'  ; Midi driver?
	jne	@@NEX
	cmp	[word si+2],'ID'  ; full midi driver identity string?
	jne	@@NEX

;; Ok, a MIDI driver is loaded at this address.
	mov	ax,701h 	; Digitized Sound capabilities request.
	int	66h		; Request.
	or	ax,ax		; digitized sound driver available?
	jnz	@@INMID 	; yes, report that to the caller.
	mov	ax,3		; Not available, but mid pak is in!
	jmp short @@EXT 	; exit with return code.
@@INMID:
	mov	ax,2		; Sound driver resident, through MIDPAK.
	jmp short @@EXT
@@NEX:	cmp	[word si],'UA'
	jne	@@NEX2
	cmp	[word si+2],'OT'
	jne	@@NEX2
	mov	ax,1
	jmp short @@EXT
@@NEX2:

	cmp	[word si],454Bh ; equal?
	jne	@@CIOUT 	; exit if not equal
	cmp	[word si+2],4E52h    ; equal?
        jne     @@CIOUT
@@OK:	mov	ax,1
@@EXT:
	pop	si
	pop	ds
	ret
@@CIOUT: xor	ax,ax		; Zero return code.
	jmp short @@EXT
	endp



Proc	InstallINT near
	ARG	DATA:WORD
;; Usage: IntallINT(&parms)
;; offset 0: interupt
;;        2: offset of interupt code
;;        4: segment of interupt code
	PENTER	0
	PushCREGS

	mov	bx,[DATA]	; Get address of parameter table
        mov     ax,[bx]         ; get the interupt vector.
        mov     di,ax           ; save interupt vector into DI as well
        mov     si,[bx+2]       ; get offset
        mov     ds,[bx+4]       ; get segment.
        mov     ah,35h          ; Get interupt vector
				int     21h             ; Do DOS call to get vector.
	mov	[ds:si-10],bx	; Save the old offset.
	mov	[ds:si-8],es	; Save the old segment
        cld
        xor     ax,ax
        mov     es,ax
	ShiftL	di,2		;
	mov	ax,si		; get offset.
        cli
        stosw
        mov     ax,ds           ; code segment
	stosw			; store it.
        sti
	xor	ax,ax		; Success

	PopCREGS
	PLEAVE
	ret
	endp

Proc	UnLoad near
	ARG	DATA:WORD
;; Usage: UnLoad(&vector)
;; Returns: AX = 0 success
;           AX nonzero, couldn't unload interupt vector.
	PENTER	0
	PushCREGS

	mov	bx,[DATA]	; get address of interupt vector
				mov     bx,[bx]         ; get the interupt vector.
        mov     dx,bx           ; put it into DX as well
	ShiftL	bx,2		;
        xor     ax,ax
        mov     ds,ax           ; Segment zero
	lds	si,[ds:bx]	; get address of interupt vector
				or      si,si           ; zero?
				jz      @@UOUT          ; exit if zero
	cmp	[WORD ds:si-2],524Bh ;'KR' Is this a kernel installed interupt?
        push    ds              ; save DS
        mov     ax,dx           ; Get interupt vector.
				mov     ah,25h          ; Do DOS 25h set interupt vector.
	mov	dx,[ds:si-10]	 ; get old offset
	mov	ds,[ds:si-8]	; get old segment
				int     21h             ; set interupt vector.
        pop     ax              ; get back segment of program.
        mov     es,ax
	push	es
	mov	es,[es:2Ch]	; Environment space.
	mov	ah,49h
	int	21h		; Free it up.
	pop	es
        mov     ah,49h          ; free memory.
        int     21h             ; free up the memory used by us.

@@EXIT: PopCREGS
	PLEAVE
        ret
@@UOUT: mov     ax,1
        jmp short @@EXIT
	endp

;; This procedure parses the command line and builds an array of
;; pointers to each argument.  Arguments are seperated by space's.
;; these spaces get replaced by zero bytes.
_argc	 dw	 0	 ; The argument count
_argv	dw	16 dup(0) ; Up to 16 arguments.
command db	128 dup(?)
Proc	ParseCommandLine	near
	mov	[_argc],0
	cmp	[byte es:80h],2
	jb	@@END
	xor	cx,cx
	mov	cl,[es:80h]	; Get length.
	SwapSegs
	dec	cx		; Less one
	lea	di,[command]
	mov	si,82h
	rep	movsb
	push	cs
	pop	ds
	lea	di,[_argv]	; Argument list.
	lea	si,[command]	; Start address.
@@SET:	inc	[_argc] 	; Increment argument counter.
	mov	ax,si		; Base argument addres.
	stosw
@@NEX:	lodsb			; Get characters until we hit space of eol
	cmp	al,32
	jne	@@NEX2
	mov	[byte ds:si-1],0 ; Turn space into a zero byte.
	jmp short @@SET
@@NEX2:
	cmp	al,13
	je	@@END1
	or	al,al
	jnz	@@NEX		; Keep skipping to next arg.
@@END1: mov	[byte ds:si-1],0	; Zero byte terminate last arg
@@END:
	ret
	endp

;;************************************************************************
;; Unique harware init code.
;;************************************************************************

GF1661	   db	   "=====:Gravis Ultrasound not detected: requires ULTRAMID.",13,10,'$'
PAS161	db	"=====:Mediavision ProAudio Specturm 16 not detected.",13,10,'$'
PAUDIO1 db	"=====:Mediavision ProAudio Spectrum not detected.",13,10,'$'
SBLASTER1 db	"=====:Creative Labs SoundBlaster not detected.",13,10,'$'
SBPRO1	  db	"=====:Creative Labs SoundBlaster Pro not detected.",13,10,'$'
SB161	db	"=====:Creative Labs SoundBlaster 16 not detected.",13,10,'$'
GF1662	   db	   "=====:Gravis Ultrasound detected.",13,10,'$'
PAS162  db      "Found:Mediavision ProAudio Specturm 16 detected.",13,10,'$'
PAUDIO2 db	"Found:Mediavision ProAudio Spectrum detected.",13,10,'$'
SBLASTER2 db	"Found:Creative Labs SoundBlaster detected.",13,10,'$'
SB162	db	"Found:Creative Labs SoundBlaster 16 detected.",13,10,'$'
SBPRO2	  db	"Found:Creative Labs SoundBlaster Pro detected.",13,10,'$'



Macro	BootStrap	NAME
	LOCAL	@@SKIP
	lea	si,[NAME]
	lea	di,[DRIVER]
	mov	cx,MAXDRIVER
	rep	movsb
	lea	ax,[DRIVER]	; address of driver.
	shr	ax,4		; /16
	mov	dx,cs		; segment of code.
	add	ax,dx		; now have segment of driver.
	push	ax
	call	InitDP
	add	sp,2		; balance stack.
	or	ax,ax		; did it get loaded!
	jz	@@SKIP
	Message NAME&2
	jmp	@@DONE
@@SKIP:
	Message NAME&1
	endm

Macro	BootStrapBlaster       NAME
	LOCAL	@@SKIP
	lea	si,[NAME]
	lea	di,[DRIVER]
	mov	cx,MAXDRIVER
	rep	movsb
	lea	ax,[DRIVER]	; address of driver.
	shr	ax,4		; /16

	mov	dx,cs		; segment of code.
	add	ax,dx		; now have segment of driver.
	push	ax

	mov	es,ax		; Into ES, now poke IRQ and base address.
	mov	ax,[SBADR]
	mov	[es:106h],ax
	mov	ax,[SBIRQ]
	mov	[es:108h],ax
	push	ds
	pop	es		; es=ds

	call	InitDP
	add	sp,2		; balance stack.
	or	ax,ax		; did it get loaded!
	jz	@@SKIP
	Message NAME&2
	jmp	@@DONE
@@SKIP:
	Message NAME&1
	endm


auto1	db	"Auto-Detecting for SoundBlaster",13,10,'$'
auto2	db	"Failed to detect a SoundBlaster or compatible.",13,10,'$'

SBADR	dw	?
SBIRQ	dw	?
MIXADDR dw	?
MIXDATA dw	?
DSP_RESET dw	?

Proc	HardwareInit	near
	mov	ax,cs
	mov	ds,ax
	mov	es,ax

;; Ok, 'hardware init'.
IF	ALLDRIVERS
	BootStrap	GF166
	BootStrap	PAS16
	BootStrap	PAUDIO
ENDIF
	Message auto1

	push	ds
	lea	ax,[SBIRQ]
	push	ax
	push	ds
	lea	ax,[SBADR]
	push	ax
	call	_DetectBlaster
	add	sp,8
	or	ax,ax		; if not detected, we are screwed.
	jnz	@@FINISH
@@SCREWED:
	Message auto2
	jmp	@@DONE
@@FINISH:
IF	ALLDRIVERS
	cmp	[VERS],1024	; 4.x required for sb16.
	jl	@@BLAST
	BootStrapBlaster       SB16
	jmp	@@DONE
ENDIF
@@BLAST:
	mov	ax,[SBADR]
	add	ax,4
	mov	[MIXADDR],ax
	add	ax,1
	mov	[MIXDATA],ax
	add	ax,1
	mov	[DSP_RESET],ax

	mov	dx,[MIXADDR]
	mov	al,0ah		      ;select Mic Vol control
	out	dx,ax
	jmp	$+2
	mov	dx,[MIXDATA]
	in	al,dx		       ;get original value
	jmp	$+2
	mov	ah,al		      ;save it
	xor	al,110b 	      ;toggle its bits
	out	dx,al		      ;write it back
	jmp	$+2
	in	al,dx		       ;read/verify changed value
	xor	al,110b
	cmp	al,ah
	mov	al,ah		      ;put the old value back
	out	dx,al
	jne	@@BLASTIT
IF	ALLDRIVERS
	BootStrapBlaster SBPRO
	jmp	@@DONE
ENDIF
@@BLASTIT:
	BootStrapBlaster       SBLASTER        ; Bootstrap the sound blaster driver.
@@DONE:
	ret
	endp

LABEL	SBLASTER    byte
	include "sblaster.inc"
IF	ALLDRIVERS
LABEL	PAS16	byte
	include "pas16.inc"
LABEL	PAUDIO	byte
	include "paudio.inc"
LABEL	SBPRO	byte
	include "sbpro.inc"
LABEL	SB16	byte
	include "sb16.inc"
LABEL	GF166	byte
	include "gf166.inc"
ENDIF

MACRO   CPROC   NAME            ; MACRO TO ESTABLISH A C CALLABLE PROCEDURE.
	PUBLIC  &NAME
PROC    &NAME  NEAR
	ENDM

VERS		dw	?
_IO_ADDX       DW   0H          ; DEFAULT I/O ADDRESS.
_INTR_NUM      DB   0           ; DEFAULT IS INTERUPT #7

INT2    DD      ?       ; HOLDS ADDRESS OF ORIGINAL INTERRUPT VECTORS.
INT3    DD      ?       ; WHICH WE STEAL TO PERFORM AUTODECTION.
INT5    DD      ?
INT7    DD      ?
INT10   DD      ?

WAIT_TIME        EQU    0200H
DMA_VOICE_IN     EQU    45H
DMA_VOICE_OUT    EQU    49H

DSP_ID_CMD              EQU    0E0H
DSP_VER_CMD             EQU    0E1H
DSP_VI8_CMD             EQU    24H
DSP_VO8_CMD             EQU    14H
DSP_VO2_CMD             EQU    17H
DSP_VO4_CMD             EQU    75H
DSP_VO25_CMD            EQU    77H
DSP_MDAC1_CMD           EQU    61H
DSP_MDAC2_CMD           EQU    62H
DSP_MDAC3_CMD           EQU    63H
DSP_MDAC4_CMD           EQU    64H
DSP_MDAC5_CMD           EQU    65H
DSP_MDAC6_CMD           EQU    66H
DSP_MDAC7_CMD           EQU    67H
DSP_TIME_CMD            EQU    40H
DSP_SILENCE_CMD         EQU    80H
DSP_PAUSE_DMA_CMD       EQU    0D0H
DSP_ONSPK_CMD           EQU    0D1H
DSP_OFFSPK_CMD          EQU    0D3H
DSP_CONT_DMA_CMD        EQU    0D4H
DSP_INTRQ_CMD           EQU    0F2H

CMS_TEST_CODE            EQU         0C6H
RESET_TEST_CODE          EQU         0AAH

CMS_EXIST                EQU         1
FM_MUSIC_EXIST           EQU         2
CTV_VOICE_EXIST          EQU         4

FM_WAIT_TIME             EQU         40H

;; SOUNDBLASTER DETECTION CODE.....................

PORTPOSSIBILITIES       DW      220H,210H,230H,240H,250H,260H

PIC0_val        db      ?
PIC1_val        db      ?

Macro   SavePic
	in      al,0A1h
	mov     [cs:PIC1_val],al
	in      al,21h
	mov     [cs:PIC0_val],al
	endm

Macro   RestorePic
	mov     al,[cs:PIC1_val]
	out     0A1h,al
	mov     al,[cs:PIC0_val]
	out     21h,al
	endm


;; INITIALIZE THE SOUND BLASTER.
;;
;;      ON ENTRY: NOTHING.
;;         EXIT:  1 -> SOUNDBLASTESR FOUND.
;;                0 -> NO SOUNDBLASTER DETECTED.
CPROC   _DetectBlaster
	ARG     BASEADR:DWORD,IRQ:DWORD
	PENTER	0
	push es
	push ds
	push si
	push di
	MOV     AX,CS
	MOV     DS,AX
	MOV     ES,AX

	LEA     DI,[PORTPOSSIBILITIES]
	MOV     CX,6            ; TRY ALL 6 POSSIBILITIES.
@@LOP:  MOV     AX,[DI]         ; GET PORT POSSIBILITY.
	MOV     [_IO_ADDX],AX   ; SAVE IN IO_ADDX
	PUSH    CX
	PUSH    DI
	CALL    DETECTBLASTER         ; SEE IF THERE
	POP     DI
	POP     CX
	JZ      @@FOUND
	ADD     DI,2            ; TRY NEXT
	LOOP    @@LOP           ;
	XOR     AX,AX
	JMP   SHORT @@ERR       ; EXIT, WITH ERROR CONDITION.
@@FOUND:
	MOV     AX,1            ; FOUND SOUND BLASTER.
	LES     DI,[BASEADR]
	MOV     AX,[_IO_ADDX]
	STOSW
	LES     DI,[IRQ]
	XOR     AX,AX   ;
	MOV     AL,[_INTR_NUM]  ; RETURN INTERRUPT NUMBER FOUND.
	STOSW
@@ERR:
	pop di
	pop si
	pop ds
	pop es

	PLEAVE
	RET
	ENDP


;; ON ENTRY: _IO_ADDX = TO THE ADDRESS TO SEARCH AT.
;;    EXIT: ZERO CONDITION -> SOUND BLASTER FOUND, HERE.
;;          NON-ZERO CONDITION, SOUND BLASTER NOT FOUND.
PROC    DETECTBLASTER  NEAR
	CALL   RESET_DSP                ; RESET THE DSP
	JNZ    @@ID90                   ;
	CALL   VERIFY_IO_CHK
	JNZ    @@ID90
	CALL   CHK_DSP_VERSION
	JNZ    @@ID90
	CALL   VERIFY_INTR
	JNZ    @@ID90
	SUB    AX,AX
@@ID90:
	RET
	ENDP

;; VERIFY THIS IO ADDRESS.
PROC    VERIFY_IO_CHK   NEAR
       MOV    BX,2
       MOV    AL,DSP_ID_CMD
       MOV    DX,[_IO_ADDX]
       ADD    DX,0CH
       CALL   WRITE_DSP_TIME
       JC     @@VIO90

       MOV    AL,0AAH
       CALL   WRITE_DSP_TIME
       JC     @@VIO90

       CALL   READ_DSP_TIME
       JC     @@VIO90

       CMP    AL,055H
       JNE    @@VIO90

       SUB    BX,BX

@@VIO90:
       MOV    AX,BX
       OR     AX,AX
       RET
       ENDP


;; HERE, WE VERIFY THIS INTERRUPT.
PROC    VERIFY_INTR     NEAR
       cli
       SavePic
       MOV      AL,2
       LEA      DX,[DUMMY_DMA_INT2]
       LEA      BX,[INT2]               ; STORAGE FOR OLD ADDRESS.
       CALL     SETUP_INTERRUPT
       MOV      AL,3
       LEA      DX,[DUMMY_DMA_INT3]
       LEA      BX,[INT3]
       CALL     SETUP_INTERRUPT
       MOV      AL,5
       LEA      DX,[DUMMY_DMA_INT5]
       LEA      BX,[INT5]
       CALL     SETUP_INTERRUPT
       MOV      AL,7
       LEA      DX,[DUMMY_DMA_INT7]
       LEA      BX,[INT7]
       CALL     SETUP_INTERRUPT
       MOV      AL,10
       LEA      DX,[DUMMY_DMA_INT10]
       LEA      BX,[INT10]
       CALL     SETUP_INTERRUPT
       sti
       MOV      [_INTR_NUM],0
       MOV      DX,[_IO_ADDX]
       ADD      DX,0CH
       MOV      AL,DSP_INTRQ_CMD
       CALL     WRITE_DSP
       SUB      AX,AX
       MOV      CX,WAIT_TIME*4
@@VI10:
       CMP      [_INTR_NUM],0
       JNZ      @@VI90
       LOOP     @@VI10
       MOV      AX,3
@@VI90:
       PUSH    AX
       cli
       MOV     AL,2
       LEA     BX,[INT2]
       CALL    RESTORE_INTERRUPT
       MOV     AL,3
       LEA     BX,[INT3]
       CALL    RESTORE_INTERRUPT
       MOV     AL,5
       LEA     BX,[INT5]
       CALL    RESTORE_INTERRUPT
       MOV     AL,7
       LEA     BX,[INT7]
       CALL    RESTORE_INTERRUPT
       MOV     AL,10
       LEA     BX,[INT10]
       CALL    RESTORE_INTERRUPT
       RestorePic
       sti
       POP     AX
       OR      AX,AX
       RET
       ENDP



PROC    CHK_DSP_VERSION         NEAR
       MOV    AL,DSP_VER_CMD
       MOV    DX,[_IO_ADDX]
       ADD    DL,0CH
       CALL   WRITE_DSP
       CALL   READ_DSP
       MOV    AH,AL
       CALL   READ_DSP
       mov	[VERS],ax
       MOV    BX,1
       CMP    AX,101H
       JB     @@CDV90
       SUB    BX,BX
@@CDV90:
       MOV    AX,BX
       OR     AX,AX
       RET
       ENDP

;;

;------------------------------------------------------------------------;
; WRITE_DSP WRITES AL TO THE SOUND BLASTER AFTER WAITING FOR LAST COMMAND
; TO COMPLETE
;------------------------------------------------------------------------;
PROC    WRITE_DSP       NEAR
	PUSH    CX              ; STUFF WITH CX IS NEW TIMEOUT CODE FOR V2.0
	MOV     CX,-1
	MOV     AH,AL
@@WD10: DEC     CX              ; IF TIMEOUT, EXIT LOOP
	JZ      @@WD11

	IN      AL,DX
	OR      AL,AL
	JS      @@WD10          ; WAIT WHILE HIGH BIT ON, BUSY.
@@WD11:
	MOV     AL,AH           ; GET BYTE TO SEND.
	OUT     DX,AL           ; SEND IT
	POP     CX              ; RESTORE CALLER'S CX REGISTER.
	RET
	ENDP

PROC    WRITE_DSP_TIME  NEAR
	PUSH    CX              ; SAVE CALLER'S CX REGISTER.

	MOV     CX,WAIT_TIME    ; APPLICATION WAIT TIME (DANGEROUS FOR VERY FAST MACHINES?)
	MOV     AH,AL           ; SAVE CHARACTRER TO SEND IN AH.

@@WDT10:
	IN      AL,DX
	OR      AL,AL
	JNS     @@WDT20
	LOOP    @@WDT10
	STC
	JMP SHORT @@WDT90
@@WDT20:
	MOV     AL,AH
	OUT     DX,AL           ; SEND THE DAMNED THING.
	CLC
@@WDT90:
	POP     CX              ; RESTORE CALLER'S CX REGISTER.
	RET
	ENDP



PROC    READ_DSP_TIME   NEAR
       PUSH   CX
       PUSH   DX

       MOV    DX,[_IO_ADDX]
       ADD    DL,0EH

       MOV    CX,WAIT_TIME

@@RDT10:
       IN     AL,DX
       OR     AL,AL
       JS     @@RDT20

       LOOP   @@RDT10
       STC
       JMP    SHORT @@RDT90

@@RDT20:
       SUB    DL,4
       IN     AL,DX
       CLC

@@RDT90:
       POP    DX
       POP    CX
       RET
	ENDP


PROC    READ_DSP        NEAR
       PUSH   DX
       MOV    DX,[_IO_ADDX]
       ADD    DL,0EH
       SUB    AL,AL

@@RD10:
       IN     AL,DX
       OR     AL,AL
       JNS    @@RD10

       SUB    DL,4
       IN     AL,DX

       POP    DX
       RET
	ENDP


PROC    RESET_DSP       NEAR
	MOV     DX,[_IO_ADDX]
	ADD     DL,6

	MOV     AL,1                ;JCM (USE THIS INSTEAD)
	OUT     DX,AL               ;JCM
					;JCM
	MOV     CX,20               ;JCM
@@WAIT: IN      AL,DX                ;JCM  ;WAIT > 3 US
	LOOP    @@WAIT             ;JCM
					;JCM
	MOV     AL,0                ;JCM  ;DROP RESET
	OUT     DX,AL               ;JCM

	MOV     CL,20H

@@RDSP10:
       CALL   READ_DSP_TIME
       CMP    AL,0AAH
       JE     @@RDSP20
       DEC    CL
       JNZ    @@RDSP10
       MOV    AX,2
       JMP    SHORT @@RDSP90
@@RDSP20:
       SUB    AX,AX
@@RDSP90:
       OR     AX,AX
       RET
       ENDP


;-------------------------------------------------
; entry: AL = INTERRUPT NUM                      |
;        DX = new vector ofs, seg is alway CS    |
;        BX = offset of store buffer             :
;-------------------------------------------------
Proc    SETUP_INTERRUPT near
       PUSH   BX
       PUSH   CX
       PUSH   DX

	xor     ah,ah           ; Zero high byte.
       MOV    CL,AL                    ; preserve interrupt number for use
       cmp     al,8
       jb      @@calc_vect
	add     al,60h         ; index slcae PIC vectors if IRQ > 7
@@calc_vect:
       ADD    AL,8                     ; calculate interrupt vector addx
       SHL    Ax,1
       SHL    Ax,1
       MOV    DI,AX

       PUSH   ES                       ; setup and preserve interrupt

       SUB    AX,AX
       MOV    ES,AX
       MOV    AX,[ES:DI]
       MOV    [cs:BX],AX               ;JCM
       MOV    [ES:DI],DX

       MOV    AX,[ES:DI+2]
       MOV    [cs:BX+2],AX             ;JCM
       MOV    [ES:DI+2],CS

       POP    ES

	mov     bx,1
	shl     bx,cl
	not     bx
	in      al,0a1h
	and     al,bh
	out     0a1h,al
	in      al,21h
	and     al,bl
	out     21h,al

       STI
       POP    DX
       POP    CX
       POP    BX
       RET
       endp


;-------------------------------------------------
; entry: AL = INTERRUPT NUM                      |
;        BX = offset to stored addx              |
;-------------------------------------------------
Proc    RESTORE_INTERRUPT       near
       MOV    CL,AL
       mov     al,cl           ; Get back interrupt number.
       xor     ah,ah
       cmp      al,8
       jb       @@calc_vect
       add      al,60h          ; index slave PIC if IRQ > 7
@@calc_vect:
       ADD    AL,8                      ; calculate interrupt vector addx
       SHL    Ax,1
       SHL    Ax,1
       MOV    DI,AX
       PUSH   ES                       ; restore interrupt vector
       SUB    AX,AX
       MOV    ES,AX
       MOV    AX,[cs:BX]               ;JCM
       MOV    [ES:DI],AX
       MOV    AX,[cs:BX+2]             ;JCM
       MOV    [ES:DI+2],AX
       POP    ES
       RET
       endp

PROC    DUMMY_ISR       FAR
LABEL   DUMMY_DMA_INT2  WORD
       PUSH   DX
       MOV    DL,2
       JMP    SHORT @@OUT
LABEL   DUMMY_DMA_INT3  WORD
       PUSH   DX
       MOV    DL,3
       JMP    SHORT @@OUT
LABEL   DUMMY_DMA_INT5  WORD
       PUSH   DX
       MOV    DL,5
       JMP    SHORT @@OUT
LABEL   DUMMY_DMA_INT7  WORD
       PUSH   DX
       MOV    DL,7
       jmp      short @@OUT
LABEL   DUMMY_DMA_INT10 WORD
	push    dx
	mov     dl,10
	jmp short @@OUT
@@OUT:
       PUSH   AX
       MOV    [CS:_INTR_NUM],DL
       MOV    DX,[_IO_ADDX]
       ADD    DX,0EH
       IN     AL,DX
       MOV    AL,20H
       OUT    20H,AL            ; SEND A NON SPECIFIC EOI
       cmp      [cs:_INTR_NUM],7
       jle      @@DONE
       out      0a0h,al         ; Acknowledge secondary PIC
@@DONE:
       POP    AX
       POP    DX
       IRET
       ENDP

	ENDS
	end	START

