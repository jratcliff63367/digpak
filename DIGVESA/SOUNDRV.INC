PLAYBACK	equ	1	;0
MASSAGE 	equ	2	;1
FIXEDFREQ	equ	4	;2
USESTIMER	equ	8	;3
SHARESTIMER	equ	16	;4 True if supports timer sharing.
LOOPEND 	equ	32	;5 Supports looping,and pending sounds.
STEREOPAN	equ	64	;6 supports stereo panning.
STEREOPLAY	equ	128	;7 Supports stereo playback!
AUDIORECORD	equ	256	;8 support digital sound recording.
DMABACKFILL	equ	512	;9 supports DMA backfilling.
PCM16		equ	1024	;10 supports 16 bit PCM!
PCM16STEREO	equ	2048	;11 support 16 bit stereo PCM


TIMER0          equ     40h             ; port address of timer 0 
portTIMER2	equ	42h		; port address of timer 2
TIME_CNTRL      equ     43h             ; 8253 control register port

Struc	SOUNDSPEC

PLAYADR FARPTR	<>	; Address of sound sample to be played.
PLAYLEN dw	?	; Length of sound sample to be played.
ISPLAYING FARPTR <>	 ; Address of our playing sample semephore.
FREQUENCY dw	?	; Frequency to play it at.

	Ends

Macro	IN_TSR
	push	ds
	push	es
	push	si
	push	di
	mov	ax,cs
	mov	ds,ax
	mov	es,ax
	endm

Macro	OUT_TSR
	pop	di
	pop	si
	pop	es
	pop	ds
	endm

Macro	WaitSound
	LOCAL	@@WT
@@WT:	mov	ax,689h
	int	66h
	or	ax,ax
	jnz	@@WT
	endm

Macro	Dally
	jmp	$+2
	endm

PCM_8_MONO	equ	0
PCM_8_STEREO	equ	1
PCM_16_MONO	equ	2
PCM_16_STEREO	equ	3

;; Set's the DIGPAK semaphore
Macro	SetSemaphore
	mov	[cs:INDIGPAK],1
	endm

;; Clear's the semaphore, and does an IRET
Macro	ClearSemaphoreIRET
	mov	[cs:INDIGPAK],0
	iret
	endm

Macro	ClearSemaphore
	mov	[cs:INDIGPAK],0
	endm

;; This macro checks the DPMI compliant FLAG
;;  If DPMI is on, then the address of the SoundStructure passed is
;;  in ESI instead of DS:SI.  First make certain it is in the low 1mb
;;  of address space.  If not, clearsemaphoreiret.  Otherwise set DS:SI
;;  equal to that address.
Macro	ConvertDPMI seg,indx
	LOCAL	@@HOP
	cmp	[cs:DPMI],0	; In 32 bit DPMI mode?
	je	@@HOP
	push	eax		; Save EAX
	mov	eax,indx	; Get the entire 32 bit flat-model address.
	shr	eax,4		; leave just the segment portion.
	mov	seg,ax		 ; place the segment into DS
	and	indx,0Fh	 ; leave just the offset portion.
	pop	eax
@@HOP:
	endm

Macro  GET20BIT
	call	makelinear
;;;    PUSH   CX
;;;    MOV    CL,4
;;;    ROL    DX,CL
;;;    MOV    CX,DX
;;;    AND    DX,0FH
;;;    XOR    CX,DX
;;;    ADD    AX,CX
;;;    ADC    DX,0
;;;    POP    CX
       endm

KINT    equ     66h

