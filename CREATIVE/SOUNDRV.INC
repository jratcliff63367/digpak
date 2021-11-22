ISCOM           equ     1
ISEXE           equ     0

DIG_ADLIB       equ     0       ; Build 1
DIG_CVXSND      equ     0       ; Build 2
DIG_VMSND       equ     0       ; Build 3
DIG_SMSND       equ     0       ; Build 4
DIG_IBMSND      equ     0       ; Build 5
DIG_DIGISP      equ     0       ; Build 6
DIG_TANEXTX     equ     0       ; Build 7
DIG_TANSLTL     equ     0       ; Build 8
DIG_SBLASTER    equ     0       ; Build 9
DIG_SOURCE      equ     0       ; Build 10
DIG_ECHOII      equ     0       ; Build 11
DIG_LANTSND     equ     0       ; Build 12
DIG_IBMBAK      equ     0       ; Build 13
DIG_IBM1BIT     equ     0       ; Build 14
DIG_PAUDIO      equ     0       ; Build 15
DIG_BIGMOUTH    equ     0       ; Build 16
DIG_MASTER      equ     0       ; BUild 17
DIG_ADLIBG      equ     0       ; Build 18
DIG_T2500       equ     0       ; Build 19
DIG_ARIA        equ     0

BACKFILL        equ     0       ; DMA backfill support is 0 by default.

MILLIKEN        equ     0

PLAYBACK        equ     1       ;0
MASSAGE         equ     2       ;1
FIXEDFREQ       equ     4       ;2
USESTIMER       equ     8       ;3
SHARESTIMER     equ     16      ;4 True if supports timer sharing.
LOOPEND         equ     32      ;5 Supports looping,and pending sounds.
STEREOPAN       equ     64      ;6 supports stereo panning.
STEREOPLAY      equ     128     ;7 Supports stereo playback!
AUDIORECORD     equ     256     ;8 support digital sound recording.
DMABACKFILL     equ     512     ;9 supports DMA backfilling.
PCM16           equ     1024    ;10 supports 16 bit PCM!
PCM16STEREO     equ     2048    ;11 supports 16 bit Stereo PCM!


TIMER0          equ     40h     ; port address of timer 0
portTIMER2      equ     42h     ; port address of timer 2
TIME_CNTRL      equ     43h     ; 8253 control register port

Struc	SOUNDSPEC

PLAYADR FARPTR  <>              ; Address of sound sample to be played.
PLAYLEN         dw      ?       ; Length of sound sample to be played.
ISPLAYING FARPTR <>             ; Address of our playing sample semephore.
FREQUENCY       dw      ?       ; Frequency to play it at.

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

PCM_8_MONO      equ     0
PCM_8_STEREO    equ     1
PCM_16_MONO     equ     2
PCM_16_STEREO   equ     3

