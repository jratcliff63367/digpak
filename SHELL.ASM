	P386		; Enable 32 bit registers.

DEBUGGING	equ	0
ACTIVISION	equ	0		; True if building Bill Volk's version.
DMA_FF_REG	equ    0CH

VERSION_NUMBER	equ	340

;; 3.0	-> stereo rev.
;; 3.1	-> version number rev, semaphore reporting.
;; 3.11 -> fixed bug halting looped sample, when looped sample wasn't playing.
;; 3.12 -> got rid of the int 3 instructions accidently left in sblaster.
;; 3.2	-> auto-init dma mode functions.
;; 3.3	-> auto-init dma on SBLASTER cards, as well as SBP16 support.
;; 3.4	-> support for 386 flat-model register passing convention.

        LOCALS                  ;; Enable local labels

        IDEAL                   ;; Use Turbo Assembler's IDEAL mode
	JUMPS

        INCLUDE "PROLOGUE.MAC"          ;; common prologue
	INCLUDE "SOUNDRV.INC"

;; Set's the DIGPAK semaphore
Macro	SetSemaphore
	mov	[cs:INDIGPAK],1
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

;; Clear's the semaphore, and does an IRET
Macro	ClearSemaphoreIRET
	mov	[cs:INDIGPAK],0
	iret
	endm

Macro	ClearSemaphore
	mov	[cs:INDIGPAK],0
	endm

IFNDEF	NOSOUND
NOSOUND equ	0
ENDIF

IFNDEF	FOREGROUND
FOREGROUND	equ	0
ENDIF

IFNDEF LIFESIZE
LIFESIZE	equ	0
ENDIF

IFNDEF	SBPRO
SBPRO	equ	0
ENDIF

IFNDEF	PAS16
PAS16	equ	0
ENDIF

IFNDEF	SENSATION
SENSATION	equ	0
ENDIF

IFNDEF	STFX
STFX	equ	0
ENDIF

IFNDEF	SBCLONE
SBCLONE equ	0
ENDIF

;; Make correct equate versus build equate.
IF	BUILD EQ 1
DIG_ADLIB	equ	1
ENDIF

IF      BUILD EQ 2
DIG_CVXSND	equ	1
IF	NOSOUND
BACKFLLL	equ	0
ELSE
BACKFILL	equ	1
ENDIF
ENDIF

IF	BUILD EQ 3
DIG_VMSND	equ	1
BACKFILL	equ	1
ENDIF
IF	BUILD EQ 4
DIG_SMSND	equ	1
BACKFILL	equ	1
ENDIF
IF	BUILD EQ 5
DIG_IBMSND	equ	1
ENDIF
IF	BUILD EQ 6
DIG_DIGISP	equ	1
ENDIF
IF	BUILD EQ 7
DIG_TANEXTX	equ	1
ENDIF
IF	BUILD EQ 8
DIG_TANSLTL	equ	1
ENDIF
IF	BUILD EQ 9
DIG_SBLASTER	equ	1
BACKFILL	equ	1
ENDIF
IF	BUILD EQ 10
DIG_SOURCE	equ	1
ENDIF
IF	BUILD EQ 11
DIG_ECHOII	equ	1
ENDIF
IF	BUILD EQ 12
DIG_LANTSND	equ	1
ENDIF
IF	BUILD EQ 13
DIG_IBMBAK	equ	1
ENDIF
IF	BUILD EQ 14
DIG_IBM1BIT	equ	1
ENDIF
IF	BUILD EQ 15
DIG_PAUDIO	equ	1
BACKFILL	equ	1
ENDIF
IF	BUILD EQ 16
DIG_BIGMOUTH	equ	1
BACKFILL	equ	1
ENDIF
IF	BUILD EQ 17
DIG_MASTER	equ	1
ENDIF
IF	BUILD EQ 18
DIG_ADLIBG	equ	1
BACKFILL	equ	1
ENDIF
IF	BUILD EQ 19
DIG_T2500	equ	1
ENDIF
IF BUILD EQ 20
DIG_ARIA EQU 1
BACKFILL equ 0
IFNDEF ARIA_STEREO
ARIA_STEREO equ 1
ENDIF
ENDIF
IF	BUILD EQ 21
DIG_VBEAI	equ	1
DIG_PAUDIO      equ     1
BACKFILL	equ	1
ENDIF

IFNDEF	DIG_VBEAI
DIG_VBEAI	equ	0
ENDIF


IF	DIG_LANTSND
;;	  include "vpi.mac"

; Defined encoding methods:
;
VWFM_mu_law        equ  0               ; mu-law companding
VWFM_nyb62         equ  1               ; nybble 62 sample compression of #0

;
;-------------------------------------------------------------------------
;
;       Voice Control Block (VCB) structure
;

VCB_RESERVED_SIZE  EQU  16

Struc		   VCB

 VCB_command       DB   ?               ; Command code
 VCB_buffer@	   FARPTR  <>		; Buffer address
 VCB_length        DW   0               ; Length of buffer
 VCB_rlength       DW   0               ; Actual # bytes transferred
 VCB_post@	   FARPTR <>		; Completion post routine address
 VCB_vca_num       DB   0               ; Voice adapter number
 VCB_cmd_cplt      DB   0               ; ff = Pending, other = Complete
 VCB_word_format   DW   ?               ; Voice word format (see above)
 VCB_rpt_count     DW   0               ; # of times to execute cmd - 1
 VCB_reserved      DB   VCB_RESERVED_SIZE DUP(0)
					; Reserved for future use
					;  (Should be set to 0)
			 ENDS

VCB_UNRESERVED_SIZE EQU VCB_reserved - VCB_command
VCB_SIZE           EQU  VCB_UNRESERVED_SIZE+VCB_RESERVED_SIZE

;
;-------------------------------------------------------------------------
;
;        Adapter channel capabilities bitmask record:
;
;   VSCH_unused    - Reserved for future assignment
;   VSCH_fdx       - 1: adapter can simultaneously process Record and Play
;                         requests (Full-duplex).
;   VSCH_record    - 1: adapter can process Record requests.
;   VSCH_play      - 1: adapter can process Play requests.
;

;;VSCH		     RECORD VSCH_unused:5,VSCH_fdx:1,VSCH_record:1,VSCH_play:1

;;VSCH_mask_play     EQU  MASK VSCH_play  ; Bit set for play capability
;;VSCH_mask_record   EQU  MASK VSCH_record
									; Bit set for record capability
;;VSCH_mask_fdx      EQU  MASK VSCH_fdx   ; Bit set for simultaneous
									;    record/play capability.

; Some adapter IDs possible in vst_adapt_id:
;

VCA_ID_LV_PC       EQU   0              ; LANtastic (tm) Voice PC-BUS
VCA_ID_LV_MCA      EQU   1              ; LANtastic Voice (tm) u-Channel


;
;-------------------------------------------------------------------------
;
;       Adapter status buffer (Returned by STATUS VCB request):
;

Struc		  VCB_statbuff

 vst_drvr_name     DB   64 DUP (?)      ; ASCIZ Voice driver name
 vst_adapt_id      DW   0               ; Voice adapter ID number (see above)
 vst_word_format   DW   ?               ; Hardware word format code
 vst_channel_mask  DB   ?               ; Channel capabilities (see above)

			 ENDS

VCB_STATBUFF_SIZE  EQU  69

;
;-------------------------------------------------------------------------
;
;       Valid VCB command codes:
;

VCB_no_wait        EQU  80h             ; Bit set for No-wait mode

VCB_CMD_STATUS     EQU  00h             ; Get adapter status
VCB_CMD_RESET      EQU  01h             ; Reset adapter/driver
VCB_CMD_DEINSTALL  EQU  02h             ; Deinstall adapter
VCB_CMD_CANCEL     EQU  03h             ; Cancel pending VCB

VCB_CMD_SEND       EQU  04h             ; Send to PLAY channel
VCB_CMD_SILENCE    EQU  05h             ; Send silence to PLAY channel
VCB_CMD_RECEIVE    EQU  06h             ; Receive from RECORD channel
VCB_CMD_THRESHOLD  EQU  07h             ; Wait for threshold

; Eligible no-wait commamds:
;

VCB_CMD_SENDNW     EQU  VCB_CMD_SEND+VCB_no_wait
							; Send to PLAY, no waiting

VCB_CMD_SILENCENW  EQU  VCB_CMD_SILENCE+VCB_no_wait
							; Send silence to PLAY, no waiting

VCB_CMD_RECEIVENW  EQU  VCB_CMD_RECEIVE+VCB_no_wait
							; Receive from RECORD, no waiting

VCB_CMD_THRESHOLDNW EQU VCB_CMD_THRESHOLD+VCB_no_wait
							; Wait for threshold in background
;
;-------------------------------------------------------------------------
;
;       VCB Status codes:

VS_OK              EQU  00h             ; Command completed successfully
VS_INVALID_COMMAND EQU  01h             ; Unknown VCB command
VS_NOT_PENDING     EQU  02h             ; Address is not a pending VCB
VS_CANCELLED       EQU  03h             ; Command was cancelled
VS_INVALID_VCA     EQU  04h             ; Invalid adapter number
VS_INVALID_WFMT    EQU  05h             ; Unsupported word format
VS_NO_PLAY         EQU  06h             ; Attempt to do output to input-
										;   only device
VS_NO_RECORD       EQU  07h             ; Attempt to read from output-only
										;   device
VS_CANT_DEINSTALL  EQU  08h             ; The driver TSR cannot be removed
										;   due to an interrupt hook
										;   conflict
VS_INVALID_LENGTH  EQU  09h             ; The Length field was not acceptable
										;   for the command and word format.
VS_PENDING         EQU 0ffh             ; VCB is running (not an error)

MPX_installed_status EQU  0             ; get installed status in AL
MPX_interrupt        EQU  2fh           ; Multiplex interrupt number
ENDIF

IF	DIG_SOURCE

Macro	SourceOn
	push	dx
	push	ax
	MOV	DX,[cs:PORTMOD+1] ;Address of LPT1 control port
	add	dx,2
				IN      AL,DX
				AND     AL,11110111b    ;Clear bit 3
	jmp	$+2
				OUT     DX,AL           ;Turn on SS
	pop	ax
	pop	dx
	endm

Macro	SourceOff
	push	dx
	push	ax
	MOV	DX,[cs:PORTMOD+1]
	add	dx,2
	IN	AL,DX
	OR	AL,00001000b	;Set bit 3
	jmp	$+2
	OUT	DX,AL
	pop	ax
	pop	dx
	endm


ENDIF

KINT	equ	66h

SEGMENT  _TEXT PARA PUBLIC 'CODE'
				ENDS

	ASSUME	CS: _TEXT, DS: _TEXT, SS: NOTHING, ES: NOTHING


SEGMENT _TEXT
IF	ISCOM
	org	100h
ENDIF
START:
	jmp	LoadSound		; Load the digitized sound driver
	db	"DIGPAK",0,13,10        ; Digitized Sound Package Identity String
IDENTIFIER:
;; =============[*][	     1	       2	 3	    ]
;; =============[*][1234567890123456789012345678901234567890]
IF	DIG_MASTER
	db	"MediaMaster or compatible",0,13,10
ENDIF
IF	DIG_ADLIB
	db	"Adlib or compatible",0,13,10
ENDIF
IF	DIG_CVXSND
IF	LIFESIZE
	db	"Life Size Enhancer",0,13,10
ELSE
IF	NOSOUND
	db	"No digital sound card",0,13,10
ELSE
	db	"Covox Speech Thing",0,13,10
ENDIF
ENDIF
ENDIF
IF	DIG_VMSND
	db	"Covox Voice Master & Sound Master II",0,13,10
ENDIF
IF	DIG_SMSND
	db	"Covox Sound Master I",0,13,10
ENDIF
IF	DIG_IBMSND
	db	"IBM Internal Speaker, Foreground",0,13,10
ENDIF
IF	DIG_DIGISP
	db	"Digispeech DS201 Speech Adaptor",0,13,10
ENDIF
IF	DIG_TANEXTX
	db	"Tandy TX/EX/HX/SX & PCjr",0,13,10
ENDIF
IF	DIG_TANSLTL
	db	"Tandy SL/TL & Sensation",0,13,10
ENDIF
IF	DIG_SBLASTER
IF	SBPRO
	db	"Sound Blaster Pro",0,13,10
ELSE
IF	STFX
	db	"ATI Stereo FX",0,13,10
ELSE
IF	SBCLONE
	db	"SoundBlaster CLONE",0,13,10
ELSE
	db	"SoundBlaster, Creative Labs",0,13,10
ENDIF
ENDIF
ENDIF
ENDIF
IF	DIG_SOURCE
	db	"Sound Source, Walt Disney",0,13,10
ENDIF
IF	DIG_ECHOII
	db	"Echo II, Street Electronics",0,13,10
ENDIF
IF	DIG_LANTSND
	db	"Lantastic Voice Adaptor",0,13,10
ENDIF
IF	DIG_IBMBAK
	db	"IBM Internal Speaker background",0,13,10
ENDIF
IF	DIG_IBM1BIT
	db	"IBM Internal Speaker, 1 bit",0,13,10
ENDIF
IF	DIG_PAUDIO
IF	PAS16
	db	"ProAudio Spectrum 16",0,13,10
ELSE
IF	DIG_VBEAI
	db	"VESA Wave Driver",0,13,10
ELSE
	db	"ProAudio Spectrum 8",0,13,10
ENDIF
ENDIF
ENDIF
IF	DIG_BIGMOUTH
	db	"BigMouth, Talking Technolgoies",0,13,10
ENDIF
IF	DIG_ADLIBG
IF	SENSATION
	db	"Tandy Sensation",0,13,10
ELSE
	db	"Adlib Gold",0,13,10
ENDIF
ENDIF
IF	DIG_T2500
	db	"Tandy 2500 XL",0,13,10
ENDIF
IF DIG_ARIA
	db  "Aria, Sierra Semiconductor",0,13,10
ENDIF
	db	"The Audio Solution, Copyright (c) 1993",0,13,10
	db	"Written by John W. Ratcliff",0,13,10
IF	ISCOM
	org	200h		; Beginning address of jumps.
	jmp	InstallInterupt 	; Install the interupt vector.
	jmp	DeInstallInterupt	; De-install the interupt.
ENDIF
;; Unique data areas to individual hardware implementations.
IF	DIG_ADLIB
AdlibIO 	dw	388h		; Base address of adilb.
DUMMYIRQ	dw	-1		; No IRQ used.
DUMMYEXTRA	dw	-1		; Nothing extra.
ENDIF
IF	DIG_CVXSND
IF	NOSOUND
	dw	-1
ELSE
BASELPT 	dw	408h		; Base address of LPT1
ENDIF
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_VMSND
PortAddress	dw	22Fh
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_SMSND
PortAddress	dw	222h
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_IBMSND
DUMMYBASE	dw	-1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_DIGISP
DUMMYBASE	dw	-1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_TANEXTX
DUMMYBASE	dw	-1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_TANSLTL
DUMMYBASE	dw	-1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_SBLASTER
_io_addx	DW	220h	    ; Default I/O address.
_intr_num	DW	7	    ; Default is interupt #7
DSP_DMA 	dw	1	; default DMA is ONE!
ENDIF
IF	DIG_SOURCE
BASELPT 	dw	408h		; Base address of LPT1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_ECHOII
PORTADDRESS	dw	208h		; Base address of Echo II
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_LANTSND
DUMMYBASE	dw	-1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_IBMBAK
DUMMYBASE	dw	-1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_IBM1BIT
DUMMYBASE	dw	-1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_PAUDIO
DUMMYBASE	dw	-1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_BIGMOUTH
PortAddress	dw	222h
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF	DIG_MASTER
card_address	dw	338h
cur_int 	dw	7
cur_dma_channel dw	 1
ENDIF
IF	DIG_ADLIBG
IO_ADDR         dw      388h    ; Default Adlib Gold I/O address.
DUMMYIRQ	dw	-1	; Read from control register.
DUMMYDMA	dw	-1	; Read from contorl registers.
ENDIF
IF	DIG_T2500
IO_ADDR 	dw	1E4h		; Base address of LPT1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1
ENDIF
IF DIG_ARIA
ARIA_ADDR   dw 290h
ARIA_IRQ    dw 10
DUMMYEXTRA  dw -1
ENDIF

;------------------------------------------------------------------
								;
								;Report DMAC position
								;

Macro	REPORTDMA DMA
LOCAL __exit

 IF DIG_PAUDIO
	push	bx
	push	cx
	push	dx
	push	si

	mov	si,[cs:DMAPointer] ; point to the DMA controller table

	xor	dx,dx
	mov	dl,[cs:si+_dmaclear]; flipflop register
	out	dx,al		;clear byte FF

  ; clear the flip flop

	mov	dx,[cs:OurDMAddress]
	inc	dx		; adjust to count addr
	mov	cx,offset DMA1AddrTable
	sub	si,cx		; increment dx if the second
	neg	si		; DMA controller is used
	sbb	si,si		; keep the flag for later
	adc	dx,0		; add one if second device
	in	al,dx		;DMAnCNT: Channel n Word Count
	mov	cl,al
	in	al,dx
	mov	ch,al		;CX = 1st value read
	in	al,dx		;DMAnCNT: Channel n Word Count
	mov	bl,al
	in	al,dx
	mov	bh,al		;BX = 2nd value read
	mov	ax,cx		;assume 1st value larger -- if not,
	cmp	ax,bx		;it must be a glitch, so we'll use
	jae	__exit		;the 2nd value
	mov	ax,bx
__exit:
	mov	cx,si
	neg	cx		; from FFFF to 1 or 0 to 0
	shl	ax,cl
        pop     si
	pop	dx
	pop	cx
	pop	bx
	ret
 ELSE ; !DIG_PAUDIO
        push bx
	push cx
	push dx

	xor dx,dx
	mov dl,[BYTE cs:&DMA]
	shl dx,1
	add dx,1

	mov al,0
        out 0ch,al              ;clear byte FF

	in al,dx		;DMAnCNT: Channel n Word Count
	mov cl,al
	in al,dx
	mov ch,al		;CX = 1st value read

	in al,dx		;DMAnCNT: Channel n Word Count
	mov bl,al
	in al,dx
	mov bh,al		;BX = 2nd value read

	mov ax,cx		;assume 1st value larger -- if not,
	cmp ax,bx		;it must be a glitch, so we'll use
	jae __exit		;the 2nd value
	mov ax,bx

__exit:
	pop dx
	pop cx
	pop bx
	ret
 ENDIF

ENDM

JumpTable	dw	offset	FUNCT1
		dw	offset	FUNCT2
		dw	offset	FUNCT3
		dw	offset	FUNCT4
		dw	offset	FUNCT5
		dw	offset	FUNCT6
		dw	offset	FUNCT7
		dw	offset	FUNCT8
		dw	offset	FUNCT9
		dw	offset	FUNCTA
		dw	offset	FUNCTB
		dw	offset	FUNCTC
		dw	offset	FUNCTD
		dw	offset	FUNCTE
		dw	offset	FUNCTF
		dw	offset	FUNCT10
		dw	offset	FUNCT11
		dw	offset	FUNCT12
		dw	offset	FUNCT13
		dw	offset	FUNCT14
		dw	offset	FUNCT15 ; Set DMA backfill mode.
		dw	offset	FUNCT16 ; Report DMAC count.
		dw	offset	FUNCT17 ; Verify DMA block.
		dw	offset	FUNCT18 ; Set PCM volume.
		dw	offset	FUNCT19 ; set 32 bit addressing mode on/off

DPMI	dw	0	; Default 32 bit addressing mode is off.

IF      BACKFILL
BACKF	dw	0	; Backfill defaults to off
ENDIF

JumpPtr 	dw	?
IF	DIG_PAUDIO OR DIG_SBLASTER
IF	DIG_SBLASTER
_voice_status	dw	0
ENDIF
ELSE
PlayingSound	dw	0	; Flag true when sound sample is playing.
ENDIF
CallBacks	dw	0	; Callback to application flag.
LABEL		CALLBACK	DWORD	     ; Callback address label.
CallLow 	dw	0	; Low word of callback address.
CallHigh	dw	0	; High word of callback address.
CallDS		dw	0	; Value of DS register at callback time.

IF	FOREGROUND
LoopConstant	dw	0
ENDIF
DivisorRate	dw	0	; Default divisor rate.

RecordMode	dw	0	; set audio recording flag.
PlayMode	dw	PCM_8_MONO	; Default play mode is 8 bit PCM.

;; Data used by Kernel interupt
KJUMP	FARPTR	<>		; Address
OLDIN	FARPTR	<>		; Original interupt vector.
ID      db      'KERN'          ; 4B45524Eh Interupt identifier string.
IND     db      'KR'            ; 4B52h indicates a kernel installed interupt.
Proc	SoundInterupt far
;;; Usage: DS:SI -> point to sound structure to play.
;; FUNCT1  AX = 0688h	 DigPlay
;; FUNCT2  AX = 0689h	 Sound Status
;; FUNCT3  AX = 068Ah	 Massage Audio
;; FUNCT4  AX = 068Bh	 DigPlay2, pre-massaged audio.
;; FUNCT5  AX = 068Ch	 Report audio capabilities.
;; FUNCT6  AX = 068Dh	 Report playback address.
;; FUNCT7  AX = 068Eh	 Set Callback address.
;; FUNCT8  AX = 068Fh	 Stop Sound.
;; FUNCT9  AX = 0690h	 Set Hardware addresses.
;; FUNCTA  AX = 0691h	 Report Current callback address.
;; FUNCTB  AX = 0692h	 Restore hardware vectors.
;; FUNCTC  AX = 0693h	 Set Timer Divisor Sharing Rate
;; FUNCTD  AX = 0694h	 Play preformatted loop
;; FUNCTE  AX = 0695h	 Post Pending Audio
;; FUNCTF  AX = 0696h	 Report Pending Status
;; FUNCT10 AX = 0697h	 Set Stereo Panning value.
;; FUNCT11 AX = 698h	 Set DigPak Play mode.
;; FUNCT12 AX = 699h	 Report Address of pending status flag.
;; FUNCT13 AX = 69Ah	 Set Recording mode 0 off 1 on.
;; FUNCT14 AX = 69Bh	 StopNextLoop
;; FUNCT15 AX = 69Ch	 Set DMA backfill mode.
;; FUNCT16 AX = 69Dh	 Report current DMAC count.
;; FUNCT17 AX = 69Eh	 Verify DMA block.
;; FUNCT18 AX = 69Fh	 Set PCM volume.
;; FUNCT19 AX = 6A0h	 Set 32 bit addressing interface on/off

IF	DEBUGGING
	call	DebugLine
ENDIF

	cmp	ax,0688h
	jb	@@CHAIN
	cmp	ax,06A0h
	ja	@@CHAIN
	SetSemaphore		; Set the inside DigPak semaphore
	sti
	sub	ax,0688h
	shl	ax,1
	add	ax,offset JumpTable
	xchg	ax,bx
	mov	bx,[cs:bx]
	xchg	ax,bx
	mov	[cs:JumpPtr],ax
	jmp	[cs:JumpPtr]	;; Near jump will be modified!!
@@CHAIN:
	cmp	[cs:OLDIN.XPTR.POFF],0
	jne	@@CHAIN2
	cmp	[cs:OLDIN.XPTR.PSEG],0
	je	@@IRET
@@CHAIN2:
	jmp	[cs:OLDIN.DPTR] 	; Chain to original interrupt vector.
@@IRET:
	ClearSemaphoreIRET
	endp


FUNCT1:
;;**************************************************************************
;:Function #1: DigPlay, Play an 8 bit digitized sound.
;:
;:	  INPUT:  AX = 688h    Command number.
;:		  DS:SI        Point to a sound structure that
;:			       describes the sound effect to be played.
;;**************************************************************************
	PushCREGS
	ConvertDPMI ds,esi
	call	CompleteSound
	call	SetAudio

IF	DIG_ADLIB OR DIG_IBMSND OR DIG_DIGISP OR DIG_TANEXTX OR DIG_ECHOII OR DIG_LANTSND OR DIG_IBMBAK OR DIG_IBM1BIT OR DIG_ADLIBG

IF      DIG_ADLIB OR DIG_IBMSND OR DIG_TANEXTX OR DIG_ECHOII OR DIG_IBMBAK
	call	DownSample9000
ENDIF
	call	TranslateSound
ENDIF

IF	DIG_T2500 OR DIG_SOURCE
	call	DownSample7000
ENDIF
IF	DIG_PAUDIO OR DIG_SBLASTER
ELSE
	mov	[PlayingSound],1
ENDIF
IF	DIG_ADLIB OR DIG_IBMSND OR DIG_TANEXTX OR DIG_ECHOII OR DIG_IBMBAK
	call	Compute9000
ENDIF
IF	DIG_T2500 OR DIG_SOURCE
	call	Compute7000
ENDIF
IF	NOSOUND
	call	Compute256
ENDIF
	call	PlaySound

	PopCREGS
	ClearSemaphoreIRET
FUNCT2:
;;**************************************************************************
;:Function #2: SoundStatus, Check current status of sound driver.
;:
;:	  INPUT:  AX = 689h
;:	  OUTPUT: AX = 0       No sound is playing.
;:		     = 1       Sound effect currently playing.
;;		    DX = 1	 Looping a sound effect
;;		  BX = Version numer, in decimal, times 100, so that 3.00
;;		       would be 300.  Version number begins with version 3.10
;;		       which includes the DigPak semaphore.
;;**************************************************************************
	mov	bx,VERSION_NUMBER      ; Return VERSION NUMBER in BX! 3.40
	cmp	[cs:LOOPING],1	; Looping a sample?
	jne	@@REP
	xor	ax,ax
	mov	dx,1		; Return high word looping flag.
	ClearSemaphoreIRET
@@REP:
IF	DIG_PAUDIO OR DIG_SBLASTER
	mov	ax,[cs:_voice_status]
ELSE
	mov	ax,[cs:PlayingSound]
ENDIF
	xor	dx,dx		; Not looping
	ClearSemaphoreIRET
FUNCT3:
;;**************************************************************************
;:Function #3: MassageAudio, Preformat audio data into ouptut hardware format.
;:
;:	  INPUT:  AX = 68Ah
;:		  DS:SI        Point to address of sound structure.
;;**************************************************************************
	PushCREGS
	ConvertDPMI ds,esi
	cmp	[cs:PlayMode],PCM_16_MONO	; Don't massage audio in 16 bit mode!
	je	@@JUSTRET
	call	SetAudio
IF	DIG_ADLIB OR DIG_IBMSND OR DIG_DIGISP OR DIG_TANEXTX OR DIG_ECHOII OR DIG_LANTSND OR DIG_IBMBAK OR DIG_IBM1BIT OR DIG_ADLIBG
IF	DIG_ADLIB OR DIG_IBMSND OR DIG_TANEXTX OR DIG_ECHOII OR DIG_IBMBAK
	call	DownSample9000
ENDIF
	call	TranslateSound
ENDIF

IF	DIG_T2500 OR DIG_SOURCE
	call	DownSample7000
ENDIF
@@JUSTRET:
	PopCREGS
	ClearSemaphoreIRET
FUNCT4:
;;**************************************************************************
;:Function #4: DigPlay2, Play preformatted audio data.
;:
;:	  INPUT:  AX = 68Bh
;:		  DS:SI        Point to address of sound structure.
;;**************************************************************************
	PushCREGS

	ConvertDPMI ds,esi
	call	CompleteSound
	call	DoSoundPlay
	mov	[cs:FROMLOOP],0    ; Turn from loop semephore off.
	PopCREGS

	ClearSemaphoreIRET
FUNCT5:
;;**************************************************************************
;:Function #5: AudioCapabilities, Report capabilities of hardware device.
;:
;:	  INPUT:  AX = 68Ch
;:	  OUTPUT: AX = Bit 0 -> On, supports background playback.
;:				Off, driver only plays as a foreground process.
;:		       Bit 1 -> On, source data is reformatted for output device.
;:				 Off, device handles raw 8 bit unsigned audio.
;:		       Bit 2 -> On, Device plays back at a fixed frequency, but
;:				    the audio driver will downsample input data
;:				    to fit.
;:				Off, device plays back at user specified frequency.
;:				(NOTE: You can still playback an audio sample at
;:				       whatever frequency you wish.  The driver
;:				       will simply downsample the data to fit
;:				       the output hardware.  Currently it does
;:				       not support upsampling though.)
;:		       Bit 3 -> On, this device uses the timer interrupt vector
;:				during sound playback.
;:		  DX = If this device plays back at a fixed frequency the DX
;:		       register will contain that fixed frequency playback rate.
;;**************************************************************************
IF	DIG_ADLIBG
	mov	ax,(PLAYBACK OR MASSAGE OR STEREOPLAY OR DMABACKFILL)
ENDIF
IF      DIG_ADLIB
	mov	ax,(PLAYBACK OR MASSAGE OR USESTIMER OR FIXEDFREQ OR SHARESTIMER)
	mov	dx,9000
ENDIF
IF	DIG_T2500
	mov	ax,(PLAYBACK OR MASSAGE OR USESTIMER OR FIXEDFREQ OR SHARESTIMER)
	mov	dx,7000
ENDIF
IF	DIG_CVXSND OR DIG_VMSND OR DIG_SMSND OR DIG_BIGMOUTH
IF	NOSOUND
	mov	ax,(PLAYBACK OR USESTIMER OR SHARESTIMER)
ELSE
	mov	ax,(PLAYBACK OR USESTIMER OR SHARESTIMER OR DMABACKFILL)
ENDIF
ENDIF
IF	NOSOUND
	or	ax,FIXEDFREQ
	mov	dx,256
ENDIF
IF	DIG_IBMSND
	mov	ax,(MASSAGE OR USESTIMER OR FIXEDFREQ OR SHARESTIMER)
	mov	dx,9000
ENDIF
IF	DIG_DIGISP
	mov	ax,(MASSAGE OR FIXEDFREQ)
	mov	dx,8000
ENDIF
IF	DIG_TANEXTX
	mov	ax,(PLAYBACK OR MASSAGE OR USESTIMER OR FIXEDFREQ OR SHARESTIMER)
	mov	dx,9000
ENDIF
IF	DIG_TANSLTL
	mov	ax,(PLAYBACK)
ENDIF
IF	DIG_SBLASTER
	mov	ax,(PLAYBACK OR AUDIORECORD)
	cmp	[cs:AUTOALLOWED],1	; allowed to do auto-init DMA?
	jne	@@NOA
	or	ax,DMABACKFILL	    ;**!!Can't get it to work!
@@NOA:
ENDIF
IF	DIG_SOURCE
	mov	ax,(PLAYBACK OR USESTIMER OR FIXEDFREQ OR SHARESTIMER)
	mov	dx,7000
ENDIF
IF	DIG_ECHOII
	mov	ax,(PLAYBACK OR MASSAGE OR USESTIMER OR FIXEDFREQ OR SHARESTIMER)
	mov	dx,9000
ENDIF
IF	DIG_LANTSND
	mov	ax,(PLAYBACK OR MASSAGE OR FIXEDFREQ)
	mov	dx,8000
ENDIF
IF	DIG_IBMBAK
	mov	ax,(PLAYBACK OR MASSAGE OR USESTIMER OR FIXEDFREQ OR SHARESTIMER)
	mov	dx,9000
ENDIF
IF	DIG_IBM1BIT
	mov	ax,(PLAYBACK OR MASSAGE OR USESTIMER OR SHARESTIMER)
ENDIF
IF	DIG_PAUDIO
	mov	ax,(PLAYBACK OR DMABACKFILL)   ;;** OR AUDIORECORD)
ENDIF
IF DIG_ARIA
	mov  ax,(PLAYBACK OR STEREOPAN)
IF ARIA_STEREO
	or   ax,STEREOPLAY
ENDIF
ENDIF
IF	FOREGROUND
	and	ax,0FFFEh	; Strip background bit OFF
ENDIF
IF	SBPRO
	or	ax,STEREOPAN
ENDIF
IF	STFX OR SBPRO OR DIG_PAUDIO
	or	ax,STEREOPLAY
ENDIF
IF	PAS16 OR DIG_ADLIBG
	or	ax,PCM16		; Supports 16 bit PCM!!!
	or	ax,PCM16STEREO
ENDIF
	mov	bx,cs
	lea	cx,[IDENTIFIER]
	ClearSemaphoreIRET
FUNCT6:
;;**************************************************************************
;:Function #6: ReportSample, Report current playback address.
;:
;:	  INPUT:  AX = 68Dh
;:	  OUTPUT: AX = Current playback address.  Obviously this only
;:		       applies to background drivers.  Note that for some
;:		       drivers this playback address is an aproximation
;:		       and not necessarily the EXACT sample location.
;:		       You can use this service to synchronize
;:		       animation or video effects temporaly with the
;:		       audio output.
;;**************************************************************************
IF	DIG_ADLIB OR DIG_CVXSND OR DIG_VMSND OR DIG_SMSND OR DIG_TANEXTX OR DIG_SOURCE OR DIG_ECHOII OR DIG_IBMBAK OR DIG_IBM1BIT OR DIG_BIGMOUTH OR DIG_T2500
IF	FOREGROUND
	xor	ax,ax
ELSE
	mov	ax,[cs:ADDRESS+1] ; Get current playback addres.
ENDIF
ELSE
	xor	ax,ax		; Should compute aproximation!
ENDIF
	ClearSemaphoreIRET
FUNCT7:
;;**************************************************************************
;:Function #7: SetCallBackAddress, sets a user's sound completion
;:		       callback addess.
;:
;:	  INPUT: AX = 068Eh
;:		 BX = Offset portion of far procedure to callback.
;:		 DX = Segment portion of far procedure to callback.
;:		 DS = Data Segment register value to load at callback time.
;:	  OUTPUT: None.
;:
;:		 This function allows the user to specify a callback
;:		 address of a far procedure to be invoked when a sound
;:		 effect has completed being played.  This function is
;:		 disabled by default.  Sending a valid address to this
;:		 function will cause a callback to occur whenever a sound
;:		 sample has completed being played.  The callers DS register
;:		 will be loaded for him at callback time.  Be very careful
;:		 when using this feature.  The application callback procedure
;:		 is being invoked typically during a hardware interupt.
;:		 Your application should spend a small an amount of time
;:		 as possible during this callback.  Remember that the
;:		 callback must be a far procedure.  The sound driver
;:		 preserves ALL registers so your callback function does
;:		 not need to do so.  Do not perform any DOS functions
;:		 during callback time because DOS is not re-entrent.
;:		 Keep in mind that your own application has been interupted
;:		 by the hardware it this point.  Be very careful when making
;:		 assumptions about the state of your application during
;:		 callback time.  Hardware callbacks are generally used
;:		 to communicate sound event information to the application
;:		 or to perform a technique called double-buffering, whereby
;:		 your application immediatly posts another sound effect to
;:		 be played at the exact time that the last sound effect
;:		 has completed.
;:
;:		 WARNING!!! Be sure to turn off hardware callbacks when
;:		 your application leaves!!! Otherwise, harware callbacks
;:		 will be pointing off into memory that no longer contains
;:		 code.	This function is for advanced programmers only.
;;**************************************************************************
	or	bx,bx
	jnz	@@SC1
	or	dx,dx
	jnz	@@SC1
	xor	ax,ax
	mov	[cs:CallBacks],ax		; Callbacks disabled.
	mov	[cs:CallLow],ax 		; Low address.
	mov	[cs:CallHigh],ax
	jmp	@@EXIT
@@SC1:	mov	[cs:CallLow],bx
	mov	[cs:CallHigh],dx
	mov	[cs:CallDS],ds
	mov	[cs:CallBacks],1

@@EXIT:
	ClearSemaphoreIRET
FUNCT8:
;;**************************************************************************
;:Function #8: StopSound, stop currently playing sound.
;:
;:	  INPUT: AX = 68Fh
;:	  OUTPUT: None.
;:
;:		Will cause any currently playing sound effect to be
;:		terminated.
;;**************************************************************************
	mov	[cs:PENDING],0	; Turn pending flag OFF when stop-sound called.
	mov	[word cs:LOOPING],0
IF	DIG_PAUDIO OR DIG_SBLASTER
ELSE
	cmp	[cs:PlayingSound],0	; Currently playing any sound?
	je	@@CNT		; If not playing sound, nothing to stop...
ENDIF
	call	StopSound
@@CNT:
	ClearSemaphoreIRET
FUNCT9:
;;**************************************************************************
;:Function #9: SetAudioHardware, set up hardware information.
;:
;:	  INPUT: AX = 690h
;:		 BX = IRQ if device needs one set.
;:		 CX = BASE I/O Address, if device needs one set.
;:		 DX = OTHER, some other possible information the hardware might need.
;:
;:	  OUTPUT: NONE.
;:
;:
;:	  Certain harware can be reconfigured to different IRQ and base
;:	  address settings.  This function call allows the application
;:	  programmer to overide these default settings.  The interpretation
;:	  of these parameters might change from driver to driver.  Currently
;:	  only the SBLASTER (Creative Labs SoundBlaster) driver can be
;:	  reconfigured, upon request of Derek Smart.
;;**************************************************************************

	ClearSemaphoreIRET
FUNCTA:
;;**************************************************************************
;;FUNCTION #10: ReportCallbackAddress
;;
;;	  INPUT: AX = 691h
;;	  OUTPUT: AX:DX -> far pointer to current callback address.
;;		  BX -> original caller's DS register.
;;
;;	  This function should probably never need to be used by your
;;	  application software.  It is provided because the MIDPAK,
;;	  MIDI driver, needs to revector hardware callbacks so that
;;	  it can handle hardware contention problems between digitized
;;	  sound playback and synthesized sound playback.
;;**************************************************************************
	mov	ax,[cs:CallLow]
	mov	dx,[cs:CallHigh]
	mov	bx,[cs:CallDS]
	ClearSemaphoreIRET
FUNCTB:
;;**************************************************************************
;;FUNCTION #11: RestoreHardware
;;
;;	  INPUT: AX = 692h
;;	  OUTPUT:
;;
;;		Put hardware back to initial state.  Invoked by the
;;		DeInstall code.  Not to be called by an application program!
;;**************************************************************************
	mov	[cs:CallBacks],0	;
	mov	[word cs:CallBack],0
	mov	[word cs:CallBack+2],0
IF	DIG_MASTER
	push	ds
	push	cs
	pop	ds
	call	REMOVE_ISR
	pop	ds
ENDIF
IF	DIG_PAUDIO OR DIG_SBLASTER
	push	ds

	push	cs
	pop	ds
	call	_ctv_uninstall

	pop	ds
ENDIF
IF	DIG_ADLIBG
	call	_ShutDownAdlibGold
ENDIF
IF	DIG_SOURCE
	SourceOff
ENDIF
IF DIG_ARIA
	push ds
	push cs
	pop  ds
	call shutdown_driver
	pop  ds
ENDIF

	ClearSemaphoreIRET
FUNCTC:
;;**************************************************************************
;; FUNCTION #12: SetTimerDivsorRate
;;
;;	   INPUT: AX = 693h
;;		  DX = Countdown timer divisor rate, so that timer based
;;		       drivers can service application timer interrupts
;;		       at their previous rate.	Service rate will be an
;;		       aproximation, that is fairly close.  To reset timer
;;		       divisor to default of 18.2 pass a 0 in the DX register.
;;**************************************************************************
	mov	[cs:DivisorRate],dx    ; Set timer divisor rate.
	ClearSemaphoreIRET
FUNCTD:
;;**************************************************************************
;; FUNCTION #13: DigPlayLoop
;;
;;	   INPUT: AX = 694h
;;		  DS:SI ->sound structure, preformated data.
;; Here's the process...
;;	Remember the current callback address.
;;	Set new callback address to US!
;;	Save sound structure.
;;	Call DigPlay.
;;	At call back, keep playing.
;;	This gets done until StopSound is called.
;;	Stop sound checks to see if we need to restore the callback address.
;;	If PlaySound is invoked, and we are currently looping a sound then
;;	stopsound is invoked.
;;**************************************************************************
	PushAll 	; Save all registers.
	ConvertDPMI ds,esi
	push	cs
	pop	es
	lea	di,[LOOPSND]
	mov	cx,SIZE LOOPSND
	rep	movsb
	mov	ax,068Fh	; Stop any currently playing sound.
	int	66h		; do it.
	mov	[cs:LOOPING],1	   ; We are now looping a sound sample.
	mov	ax,cs
	mov	ds,ax
	mov	dx,ax		;
	mov	ax,068Eh
	lea	bx,[LoopBack]	;
	int	66h		; Set loop callback.
	PopAll
	push	cs
	pop	ds
	lea	si,[LOOPSND]
	mov	[word cs:LOOPSOUND],si
	mov	[word cs:LOOPSOUND+2],ds
	mov	[cs:FROMLOOP],1 ; Set from looping semephore
	mov	ax,068Bh	; Do FUNCT4
	jmp	FUNCT4		; Do a DigPlay2
FUNCTE:
;;**************************************************************************
;; FUNCTION #14: PostAudioPending
;;
;;	   INPUT: AX = 695h
;;		  DS:SI ->sound structure, preformated data.
;;	   OUTPUT: AX = 0  Sound was started playing.
;;		   AX = 1  Sound was posted as pending to play.
;;**************************************************************************
	PushCREGS
	ConvertDPMI ds,esi
	cli    ; Turn off interupts while making this determination.
IF	DIG_PAUDIO OR DIG_SBLASTER
	mov	ax,[cs:_voice_status]
ELSE
	mov	ax,[cs:PlayingSound]
ENDIF
	or	ax,ax		; Currently playing a sound?
	jnz	@@POST		; yes->try to post pending.
	sti			; We can play it now.
	call	DoSoundPlay	;
	xor	ax,ax		; Return, audio sample is now playing.
	PopCREGS
	ClearSemaphoreIRET
@@POST: cmp	[cs:PENDING],1	; Already have a pending sound effect?
	jne	@@POST2 	; no, post it for pending play.
	mov	ax,2		; return code of two.
	PopCREGS
	ClearSemaphoreIRET
@@POST2:mov	[cs:PENDING],1
	push	es
	push	di
	push	cs
	pop	es
	lea	di,[PENDSND]	; Pending sound.
	mov	cx,SIZE PENDSND
	rep	movsb
	mov	[cs:PENDING],1
	mov	[cs:CallBacks],1
	mov	[word cs:CallBack],offset PlayPending
	mov	[word cs:CallBack+2],cs
	mov	[word cs:CallDS],cs
	pop	di
	pop	es
	mov	ax,1		; Posted as pending.
	PopCREGS
	ClearSemaphoreIRET
FUNCTF:
;;**************************************************************************
;; FUNCTION #15: AudioPendingStatus
;;
;;	   INPUT: AX = 696h
;;	  OUTPUT: AX = 0 No sound is playing.
;;		  AX = 1 Sound playing, sound pending.
;;		  AX = 2 Sound playing, no sound pending.
;;**************************************************************************
	cli		; Clear interrupts while we make this determination.
IF	DIG_PAUDIO OR DIG_SBLASTER
	mov	ax,[cs:_voice_status]
ELSE
	mov	ax,[cs:PlayingSound]
ENDIF
	or	ax,ax		; Currently playing a sound?
	jnz	@@POST		; yes->try to post pending.
	ClearSemaphoreIRET
@@POST: cmp	[cs:PENDING],1	; Have a sound pending?
	je	@@PEND		; yes, return pending status.
	mov	ax,1		; Sound is playing, but no sound is pending.
	ClearSemaphoreIRET
@@PEND:
	mov	ax,2
	ClearSemaphoreIRET
FUNCT10:
;;**************************************************************************
;; FUNCTION #16: SetStereoPan
;;
;;	   INPUT: AX = 697h
;;		  DX = stereo pan value. 0 full volume right.
;;					64 full volume both.
;;				       127 full volume left.
;;	 OUTPUT: AX = 0 command ignored, driver doesn't support stereo panning.
;;		 AX = 1 pan set.
;;**************************************************************************
IF	SBPRO
	mov	bx,dx
	cmp	dx,64		; full volume right?
	jge	@@other 	; other case.
	add	bx,8		; Rounding.
	mov	al,15		; Times 15.
	mul	bl
	ShiftR	ax,6		; /64.
	ShiftL	al,4		; high nibble.
	or	al,0Fh		; Max volume right.
	jmp short @@SETV
@@other:
	mov	bx,127
	sub	bx,dx
	add	bx,8
	mov	al,15
	mul	bl
	ShiftR	ax,6		; /64
	or	al,0F0h 	; Max volume left.
@@SETV:
	mov	dx,[cs:_io_addx]	; Base I/O address of sound blaster.
	add	dx,4			; Point to mixer address port.
	mov	bx,ax
	mov	ax,04h
	out	dx,al			; Send
	jmp	$+2
	mov	ax,bx			; Get volume computed.
	inc	dx			; +1
	out	dx,al			; Send it.
	mov	ax,1			; Return volume set.
ELSE
	xor	ax,ax		; Doesn't support stereo panning.
ENDIF
IF DIG_ARIA
	push ds
	push cs
	pop  ds
	mov  [panpot],dx
	call set_volume
	pop  ds
	mov  ax,1
ENDIF
	ClearSemaphoreIRET
FUNCT11:
;;**************************************************************************
;; FUNCTION #17: SetPlayMode
;;
;;	   INPUT: AX = 698h
;;		  DX = Play Mode function.
;;			  DX = 0 -> 8 bit PCM
;;			     = 1 -> 8 bit Stereo PCM (left/right)
;;			     = 2 -> 16 bit PCM
;;			     = 3 -> 16 bit PCM stereo.
;;
;;	 OUTPUT: AX = 1 -> mode set.
;;		 AX = 0 -> mode not supported by this driver.
;;
;;**************************************************************************
	cmp	dx,PCM_8_MONO	; ALL drivers support 8 bit PCM mono sound.
	je	@@OK

IF DIG_ARIA
IF ARIA_STEREO
	cmp  dx,2
ELSE
	cmp  dx,1
ENDIF
	jae  short @@NOT
	jmp  short @@OK
ENDIF


;; Adlib Gold and ProAudio Spectrum 16 support 16 bit stereo sound.
IF      DIG_ADLIBG OR PAS16
	cmp	dx,PCM_16_STEREO	; Adlib gold supports 16 bit stereo
	je	@@OK
ENDIF

;; Adlib Gold and ProAudio Spectrum 16 support 16 bit mono sound.
IF	PAS16 OR DIG_ADLIBG
	cmp	dx,PCM_16_MONO		; Pas16 supports 16 bit PCM!
	je	@@OK
ENDIF

;; All sound cards that support 8 bit stereo PCM
IF	STFX OR SBPRO OR DIG_PAUDIO OR DIG_ADLIBG OR DIG_ARIA
	cmp	dx,PCM_8_STEREO
	je	@@OK
ENDIF
	jmp	@@NOT		; Non supported sound playback mode.
@@OK:	mov	[cs:PlayMode],dx
IF	DIG_PAUDIO
	mov	[cs:StereoMono],0FFh
	cmp	dx,PCM_8_STEREO
	je	@@STEREO
	cmp	dx,PCM_16_STEREO
	jne	@@OK2
@@STEREO:mov	[cs:StereoMono],0
@@OK2:
ENDIF
	mov	ax,1		; Set!
	ClearSemaphoreIRET
@@NOT:
	xor	ax,ax
	ClearSemaphoreIRET
FUNCT12:
;;**************************************************************************
;; FUNCTION #18: Report Address of Pending Flag
;;
;;	   INPUT: AX = 699h
;;
;;	 OUTPUT: AX:DX -> form far address of pending status flag.
;;		 BX:DX -> form address of DigPak interrupt semaphore.
;;
;;**************************************************************************
	mov	dx,cs		; Code segment.
	lea	ax,[PENDING]	; Address of pending flag.
	lea	bx,[INDIGPAK]	; Address of semaphore address.
	ClearSemaphoreIRET

FUNCT13:
;;**************************************************************************
;; FUNCTION #19: Set audio recording mode.
;;
;;	   INPUT: AX = 69Ah
;;		  DX = 0 turn audio recording ON.
;;		     = 1 turn audio recording OFF.
;;
;;	 OUTPUT: AX = 0 sound driver doesn't support audio recording.
;;		 AX = 1 audio recording mode is set.
;;
;;**************************************************************************
IF	DIG_SBLASTER OR DIG_PAUDIO
	mov	[cs:RecordMode],dx
	mov	ax,1
ELSE
	mov	ax,0
ENDIF
	ClearSemaphoreIRET

FUNCT14:
;;**************************************************************************
;; FUNCTION #20: StopNextLoop
;;
;;	   INPUT: AX = 69Bh
;;
;;	   OUTPUT: NOTHING, Stop Looped sample, next time around.
;;
;;**************************************************************************
	mov	[cs:CallBacks],0
	mov	[cs:LOOPING],0
	ClearSemaphoreIRET
FUNCT15:
;;**************************************************************************
;; FUNCTION #21: Set DMA back fill mode.
;;
;;	   INPUT: AX = 69Ch
;;		  DX = backfill mode 0 means turn it off.
;;		       and a 1 means to turn it on.
;;
;;	   OUTPUT: AX = 1 -> back fill mode set.
;;			0 -> driver doesn't support DMA backfill.
;;
;;**************************************************************************
IF	BACKFILL
	push	ds
	push	di
	push	si

	push	cs
	pop	ds

	push	dx
	call	StopSound
	pop	dx
	mov	[cs:BACKF],dx
	or	dx,dx		; Trying to turn backfill off?
	jnz	@@NOTOFF
@@NOTOFF:
	mov	ax,1		; Back fill mode was set.

	pop	si
	pop	di
	pop	ds
ELSE
	xor	ax,ax		; Not a backfill driver.
ENDIF
	ClearSemaphoreIRET
FUNCT16:
;;**************************************************************************
;; FUNCTION #22: Report current DMAC count.
;;
;;	   INPUT: AX = 69Dh
;;
;;	   OUTPUT: AX = Current DMAC count.
;;
;;**************************************************************************
IF	BACKFILL
	call	ReportDMAC
ENDIF
	ClearSemaphoreIRET
FUNCT17:
;;**************************************************************************
;; FUNCTION #23: Verify DMA block, check to see if it crosses a 64k page
;;		 boundary for the user.
;;
;;	   INPUT: AX = 69Eh
;;		  ES:BX -> address of sound.
;;		  CX	-> length of sound effect.
;;
;;	   OUTPUT: AX = 1 Block is ok, DOESN'T cross 64k bounadary.
;;		   AX = 0 block failed, DOES cross 64k boundary.
;;
;;**************************************************************************
	PushCREGS
	ConvertDPMI es,ebx
	push	cx
	push	es
	push	bx
	call	CheckBoundary
	add	sp,6
	PopCREGS
	ClearSemaphoreIRET

FUNCT18:
;;**************************************************************************
;; FUNCTION #24: Set PCM volume.
;;
;;	   INPUT: AX = 69Eh
;;		  BX = Left channel volume (or both if mono) 0-256
;;		  CX = Right channel volume (or both if mono) 0-256
;;
;;	   OUTPUT: AX = 1 Volume set
;;		   AX = 0 Device doesn't support volume setting.
;;
;;**************************************************************************
	xor	ax,ax		; Default, volume not set.
IF	DIG_PAUDIO
BI_OUTPUTMIXER  equ 00h                 ;PAS equates
BI_L_PCM        equ 06h
BI_R_PCM        equ 0dh

	push	ds
	push	es
	push	di
	push	si

	push	cs
	pop	ds		; DS=CS

	mov	[LEFTVOL],BX
	mov	[RIGHTVOL],CX

	mov	ax,0bc03h	      ;get driver function table address
	int	2fh
	mov	[WORD MV_ftable],bx
	mov	[WORD MV_ftable+2],dx

	mov	bx,[LEFTVOL]
	mov	cx,BI_OUTPUTMIXER
	mov	dx,BI_L_PCM
	les	di,[MV_ftable]
	call	[dword es:di+0]

	mov	cx,BI_OUTPUTMIXER
	mov	dx,BI_R_PCM
	les	di,[MV_ftable]
	mov	bx,[RIGHTVOL]
	call	[dword es:di+0]

	pop	si
	pop	di
	pop	es
	pop	ds
	mov	ax,1
ENDIF
IF DIG_ARIA
	PushCREGS
	push ds
	push cs
	pop  ds
	shr  bx,1
	xor  bh,bh
	xchg bh,bl
	shr  cx,1
	xor  ch,ch
	xchg ch,cl
	mov  si,bx
	mov  di,cx
	call set_volume_helper
	pop  ds
	PopCREGS
	mov  ax,1
ENDIF
	ClearSemaphoreIRET
;; Set 32 bit DPMI compliant address passing on.
FUNCT19:
	mov	[cs:DPMI],dx	; Set it.
	ClearSemaphoreIRET

IF	DIG_PAUDIO
LEFTVOL dw	?
RIGHTVOL dw	?
MV_ftable	dd	?
ENDIF

Macro  GET20BIT
			 PUSH   CX
			 MOV    CL,4
			 ROL    DX,CL
			 MOV    CX,DX
			 AND    DX,0FH
			 AND    CX,0FFF0H
			 ADD    AX,CX
			 ADC    DX,0
			 POP    CX
			 endm

Proc	CheckBoundary	near
	ARG	SOURCE:DWORD,SLEN:WORD
	PENTER	0

	mov	ax,[word SOURCE]
	mov	dx,[word SOURCE+2]
	GET20BIT		; Into 20 bit mode.
	mov	bx,dx		; Save DMA page.
	mov	ax,[word SOURCE]
	mov	dx,[word SOURCE+2]
	add	ax,[SLEN]		; Point to end.
	GET20BIT
	mov	ax,1		; Default is OK.
	cmp	bl,dl		; Same DMA page?
	je	@@OK
	xor	ax,ax		; Didn't work.
@@OK:
	PLEAVE
	ret
	endp


Proc	PlayPending	far
	cmp	[PENDING],1  ; Pending?
	jne	@@not
	mov	[PENDING],0
	mov	[cs:CallBacks],0	; No longer have one pending..
	lea	si,[PENDSND]	; Address of pending sound.
	call	DoSoundPlay	; Do a sound play call.
	ret
@@not:
	mov	[cs:CallBacks],0	; Disable callbacks.
	ret
	endp

Proc	DoSoundPlay	near
	PushCREGS		; Save all of the important C registers.
	call	SetAudio
IF DIG_ARIA
	call  PlaySound
	mov   [PlayingSound],1
	PopCREGS
	ret
ENDIF
IF	DIG_PAUDIO OR DIG_SBLASTER
ELSE
	mov	[PlayingSound],1
ENDIF
IF	DIG_ADLIB OR DIG_IBMSND OR DIG_TANEXTX OR DIG_ECHOII OR DIG_IBMBAK
	call	Compute9000
ENDIF
IF	DIG_T2500 OR DIG_SOURCE
	call	Compute7000
ENDIF
IF	NOSOUND
	call	Compute256
ENDIF
	call	PlaySound		; Restore important C registers.
	PopCREGS
	ret
	endp


Proc	CheckCallBack	near
	cmp	[cs:CallBacks],0	; Callbacks enabled?
	je	@@GOUT		; no, exit.
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
@@GOUT:
	ret
	endp

INDIGPAK	dw	0	; Inside DigPak semaphore.

FROMLOOP	dw	0
SAVECALLBACK	dd	?	; Saved callback address.
SAVECALLDS	dw	?
LOOPING 	dw	0	; True if we were looping.

LOOPSOUND	dd	?
LOOPSND 	SOUNDSPEC	<>

PENDING 	dw	0	; True, when second sound sample is pending.
PENDSND         SOUNDSPEC <>    ; Sound structure of pending sound.

Proc	LoopBack	far
	mov	ax,068Bh	; Play preformated data.
	mov	[cs:FROMLOOP],1
	lds	si,[LOOPSOUND]	;
	int	66h		; Start playing the sound again.
	ret
	endp

Proc    SetAudio        near
IF	DIG_PAUDIO OR DIG_SBLASTER
	mov	[ds:(SOUNDSPEC ptr si).ISPLAYING.XPTR.POFF],offset _voice_status
ELSE
	mov	[ds:(SOUNDSPEC ptr si).ISPLAYING.XPTR.POFF],offset PlayingSound
ENDIF
	mov	[ds:(SOUNDSPEC ptr si).ISPLAYING.XPTR.PSEG],cs
	les	bx,[ds:(SOUNDSPEC ptr si).PLAYADR.DPTR]
	mov	cx,[ds:(SOUNDSPEC ptr si).PLAYLEN]
	mov	dx,[ds:(SOUNDSPEC si).FREQUENCY]
	push	cs
	pop	ds		; DS = Code group.
	ret
	endp

Proc	EndLoop near
	mov	[cs:CallBacks],0	;
	mov	[word cs:CallBack],0
	mov	[word cs:CallBack+2],0
	mov	[word cs:LOOPING],0
	call	StopSound
	ret
	endp

Proc	CompleteSound	near
	cmp	[cs:FROMLOOP],1    ; In loop callback?
	jne	@@YES
	call	EndLoop 	; don't wait for loop to complete, end it!
@@YES:
IF	DIG_PAUDIO OR DIG_SBLASTER
@@WT:	cmp	[cs:_voice_status],0	 ; Wait until last sound completed.
ELSE
@@WT:	cmp	[cs:PlayingSound],0	; Wait until last sound completed.
ENDIF
	jne	@@WT
	ret
	endp

IF	DIG_T2500 OR DIG_SOURCE
Proc	Compute7000	near
	cmp	dx,7000
	jle	@@OK
	push	bx
	push	dx
	mov	ax,cx
	mov	bx,7000
	mul	bx
	pop	bx
	div	bx
	mov	cx,ax
	pop	bx
	mov	dx,7000 	; Playback freq is now 9000!
@@OK:
	ret
	endp

;; Downsample input sound sample to 9khz!
Proc	DownSample7000	near
	PushAll

	cmp	dx,7000 		; <= 8khz?
	jbe	@@DON			; yes, just play it at 8.
@@DOWNIT:
	push	dx

	xor	dx,dx
	mov	ax,7000 		; base of 8khz.
	mov	dl,ah
	mov	ah,al
	xor	al,al			; Times 256
	pop	di
	div	di
@@MODIT:
	push	es
	pop	ds
	mov	si,bx		; DS:SI source address.
	mov	bx,si			; Save start address into BX.
	mov	di,si			; Initial destination address.
	push	ds
	pop	es			; ES=DS
	xor	ah,ah			; Zero build.
@@DOWN: movsb				; Store it.
	add	ah,al			; Add fraction.
	jnc	@@BACK			; If not carry, don't advance DI.
	loop	@@DOWN			; Keep downsampling.
	jmp short @@DON
@@BACK: dec	di			; Don't repeat last byte.
	loop	@@DOWN
@@DON:
	PopAll
	ret
	endp

ENDIF

IF	NOSOUND
Proc	Compute256	near
	cmp	dx,256
	jle	@@OK
	push	bx
	push	dx
	mov	ax,cx
	mov	bx,256
	mul	bx
	pop	bx
	div	bx
	mov	cx,ax
	pop	bx
	mov	dx,256		; Playback freq is now 9000!
@@OK:
	ret
	endp
ENDIF

IF	DIG_ADLIB OR DIG_IBMSND OR DIG_TANEXTX OR DIG_ECHOII OR DIG_IBMBAK
Proc	Compute9000	near
	cmp	dx,9000
	jle	@@OK
	push	bx
	push	dx
	mov	ax,cx
	mov	bx,9000
	mul	bx
	pop	bx
	div	bx
	mov	cx,ax
	pop	bx
	mov	dx,9000 	; Playback freq is now 9000!
@@OK:
	ret
	endp

;; Downsample input sound sample to 9khz!
Proc	DownSample9000	near
	PushAll

	cmp	dx,9000 		; <= 8khz?
	jbe	@@DON			; yes, just play it at 8.
@@DOWNIT:
	push	dx

	xor	dx,dx
	mov	ax,9000 		; base of 8khz.
	mov	dl,ah
	mov	ah,al
	xor	al,al			; Times 256
	pop	di
	div	di
@@MODIT:
	push	es
	pop	ds
	mov	si,bx		; DS:SI source address.
	mov	bx,si			; Save start address into BX.
	mov	di,si			; Initial destination address.
	push	ds
	pop	es			; ES=DS
	xor	ah,ah			; Zero build.
@@DOWN: movsb				; Store it.
	add	ah,al			; Add fraction.
	jnc	@@BACK			; If not carry, don't advance DI.
	loop	@@DOWN			; Keep downsampling.
	jmp short @@DON
@@BACK: dec	di			; Don't repeat last byte.
	loop	@@DOWN
@@DON:
	PopAll
	ret
	endp
ENDIF

;; Ok, here is all of the adlib gold source.
;****************************************************************************

IF	DIG_ADLIBG
;;** FINDADLIBG
; DATA AREA
selected_IRQ    db 3,4,5,7,10,11,12,15
default_pan	dw	64
panpot		dw	?
default_vol	dw	127
main_volume	dw	?
init_OK 	dw	0	; Default init failed.
PRC_0_shadow	dw	?	;
mask_save	dw	?

;;		      0     1	 2    3
PCM_Hz          dw 44100,22050,11025,7350
freq_bits       db 00000000b,00001000b,00010000b,00011000b

pack_modes      db 0,1,128,129,4,132

;		      0 	 1	  2	     3	      4 	 5
;                  m8 PCM    m4 ADPCM  s8 PCM    s4 ADPCM  m16 PCM   s16 PCM
PRC_0_values    db 01100110b,01100010b,01000110b,00100010b,01100110b,01000110b
PRC_1_values    db 00000000b,00000000b,00100110b,01000010b,00000000b,00100110b

SFC_0_values    db 00000101b,00000101b,10000101b,10000101b,01000101b,11000101b
SFC_1_values    db 00000010b,00000010b,00000011b,00000011b,00000010b,01000011b


CTRL_ADDR       dw ?
CTRL_DATA       dw ?
DSP_ADDR        dw ?
DSP_DATA        dw ?
DSP_IRQ         dw ?
DSP_DMA         dw ?

pan_graph       db 0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,30                      
                db 32,34,36,38,40,42,44,46,48,50,52,54,56,58,60,62                
                db 64,66,68,70,72,74,76,78,80,82,84,86,88,90,92,94                
                db 96,98,100,102,104,106,108,110,112,114,116,118,120,122,124,127  
                db 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
                db 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
                db 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
                db 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127


;****************************************************************************
; DATA AREA FOR INTERUPT HANDLER

DMAPAG_offset   db 07h,03h,01h,02h,-1,0bh,09h,0ah

iv_status	dw	0		; Initially interrupt not set.
old_IRQ_o	dw	?	; Old IRQ offset.
old_IRQ_s	dw	?	; Old IRQ segment.
PIC0_val	db	?	;
PIC1_val	db	?	;

DMA_len_l	dw	0	; Low word count of remaining DMA transfer.
DMA_len_h	dw	0	; High word count of remaining DMA transfer.
DMA_ptr 	dd	0	; Address of data being dma'ed out.
blk_len         dw ?
packing         dw ?

;****************************************************************************
; MACRO AREA

Macro	P_MMA_write	 ARG1,ARG2,ARG3
	mov	ax,ARG3
	push	ax
	mov	ax,ARG2
	push	ax
	mov	ax,ARG1
	push	ax
	call	MMA_write
	add	sp,6
	endm

Macro	M_get_ctrl_reg	REG
	mov	ax,REG
	push	ax
	call	get_ctrl_reg
	add	sp,2
	endm

Macro	M_set_ctrl_reg REG,VAL
	push	VAL
	mov	ax,REG
	push	ax
	call	set_ctrl_reg
	add	sp,4
	endm

Macro	FAR_TO_HUGE   fp_seg,fp_off		;normalize far pointer
                push ax bx             
                mov ax,fp_seg
								mov bx,fp_off
                shr bx,1
                shr bx,1
                shr bx,1
                shr bx,1
                add ax,bx
                mov fp_seg,ax
                and fp_off,0fh
                pop bx ax
                ENDM

Macro	ADD_PTR  add_l,add_h,pseg,poff	   ;add 32-bit dword to far ptr
                push bx
                push cx
                mov bx,pseg
                xor cx,cx
                REPT 4
                shl bx,1
                rcl cx,1
                ENDM
                add bx,poff
                adc cx,0
                add bx,add_l
                adc cx,add_h
                mov poff,bx
                and poff,1111b
                REPT 4
                shr cx,1
                rcr bx,1
                ENDM
                mov pseg,bx
                pop cx
                pop bx
                ENDM

SMALL_MODEL	equ	1

Macro	CPROC	name
	public	_&name
IF	SMALL_MODEL
Proc	_&name	near
ELSE
Proc	_&name	far
ENDIF
	endm

Proc	halt_DMA	near
	mov	ax,[PRC_0_shadow]
	and	ax,11111110b	    ;clear GO bit
	P_MMA_write 0,9,ax
	ret
	endp

;****************************************************************************
Proc	StopSound	near
	PushCREGS
	push	cs
	pop	ds		; DS=CS

	pushf
	cli
	cmp	[PlayingSound],0	; Currently playing a sound?
	je	@@NOT		; ->skip, not playing a sound anyway.

	call	IRQ_rest_vect		   ; Restore the interrupt vector.
	call	halt_DMA		; Halt the DMA transfer.

	mov	[PlayingSound],0	; Finished.

	call	CheckCallBack	;

@@NOT:
	popf
	PopCREGS
	ret
	endp

;****************************************************************************
;*                                                                          *
;*  Interface primitives                                                    *
;*                                                                          *
;****************************************************************************

Proc	IO_wait near
	mov	cx,500
	mov	dx,[CTRL_ADDR]
@@wait: in	al,dx
	and	al,01000000b
	loopnz	@@wait
	ret
	endp

;****************************************************************************
Proc	enable_ctrl	near
	mov	dx,[CTRL_ADDR]
	mov	al,0ffh
	out	dx,al
	ret
	endp

;****************************************************************************
Proc	disable_ctrl	near
	call	IO_wait
	mov	dx,[CTRL_ADDR]
	mov	al,0feh
	out	dx,al
	ret
	endp

;****************************************************************************
Proc	get_ctrl_reg
	ARG	RegNum:WORD
	PENTER	0

	call	IO_wait
	mov	dx,[CTRL_ADDR]
	mov	ax,[RegNum]
	out	dx,al
	call	IO_wait
	mov	dx,[CTRL_DATA]
	in	al,dx

	PLEAVE
	ret
	ENDP

;****************************************************************************
Proc	set_ctrl_reg
	ARG	RegNum:WORD,Val:WORD
	PENTER	0

	call	IO_wait
	mov	dx,[CTRL_ADDR]
	mov	ax,[RegNum]
	out	dx,al
	call	IO_wait
	mov	dx,[CTRL_DATA]
	mov	ax,[Val]
	out	dx,al

	PLEAVE
	ret
	endp

;****************************************************************************
Proc	MMA_wait	near
	mov	cx,100
@@kill_time:
	jmp	$+2
	loop	@@kill_time
	ret
	endp

;****************************************************************************
Proc	MMA_write	near
	ARG	Chan:WORD,Reg:WORD,Val:WORD
	PENTER	0

	mov	ax,[Reg]
	mov	dx,[DSP_ADDR]
	out	dx,al
	call	MMA_wait
	mov	dx,[Chan]
	shl	dx,1
	add	dx,[DSP_DATA]
	mov	ax,[Val]
	out	dx,al
	call	MMA_wait

	PLEAVE
	ret
	endp


;****************************************************************************
Proc	reset_DSP	near
	PushCREGS

	P_MMA_write  0,9,10000000b
	P_MMA_write  0,9,01110110b

	P_MMA_write  1,9,10000000b
	P_MMA_write  1,9,01110110b

	mov	ax,01110110b
	mov	[PRC_0_shadow],ax
                
	mov	ax,1

	PopCREGS
	ret
	endp


Proc	set_volume	near
	PushCREGS

	mov	si,127
	sub	si,[panpot]
	mov	al,[pan_graph+si]
	mul	[BYTE main_volume]
	mov	di,ax		    ;DI = right volume 0-16129
	mov	si,[panpot]
	mov	al,[pan_graph+si]
	mul	[BYTE main_volume]
	mov	si,ax		    ;SI = left volume 0-16129

	mov	cx,6
	shr	di,cl		    ;right volume 0-252
	P_MMA_write 0,10,di

	mov	cx,6
	shr	si,cl		    ;left volume 0-252
	P_MMA_write 1,10,si

	PopCREGS
	ret
	endp


Proc	hardware_xfer	near
	mov	ax,[PRC_0_shadow]
	or	ax,00000001b	     ;set GO bit
	P_MMA_write 0,9,ax
	ret
	endp

;; Here we attempt to detect the presence of an Adlib Gold card.
Proc	DetectAdlibGold near
	pushf
	cli

	mov	dx,[IO_ADDR]
	add	dx,2
	mov	[CTRL_ADDR],dx
	inc	dx
	mov	[CTRL_DATA],dx

	call	enable_ctrl

	PushI	9
	call	get_ctrl_reg		; Get left volume.
	add	sp,2
	mov	si,ax

	PushI	10
	call	get_ctrl_reg
	add	sp,2
	mov	di,ax

	xor	si,0101b	      ;tweak a few bits
	xor	di,1010b

	push	si
	PushI	9
	call	set_ctrl_reg
	add	sp,4

	push	di
	PushI	10
	call	set_ctrl_reg
	add	sp,4

	PushI	9
	call	get_ctrl_reg
	add	sp,2
	cmp	ax,si		; It is the same right?
	mov	ax,0
	jne	@@exit		; failed, didn't get back same values we wrote.

	PushI	10
	call	get_ctrl_reg
	add	sp,2

	cmp	ax,di
	mov	ax,0
	jne	@@exit

	 xor	si,0101b	      ;control chip found: restore old
	 xor	di,1010b	      ;values & re-enable FM sound

	push	si
	PushI	9
	call	set_ctrl_reg
	add	sp,4

	push	di
	PushI	10
	call	set_ctrl_reg
	add	sp,4

	call	disable_ctrl
	mov	ax,1		      ;return success

@@exit:
	popf			 ;return AX=0 if not found
	ret
	endp

LastSet dw	-1		; Previously set frequency.
LastMode dw	-1

;; Silly little macro that does the following:
;;   AX -> contains frequency we are matching against.
;;   DX -> closest match so far.
;;   DI -> will contain closest INDEX.
Macro	Closest FREQ,INDEX
	LOCAL	@@OK,@@NOT
	mov	bx,FREQ/2
	sub	bx,ax
	jns	@@OK
	neg	bx
@@OK:	cmp	bx,dx
	jge	@@NOT
	mov	dx,bx		; New closest match.
	mov	di,INDEX	; closest match index.
@@NOT:
	endm

Proc	set_sample_rate near
	ARG	FREQ:WORD
	PENTER	0
	PushCREGS


	mov	ax,[PlayMode]
	cmp	ax,[LastMode]
	je	@@DOFREQ
	mov	ax,[FREQ]
	jmp short @@GO
@@DOFREQ:
	mov	ax,[FREQ]
	cmp	ax,[LastSet]	; Same as last set?
	je	@@DONT		; no need to reset.
@@GO:
	mov	[LastSet],ax	; Currently set frequency.
	shr	ax,1		; /2.
	mov	dx,32767
	Closest 44100,0
	Closest 22050,1
	Closest 11025,2
	Closest 7350,3

	pushf
	cli			;make sure IRQ's are off

	cmp	[PlayMode],PCM_16_STEREO	; In stereo 16 bit mode?
	jne	@@TRYA
	mov	si,5	; 16 bit stereo pcm index.
	jmp short @@CONT
@@TRYA:
	cmp	[PlayMode],PCM_16_MONO	; in 16 bit mono sound mode?
	jne	@@TRY2
	mov	si,4	; mono 16 bit pcm!
	jmp short @@CONT
@@TRY2: mov	si,0		; Temporarily hard coded to 8 bit pcm.
	cmp	[PlayMode],PCM_8_STEREO
	jne	@@CONT
	mov	si,2		; index to 8 bit setereo.
@@CONT:
	P_MMA_write 0,9,10000000b  ;reset both FIFO 0
	mov	al,[freq_bits+di]	; set transfer mode.
	or	al,[PRC_0_values+si]
	mov	[PRC_0_shadow],ax
	P_MMA_write 0,9,ax

	P_MMA_write 1,9,10000000b	; reset FIFO 1
	mov	al,[freq_bits+di]	; set transfer mode.
	or	al,[PRC_1_values+si]
	P_MMA_write 1,9,ax

	P_MMA_write 0,11,0	   ;write 4 dummy bytes to
	P_MMA_write 0,11,0	   ;allow proper FIFO DMA
	P_MMA_write 0,11,0	   ;initialization
	P_MMA_write 0,11,0

	mov	al,[SFC_0_values+si]
	P_MMA_write 0,12,ax

	mov	al,[SFC_1_values+si]
	P_MMA_write 1,12,ax

@@skip:
	mov ax,1

	popf
@@DONT:
	PopCREGS
	PLEAVE
	ret
	endp

;****************************************************************************
; INTERUPT AND DMA CODE SECTION

;****************************************************************************
Proc	IRQ_set_vect	near
	ARG	Handler:DWORD
	PENTER	0
	PushCREGS

	pushf			;avoid interruption
	cli

	cmp	[iv_status],0	      ;avoid redundant settings
	jne	@@exit

	mov	bx,[DSP_IRQ]	      ;index interrupt vector for IRQ
	cmp	bx,8
	jb	@@calc_vect
	add	bx,60h		    ;index slave PIC vectors if IRQ > 7
@@calc_vect:
	add	bx,8
	shl	bx,1
	shl	bx,1

	mov	ax,0		    ;save old handler address, install
	mov	ds,ax		    ;new handler
	les	di,[bx]
	mov	[cs:old_IRQ_s],es
	mov	[cs:old_IRQ_o],di
	les	di,[Handler]
	mov	[bx],di
	mov	[bx+2],es

	push	cs
	pop	ds

	mov	cx,[DSP_IRQ]	      ;enable hardware interrupts from DSP
	mov	bx,1
	shl	bx,cl
	not	bx
	in	al,0a1h
	mov	[PIC1_val],al
	and	al,bh
	out	0a1h,al
	in	al,21h
	mov	[PIC0_val],al
	and	al,bl
	out	21h,al

	mov	[iv_status],1

@@exit:
	popf
	PopCREGS
	PLEAVE
	ret
	endp

;****************************************************************************
Proc	IRQ_rest_vect	near
	PushCREGS

	pushf			;avoid interruption
	cli

	cmp	[iv_status],1	      ;avoid redundant settings
	jne	@@exit

	mov	cx,[DSP_IRQ]	      ;stop hardware interrupts from DSP
	mov	bx,1
	shl	bx,cl
	in	al,0a1h
	or	al,bh
	and	al,[PIC1_val]	      ;don't kill any interrupts that were
	out	0a1h,al 	    ;initially active
	in	al,21h
	or	al,bl
	and	al,[PIC0_val]
	out	21h,al

	mov	bx,[DSP_IRQ]	      ;index interrupt vector for IRQ
	cmp	bx,8
	jb	@@calc_vect
	add	bx,60h		    ;index slave PIC vectors if IRQ > 7
@@calc_vect:
	add	bx,8
	shl	bx,1
	shl	bx,1

	mov	ax,0		    ;restore old handler address
	mov	ds,ax
	mov	ax,[cs:old_IRQ_o]
	mov	dx,[cs:old_IRQ_s]
	mov	[bx],ax
	mov	[bx+2],dx

	push	cs
	pop	ds
	mov	[iv_status],0
	mov	[PlayingSound],0

	call	CheckCallBack

@@exit:
	popf
	PopCREGS
	ret
	endp

Proc	sub_ptr near
	ARG	Off1:word,Seg1:word,Off2:word,Seg2:word
	PENTER	0

	mov	ax,[Seg2]
	mov	dx,0
    REPT 4
	shl	ax,1
	rcl	dx,1
    ENDM
	add	ax,[Off2]
	adc	dx,0

	mov	bx,[Seg1]
	mov	cx,0
    REPT 4
	shl	bx,1
	rcl	cx,1
    ENDM
	add	bx,[Off1]
	adc	cx,0

	sub	ax,bx
	sbb	dx,cx

	PLEAVE
	ret
	endp

Proc	reportDMAC     near
	REPORTDMA DSP_DMA
	endp

Proc	program_DMAC	near
	ARG	Addr:word,Page:word,Len:word
	PENTER	0

	pushf			;make sure interrupts are off
	cli

	mov	ax,[DSP_DMA]
	or	ax,4h		     ;DMASET: Set bit (mask or request)
	out	0ah,al

	mov	bx,[DSP_DMA]
	mov	dx,80h		    ;DMAPAG: Base address
	add	dl,[DMAPAG_offset+bx]
	mov	ax,[Page]
	out	dx,al

	mov	al,0
	out	0ch,al		    ;DMACLFF: Clear Byte Pointer Flip Flop
                
	mov	dx,[DSP_DMA]
	shl	dx,1
	mov	ax,[Addr]
	out	dx,al		    ;DMAnADR: Channel n Current Address
	mov	al,ah
	out	dx,al

	mov	dx,[DSP_DMA]
	shl	dx,1
	add	dx,1
	mov	ax,[Len]
	out	dx,al		    ;DMAnCNT: Channel n Word Count
	mov	al,ah
	out	dx,al

	mov	ax,48h
	cmp	[BACKF],1	; In DMA backfill mode?
	jne	@@NOTBF
;; Set dma loop mode
	or	ax,16		; put that puppy in loop back mode!
@@NOTBF:
	or	ax,[DSP_DMA]
	out	0bh,al		    ;DMAMD: Write Mode Register

	mov	ax,[DSP_DMA]
	or	ax,0h		     ;DMARST: Reset bit (mask or request)
	out	0ah,al

	popf
	PLEAVE
	ret
	endp


;; This is the DMA transfer hardware interrupt.
PROC	DMA_IRQ far
	SetSemaphore
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	ds
	push	es
	cld

	mov	ax,cs
	mov	ds,ax		; Establish DGROUP addressability.

	mov	dx,[DSP_ADDR]	; Get DSP address.
	in	al,dx
	and	al,00000001b	    ;FIF0 interrupt?
	jz	@@EOI		     ;no, exit


	mov	dx,[DSP_DMA]
	shl	dx,1
	inc	dx
	in	al,dx		     ;DMAnCNT: Channel n Word Count
	mov	bl,al
	in	al,dx
	mov	ah,al
	mov	al,bl

	cmp	ax,0ffffh
	jne	@@EOI

	cmp	[BACKF],1
	je	@@EOI
	mov	ax,[DMA_len_l]	      ;at end of block?
	or	ax,[DMA_len_h]
	jz	@@end_of_block
	call	xfer_chunk	   ;no, send next chunk
	jmp	@@EOI
@@end_of_block:
	call IRQ_rest_vect	;else look for an unplayed buffer...
@@EOI:	mov	al,20h		    ;send EOI to PIC
	cmp	[DSP_IRQ],8	      ;clear PIC1 if IRQ >= 8
	jb	@@master
	out	0a0h,al
@@master:
	out 20h,al

@@exit: pop	es
	pop	ds
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax

	ClearSemaphoreIRET
	endp


Proc	DMA_transfer	near
	ARG	Addr:DWORD,LenL:WORd,LenH:word
	PENTER	0
	PushCREGS

	les	si,[Addr]
	mov	ax,[LenL]
	mov	dx,[LenH]

	mov	[WORD DMA_ptr],si
	mov	[WORD DMA_ptr+2],es
	mov	[DMA_len_l],ax
	mov	[DMA_len_h],dx

	call	xfer_chunk

	PopCREGS
	PLEAVE
	ret
	endp

;; This procedure transfers the next chunk-o-data on this DMA interrupt.
;; Trashes registers (will restore DS though).
Proc	xfer_chunk	near
	lds	si,[DMA_ptr]

	FAR_TO_HUGE ds,si	;DS:SI = start of data to send
	mov	di,ds
	and	di,0f000h
	add	di,1000h	    ;DI:0000 = start of next physical page

	push	di		; Seg 2
	mov	ax,0
	push	ax		; Offset 2
	push	ds		; Seg 1
	push	si		; Offset 1
	call	sub_ptr 	; Subtract pointers
	add	sp,8

	sub	ax,1
	sbb	dx,0
	mov	[cs:blk_len],ax 	 ;AX = # of bytes left in page -1

	mov	ax,[cs:DMA_len_l]	 ;set AX:DX = total # of bytes left -1
	mov	dx,[cs:DMA_len_h]
	sub	ax,1
	sbb	dx,0
	cmp	dx,0		    ;> 64K?
	ja	@@len_valid	     ;yes, send rest of current page only
	cmp	ax,[cs:blk_len] 	 ;> # of bytes left in page?
	ja	@@len_valid	     ;yes, send rest of current page only
	mov	[cs:blk_len],ax 	 ;else send all remaining data

@@len_valid:
	mov	ax,ds		    ;program DMA controller with chunk len
	mov	dx,0		    ;and addr
 REPT 4
	shl	ax,1
	rcl	dx,1
 ENDM
	add	ax,si
	adc	dx,0

	push	cs
	pop	ds

	push	[blk_len]
	push	dx
	push	ax
	call	program_DMAC
	add	sp,6

	call	hardware_xfer
                
	lds	si,[cs:DMA_ptr] 	 ;add len of chunk +1 to DMA pointer
	ADD_PTR [cs:blk_len],0,ds,si
	ADD_PTR 1,0,ds,si
	mov	[WORD cs:DMA_ptr],si
	mov	[WORD cs:DMA_ptr+2],ds

	push	cs
	pop	ds

	mov	ax,[DMA_len_l]	      ;subtract len of transmitted chunk +1
	mov	dx,[DMA_len_h]
	sub	ax,[blk_len]
	sbb	dx,0
	sub	ax,1
	sbb	dx,0
	mov	[DMA_len_h],dx
	mov	[DMA_len_l],ax

	cmp	[packing],4	      ;did we just send an initial chunk?
	jae	@@exit
	add	[packing],4	      ;yes, switch to "continue" opcode set

@@exit:
	ret			;return DX:AX = remaining bytes
	endp


;****************************************************************************
;; C callable interface to Adlib Gold card.
CPROC	InitAdlibGold
	ARG	IO:WORD
	PENTER	0
	PushCREGS

	pushf
	cli		; Need interrupts cleared during hardware startup.

	mov	ax,cs
	mov	ds,ax

	mov	ax,[IO]
	or	ax,ax		; If zero, then use default.
	jz	@@NOTIO
	mov	[IO_ADDR],ax	; Overide devault value.
@@NOTIO:
	mov	ax,[IO_ADDR]	; Get IO address.
	add	ax,2
	mov	[CTRL_ADDR],ax		;set I/O parms for control chip
	inc	ax
	mov	[CTRL_DATA],ax
	inc	ax
	mov	[DSP_ADDR],ax		;set I/O parms for sampling channels
	inc	ax
	mov	[DSP_DATA],ax

IF	SENSATION
	mov	ax,1
ELSE
	call	DetectAdlibGold 	; Detect Adlib Gold's presence.
	or	ax,ax
	jz	@@exit_init	       ;verify device, establish addresses
ENDIF
	call	enable_ctrl
	M_get_ctrl_reg 11h	;(Audio Selection)
	and	ax,11111100b	      ;set filters to playback mode
	M_set_ctrl_reg 11h,ax
	M_get_ctrl_reg 13h   ;(Audio IRQ/DMA Select - Channel 0)
	mov	[mask_save],ax
	mov	si,ax
	or	ax,10001000b	       ;(DEN0 | AEN)
	M_set_ctrl_reg 3h,ax
	call	disable_ctrl

	mov	ax,si
	and	ax,01110000b	      ;isolate DMA SEL 0 bits
	mov	cx,4
	shr	ax,cl
	mov	[DSP_DMA],ax		;record DMA channel in use

	and	si,00000111b	      ;isolate INT SEL A bits
	mov	al,[selected_IRQ+si]
	mov	[DSP_IRQ],ax		;record IRQ line in use

	call	reset_DSP

	mov	ax,[default_pan]
	mov	[panpot],ax
	mov	ax,[default_vol]
	mov	[main_volume],ax
	call	set_volume

	mov	[init_OK],1

	mov ax,1
@@exit_init:
	popf
	PopCREGS
	PLEAVE
	ret
	endp

Proc	PlaySound	near
	PushAll

	mov	[PlayingSound],1	; Turn playing sound flag true.

	push	dx		; Pass frequency.
	push	cx		; Pass length.
	push	es		; segment
	push	bx		; address.
	call	_PlayDigitalAudio
	add	sp,8		; balance stack.

	PopAll
	ret
	endp

Proc    TranslateSound  near
	PushAll 	; Save all registers.
	push	cx	; Length.
	push	es
	push	bx		; Address of sound effects.
	call	_FormatDigitalAudio
	add	sp,6	; balance stack.
	PopAll
	ret
	endp

CPROC	FormatDigitalAudio
	ARG	DATA:DWORD,SLEN:WORD
	PENTER	 0
	PushCREGS

	lds	si,[DATA]
	mov	cx,[SLEN]
	shr	cx,1
	pushf
@@GO:	xor	[word ds:si],8080h
	add	si,2
	dec	cx
	jnz	@@GO
	popf
	jnc	@@NOT
	xor	[byte ds:si],80h
@@NOT:

	PopCREGS
	PLEAVE
	ret
	endp


CPROC	PlayDigitalAudio
	ARG	DATA:DWORD,SLEN:WORD,FREQ:WORD
	PENTER	0
	PushCREGS

	mov	ax,cs
	mov	ds,ax

	push	[FREQ]	; Pass digital audio playback frequency.
	call	set_sample_rate ; Set card up for this sample rate.
	add	sp,2	; Balance stack every so prettily.


	push	cs
	lea	ax,[DMA_IRQ]	; Get address if interrupt processing routine.
	push	ax
	call	IRQ_set_vect
	add	sp,4


	xor	ax,ax		; high word of length is zero.
	push	ax
	push	[SLEN]		; Low word of sound length.
	push	[word DATA+2]
	push	[word DATA]
	call	DMA_transfer
	add	sp,8		; balance stack.

	PopCREGS
	PLEAVE
	ret
	endp


CPROC	SetDigitalVolume
	ARG	VOL:WORD
	PENTER	0
	PushCREGS

	mov	ax,cs
	mov	ds,ax

	pushf
	cli

	mov	ax,[VOL]
	mov	[main_volume],ax

	call	set_volume

	popf
	PopCREGS
	PLEAVE
	ret
	endp


CPROC	SetDigitalPanPot
	ARG	PAN:WORD
	PENTER	0
	PushCREGS

	mov	ax,cs
	mov	ds,ax

	pushf
	cli

	mov	ax,[PAN]
	mov	[panpot],ax

	call	set_volume

	popf
	PopCREGS
	PLEAVE
	ret
	endp

CPROC	GetDigitalPanPot
	mov	ax,[cs:panpot]
	ret
	endp

CPROC	GetDigitalVolume
	mov	ax,[cs:main_volume]
	ret
	endp


CPROC	ShutDownAdlibGold
	PushCREGS
	pushf

	mov	ax,cs
	mov	ds,ax
	cli

	cmp	[init_OK],0
	je	@@exit


;; Need to stop any DMA transfer in effect!

	call	enable_ctrl
	M_set_ctrl_reg 13h,[mask_save]
	call	disable_ctrl

	call	reset_DSP

	mov	[init_OK],0

@@exit:
	popf
	PopCREGS
	ret
	endp

ENDIF
;;

;;****************************************************************************
;; Sound Buffer translation routines go here!
;;****************************************************************************
IF	DIG_LANTSND

LANADR	FARPTR	<>		; Far address of lantastic voice driver.
VNUM	db	?
MY_VCB	VCB	<>		; My VCB

LanXLT	db	15,15,16,16,16,16,17,17,17,17,18,18,18,18,19,19,19
	db	19,20,20,20,20,21,21,21,21,22,22,22,22,23,23,23
	db	23,24,24,24,24,25,25,25,25,26,26,26,26,27,27,27
	db	27,28,28,28,28,29,29,29,29,30,30,30,30,31,31,31
	db	31,32,32,33,33,34,34,35,35,36,36,37,37,38,38,39
	db	39,40,40,41,41,42,42,43,43,44,44,45,45,46,46,47
	db	47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62
	db	63,65,67,69,71,73,75,77,79,83,87,91,95,103,111,255
	db	239,231,223,219,215,211,207,205,203,201,199,197,195,193,191,190
	db	189,188,187,186,185,184,183,182,181,180,179,178,177,176,175,175
	db	174,174,173,173,172,172,171,171,170,170,169,169,168,168,167,167
	db	166,166,165,165,164,164,163,163,162,162,161,161,160,160,159,159
	db	159,159,158,158,158,158,157,157,157,157,156,156,156,156,155,155
	db	155,155,154,154,154,154,153,153,153,153,152,152,152,152,151,151
	db	151,151,150,150,150,150,149,149,149,149,148,148,148,148,147,147
	db	147,147,146,146,146,146,145,145,145,145,144,144,144,144,143

Proc	TranslateSound	near
	PushAll

	cmp	dx,8000 		; <= 8khz?
	jle	@@TRANS 		; yes, just play it at 8.
@@DOWNIT:
	push	dx

	xor	dx,dx
	mov	ax,8000 		; base of 8khz.
	mov	dl,ah
	mov	ah,al
	xor	al,al			; Times 256
	pop	di
	div	di
@@MODIT:
	push	es
	pop	ds
	mov	si,bx		; DS:SI source address.
	mov	bx,si			; Save start address into BX.
	mov	di,si			; Initial destination address.
	push	ds
	pop	es			; ES=DS
	xor	ah,ah			; Zero build.
@@DOWN: movsb				; Store it.
	add	ah,al			; Add fraction.
	jnc	@@BACK			; If not carry, don't advance DI.
	loop	@@DOWN			; Keep downsampling.
	jmp short @@DON
@@BACK: dec	di			; Don't repeat last byte.
	loop	@@DOWN
@@DON:	mov	si,bx			; Get back base address.
	sub	di,bx			; Length.
	mov	cx,di			; into CX
	jmp short @@MULAW
@@TRANS:
	mov	si,bx
	push	es
	pop	ds
@@MULAW:
	mov	di,si
	lea	bx,[LanXLT]
@@CVT:	lodsb			; Get 8 bit audio sample.
	xlat	[cs:bx]
	stosb			; store mu_law data value.
	loop	@@CVT

	PopAll
	ret
	endp

Proc	PlaySound	near
	mov	si,bx
	cmp	dx,8000
	jle	@@OK
	push	dx
	mov	ax,cx
	mov	bx,8000
	mul	bx
	pop	bx
	div	bx
	mov	cx,ax
@@OK:	mov	ax,cs
	mov	ds,ax		; DS=CS ES=Segment of audio sample.

	mov	[MY_VCB.VCB_command],(VCB_CMD_SEND+VCB_no_wait)     ; Send!
	mov	[MY_VCB.VCB_buffer@.XPTR.PSEG],es
	mov	[MY_VCB.VCB_buffer@.XPTR.POFF],si
	mov	[MY_VCB.VCB_length],cx
	mov	[MY_VCB.VCB_post@.XPTR.PSEG],cs
	mov	[MY_VCB.VCB_post@.XPTR.POFF],offset SoundDone
	mov	[MY_VCB.VCB_vca_num],0
	mov	[MY_VCB.VCB_word_format],VWFM_mu_law	; mu-law companding
	mov	[MY_VCB.VCB_rpt_count],0

	push	ds
	pop	es			;; ES=DS=CS
	lea	bx,[MY_VCB]		;; VCB address.
	call	[LANADR.DPTR]		;; Far call to lanvoice interface.
	ret
	endp

Proc	SoundDone	far
	SetSemaphore
	mov	[cs:PlayingSound],0
	cmp	[cs:CallBacks],0	; Callbacks enabled?
	je	@@GOUT		; no, exit.
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
@@GOUT: ClearSemaphoreIRET
	iret
	endp

Proc	StopSound	; not currently implemented.
	ret
	endp

ENDIF

IF	DIG_ECHOII
Proc	TranslateSound near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; Registers DX,CX,ES,BX,DS must be saved.
	push	bx
	push	cx
	push	dx
	push	di

	mov	di,bx		; becomes dest.
	cld
@@DOT:	mov	al,[es:di]	; Get full 8 bit unsigned sample.
	add	al,128
	or	al,01
	cmp	al,80h
	jne	@@OK
	inc	al
@@OK:	stosb			; Store result
	loop	@@DOT		; Complete the translation process.

	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
	endp

ENDIF

IF	DIG_TANEXTX
;; The original logarithmic 8-4 bit translate table.  This table
;; was designed to accept signed data as the source however.
LABEL	TransTable BYTE
	db	   6, 6, 6, 6, 5, 5, 5, 5, 5, 5, 5, 5
	db	   5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 4
	db	   4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4
	db	   4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 3
	db	   3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
	db	   3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2
	db	   2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2
	db	   2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	db	   1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
	db	   1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0
	db	   0, 0, 0, 0, 0, 0, 0, 0, 15, 15, 15, 15
	db	   15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15
	db	   15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15
	db	   15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15
	db	   15, 15, 15, 14, 14, 14, 14, 14, 14, 13, 13, 13
	db	   13, 13, 13, 12, 12, 12, 12, 12, 12, 12, 12, 11
	db	   11, 11, 11, 11, 11, 11, 11, 10, 10, 10, 10, 10
	db	   10, 10, 10, 10, 10, 9, 9, 9, 9, 9, 9, 9
	db	   9, 9, 9, 9, 8, 8, 8, 8, 8, 8, 8, 8
	db	   8, 8, 8, 8, 7, 7, 7, 7, 7, 7, 7, 7
	db	   7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 6
	db	   6, 6, 6, 6

Proc	TranslateSound near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; Registers DX,CX,ES,BX,DS must be saved.
	push	bx
	push	cx
	push	dx
	push	di

	mov	di,bx		; becomes dest.
	add	bx,cx
	dec	bx
	mov	[byte es:bx],0	     ; Turn volume down to zero when done!
	lea	bx,[TransTable]
	cld
@@DOT:	mov	al,[es:di]	; Get full 8 bit unsigned sample.
	sub	al,128		; Make it signed 8 bit data.
	xlat			; Translate against table.
	or	al,90h		; Or Tandy Volume sound channel.
	stosb			; Store result
	loop	@@DOT		; Complete the translation process.

	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
	endp

Proc	_tinit	near
	push	bx
	push	cx

; This routine initilizes the Tandy for digitized sound outzut on channel 0
        in      al,61h           ; get Port B of 8255
        or      al,01100010b     ; route sound through TI chip
        out     61h,al           ; update Port B
        mov     bx,1             ; frequency countdown 1
        mov     al,00001000b     ; bit pattern in low nibble to update
        mov     ah,al            ; sav reg spec
        mov     cl,4             ; prepare to shift
        sal     ah,cl
        mov     al,bl            ; low 8 bits
        and     al,0fH           ; we need only the low 4 bits
        or      al,ah            ; or in the reg spec
        out     0C0h,al
        mov     cl,4
        shr     bx,cl            ; shift down high 6 bits
        mov     al,bl
        and     al,3fH           ; only 6 bits
        out     0C0h,al

	pop	cx
	pop	bx
        ret
	endp


ENDIF
IF	DIG_ADLIB
alxlat		db	63,63,62,54,50,46,44,42,40,38,38,37,36,35,34,33
		db	32,31,30,30,30,29,28,28,27,27,26,26,25,25,25,24
		db	24,23,23,23,22,22,22,21,21,21,21,20,20,20,19,19
		db	19,19,19,18,18,18,18,17,17,17,17,17,17,16,16,16
		db	16,15,15,15,15,15,15,15,14,14,14,14,14,13,13,13
		db	13,13,13,13,12,12,12,12,12,12,12,12,11,11,11,11
		db	11,11,11,11,10,10,10,10,10,10,10,10,10,10,9,9
		db	9,9,9,9,9,9,8,8,8,8,8,8,8,8,8,8
		db	8,8,7,7,7,7,7,7,7,7,7,7,7,6,6,6
		db	6,6,6,6,6,6,6,6,6,6,5,5,5,5,5,5
		db	5,5,5,5,5,5,5,4,4,4,4,4,4,4,4,4
		db	4,4,4,4,4,4,3,3,3,3,3,3,3,3,3,3
		db	3,3,3,3,3,3,3,2,2,2,2,2,2,2,2,2
		db	2,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1
		db	1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0
		db	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
Proc	TranslateSound near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; Registers DX,CX,ES,BX,DS must be saved.
	push	bx
	push	cx
	push	dx
	push	di

	mov	di,bx		; becomes dest.
	cld
	lea	bx,[alxlat]	; Adlib translate table.
@@DOT:	mov	al,[es:di]	; Get full 8 bit unsigned sample.
	xlat
	stosb			; Store result
	loop	@@DOT		; Complete the translation process.

	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
	endp

;;; Adlib board specific equates.
ADDR_DELAY	equ	10	; 3812 address write delay
DATA_DELAY	equ	40	; 3812 data write delay
TIMER		equ	40H	; 8253 timer I/O addr
TIMER0		equ	(TIMER+0)	; 8253 counter-0 addr
TIMER_MODE	equ	(TIMER+3)	; 8253 mode register addr
F_NUM		equ	655	; constant for 0.25 Khz
BLOCK		equ	3	; ""  "" 
DELAY_COUNT 	equ	(1193*2) ; 1/4 cycle of 250Hz count ( 1193180 / 1000)
				; *2 because timer count down by 2

; 65536/1193180 * 256M
LOOP_DIVH	equ	0d6H
LOOP_DIVL	equ	8d7eH


; PrepareToSampleOut()
;
; This routine start the oscillator whith a frequency of 250 Hz, and
; wait until 1/4 of the first period (sin). Then set the frequency to 0,
; in order to block the internal level to its maximum.
; If the voice 0 is used only for sampling, call this routine once;
; otherwise call before every time you call 'OutSample()'
;
Proc	PrepareToSampleOut     near
	mov	ax,[AdlibIO]
	inc	ax
	mov	[PORTMOD+1],ax		; Adlib port address.

	mov	dx,[cs:AdlibIO]    ; Get the adlib board I/O address.

; set some parameters of voice-0:
	mov	ax, 02021H	; am= 0, vib= 0, eg-type= 1, ksr= 0, multi= 1
	call	OutAdlib
	mov	ax, 060f0H	; attack rate == MAX, decay rate = MIN
	call	OutAdlib
	mov	ax, 080f0H	; sustain level = MAX, release rate = MIN
	call	OutAdlib
	mov	ax, 0C001H	; feed-back= 0, connection = 1 (additive)
	call	OutAdlib
	mov	ax, 0E000H	; wave-select = 0 (sinus)
	call	OutAdlib
	mov	ax, 0433fH	; voice-0, slot-1 = MAX attenuation
	call	OutAdlib

; make sure that voice-0 is off:
	mov	ax, 0B001H	; voice 0, f_num = 256
	call	OutAdlib

; start note-on on voice-0 with freq. of 250 Hz:
	mov	ax, 0A000H+(F_NUM AND 0ffH)	; set 250 Hz
	call	OutAdlib
	mov	ax, 0B000H+20H+(BLOCK SHL 2)+(F_NUM SHR 8)
	call	OutAdlib

; disable interrupt for timing section:
	cli

; Time 1/4 of period using the timer-0 of the system. The timer frequency
; is 1193180 Hz.
	mov	al, 00H		; latch counter-0
	out	TIMER_MODE, al
	in	al, TIMER0	; low byte
	mov	bl, al
	in	al, TIMER0	; high byte
	mov	bh, al		; count in BX

; wait until timer-2 down by DELAY_COUNT:
@@LP3:	mov	al, 00H 	; latch counter-0
	out	TIMER_MODE, al
	in	al, TIMER0	; low byte
	mov	cl, al
	in	al, TIMER0	; high byte
	mov	ch, al		; assemble 16 bits word in DX
	neg	cx
	add	cx, bx		; start - end
	cmp	cx, DELAY_COUNT
	jb	@@LP3

; time-out...
; block frequency of voice-0:
	mov	ax, 0B000H+20H	; set high bits of f_num and block to 0
	call	OutAdlib
	mov	ax, 0A000H	; set f_num to 0
	call	OutAdlib

	sti

; set address register to Total-Level of oper-0, voice 0
	mov	al,40H
	out	dx,al
	inc	dx		; dx = port +1

; small delay...
	in	al, dx
	in	al, dx
	in	al, dx
	in	al, dx
	in	al, dx

	ret
	endp


; Output addr and data to Adlib Board.
;
; AH: addr
; AL: data
; DX: io port
;
; lost: AX
Proc	OutAdlib NEAR
	push	cx			; Preserve CX register.
	push	ax			; Preserve AX register.
	mov	al, ah			; Get high byte to send.
	out	dx, al			; send it.

	mov	cx, ADDR_DELAY		; Loop count for address delay.
@@LP4:	in	al, dx			; Poll in-port for delay.
	loop	@@LP4			; keep looping.

	inc	dx			; Advance to data portion.
	pop	ax			; Get back data byte to send.
	out	dx, al			; Send the data byte.
	dec	dx			; Back DX off to the address again.

	mov	cx, DATA_DELAY		; Get the data delay.
@@LP5:	in	al, dx			; Read in-port for delay.
	loop	@@LP5			; keep looping.

	pop	cx			; Restore caller's CX register.
	ret
	endp

ENDIF
IF	DIG_IBMSND OR DIG_IBM1BIT OR DIG_IBMBAK
;; Same audio buffer translate for any data going out to the internal speaker.
MAXTIME 	equ	58
FRAMESIZE	equ	2048
MINDELTA	equ	40
Proc	TranslateSound
	PushAll
	call	MassageSound	; Massage it to maximumal volume.
	call	MaximizeAudio	; into TIMER2 interupt value range.
	PopAll
	ret
	endp

Proc	MassageSound	near
	push	ds
	push	si
	push	dx		; Save rate.
	push	cx
	push	bx		; Save starting address.

	push	es		; ES=DS
	pop	ds		;
	mov	si,bx
	mov	di,bx		; Get starting address.

@@MLD:	push	cx		; Save current count
	cmp	cx,FRAMESIZE
	jbe	@@LAST
	mov	cx,FRAMESIZE	 ; Modulate in frames of 256
@@LAST:
	call	MassageFrame	; massage the data in this frame.
	pop	cx		; Get back the count.
	cmp	cx,FRAMESIZE
	jbe	@@OUT
	sub	cx,FRAMESIZE	; Decrement loop counter by frame size.
	jmp short @@MLD

@@OUT:

	pop	bx
	pop	cx
	pop	dx
	pop	si
	pop	ds
	ret
	endp


Proc	MassageFrame	near
;; CX -> number of samples to do loudening on.
	mov	bx,255	; BL ->minimum encountered, BH maximum encounterd.
	push	cx
@@MNMX: lodsb		; Get data sample
	cmp	al,bl	; below minimum encountered so far?
	jae	@@NMN	; No, skip
	mov	bl,al	; New minimum.
@@NMN:	cmp	al,bh	; > maximum found so far?
	jbe	@@NMX	; no, skip.
	mov	bh,al	; New maximum data sample.
@@NMX:	loop	@@MNMX	; Keep looking.
	pop	cx

	mov	dl,bh	; Get the maximum.
	sub	dl,bl	; Minus the minumum.
	inc	dl	; Plus one
	cmp	dl,2	; Must be at least two.
	jae	@@ML
	mov	dl,2	; Set divisor to a two.
@@ML:	cmp	dl,MINDELTA   ; If change is small?
	jae	@@US
	mov	di,si
	ret

@@US:	mov	si,di	; Back to current address.
@@MLD:	lodsb		; Get data sample.
	sub	al,bl	; Minus minum, gives us delta.
	mov	ah,al	; Into AH
	xor	al,al	;*256
	div	dl	; Divided by dl.
	stosb		; Store modulated data sample.
	loop	@@MLD

	ret
	endp

IF	DIG_IBM1BIT
CUTOFF	equ	128
Proc	MaximizeAudio	near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; Modify sample brought in.
	push	es
	push	ds
	push	si
	push	cx

	in	al,61h		; Get current Port B byte
	and	al,(NOT 3)
				; 0 and 1 is off.
				; bit 0 = don't gate for timer 2
                                ; bit 1 = speaker on
        out     61h,al          ; store it back  

@@OKF:	mov	si,bx
	mov	di,bx
	mov	ax,es
	mov	ds,ax		; DS:SI source audio address.
	in	al,61h
	and	al,(NOT 1)	; Speaker off and not timer-2 hooked.
	mov	ah,al		; Into AH
@@MOD:	lodsb			; Get source data sample.
	cmp	al,CUTOFF
	ja	@@ON
	mov	al,ah
	stosb
	loop	@@MOD
	jmp short @@OUT
@@ON:	mov	al,ah
	or	al,2		; Speaker on bit.
	stosb			; Store result.
	loop	@@MOD
@@OUT:
	pop	cx
	pop	si
	pop	ds
	pop	es
	ret
	endp
ELSE
Proc	MaximizeAudio	near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; Modify sample brought in.
	mov	di,bx
@@MOD:	mov	al,[es:di]	; Get audio sample.
	shr	al,1		; Divide it by two.
	shr	al,1		; Divide it by four.
@@OK1:	cmp	al,51		; Too big for it's britches?
	jbe	@@OK		; no->fits just fine.
	mov	al,51		; Just use maximum.
@@OK:	inc	al
	stosb			; Store result.
	loop	@@MOD
	ret
	endp
ENDIF
ENDIF

IF	DIG_MASTER
Proc	PlaySound
	push	dx	;Frequency.
	push	cx	;Length of sound sample.
	push	es	; Segment
	push	bx	; Offset.
	call	_asmplay
	add	sp,8
	ret
	endp

Proc	StopSound
	ret
	endp

	MASM
	JUMPS

; 
; The following constants hard wire this code to a specific
;  set of jumper settings.  Depending on application, they might
;  be variables
;
;
; The following defines are API specific
;
UNSIGNED_DATA equ 1	;; The card uses signed data as it's native
			;; format.  Since unsigned is the standard for 8 bit
			;; audio, this code will do an on the fly translation
			;; if UNSIGNED_DATA is non zero
;
; **************************************************************
;  **                                                           **
;  ** THE FOLLOWING ARE HARDWARE SPECIFIC DEFINES               **
;  **   NOT ALL OF THEM ARE USED                                **
;  **                                                           **
;  **                                                           **
;  **************************************************************
;  Register offsets:
HOST_STAT_REG_OFFSET		EQU		000000003h
HOST_DATA_REG_OFFSET		EQU		000000002h
STAT_REG_OFFSET		EQU		000000000h
DATA_REG_OFFSET		EQU		000000001h
;  Host Control Register bits
;  When this bit low, card is reset.  When high card runs
HCR_RESET		EQU		000000080h
;  When this bit low, card interrupts are disabled
HCR_INTERRUPT		EQU		000000040h
;  When this bit low, card audio is muted
HCR_MUTE		EQU		000000020h
;  When this bit high, line input enabled
HCR_LINE		EQU		000000008h
;  When this bit is high, interrupts from host to PC are enabled
HCR_HOST_RX_INT		EQU		000000001h
;  Host status resgister bits
;  When bit set, there is data from the card
HSTAT_DAV		EQU		000000002h
;  When bit set, card is ready for data
HSTAT_RFD		EQU		000000020h
;  Define the normal HCR values we will use
;  Note: this is where a mic/line selection is made for recording
;NORM_HCR_VALUE		EQU		0000000e9h
HCR_BASE_VALUE		equ		HCR_RESET OR HCR_MUTE OR HCR_LINE OR HCR_HOST_RX_INT
HCR_VALUE_INTS_ON	equ 		HCR_BASE_VALUE or HCR_INTERRUPT
HCR_VALUE_INTS_OFF	equ 		HCR_BASE_VALUE
;  Messages from board
;  Ack coming back from last message sent
HMSG_ACK		EQU		000000080h
;  The current DMA operation is done.  You may free or re-use the buffer
HMSG_DMA_DONE		EQU		000000081h
;  The current digital audio buffer is empty (send next one)
HMSG_BUF_EMPTY		EQU		000000082h
;  Playback has stopped (buffer underflow)
HMSG_PLAY_STOP		EQU		000000083h
HMSG_RECORD_OVF		EQU		000000085h
HMSG_MIDI_XOFF		EQU		000000086h
HMSG_MIDI_XON		EQU		000000087h
HMSG_DMA_PAGE0		EQU		000000090h
HMSG_DMA_PAGE1		EQU		000000091h
HMSG_DMA_PAGE2		EQU		000000092h
HMSG_DMA_PAGE3		EQU		000000093h
;  Commands to board
HCMD_OPEN_PCM_CHAN		EQU		00000008ch
HCMD_START_PCM_PLAY		EQU		00000008dh
HCMD_DNLOAD_PCM_BLOCK		EQU		00000008eh
HCMD_CLOSE_PCM_CHAN		EQU		000000090h
;  get number of synth voices
HCMD_GET_NUM_VX		EQU		000000094h
HCMD_ENTER_RECORD		EQU		000000097h
HCMD_START_RECORD		EQU		000000098h
;  Size of the DMA buffers in all formats
DMA_BUFFER_SIZE_16m		EQU		1000h
DMA_BUFFER_SIZE_8m		EQU		0800h
DMA_BUFFER_SIZE_16s		EQU		000002000h
DMA_BUFFER_SIZE_8s		EQU		1000h
DMA_BUFFER_SIZE_MAX		EQU		000002000h
;  In order to have a delay this is not overly CPU speed 
;  * dependent, it is nice to have a register that may safely
;  * be read to generate an i/o wait state
;  
;  This is an arbitrary number. 
MAX_POLL		EQU		40000d
;  Number of times to poll when waiting for response from card
; ************** General defines we need ************
; **************************************************************
;  **                                                           **
;  **  DMA CONTROLLER DEFINES                                   **
;  **                                                           **
;  **                                                           **
;  **                                                           **
;  **************************************************************
; **************************************
; 	Single mask register bits	
; 	      (Write only)		
; **************************************
;  Disable DMA request for selected channel	
DISABLE_DMA_REQ		EQU		000000004h
;  Enable DMA request for selected channel	
ENABLE_DMA_REQ		EQU		000000000h
; ******************************
;  	Mode register bits 	
; 	     (Write only)	
; ******************************
;  Transfer types for selected channel 
;  write transfer mode 
WRITE_TRANSFER		EQU		000000004h
;  read transfer mode 
READ_TRANSFER		EQU		000000008h
;  Address increment/decrement for selected channel 
;  increment addresses 
ADDRESS_INCREMENT		EQU		000000000h
;  decrement addresses 
ADDRESS_DECREMENT		EQU		000000020h
;  DMA service modes for selected channel 
;  select demand mode 
DEMAND_MODE		EQU		000000000h
;  select single mode 
SINGLE_MODE		EQU		000000040h
;  select block mode 
BLOCK_MODE		EQU		000000080h
;  select cascade mode 
CASCADE_MODE		EQU		0000000c0h
; **************************************************************
;  	General register addresses for DMA controller 1 	
; 			(Channels 0 through 3)			
; **************************************************************
;  DMA1 single mask register
; 						(write only)		 
DMA1_SGL_MASK_REG		EQU		00000000ah
;  DMA1 mode register (write only) 
DMA1_MODE_REG		EQU		00000000bh
;  Read to clear byte pointer
; 						flip-flop		 
DMA1_CLEAR_FF		EQU		00000000ch
;
;************************************************************************
;************************************************************************
;************************************************************************
;************************************************************************
;************************************************************************
;
;***************** Here is the data segment (if used) **********
;
    ;
    ; two DMA buffers. Only one is used, second one is in
    ; case the first one is on a page boundary
    ;
possible_buffer1 db DMA_BUFFER_SIZE_8m dup (0)
possible_buffer2 db DMA_BUFFER_SIZE_8m dup (0)
    ;
ddmaptr  dd 0		    ;; far pointer to the current dma buffer
dmaphys dd 0		    ;; physical address of "    "
_dma_buffer_size dw ?	    ;; bytes in 	 "              "
			    ;; Note: if steroe or 16 bit used, this would be variable
    ;
_waitforstart	dw	0	   ;; flag
count		dw	0
pointer 	dd	0
bufferhasdata	db	0

dma_page_register db 087h, 083h, 081h , 082h
save_vector dd 0
save_imr db 0

;
;************************ Here is the code segment ***********
; 
;******************** commands to cards ************
;cmd in bl
;sends to host port
commandtocard proc near
    push cx
    mov cx, 3000
    mov dx, [card_address]
    add dx, HOST_STAT_REG_OFFSET
wait_rfd:
    in al, dx
    test al, HSTAT_RFD
    jne are_ready_for_data
    loop wait_rfd
    stc
    jmp short out_common
    ;
are_ready_for_data:
    dec dx			;;point to data register
    mov al, bl
    out dx, al
    clc
out_common:
    pop cx
    ret
commandtocard endp
;
;***************** Some macros and procs for ISR vector manipulation **********
;
POINT_TO_ISR macro
    mov ax, [cs:cur_int]
    add ax, 8			;get software int number for 8086
    shl ax,1
    shl ax,1			;make into pointer to dwords
    mov si, ax
    xor ax, ax
    mov es, ax			;es:si points to int vector
    endm
;
SETUP_ISR macro
    POINT_TO_ISR
    ;
    mov ax, es:[si]
    mov word ptr save_vector, ax
    mov ax, es:[si + 2]
    mov word ptr save_vector + 2, ax	;save off vectors
    ;
    mov ax, offset _irqhandler
    mov es:[si], ax
    mov ax, cs
    mov es:[si+2], ax			;set up new vector
    ;
    in al, 21h				;read the imr
    mov save_imr, al			;save it
    mov bl, al				;put in bl
    mov al, 1
    mov cl, [byte ptr cs:cur_int]
    shl al, cl				;put a bit in the int position
    not al				;put a zero in the position
    and al, bl				;leave the other bits alone
    out 21h, al				;and enable ints
    endm
;
REMOVE_ISR proc near
    POINT_TO_ISR
    mov ax, word ptr save_vector
    mov es:[si], ax
    mov ax, word ptr save_vector + 2
    mov es:[si+2], ax			;restore the vector
    ;
    mov al, save_imr
    out 21h, al				;restore the int mask reg
    ;
    mov dx, [card_address]
    add dx, HOST_STAT_REG_OFFSET
    mov al, HCR_VALUE_INTS_OFF
    out dx, al				;;disable card ints
    ret
remove_isr endp
;   
;********************** start moving data ***************
;
; This is the big function that starts everything
;
;sample rate in cx
startmovingdata proc near
    SETUP_ISR				;; install the isr vectors and program the PIC chip
    mov dx, [card_address]
    add dx, HOST_STAT_REG_OFFSET
    mov al, HCR_VALUE_INTS_ON
    out dx, al				;;make sure HCR has correct value (card running, irq on)
    ;
    mov bl, HCMD_OPEN_PCM_CHAN
    call commandtocard			;;open a pcm channel
    mov bl, cl
    and bl, 7fh
    call commandtocard			;send first 7 bits of rate
    mov ax, cx
    shl ax, 1
    mov al, ah			
    and al, 7fh		
    mov bl, al
    call commandtocard			;send 2nd 7 bits of rate    
    mov al, ch
    mov cl, 6
    shr al, cl
    and al, 3
    mov bl, al
    call commandtocard			;last bits of rate
    mov bl, 2 				;format command for 8 bit mono
    call commandtocard			;send format
    xor ax, ax
    call _filldmabuffer			;fill a DMA buffer with data
    mov _waitforstart, 1		;set flag for ISR (we will start from isr when
					;  first buffer done downloading)
    call _dnloaddmabuffer		;download the first buffer to the card
    xor ax, ax
    ret
startmovingdata endp
;
;*********************** dnloaddmabuffer ******************
public _dnloaddmabuffer
_dnloaddmabuffer proc near
    cmp bufferhasdata, 0
    jne @@hop
	xor ax, ax
	ret
@@hop:
    call _dmastart			;start the dma controller
    mov bl, HCMD_DNLOAD_PCM_BLOCK
    call commandtocard
    xor ax, ax
    ret
_dnloaddmabuffer endp

;********************** fill dma buffer ***********************
public _filldmabuffer
_filldmabuffer proc near
    ;********************** do a block move into the current buffer
    cld
    push si
    push di
    push ds

    mov ax, count			;;how much data left
    or ax, ax
    jne @@hop1				    ;;go up if some left
    pop ds

    jmp send_flag			;;if none left, flag as such and leave
@@hop1:
    ;----------------- now do the block move to DMA buffer --------
    
    mov cx, _dma_buffer_size		;bytes to move
    les di, ddmaptr			;point es:di to dma buffer
    lds si, pointer			;point ds:se to data
    shr cx, 1				;number of words to move
if UNSIGNED_DATA
    push bp
    mov bp, 8080h			;set up mask for signed unsigned conversion
signed_loop:
    lodsw				;get two signed samples
    xor ax, bp				;convert to unsigned
    stosw				;save them
    loop signed_loop			;do all samples
    jnc @@hop2				    ;was there an odd number?
    lodsb 
    xor ax,bp				;do the odd byte
    stosb
@@hop2:
    pop bp
else
    rep movsw
endif
    pop ds
    ;*******
    mov ax, count
    cmp ax, _dma_buffer_size		;did we just xfer more bytes that are left in RAM?
    jae @@hop3				    ;go up if not
    ;
    ; zero out the buffer
    ;
    les di, ddmaptr			;point es:di to dma buffer
    add di, count			;point to the first byte to get rid of
    mov cx, _dma_buffer_size
    sub cx, count			;find number of bytes till end of buffer
    xor ax, ax
    rep stosb				;zero out what is left
    mov count, ax			;our count is now zero
    jmp short mov_common
    ;----------
@@hop3:
    mov word ptr pointer, si		;save the next pointer location (64 limit)

    mov ax, count
    sub ax, _dma_buffer_size
    mov count, ax	;count down data
mov_common:
    mov al, 1
send_flag:
    mov bufferhasdata, al		;set the flag for more data
    ;
    pop di
    pop si
    xor ax, ax
    ret
_filldmabuffer endp
;
;****************************** ISR **************************
;
do_286 equ 0				;make work on all machines
push_all_regs	macro
		push	es
		push	ds
		if do_286
		    pusha
		else
		    push	dx
		    push	cx
		    push	bx
		    push	si
		    push	di
		    push	ax
		    push	bp
		endif
		endm
;
pop_all_regs	macro
		if do_286
		    popa
		else
		    pop	bp
		    pop	ax
		    pop	di
		    pop	si
		    pop	bx
		    pop	cx
		    pop	dx
		endif
		pop	ds
		pop	es
		endm
;
;
public _IRQHandler 
_IRQHandler proc far
	SetSemaphore
    push_all_regs
    mov ax, cs
    mov ds, ax
irq_loop:
    call readhost
    jc no_host				;;leave if nothing from host
    cmp al, HMSG_DMA_DONE
    jne not_dma_done
    ;
    call _FillDmaBuffer			;fill the next dma buffer
    test _waitforstart, not 0		;are we in the startup proc?
    je irq_loop				;if not, look for more messages
    xor ax, ax	
    mov _waitforstart, ax		;clear this flag
    call _dnloaddmabuffer		;send the second initial buffer
    mov bl, HCMD_START_PCM_PLAY
    call commandtocard
    jmp short irq_loop		;;and look for more messages
    ;-----------
not_dma_done:
    cmp al, HMSG_BUF_EMPTY
    jne not_buf_empty
    ;
    call _dnloadDmaBuffer
    jmp short irq_loop
    ;-----------
not_buf_empty:
    cmp al, HMSG_PLAY_STOP
    jne not_play_stop
    ;
    mov bl, HCMD_CLOSE_PCM_CHAN
    call commandtocard 
    xor al, al
    mov cs:PlayingSound,0
    call remove_isr
    jmp short irq_loop
    ;--------
not_play_stop:
    jmp short irq_loop
    ;--------
no_host:
    mov al, 20h
    out 20h, al
    pop_all_regs
    ClearSemaphoreIRET
_IRQHandler endp
;
readhost proc near
    mov dx, [card_address]
    add dx, HOST_STAT_REG_OFFSET		;;dx points to stat register
    in al, dx					;;read the stat reg
    test al, HSTAT_DAV				;;data available?
    je @@hop4					    ;; go up if not
    dec dx			;;point to the data reg
    in al, dx			;;read the host message
    clc				;;return ok
    ret
    @@hop4:
    stc 			;;return error
    ret
readhost endp
;
;********************** dma start ************
public _dmastart
_dmastart proc near
    push si
    mov al, [byte ptr cs:cur_dma_channel]
    or al, DISABLE_DMA_REQ
    out DMA1_SGL_MASK_REG, al	;disable dma xfers on our channel
    ;
    mov bx, word ptr dmaphys + 0
    mov cx, word ptr dmaphys + 2	;cx:bx has the physical address of buff 1
    mov si, offset dma_page_register
    add si, [cs:cur_dma_channel]
    mov dl, [si]			;get the page register for this channel
    xor dh, dh
    mov al, cl				;get the page of our buffer
    out dx, al				;and send it
    ;
    mov al, [byte ptr cs:cur_dma_channel]
    or al, (ADDRESS_INCREMENT or DEMAND_MODE or READ_TRANSFER)
    out DMA1_MODE_REG, al	;send the mode to the DMA controller
    ;
    xor al, al
    out DMA1_CLEAR_FF, al	;clear the dma ff
    ;
    mov dx, [cs:cur_dma_channel]
    add dx, dx			;point to chan * 2 = low buffer address
    mov al, bl
    out dx, al			;write out low byte of address
    mov al, bh
    out dx, al			;write out hight byte
    ;
    inc dx			;point to dma count register
    mov ax, _dma_buffer_size
    dec ax			;get dma count - 1
    out dx, al
    mov al, ah
    out dx, al			;write the count
    ;
    mov al, [byte ptr cs:cur_dma_channel]
    or al, ENABLE_DMA_REQ
    out DMA1_SGL_MASK_REG, al	;start dma
    ;
    pop si
;;    call _finishdma
    xor ax, ax
    ret
_dmastart endp
;
;*********************** the function **********************
stack struc
bpstore dw ?
xretn dw ?
arg_ptr dd ?
arg_count dw ?
arg_rate dw ?
stack ends
;
SETUP_DMA_BUFFER macro
    mov _dma_buffer_size, DMA_BUFFER_SIZE_8m	;;if different formats supported
						;; could be variable
    mov ax, offset possible_buffer1
try_again:
    mov word ptr ddmaptr, ax
    mov ax, cs
    mov word ptr ddmaptr + 2, ax
    
    xor dx, dx
    mov cx, 4
@@bip1:
    shl ax,1
    rcl dx,1
    loop @@bip1
    ;				now dx:ax has ds * 4
    add ax, word ptr ddmaptr
    adc dx, 0
    mov word ptr dmaphys, ax
    mov word ptr dmaphys + 2, dx		;; save off physical address
    ;
    add ax, _dma_buffer_size
    jnc @@hop5					    ;;are we crossing a page boundary?
	mov ax, offset possible_buffer2		;; if so, use the other buffer
	jmp try_again
    @@hop5:
    endm


;
public _asmplay
_asmplay proc near
    push bp
    mov bp, sp
    push si
    push di
    push es
    push ds
    ;
    mov ax, cs
    mov ds, ax
    ;
    SETUP_DMA_BUFFER
    ;
    mov cs:PlayingSound, 1			 ;set flag that we are running
    ;
    les si, [bp].arg_ptr
    mov word ptr pointer, si
    mov word ptr pointer + 2, es
    ;
    mov ax, [bp].arg_count
    mov count, ax
    ;
    mov cx, [bp].arg_rate
    call startmovingdata
    ;
    cld
    pop ds
    pop es
    pop di
    pop si 
    pop bp
    ret
_asmplay endp
;
;********************** CARD TEST/RESET ROUTINE ***************
;
;
;********* misc macros etc... ****
;
    WAIT_A_BIT macro
    push cx
    mov cx, 30000
bit_loop:
    in al, dx			;do some cpu speed independent delays
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    in al, dx
    loop bit_loop
    pop cx
    endm
;
WAIT_A_LONG_TIME macro
    push cx
    mov cx, 7
wait_loop:
    WAIT_A_BIT
    loop wait_loop
    pop cx
    endm

;
reset_card macro
    mov dx, [card_address]
    add dx, HOST_STAT_REG_OFFSET
    mov al, 0
    out dx, al			;reset the cpu
    ;
    in al, dx			;delay an i/o cycle
    mov al, HCR_VALUE_INTS_OFF
    out dx, al			;let cpu run now
    WAIT_A_LONG_TIME		;and wait untill it is running
    endm
;
;
test_card proc near
    mov al, 1
    call test2			
    jnc @@hop6			    ;leave if ok
    mov al, 0
    call test2
@@hop6:
    ret
test_card endp
;
test2 proc near
    call empty_messages
    jc @@hip7
    call hardwarealive
    @@hip7:
test2 endp
;   
alive_flag db ?
hardwarealive proc
    mov alive_flag, al
    mov cx, 25		;try 25 times to get a response
alive_loop:
    mov bl, HCMD_GET_NUM_VX
    call commandtocard    	;ask card how many synth voices it has
    call getmsg		;read response
    jc no_good_msg	;go up if none
    cmp al, 12
    jb no_good_msg
    cmp al, 24
    ja no_good_msg	;valid numbers are 12..24
    clc
    ret			;return ok if card is alive
    ;
no_good_msg:
    ;
    test alive_flag, 1	;are we being tested for the first time?
    je second_time	;go up if not
    reset_card		;if first time, reset the card
    jmp short aliveout	;and leave with error set
    ;-----------
second_time:
    push cx
    mov dx, [card_address]
    add dx, HOST_STAT_REG_OFFSET
    mov al, HCR_VALUE_INTS_OFF
    out dx, al		;make sure card awake and ints off
    mov cx, MAX_POLL
wake_loop:
    in al, dx		;read the card
    test al, 055h
    je woken_up
    loop wake_loop
woken_up:
    pop cx
    ;
    loop  alive_loop
aliveout:
    stc
    ret
hardwarealive endp
;
empty_messages proc near
    mov cx, MAX_POLL
empty_loop:
    call readhost
    jnc are_notempty
    clc
    ret
are_notempty:
    loop empty_loop
    stc
    ret
empty_messages endp
;
getmsg proc near
    push cx
    mov cx, MAX_POLL
getmsg_loop:
    call readhost
    jnc got_msg
    loop getmsg_loop
    stc
    jmp short get_out
    ;------------
got_msg:
get_out:
    pop cx
    ret
getmsg endp
;
	ENDIF

	IDEAL
	JUMPS

IF	DIG_PAUDIO

 IFE	DIG_VBEAI

;;** FINDPAS
	MASM

;   /*\
;---|*|----====< Media Vision digital driver >====----
;---|*|
;   \*/

;
; C convention stack parameters
;
wParm1		equ	[bp+4+00h]
wParm2		equ	[bp+4+02h]
wParm3		equ	[bp+4+04h]
wParm4		equ	[bp+4+06h]
wParm5		equ	[bp+4+08h]

dParm1		equ	[bp+4+00h]
dParm2		equ	[bp+4+04h]
dParm3		equ	[bp+4+08h]
dParm4		equ	[bp+4+0ch]

bptr		equ	byte ptr
wptr		equ	word ptr

pause		equ	<jmp $+2>
disable 	equ	cli
enable		equ	sti

TRUE	equ	-1
FALSE	equ	0

	.xlist
	include common.inc
	include state.inc
	.list


;
; These variables are DMA/Buffer control variables
;
TheDMAChannel	db	01h		; defaults to channel 1
;
TheIRQChannel	db	07h		; defaults to IRQ 7
TheIRQMask1	db	0		; 8259 interrupt mask
TheIRQMask2	db	0	      ; mask for second pic.
;
TheDMAMode	db	00h		; 44h for input, 48h for output
;
TheSampleRate	dd	0		; 3k through 88k
StereoMono	db	-1		; ff for mono, 00 for stereo
PCMDirection	db	0		; bit mask for the DMA controller
;
	public	_voice_status
_voice_status	label	word
DMARunning	dw	0		; Holds current status:
;					;   0 = inactive, available
;					;   1 = currently playing
;					;   2 = currently recording
;
CallBackRoutine dd	0		; User's callback routine
OldIRQRoutine	dd	0		; holds the original routine
mvSetFilter     dd      0               ; set filter vector to mvsound.sys
;
dmamask 	equ	bICsampbuff	; dma mask for PCM state machine
;
DMAOUTPUT	equ	0+dmamask	; DMA is used to drive the output
DMAINPUT	equ	1+dmamask	; DMA is used to read input
NumberOfInterrupts	dw	0	; number of interrupts that have occured
intwaitcount		dw	0	; # of 'in' waits for DMA TC to occur

;
; These variables direct our code to the proper DMA channel
;
OurDMAPageReg	dw	CH1PAGEREG	; default to DMA channel 1 page reg
OurDMAddress	dw	DMAC1ADDR	; default to DMA channel 1 address reg

;
; structure for pointing to the above table of DMA addresses
;

dmaaddr struc
_dmach		db	?	; DMA channel selected
_dmachmask	db	?	; DMA channel mask bit
_dmardstat      db      ?       ; DMA read status
_dmawrcntrl	db	?	; DMA write command register
_dmawreq	db	?	; DMA write request register
_dmawrsmr	db	?	; DMA write single mask register
_dmawrmode	db	?	; DMA write mode register
_dmaclear	db	?	; DMA clear low/high flip-flop
_dmardtemp	db	?	; DMA read temp register
_dmawrclr	db	?	; DMA write master clear
_dmaclrmsk	db	?	; DMA clear mask register
_dmawrall	db	?	; DMA write all mask register bits
dmaaddr ends

;
; table of address pointers to the various DMA 2 addresses
;
        public  DMA1AddrTable
DMA1AddrTable	label	byte
	db	DEFAULTDMA	; DMA channel selected
	db	0010B		; DMA channel mask bit
        db      DMARDSTAT       ; DMA read status
	db	DMAWRCNTRL	; DMA write command register
	db	DMAWREQ 	; DMA write request register
	db	DMAWRSMR	; DMA write single mask register
	db	DMAWRMODE	; DMA write mode register
	db	DMACLEAR	; DMA clear low/high flip-flop
	db	DMARDTEMP	; DMA read temp register
	db	DMAWRCLR	; DMA write master clear
	db	DMACLRMSK	; DMA clear mask register
	db	DMAWRALL	; DMA write all mask register bits
;
; table of address pointers to the various DMA 2 addresses
;
	public	DMA2AddrTable
DMA2AddrTable   label   byte
        db      DEFAULTDMA      ; DMA channel selected
        db      0010B           ; DMA channel mask bit
	db	DMA2RDSTAT	; DMA read status
	db	DMA2WRCNTRL	; DMA write command register
	db	DMA2WREQ	; DMA write request register
	db	DMA2WRSMR	; DMA write single mask register
	db	DMA2WRMODE	; DMA write mode register
	db	DMA2CLEAR	; DMA clear low/high flip-flop
	db	DMA2RDTEMP	; DMA read temp register
	db	DMA2WRCLR	; DMA write master clear
	db	DMA2CLRMSK	; DMA clear mask register
	db	DMA2WRALL	; DMA write all mask register bits

	public	DMAPointer
DMAPointer      dw      offset DMA1AddrTable    ; default to channel 1 table

;
; These variables mirror the hardware state
;

mvhwShadowPointer	dd	0	;HardwareShadowTable ; points to the start of the data table
HardwareShadowTable	db	(size MVState) dup (0)
filterreg		db	0	; local storage for interrupts

;
; DMA buffer handling tables
;
MAXDMATABLELEN	equ	32
OutDMAIndex	dw	0	; output index to these tables
InDMAIndex	dw	0	; input index to these tables
DMAListCount	dw	0	; count of entries in the list
CurrentDMAIndex dw	0	; current block's index into tables
CompletionFlag	dw	0	; the completion flag

DMAAddressTable 	label	word
	dd	MAXDMATABLELEN dup(0)	; 32 buffers

DMALengthTable		label	word
	dw	MAXDMATABLELEN dup(0)	; 32 lengths

DMAFlagTable		label	word
	dw	MAXDMATABLELEN dup(0)	; 32 return pointers

;
; table of filter settings
;
FilterTable	label	byte
	db     000000b			; mute - goes to PC speaker
	db     100100b			; 20hz to  2.9khz
	db     111001b			; 20hz to  5.9khz
	db     110001b			; 20hz to  8.9khz
	db     101001b			; 20hz to 11.9khz
	db     100010b			; 20hz to 15.9khz
	db     100001b			; 20hz to 17.8khz
;
FilterLevel     label   byte
	dw	0			; mute
	dw	2982*2			; 20hz to  2.9khz
	dw	5965*2			; 20hz to  5.9khz
	dw	8948*2			; 20hz to  8.9khz
	dw	11931*2 		; 20hz to 11.9khz
	dw	15909*2 		; 20hz to 15.9khz
	dw	17897*2 		; 20hz to 17.8khz
;
; stuff needed for sound blaster code compatibility
;
        public  _io_addx
_io_addx	dw	0220h	; don't care really!!!

;
;   /*\
;---|*|----====< _ctv_callback(void far *) >====----
;---|*|
;---|*| Loads a callback routine. A null cancels callbacks
;---|*|
;---|*| Entry Conditions:
;---|*|     far address to an interrupt routine, or 0 to flush it
;---|*|
;---|*| Exit Conditions:
;---|*|     none
;---|*|
;   \*/
	public	_ctv_callback
_ctv_callback	PROC	near
	push	bp
	mov	bp,sp

	mov	ax,dParm1+0
	mov	wptr [CallBackRoutine+0],ax
	mov	ax,dParm1+2
	mov	wptr [CallBackRoutine+2],ax

	pop	bp
	ret

_ctv_callback	ENDP


;
;   /*\
;---|*|----====< _ctv_card_here() >====----
;---|*|
;---|*| Return a value indicating the board presence.
;---|*|
;---|*| Entry Conditions:
;---|*|     None
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 0, no card found
;---|*|     AX = 0110b if card found
;---|*|
;   \*/
	public	_ctv_card_here
_ctv_card_here	PROC	near
;
; setup a pointer to our local hardware state table
;
	lea	bx,HardwareShadowTable
	mov	wptr [mvhwShadowPointer+0],bx
	mov	wptr [mvhwShadowPointer+2],ds
;
; make sure MVSOUND.SYS is loaded
;
        mov     ax,0bc00h               ; make sure MVSOUND.SYS is loaded
	mov	bx,'??'
	sub	cx,cx
	sub	dx,dx
	int	2fh
	xor	bx,cx
	xor	bx,dx
	cmp	bx,'MV'                 ; is it loaded?
	jnz	geve_bad		; no, exit out...
;
; get the DMA and IRQ
;
	mov	ax,0bc04h
	int	2fh
	cmp	ax,'MV'                 ; good?
	jnz	@@LOC1			; no, continue on...

	mov	bptr [TheIRQChannel],cl
	mov	bptr [TheDMAChannel],bl

	push	bx
	push	cx
	push	ax

	mov	bx,1
	shl	bx,cl		; get mask.
	mov	[TheIRQMask1],bl
	mov	[TheIRQMask2],bh

	pop	ax
	pop	cx
	pop	bx

    ;
    @@LOC1:
;
; setup our DMA and IRQ addressing
;
	mov	al,bl
	call	near ptr SelectDMA

	mov	al,[TheIRQChannel]
	call	near ptr SelectIRQ
;
; get the setfilter routine
;
	mov	ax,0bc03h
	int	2fh
	cmp	ax,'MV'                 ; good?
	jnz	@@LOC2			; no, continue on...

        push    es
	mov	es,dx
	les	ax,es:[bx+(2*4)]	; get the filter vector
	mov	wptr [mvSetFilter+0],ax
	mov	wptr [mvSetFilter+2],es
	pop	es
    ;
    @@LOC2:
;
; get the state table pointer
;
        mov     ax,0bc02h               ; get the state table
	int	2fh
	cmp	ax,'MV'                 ; good?
	jnz	@@LOC3			; no, continue on...

        mov     wptr [mvhwShadowPointer+0],bx
	mov	wptr [mvhwShadowPointer+2],dx
    ;
    @@LOC3:
;
; all done, return with FM and DAC found
;
        mov     ax,0110b                ; returns FM and DAC available
	ret
;
geve_bad:
	sub	ax,ax			; return null & void
	ret

_ctv_card_here  ENDP

;
;   /*\
;---|*|---------------====< _ctv_continue >====---------------
;---|*|
;---|*| Turn on the h/w from making interrupt and DMA requests. This assumes
;---|*| the hardware has already been setup and is ready to go...
;---|*|
;---|*| Entry Conditions:
;---|*|     DS points to our data segment
;---|*|     None
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if no current DMA process.
;---|*|     AX = 0 if DMA process running.
;---|*|
;   \*/
	public	_ctv_continue
_ctv_continue	PROC	near
	push	es
	push	di
;
; Setup the audio filter sample bits
;
	mov	ax,1			; setup to return in error
	cmp	DMARunning,0		; are we running?
	jz	ctvcnt_05		; no, exit out

        les     di,[mvhwShadowPointer]
        mov     dx,AUDIOFILT

        disable

	mov	al,es:[di._audiofilt]
	or	al,bFIsrate		; enable sample rate and buffer timers
	mov	es:[di._audiofilt],al
	out	dx,al

	enable

        sub     ax,ax                   ; return good...
;
ctvcnt_05:
        pop     di
	pop	es
	ret

_ctv_continue	ENDP

;
;   /*\
;---|*|---------------====< _ctv_detect >====---------------
;---|*|
;---|*| Turn on the h/w from making interrupt and DMA requests. This assumes
;---|*| the hardware has already been setup and is ready to go...
;---|*|
;---|*| Entry Conditions:
;---|*|     DS points to our data segment
;---|*|     None
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if no board present, or not functioning
;---|*|     AX = 0 if all okay, board is good.
;---|*|
;   \*/
	public	_ctv_detect
_ctv_detect	PROC	near
;
; make sure the card is loaded...
;
	call	_ctv_card_here
	cmp	al,0110b
	jnz	@@LOC4
	sub	ax,ax
    ;
    @@LOC4:
	ret

_ctv_detect     ENDP

;
;   /*\
;---|*|---------------====< _ctv_halt >====---------------
;---|*|
;---|*| Stop I/O & remove ourselves from the system
;---|*|
;---|*| Entry Conditions:
;---|*|     DS points to our data segment
;---|*|     None
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if not running
;---|*|     AX = 0 if now paused
;---|*|
;   \*/
	public	_ctv_halt
_ctv_halt	PROC	near
;
; make sure we're running
;
	cmp	[BACKF],1	; In auto-init mode?
	jne	@@NOTBF
	mov	[BACKF],0
@@NOTBF:
	mov	ax,1
	cmp	DMARunning,0		; if no dma operation, exit now...
	jz	ctvhlt_05
	call	near ptr StopPCM	; flush the dma operation.
	sub	ax,ax
;
ctvhlt_05:
	ret

_ctv_halt	ENDP

;
;   /*\
;---|*|---------------====< _ctv_output >====---------------
;---|*|
;---|*| Play a block of Data
;---|*|
;---|*| Entry Conditions:
;---|*|     dParm1 is the far block pointer
;---|*|     wParm3 is the block  length
;---|*|     wParm4 is the sample rate
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if not running
;---|*|     AX = 0 if now running
;---|*|
;   \*/
	public	_ctv_output
_ctv_output	PROC	near
	push	bp
	mov	bp,sp
;
; SB compatiblity means we can only handle one block at a time. Take out
; this check if you want to queue up multiple blocks at a time...
;
	cmp	DMARunning,0		; we handle just one block at a time...
	jnz	ctvou_bad
;
; calculate the sample rate for this block
;
	mov	ax,wParm4		; get the sample rate
	sub	dx,dx
	call	near ptr _calcsamplerate
	jc	ctvou_bad

        mov     ax,wParm4               ; get the sample rate
        sub     dx,dx
	call	dacfilter		; setup the filter for this block
;
; pass the block in to the output code
;
        mov     ax,-1                   ; return flag now used to do int 15
	push	ax
	push	ax
	sub	dx,dx
	mov	ax,wParm3		; length
	push	dx
	push	ax
	push	wptr dParm1+2
	push	wptr dParm1+0
	call	DACOutput
	add	sp,6*2
	sub	ax,ax
	jmp	short ctvou_exit
;
ctvou_bad:
	mov	ax,1
;
ctvou_exit:
        pop     bp
	ret

_ctv_output     ENDP

;
;   /*\
;---|*|---------------====< _ctv_pause >====---------------
;---|*|
;---|*| Pause the I/O activity
;---|*|
;---|*| Entry Conditions:
;---|*|     None
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if not running
;---|*|     AX = 0 if now paused
;---|*|
;   \*/
	public	_ctv_pause
_ctv_pause	PROC	near
	push	es
	push	di
;
; make sure we're running
;
	mov	ax,1
	cmp	DMARunning,0
	jz	ctvpau_05
;
; Setup the audio filter sample bits
;
	les	di,[mvhwShadowPointer]
        mov     dx,AUDIOFILT

        disable

        mov     al,es:[di._audiofilt]
	and	al,not bFIsrate 	   ; flush the enable bits
	mov	es:[di._audiofilt],al
	out	dx,al

	enable
	sub	ax,ax
;
ctvpau_05:
        pop     di
	pop	es
	ret

_ctv_pause      ENDP

;
;   /*\
;---|*|---------------====< _ctv_speaker >====---------------
;---|*|
;---|*| Turn the speaker on/off
;---|*|
;---|*| Entry Conditions:
;---|*|     None
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 0 if no error
;---|*|
;   \*/
	public	_ctv_speaker
_ctv_speaker	PROC	near
        sub     ax,ax
	ret

_ctv_speaker    ENDP

;
;   /*\
;---|*|---------------====< _ctv_uninstall >====---------------
;---|*|
;---|*| Stop I/O & remove ourselves from the system
;---|*|
;---|*| Entry Conditions:
;---|*|     None
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if not running
;---|*|     AX = 0 if now paused
;---|*|
;   \*/
	public	_ctv_uninstall
_ctv_uninstall	PROC	near
;
; flush everything.
;
	call	near ptr StopSound
	call	near ptr _unloadirqvector ; restore the original vector
	ret

_ctv_uninstall  ENDP

;
;----------------------------=======================---------------------------
;----------------------------====< Subroutines >====---------------------------
;----------------------------=======================---------------------------
;

;
;   /*\
;---|*|---------------====< dacfilter(int) >====---------------
;---|*|
;---|*| Set the filter from 0 to 100%, where 0 is mute, 100% is highest
;---|*| filtering.
;---|*|
;---|*| Entry Conditions:
;---|*|     dx:ax holds the sample rate
;---|*|
;---|*| Exit Conditions:
;---|*|     DX:AX point to the state table
;   \*/

dacfilter	proc	near
	mov	bx,100			; default to 100 %
        or      dx,dx                   ; is it REAL big?
	jnz	dacffnd 		; yes, go for it...
	cmp	ax,17897*2		; gt 17897?
	jae	dacffnd 		; yes, go for it...

	mov	bx,84			; 84 %
        cmp     ax,15909*2              ; gt 15909?
	jae	dacffnd 		; yes, go for it...

	mov	bx,67			; 67 %
        cmp     ax,11931*2              ; gt 11931?
	jae	dacffnd 		; yes, go for it...

	mov	bx,50			; 50 %
        cmp     ax,8948*2               ; gt 8948?
	jae	dacffnd 		; yes, go for it...

	mov	bx,34			; 34 %
        cmp     ax,5965*2               ; gt 5965?
	jae	dacffnd 		; yes, go for it...

	mov	bx,17			; 17 %

;
dacffnd:
	cmp	wptr [mvSetFilter+2],0	; any setfilter vector?
	jz	@@LOC5			; no, skip the setting
	call	[mvSetFilter]		; set the filter to a proper level
    ;
    @@LOC5:
        ret

dacfilter	endp

;
;   /*\
;---|*|---------------====< DACOutput() >====---------------
;---|*|
;---|*| Queue up the block, start output, then return
;---|*|
;---|*| Entry Conditions:
;---|*|     dParm1 is the block pointer
;---|*|     dParm2 is the block length
;---|*|     dParm3 is a pointer to a flag set to 0 after the block played
;---|*|
;---|*| Exit Conditions:
;---|*|     AX =  0, pointers not queue - no room
;---|*|     AX = -1, pointers queued - will be recorded
;---|*|
;   \*/

DACOutput	PROC	near
	push	bp
	mov	bp,sp
;
; check for the proper dac direction. If not output, setup for so...
;
	call	near ptr setupoutput	; setup the h/w for output
;
; take this block and load into the queue
;
	mov	ax,dParm1+0		; get the starting address
	mov	dx,dParm1+2
	call	near ptr makelinear

	mov	cx,dParm2+0		; get the length
	mov	si,dParm2+2		; get the length
	call	near ptr calcblock	; returns cx holding the used portion
	jc	daci_full		; no blocks to be unloaded
;
; save the DMA complete flag pointer
;
	mov	bx,InDMAIndex
	sub	bx,1			; step back
	jnc	@@LOC6
	mov	bx,MAXDMATABLELEN-1
    ;
    @@LOC6:

	shl	bx,1			; make a word index
	mov	DMAFlagTable[bx],-1
;
; startup the output
;
	cmp	DMARunning,1		; already running?
	jz	@@LOC7			; yes, continue on...
	call	near ptr restartblockout; do it, just as an interrupt would
    ;
    @@LOC7:
	mov	ax,-1
	pop	bp
	ret
;
daci_full:
	sub	ax,ax
	pop	bp
	ret

DACOutput       endp

;
;--------------------------=======================-------------------------
;--------------------------====< subroutines >====-------------------------
;--------------------------=======================-------------------------
;

;   /*\
;---|*|----====< _calcsamplerate >====----
;---|*|
;---|*|  Calculate the H/W timer value (internal routine)
;---|*|
;---|*| Entry Conditions:
;---|*|       DX:AX hold the users requested sample rate
;---|*|
;---|*| Exit Conditions:
;---|*|       carry SET if bad value
;---|*|       No registers modified
;---|*|
;   \*/

_calcsamplerate proc near
	push	es
	push	di
	les	di,[mvhwShadowPointer]

	mov	wptr [TheSampleRate+0],ax
	mov	wptr [TheSampleRate+2],dx
;
; make sure sample rate does not exceed 88200
;
        mov     cx,ax                   ; do 32 bit subtraction
	sub	cx,05888H+1		; 157C0 is decimal 88200
	mov	cx,dx			; too high?
	sbb	cx,00001H		;  over 88200 khz is bad
	jnc	CaSaRa_bad		; bomb out greater than 88200
;
; load 1193180 in bx:cx for 32x32 bit division
;
	mov	bx,0012h
	mov	cx,34dch		; load bx:cx with 1193180

	xchg	bx,dx			; dx:ax = 1193180
	xchg	cx,ax			; bx:cx = sample rate
;
; since we don't have 32x32 bit division, we'll cheat here. No great loss.
;
	or	bx,bx			; is value over 64k?
	jz	@@LOC8			; no, continue on...
	shr	bx,1			; yes, divide all by 2
	rcr	cx,1			; to allow division of 32x16 bits
	shr	dx,1
	rcr	ax,1
;
@@LOC8:
	div	cx
	mov	es:[di._samplerate],ax	; save just the low order
	clc
	jmp	short CaSaRa_exit
;
CaSaRa_bad:
	stc
;
CaSaRa_exit:
        pop     di
	pop	es
	ret

_calcsamplerate endp

;
;   /*\
;---|*|----====< common_dacadc_setup >====----
;---|*|
;---|*| this is common code to both the ADCInput and DACOutput setup routines
;---|*|
;   \*/

common_dacadc_setup	proc near
;
; reset the pointer, etc...
;
	mov	OutDMAIndex,0		; output index to these tables
	mov	InDMAIndex,0		; input index to these tables
	mov	DMAListCount,0		; count of entries in the list
	mov	DMARunning,0		; flush the running flag
	ret

common_dacadc_setup	endp

;
;   /*\
;---|*|----====< _getirqoffset >====----
;---|*|
;---|*| takes the IRQ # & converts to offset in vector table
;---|*|
;   \*/

;; BX contains IRQ #, return code BX is offset from segment 0.
_getirqoffset	proc  near
	cmp	bl,8
	jb	@@CALC
	add	bl,60h		; index slave PIC vectors if IRQ > 7
@@CALC: add	bl,8
	shl	bx,1
	shl	bx,1
	ret
_getirqoffset	endp


;   /*\
;---|*|----====< KillDMA >====----
;---|*|
;---|*| KillDMA  -- flush our DMA settings
;---|*|
;   \*/

KillDMA proc	near
	push	es
	push	di
;
; mask out the DMA to stop it
;
	disable
	mov	di,[DMAPointer] 	; get the DMA pointer
;
; mask out the DMA to stop it
;
	mov	al,[di._dmach]		; get the adjusted dma channel #
        or      al,0100b                ; disable the DMA
        sub     dx,dx                   ; clear out the high byte
	mov	dl,[di._dmawrsmr]
	out	dx,al
;
; remove control on the DRQ line
;
        les     di,[mvhwShadowPointer]

        mov     al,es:[di._crosschannel]; get the state
        mov     dx,CROSSCHANNEL
	and	al,not bCCdrq		; clear the DRQ bit
	out	dx,al

        mov     es:[di._crosschannel],al; and save the new state
	enable

	pop	di
	pop	es
	ret

KillDMA endp

;
;   /*\
;---|*|----====< LoadDMA >====----
;---|*|
;---|*| LoadDMA  -- Load the DMA controller to read/write data to the MV board
;---|*|
;---|*| Entry Conditions:
;   \*/

LoadDMA proc	near
	push	es
	push	di
	push	si

        les     di,[mvhwShadowPointer]
	mov	bx,OutDMAIndex
	mov	si,[DMAPointer] 	; point to the DMA controller table
	sub	dx,dx			; clear out the high byte
;
; kill the dma until all programming is done
;
	mov	al,[si._dmach]		; get the adjusted dma channel #
        or      al,0100b                ; causes all DMA to be suspended
	mov	dl,[si._dmawrsmr]
	out	dx,al
;
; program the mode
;
        mov     al,[TheDMAmode]         ; get the app's desired mode
	or	al,[si._dmach]		; merge the adjusted dma channel #
	mov	dl,[si._dmawrmode]
	cmp	[BACKF],1		; In backfill mode?
	jne	@@OKBF
	or	al,16			; Turn backfill mode ON!!
@@OKBF:
        out     dx,al
;
; get the buffer index, to setup the page register
;
	mov	dx,[OurDMAPageReg]
	shl	bx,1
        shl     bx,1
        mov     ax,DMAAddressTable[bx+2]
	out	dx,al
;
; reset the flip-flop, then output the address, then count
;
	mov	dl,[si._dmaclear]	; dh is still clear...
        out     dx,al                   ; flush...
	mov	dl,al			; save the page # for the shift

	mov	ax,DMAAddressTable[bx]	; get the low 16 bits
	cmp	si,offset DMA1AddrTable ; 1st DMA controller?
	jz	LDDMA05 		; yes, continue on...
	shr	dl,1			; no, divide the buffer in half
	rcr	ax,1			; by shifting 17 bits
    ;
    LDDMA05:
	mov	dx,[OurDMAddress]
	out	dx,al
	pause
	xchg	ah,al
	out	dx,al

	shr	bx,1			; get the length
        mov     ax,DMALengthTable[bx]
	dec	ax
        cmp     si,offset DMA1AddrTable ; is this the 2nd dma controller?
	jz	lodma03 		; no, use the full length
	shr	ax,1
        inc     dx                      ; move to next port address
    ;
    lodma03:
	inc	dx			; move to next port address
	out	dx,al
	pause
	xchg	ah,al
	out	dx,al
;
; before we enable the DMA, let's make sure the DRQ is controlled, not floating
;
	mov	al,es:[di._crosschannel]; get the state
        mov     dx,CROSSCHANNEL
	or	al,bCCdrq		; set the DRQ bit to control it
	out	dx,al
	mov	es:[di._crosschannel],al; and save the new state
;
; re-enable the dma now that all programming is done
;
	mov	al,[si._dmach]		; get the adjusted dma channel #
        sub     dx,dx                   ; clear dh
	mov	dl,[si._dmawrsmr]
	out	dx,al			; & let'er loose (not moving though...)
;
; all done, return home...
;
	pop	si
	pop	di
	pop	es
	ret

LoadDMA endp

;
;   /*\
;---|*|----====< _loadirqvector >====----
;---|*|
;---|*| Restore the original vector
;---|*|
;---|*| Entry Conditions:
;---|*|
;---|*| Exit Conditions:
;---|*|     Nothing
;---|*|
;---|*|
;---|*|
;   \*/

_loadirqvector	proc near
	push	es

        les     ax,OldIRQRoutine
	mov	bx,es
	or	bx,ax
	jnz	@@LOC10

	lea	ax,OurIntVector
	mov	dx,cs

	xor	bx,bx
	mov	bl,[TheIRQChannel]
	call	near ptr _getirqoffset

	push	ds
	sub	cx,cx
	mov	ds,cx

	disable
	xchg	ds:[bx+0],ax
	xchg	ds:[bx+2],dx

	pop	ds

	mov	wptr [OldIRQRoutine+0],ax
	mov	wptr [OldIRQRoutine+2],dx
;
; Setup the system interrupt mask (IRQ mask)
;

	in	al,IRQ1MASKREG
	mov	ah,TheIRQMask1
	not	ah
	and	al,ah
	out	IRQ1MASKREG,al

	in	al,IRQ2MASKREG
	mov	ah,TheIRQMask2
	not	ah
	and	al,ah
	out	IRQ2MASKREG,al
;
; Setup the Interrupt Control Register
;
	les	bx,[mvhwShadowPointer]

        mov     dx,INTRCTLR
	in	al,dx			; get the real mask
	or	al,bICsampbuff		; interrupt on sample buffer count
	out	dx,al			; send it..
	mov	es:[bx._intrctlr],al	; save it..

	enable
;
@@LOC10:
	pop	es
	ret

_loadirqvector	endp

;
;   /*\
;---|*|----====< restartblockout >====----
;---|*|
;---|*| play the next block
;---|*|
;   \*/

restartblockout proc near
	cmp	DMAListCount,0		; any blocks going out?
	jz	@@LOC11 		; no, exit
;
; Program the DMA, then our board circuitry to start the interrupts
;
	mov	ax,OutDMAIndex		; save the current index
	mov	CurrentDMAIndex,ax	; for the DMA operation

	call	near ptr LoadDMA	; setup the DMA controller
	call	near ptr SetupPCMDMAIO	; Setup the MV Hardware
	mov	DMARunning,1		; set the global status word
;
; adjust the outbound pointers
;
	inc	OutDMAIndex		; adjust it...
	cmp	OutDMAIndex,MAXDMATABLELEN
	sbb	ax,ax			; ax = ffff if LE max count
	and	OutDMAIndex,ax		; make it wrap
;
; one less in the list
;
	sub	DMAListCount,1		; dec the count of entries in the list
	adc	DMAListCount,0
;
@@LOC11:
        ret

restartblockout endp

;
;   /*\
;---|*|----====< setupoutput >====----
;---|*|
;---|*| setupoutput  --  set the direction for DMA output
;---|*|
;   \*/

setupoutput	proc near
	mov	[CompletionFlag],0
;
; Select the DMA mode for playing
;
	cmp	[RecordMode],0	;
	je	@@play

	mov	[TheDMAMode],44h	; INPUT!
	mov	[PCMDirection],0	; zero the bits for input
	jmp short @@rent
@@play:
	mov	[TheDMAMode],48h	  ; playback mode is 48h
	mov	[PCMDirection],bCCdac	; bit d6 of crosschannel
@@rent:
;
; perform common setup stuff...
;
	call	near ptr common_dacadc_setup
;
seupot_exit:
	ret

setupoutput	endp

;
;   /*\
;---|*|----====< SetupPCMDMAIO >====----
;---|*|
;---|*| SetupPCMDMAIO  --  Setup to output to the DAC
;---|*|
;   \*/

SetupPCMDMAIO	proc near
	push	es
	push	di
	les	di,[mvhwShadowPointer]
;
; Setup the Sample Timer (T0 & square wave output)
;
	mov	al,00110110b		; 36h Timer 0 & square wave
	mov	dx,TMRCTLR
        disable
        out     dx,al
	mov	es:[di._tmrctlr],al
;
; load it now into timer 0
;
	mov	ax,es:[di._samplerate]	; pre-calculated & saved in prior code
	mov	dx,SAMPLERATE
	out	dx,al
	pause
	xchg	ah,al
	out	dx,al
	mov	intwaitcount,ax 	; save the wait count
;
; Setup the Sample Buffer Counter Timer (T1 & rate generator)
;
	mov	al,01110100b		; 74h Timer 1 & rate generator
	mov	dx,TMRCTLR

        out     dx,al
	mov	es:[di._tmrctlr],al	; local timer control register

	mov	bx,OutDMAIndex		; get the current block's index
	shl	bx,1
	mov	ax,DMALengthTable[bx]
        sub     ax,2                    ; ints happen 2 samples prior

        mov     bl,[TheDMAChannel]      ; is this a 16 bit channel?
	mov	bh,bptr cs:[PlayMode]	; bh holds the 0,1=8 2,3=16
	and	bh,2			; 0=8 bit, 2=16 bit

	sub	cx,cx			; ch = multiplier, cl=divider
	cmp	bx,0003h		; 8 bits on 8 bit channel?
	jbe	@SEP05			; yes, continue on...

	inc	cx			; divide by 2
	cmp	bx,0007h		; 8 bits on 16 bit channel?
	jbe	@SEP05			; yes, continue on...

	xchg	ch,cl			; multiply by 2
	cmp	bx,0203h		; 16 bits on 8 bit channel?
	jbe	@SEP05			; yes, continue on...
	sub	cx,cx			; no multiply or divide
    ;
    @SEP05:
        shr     ax,cl                   ; if 8 on 16 divide by 2
	xchg	ch,cl
	shl	ax,cl			; if 16 on 8 multiply by 2

	sub	cx,cx			; The buffer size is # of bytes, so
	neg	bh			; we must convert it to the data size
	adc	cx,cx
	shr	ax,cl

	mov	dx,SAMPLECNT		; get the address
	mov	es:[di._samplecnt],ax	; save it
        out     dx,al
        pause
	xchg	ah,al
	out	dx,al

IF      PAS16
	mov	al,00000011b
	cmp	[cs:PlayMode],PCM_16_STEREO
	je	@@ON16
	cmp	[cs:PlayMode],PCM_16_MONO
	jne	@@OFF
@@ON16: mov	al,00000111b
@@OFF:	mov	dx,SAMPLESIZE	; Get sample size register.
	out	dx,al		; oversampling.
	pause
ENDIF

;
; setup the direction, stereo/mono and DMA enable bits
;
	mov	al,bCCmono		; get the stereo/mono mask bit
	and	al,[StereoMono] 	; al = bCCmono if in mono mode
	or	al,[PCMDirection]	; get the PCM direction bit mask
	or	al,bCCenapcm + bCCdrq	; enable the PCM state machine
        mov     dx,CROSSCHANNEL
	mov	ah,0fh			; get a mask to load non PCM bits
	and	ah,es:[di._crosschannel]; grab all but PCM/DRQ/MONO/DIRECTION
	or	al,ah			; merge the two states
	xor	al,bCCenapcm		; disable the PCM bit
	out	dx,al			; send to the hardware
	xor	al,bCCenapcm		; enable the PCM bit
	out	dx,al			; send to the hardware
	mov	es:[di._crosschannel],al; and save the new state
;
; Setup the audio filter sample bits
;
	mov	dx,AUDIOFILT
	mov	al,es:[di._audiofilt]
	or	al,(bFIsrate+bFIsbuff)	   ; enable the timer gates
	out	dx,al			   ; Fly, baby Fly!!!
	mov	es:[di._audiofilt],al
        mov     filterreg,al               ; save a local copy

	enable

	pop	di
	pop	es
	ret

SetupPCMDMAIO	endp

;
;   /*\
;---|*|----====< SelectDMA() >====----
;---|*|
;---|*| Selects the DMA channel 1, 2, or 3
;---|*|
;---|*| Entry Conditions:
;---|*|     al points to DMA number (1, 2, 3 )
;---|*|
;---|*| Exit Conditions:
;---|*|     AX =  0, good buffer, all okay
;---|*|     AX = -1, good buffer, all okay
;---|*|
;   \*/

SelectDMA	proc	near
	and	ax,0111b		; save the channels
        mov     bx,ax                   ; get some of the I/O addreses
	shl	bx,1			; into DX

        mov     dx,cs:[dmatable+bx]
	or	dx,dx			; valid entry?
	jz	seldma_bad		; no, bomb out...

        mov     TheDMAChannel,al        ; select the channel.
	mov	bptr OurDMAPageReg,dh	; ...the page register,
	mov	bptr OurDMAddress,dl	; ...the address register,

	lea	bx,DMA1AddrTable	; get the DMA channel addresses
	cmp	al,4
	jl	seldma_05
	lea	bx,DMA2AddrTable	; get the DMA channel addresses
	sub	al,4			; make it zero based
    ;
    seldma_05:
	mov	[bx._dmach],al		; save the adjusted dma channel #
	mov	cl,al			; use it as a shift count
	mov	ax,1			; calculate a DMA mask
	shl	al,cl
	mov	[bx._dmachmask],al	; save the dma channel mask

	mov	[DMAPointer],bx 	; save the pointer to all DMA addrs
	sub	ax,ax
	ret
;
seldma_bad:
	mov	ax,-1
	ret
;
; dma channels, etc
;
dmatable	label	word
	dw	(CH0PAGEREG SHL 8) + DMAC0ADDR
        dw      (CH1PAGEREG SHL 8) + DMAC1ADDR
	dw	(CH2PAGEREG SHL 8) + DMAC2ADDR
	dw	(CH3PAGEREG SHL 8) + DMAC3ADDR
        dw      0
	dw	(CH5PAGEREG SHL 8) + DMA2C5ADDR
	dw	(CH6PAGEREG SHL 8) + DMA2C6ADDR
	dw	(CH7PAGEREG SHL 8) + DMA2C7ADDR

SelectDMA       endp

;
;   /*\
;---|*|---------------====< SelectIRQ( int ) >====---------------
;---|*|
;---|*| Selects the IRQ line for DMA control
;---|*|
;---|*| Entry Conditions:
;---|*|     al points to IRQ number (3,5,6,7)
;---|*|
;---|*| Exit Conditions:
;---|*|     AX =  0, good buffer, all okay
;---|*|     AX = -1, bad IRQ #
;---|*|
;   \*/

SelectIRQ	proc	near
	push	ax
	call	near ptr _unloadirqvector ; attempt to restore original vector
	pop	ax

        mov     cl,al
	mov	bl,01
	shl	bl,cl			; bl holds the IRQ bit mask

	mov	TheIRQChannel,al

	mov	cl,al
	mov	bx,1
	shl	bx,cl
	mov	TheIRQMask1,bl
	mov	TheIRQMask2,bh

	call	near ptr _loadirqvector ; load the new vector

        sub     ax,ax
;
seirqbad:
	ret

SelectIRQ       endp

;
;   /*\
;---|*|--------------------====< void StopPCM() >====--------------------
;---|*|
;---|*| Turn off the PCM timers, interrupts, and state machine.
;---|*|
;---|*| Entry Conditions:
;---|*|    None
;---|*|
;---|*| Exit  Conditions:
;---|*|    None
;---|*|
;   \*/

StopPCM proc	near
	push	es
	push	di
	les	di,[mvhwShadowPointer]
;
; clear the audio filter sample bits
;
	mov	dx,AUDIOFILT
	disable
	mov	al,es:[di._audiofilt]	; get the state
	and	al,not (bFIsrate+bFIsbuff) ; flush the sample timer bits
	out	dx,al
	mov	es:[di._audiofilt],al	; save the new state
;
; clear the PCM enable bit
;
	mov	al,es:[di._crosschannel]; get the current cross channel
	and	al,not bCCenapcm	; clear the PCM enable bit
	mov	dx,CROSSCHANNEL
	out	dx,al			; send to the hardware
	mov	es:[di._crosschannel],al
	enable				; drop dead...
;
; flush the buffer pointers
;
	mov	OutDMAIndex,0		; output index to these tables
	mov	InDMAIndex,0		; input index to these tables
	mov	DMAListCount,0		; count of entries in the list
;
; flush the DMA setup
;
	call	near ptr KillDMA	; stop the DMA too...
	mov	DMARunning,0		; dead now...

;
; flush any pending interrupts
;
;;**!!!        mov     dx,INTRCTLRST	       ; I/O write flushes the IRQ
;;**!!!        out     dx,al

	pop	di
	pop	es
	ret

StopPCM endp

;
;   /*\
;---|*|----====< _unloadirqvector >====----
;---|*|
;---|*| Restore the original vector
;---|*|
;---|*| Entry Conditions:
;---|*|     Nothing
;---|*|
;---|*| Exit Conditions:
;---|*|     Nothing
;---|*|
;   \*/

_unloadirqvector proc near
	pushf
	cli
	push	es
	push	cs
	pop	ds		; DS=CS

	les	ax,[OldIRQRoutine]		; get far address of old irq
	mov	bx,es
	or	bx,ax				; 0:0?
	jz	@@LOC12 		; yes, not set, return.

	xor	bx,bx
	mov	bl,[TheIRQChannel]
	call	near ptr _getirqoffset

	push	ds
	sub	cx,cx
	mov	ds,cx

        disable
	mov    [ds:bx+0],ax
	mov    [ds:bx+2],es
	pop	ds
;
; clear the appropriate Interrupt Control Register bit
;
                mov dx,INTRCTLRST
                out dx,al
                jmp $+2
                in al,dx
                mov dx,INTRCTLR
                in al,dx
                and al,11110111b        ;disable IRQs on sample buffer empty
                out dx,al
    ;
    ; clear the system interrupt mask if no others are using it...
    ;

        in      al,IRQ1MASKREG
	or	al,[TheIRQMask1]
	out	IRQ1MASKREG,al

	in	al,IRQ2MASKREG
	or	al,[TheIRQMask2]
	out	IRQ2MASKREG,al

    ;
    @@LOC12:

        enable

        sub     ax,ax
	mov	wptr [OldIRQRoutine+0],ax
	mov	wptr [OldIRQRoutine+2],ax
;
@@LOC13:
	pop	es
	popf
	ret

_unloadirqvector endp

	IDEAL
Proc	reportDMAC     near
	REPORTDMA TheDMAChannel
	endp
	MASM

;
;   /*\
;---|*|----====< OurIntVector >====----
;---|*|
;---|*| OurIntVector  -- process DMA interrupts
;---|*|
;   \*/

intsemaphore    db      -1              ; -1 free, 0+ locked
nestedcount	db	-1		; # of times a nested INT occured

OurIntVector    proc    far
	SetSemaphore
	push	ax
	push	bx
	push	cx
	push	dx
	push	ds

	mov	ax,cs			; all others use their data segments
	mov	ds,ax

	mov	dx,INTRCTLRST		; clear the interrupt
	in	al,dx

	test	al,bISsampbuff		; our interrupt?
	jz	skip_int		; no, continue on...

	out	dx,al			; flush it...

	cmp	[BACKF],1
	jne	@@GO
	jmp	exit_int
@@GO:

	inc	cs:[nestedcount]
	inc	cs:[intsemaphore]
        jnz     oiv_done
;
processnestedints:
;
; reduce the nested count
;
	dec	cs:[nestedcount]
	sti				; allow ints during the wait
;
; wait for the DMA to TC
;
	mov	bx,[DMAPointer] 	; get the DMA table
	mov	ah,[bx._dmachmask]

	mov	cx,intwaitcount 	; save the wait count
	shl	cx,1
	sub	dx,dx
	mov	dl,[bx._dmardstat]	; get the status register
    ;
    @@LOC14:
	in	al,dx			; get the status
	test	al,ah			; has it TC'ed?
	loopz	@@LOC14 		; not yet...

	mov	dx,AUDIOFILT		; preload the port address
	mov	al,[filterreg]		; flush the timers
	and	al,not (bFIsrate+bFIsbuff)
	out	dx,al
	mov	DMARunning,0		; DMA is no longer active
;
; perform more I/O on block data
;
	call	near ptr continueblockout
;
; finish the interrupt
;
        inc     [NumberOfInterrupts]
	cmp	nestedcount,-1
	jnz	processnestedints
;
oiv_done:
	dec	cs:[intsemaphore]
;
exit_int:
	mov	al,EOI			; clear the interrupt
	cmp	[cs:TheIRQChannel],7
	jbe	@@IRQ1
	out	IRQ2ACKREG,al
@@IRQ1: out	IRQ1ACKREG,al

	pop	ds
	pop	dx
        pop     cx
	pop	bx
        pop     ax
	ClearSemaphoreIRET
;
skip_int:
	pushf
	call	dword ptr ds:[OldIRQRoutine] ; perform the old interrupt
	jmp	short exit_int

OurIntVector    endp

;
continueblockout	proc near
;
; this is interrupt code! save everything!
;
	push	bx
	push	cx
;
; set the played out block's flag to 0
;
	mov	bx,CurrentDMAIndex
	shl	bx,1
	mov	bx,wptr DMAFlagTable[bx]
	or	bx,bx
	jz	@@LOC15

	call	CheckCallback
;;	  cmp	  wptr [CallBackRoutine+2],0	  ; is there a callback routine?
;;	  jz	  @@LOC15			  ; no, continue on...
;;	  pushf
;;	  call	  [CallBackRoutine]		  ; yes, go process it...
    ;
    @@LOC15:
;
; start the next block
;
	call	near ptr restartblockout

        pop     cx
	pop	bx
        ret

continueblockout	endp

;
;   /*\
;---|*|------====< calcblock >====------
;---|*|
;---|*| Takes a linear block & cuts it up into smaller block that
;---|*| don't cross a 64k boundary.
;---|*|
;---|*| Entry Conditions:
;---|*|     dx:ax is the linear address to the DMA buffer
;---|*|     si:cx holds the length
;---|*|
;---|*| Exit Conditions:
;---|*|     carry set if in error, or clear if all queued up
;---|*|
;   \*/

calcblock	proc near
	push	bp
	push	di			; save these...
;
; save the original index and count incase we bomb out & have to restore them
;
	push	[InDMAIndex]		; save in case we run out of room
        mov     di,[DMAListCount]
	push	di			; save it to add our count
;
; see if the length + address is over 64k
;
	sub	bx,bx
        mov     bp,ax                   ; bp = low 16 bits of the address
	add	bp,cx			; does this block cover a 64k boundary?
	adc	bx,si
	jz	cabl_05 		; no, we have an easy time of it...
;
; it covers a 64k boundary, so take this block & queue it!
;
	sub	bx,bx
	mov	bp,ax			; get the length of this block
	not	bp			; in a full 32 bit length
	add	bp,1
	adc	bx,bx			; bx:bp hold the length of this block

	sub	cx,bp			; remove this length from the count.
	sbb	si,bx			; the whole block may fit within 64k,
	cmc				; so clear the carry if so...
	sbb	bx,bx			; bx = 0000 if whole block fits in 64k
	and	si,bx			; kill the rest of the length if queued

	call	near ptr queueit	; load the queue with this block
	mov	ax,0			; (move to the next 64k boundary)
	inc	dx			; (without changing the carry)
        jnc     cabl_full               ; exit if full...
;
cabl_05:
;
; queue up all middle blocks that are 64k in length
;
	or	si,si			; greater than 64k?
	je	cabl_10 		; no, go save the last block

	sub	bp,bp			; bp hold the length (0=64k)
	dec	si			; decrement a 64k chunk

	call	near ptr queueit	; load the queue with this block
	inc	dx			; (move up 64k. carry not changed here)
	jnc	cabl_full		; exit if full
	jmp	short cabl_05
;
cabl_10:
;
; queue up the last block portion that extends over 64k
;
	or	cx,cx			; any ending portion?
	jz	@@LOC16 		; no, continue on...
	mov	bp,cx			; bx:bp hold the length
	call	near ptr queueit	; load the queue with this block
	jnc	cabl_full		; exit if full
    ;
    @@LOC16:
;
; we have finally finished the whole block. cleanup & exit
;
        pop     ax                      ; get the original count

        cli
	sub	ax,[DMAListCount]	; get the # of played out blocks
	sub	di,ax			; remove it from the new count
	mov	[DMAListCount],di	; lod the new count
	sti

        pop     ax                      ; flush the saved InDMAIndex
	clc
        jmp     short cabl_exit
;
cabl_full:
	pop	ax			; flush the original count
	pop	[InDMAIndex]		; restoer the in index
	stc				; exit bad
;
cabl_exit:
	pop	di			; save these...
	pop	bp
	ret

calcblock	endp

;
;   /*\
;---|*|----====< queueit >====----
;---|*|
;---|*| Queue the DMA address & do post inc on the count
;---|*|
;---|*| Entry Conditions:
;---|*|   bp hold the one based length (0000 = 64k)
;---|*|   dx:ax hold the address
;---|*|
;---|*| Exit Conditions:
;---|*|   carry set if queued, not set if out of room
;---|*|
;   \*/

queueit proc	near
	cmp	bp,3
	jbe	@@LOC17

        mov     bx,InDMAIndex
	shl	bx,1
	mov	DMALengthTable[bx],bp	; save the length

        shl     bx,1
	mov	DMAAddressTable[bx+0],ax; save the buffer
	mov	DMAAddressTable[bx+2],dx; save the buffer

	mov	DMAFlagTable[bx],00	; flush the flag pointer

	inc	InDMAIndex		; advance the pointer
	cmp	InDMAIndex,MAXDMATABLELEN
	sbb	bx,bx
	and	InDMAIndex,bx

	inc	di
;
@@LOC17:
	cmp	di,MAXDMATABLELEN
        ret

queueit endp

;
;   /*\
;---|*|------====< void far * makelinear() >====------
;---|*|
;---|*| Convert a segment:offset into a linear address
;---|*|
;---|*| Entry Conditions:
;---|*|     dx:ax is the segment:offset to the DMA buffer
;---|*|
;---|*| Exit Conditions:
;---|*|     dx:ax is the linear address to the DMA buffer
;---|*|
;   \*/
makelinear      proc    near
        mov     bx,dx                   ; convert it to a linear address
	mov	cl,4
	rol	dx,cl
	and	dx,000fh
	shl	bx,cl			; add offset portion of seg to offset
	add	ax,bx
	sbb	bx,bx			; bx = ffff if ax wrapped
	sub	dx,bx			; increment dx if ax wrapped
	ret

makelinear	endp


	IDEAL

Proc	PlaySound	near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; DX ->rate to play at.
	cmp	[cs:PlayMode],PCM_16_STEREO
	je	@@TWICE
	cmp	[cs:PlayMode],PCM_8_STEREO
	jne	@@OK
@@TWICE:
	shl	dx,1		; Times 2 playback frequency, when in stereo.
@@OK:	push	dx			; Save sampling rate.
	push	cx			; Number of bytes.
	push	es			; Segment
	push	bx			; Offset
	mov	ax,cs
	mov	ds,ax			; DS=CS
	call	_ctv_output		; Send it.
	add	sp,8			; Balance stack.
	ret
	endp

Proc	StopSound	near
	push	ds

	push	cs
	pop	ds
	call	_ctv_halt

	pop	ds
	ret
	endp


Proc	DoCallBacks	near
	cmp	[cs:CallBacks],0
	je	@@GOUT
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
@@GOUT: ret
	endp

;;////////////////////////////////// VBEAI interface /////////////////////////

 ELSE ; DIG_VBEAI

        MASM

	include vbeai.inc


;   /*\
;---|*|----====< Media Vision digital driver >====----
;---|*|
;   \*/

;
; C convention stack parameters
;
wParm1		equ	[bp+4+00h]
wParm2		equ	[bp+4+02h]
wParm3		equ	[bp+4+04h]
wParm4		equ	[bp+4+06h]
wParm5		equ	[bp+4+08h]

dParm1		equ	[bp+4+00h]
dParm2		equ	[bp+4+04h]
dParm3		equ	[bp+4+08h]
dParm4		equ	[bp+4+0ch]

bptr		equ	byte ptr
wptr		equ	word ptr

pause		equ	<jmp $+2>
disable 	equ	cli
enable		equ	sti

TRUE	equ	-1
FALSE	equ	0

;
; stuff needed for sound blaster code compatibility
;
        public  _io_addx
_io_addx	dw	0220h	; don't care really!!!

	public	_voice_status
_voice_status	dw	0		; Holds current status:

StereoMono	db	0FFh		; Default is mono flag 0FFh.

hWAVE		dw	0		; handle to the wave device
CallBackRoutine dd      0               ; User's callback routine
ServicesPtr	dd	0		; holds the original routine

SERVICESLEN	equ	2048		; size of the services structure
hServices	db	SERVICESLEN dup(0) ; info & services structure address

;
;   /*\
;---|*|----====< _ctv_callback(void far *) >====----
;---|*|
;---|*| Loads a callback routine. A null cancels callbacks
;---|*|
;---|*| Entry Conditions:
;---|*|     far address to an interrupt routine, or 0 to flush it
;---|*|
;---|*| Exit Conditions:
;---|*|     none
;---|*|
;   \*/
	public	_ctv_callback
_ctv_callback	PROC	near
	push	bp
	mov	bp,sp

	mov	ax,dParm1+0
	mov	wptr [CallBackRoutine+0],ax
	mov	ax,dParm1+2
	mov	wptr [CallBackRoutine+2],ax

	pop	bp
	ret

_ctv_callback	ENDP

;
;   /*\
;---|*|----====< _ctv_card_here() >====----
;---|*|
;---|*| Return a value indicating the board presence.
;---|*|
;---|*| Entry Conditions:
;---|*|     None
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 0, no card found
;---|*|     AX = 0110b if card found
;---|*|
;   \*/
	public	_ctv_card_here
_ctv_card_here	PROC	near
	sub	cx,cx			; query each device

;;**	%out Take this out!!!
;;**	int 3

;
crdhr_05:
	inc	cx			; move to the next handle

        mov     ax,VESAFUNCID
	mov	bl,VESAFUNC2
	mov	dx,01			; query #1 get the info struct. length
	int	INTHOOK

        sub     ax,004Fh                ; good?
	jnz	geve_bad		; no, bail out

	cmp	di,SERVICESLEN		; too big?
	ja	crdhr_05		; yes, skip this one...

        mov     ax,VESAFUNCID
	mov	bl,VESAFUNC2
	mov	dx,02			; query #2 get the info structure
	mov	si,cs			; si:di points to the info structure
	mov	di,offset hServices
	int	INTHOOK

	sub	ax,004Fh		; good call?
	jnz	geve_bad		; no, bail out...

	cmp	cs:[di.gdcclassid],DACDEVICE ; DAC?
	jnz	crdhr_05		; no, go find another one...

	cmp	cs:[di.gdcu.wimemreq],SERVICESLEN-16 ; enough memory?
	ja	crdhr_05		; no, go find another one...

	mov	ax,VESAFUNCID
	mov	bl,VESAFUNC2
	mov	dx,WAVESETPREFERENCE	; query #2 get the info structure
	mov	si,-1
	mov	di,si
	int	INTHOOK

	or	di,di			; highest priority?
	jnz	crdhr_05		; no, go for more...

	mov	hWAVE,cx		; yes, this is our handle
;
; all done, return with FM and DAC found
;
        mov     ax,0110b                ; returns FM and DAC available
	ret
;
geve_bad:
	sub	ax,ax			; not found...
	ret

_ctv_card_here  ENDP

;
;   /*\
;---|*|---------------====< _ctv_continue >====---------------
;---|*|
;---|*| Turn on the h/w from making interrupt and DMA requests. This assumes
;---|*| the hardware has already been setup and is ready to go...
;---|*|
;---|*| Entry Conditions:
;---|*|     DS points to our data segment
;---|*|     None
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if no current DMA process.
;---|*|     AX = 0 if DMA process running.
;---|*|
;   \*/
	public	_ctv_continue
_ctv_continue	PROC	near
        push    es
	push	di

	mov	ax,1			; prepair for failure
	cmp	wptr [ServicesPtr+2],0	; get the services structure
	jz	@CTCN05

	les	di,[ServicesPtr]	; get the services structure
	call	es:[di.wsResumeIO]
	inc	ax			; go from ffff to 0 or 0 to 01
;
@CTCN05:
        pop     di
	pop	es
	ret

_ctv_continue	ENDP

;
;   /*\
;---|*|---------------====< _ctv_detect >====---------------
;---|*|
;---|*| Turn on the h/w from making interrupt and DMA requests. This assumes
;---|*| the hardware has already been setup and is ready to go...
;---|*|
;---|*| Entry Conditions:
;---|*|     DS points to our data segment
;---|*|     None
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if no board present, or not functioning
;---|*|     AX = 0 if all okay, board is good.
;---|*|
;   \*/
	public	_ctv_detect
_ctv_detect	PROC	near
        push    es
	push	si
;
; open the VBE/AI driver
;
	mov	si,offset hServices	; offset/16
	mov	cl,4
	shr	si,cl
	mov	ax,cs
	add	si,ax			; + segment
	inc	si			; + 16

	mov	ax,VESAFUNCID		; open function
	mov	bl,VESAFUNC3
	mov	cx,[hWAVE]		; device handle is required
	sub	dx,dx			; select 16 bit interface
	int	INTHOOK 		; open the device

	sub	ax,004Fh		; did it work?
	jnz	@@LOC4			; no, bail

	mov	wptr [ServicesPtr+0],cx ; yes, save it & say we're open for
	mov	wptr [ServicesPtr+2],si ; business

	mov	es,si
	mov	si,cx

	mov	wptr es:[si.wsApplPSyncCB+0],offset VBECallback
	mov	wptr es:[si.wsApplPSyncCB+2],cs
	mov	wptr es:[si.wsApplRSyncCB+0],offset VBECallback
	mov	wptr es:[si.wsApplRSyncCB+2],cs

	sub	ax,ax			; return okay
    ;
    @@LOC4:
	pop	si
	pop	es
	ret

_ctv_detect     ENDP

;
;   /*\
;---|*|---------------====< _ctv_halt >====---------------
;---|*|
;---|*| Stop I/O & remove ourselves from the system
;---|*|
;---|*| Entry Conditions:
;---|*|     DS points to our data segment
;---|*|     None
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if it was not running
;---|*|     AX = 0 if now stopped
;---|*|
;   \*/
	public	_ctv_halt
_ctv_halt	PROC	near
        push    es
	push	di

	mov	ax,1			; prepair for failure
	cmp	wptr [ServicesPtr+2],0	; get the services structure
	jz	@CTHL05

	les	di,[ServicesPtr]	; get the services structure
	call	es:[di.wsStopIO]

	sub	ax,ax			; it is stopped, no matter what
;
@CTHL05:
        pop     di
	pop	es
	ret

_ctv_halt	ENDP

;
;   /*\
;---|*|---------------====< _ctv_output >====---------------
;---|*|
;---|*| Play a block of Data
;---|*|
;---|*| Entry Conditions:
;---|*|     dParm1 is the far block pointer
;---|*|     wParm3 is the block  length
;---|*|     wParm4 is the sample rate
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if not running
;---|*|     AX = 0 if now paused
;---|*|
;   \*/
	public	_ctv_output
_ctv_output	PROC	near
        push    bp
	mov	bp,sp

	push	es
	push	si

        mov     ax,1                    ; mono
	cmp	wptr [ServicesPtr+2],0	; get the services structure
	jz	@CTOU10

	les	si,[ServicesPtr]	; get the services structure
;
; set the sample rate
;
        push    ax
	cwd
        mov     ax,wParm4               ; get the sample rate
	push	dx
        push    ax
	push	dx			; no compression
	mov	ax,8			; 8 bit pcm
	push	ax

	call	es:[si.wsPCMInfo]	; set the sample rate
;
; see which type of playback we need
;
	cmp	[BACKF],1		; In DMA backfill mode?
	jz	@CTOU05 		; yes, do 'playcont'
;
; start the block
;
	push	wptr dParm1+2		; far *
	push	wptr dParm1+0
	sub	ax,ax
	push	ax			; length
	push	wptr wParm3		; length

	call	es:[si.wsPlayBlock]	; start the block
	neg	ax			; FFFF=1, 0=0
	xor	al,1			; 1=BAD, 0=GOOD
	jmp	short @CTOU10
;
@CTOU05:
;
; start the block
;
	push	wptr dParm1+2		; far *
	push	wptr dParm1+0
	sub	ax,ax
	push	ax			; full length
	push	wptr wParm3		; full length
	push	ax			; second length
	push	wptr wParm3		; second length

	call	es:[si.wsPlayCont]	; start the block
	neg	ax			; FFFF is now 1, 0 is now 0
	xor	al,1			; 1=BAD, 0=GOOD
;
@CTOU10:
	pop	si
	pop	es
	pop	bp
	ret

_ctv_output     ENDP

;
;   /*\
;---|*|---------------====< _ctv_pause >====---------------
;---|*|
;---|*| Pause the I/O activity
;---|*|
;---|*| Entry Conditions:
;---|*|     None
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if not running
;---|*|     AX = 0 if now paused
;---|*|
;   \*/
	public	_ctv_pause
_ctv_pause	PROC	near
        push    es
	push	di

	mov	ax,1			; prepair for failure
	cmp	wptr [ServicesPtr+2],0	; get the services structure
	jz	@CTPA05

	les	di,[ServicesPtr]	; get the services structure
	call	es:[di.wsPauseIO]
	inc	ax			; go from ffff to 0 or 0 to 01
;
@CTPA05:
        pop     di
	pop	es
	ret

_ctv_pause      ENDP

;
;   /*\
;---|*|---------------====< _ctv_speaker >====---------------
;---|*|
;---|*| Turn the speaker on/off
;---|*|
;---|*| Entry Conditions:
;---|*|     None
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 0 if no error
;---|*|
;   \*/
	public	_ctv_speaker
_ctv_speaker	PROC	near
        sub     ax,ax
	ret

_ctv_speaker    ENDP

;
;   /*\
;---|*|---------------====< _ctv_uninstall >====---------------
;---|*|
;---|*| Stop I/O & remove ourselves from the system
;---|*|
;---|*| Entry Conditions:
;---|*|     None
;---|*|     DS points to our data segment
;---|*|
;---|*| Exit Conditions:
;---|*|     AX = 1 if not running
;---|*|     AX = 0 if now paused
;---|*|
;   \*/
	public	_ctv_uninstall
_ctv_uninstall	PROC	near
;
; flush everything.
;
	mov	ax,VESAFUNCID		; close function
	mov	bl,VESAFUNC4
	mov	cx,[hWAVE]		; device handle is required
	sub	dx,dx			; select 16 bit interface
	int	INTHOOK 		; open the device

	sub	ax,004Fh		; NZ if
	neg	ax
	sbb	ax,ax			; FFFF if not good, else 0000
	neg	ax			; 0001 if not good, else 0000
	ret

_ctv_uninstall  ENDP

;
;----------------------------=======================---------------------------
;----------------------------====< Subroutines >====---------------------------
;----------------------------=======================---------------------------
;

;
;   /*\
;---|*|----====< VBECallback >====----
;---|*|
;---|*| VBECallback  --  End of block interrupts are handed to this routine
;---|*|
;   \*/

VBECallback	proc	far
        push    ds

        push    cs
	pop	ds

	cmp	[BACKF],1		; In DMA backfill mode?
	jz	@VBECB05		; yes, we don't do anying

	mov	_voice_status,0 	; the block is now done

;;;;;;;;call	CheckCallback		; we only do single block, not
;					; continuous blocks needing CBs
@VBECB05:
	pop	ds			; no registers modified
	retf	10			; pascal style

VBECallback	endp

;
;   /*\
;---|*|----====< reportDMAC >====----
;---|*|
;---|*| Report the current position of the DMA controller
;---|*|
;   \*/

reportDMAC      proc    near
	push	bx
	push	cx
	push	dx
	push	es

	sub	ax,ax			; prepair for failure
	cmp	wptr cs:[ServicesPtr+2],0 ; any servicces?
	jz	@REMD05 		; no, bail out

	les	bx,cs:[ServicesPtr]	; get the services structure

	mov	ax,WAVEGETCURRENTPOS
	push	ax

	push	ax			; don't care about the 2nd parm
        push    ax

	call	es:[bx.wsDeviceCheck]
;
@REMD05:
	pop	es
	pop	dx
	pop	cx
	pop	bx
	ret
 
reportDMAC	endp


;;////////////////////////// IDEAL stuff... //////////////////////////////////

        IDEAL

Proc	PlaySound	near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; DX ->rate to play at.
	cmp	[cs:PlayMode],PCM_8_STEREO
	jne	@@OK
	shl	dx,1		; Times 2 playback frequency, when in stereo.
@@OK:
	push	dx			; Save sampling rate.
	push	cx			; Number of bytes.
	push	es			; Segment
	push	bx			; Offset
	mov	ax,cs
	mov	ds,ax			; DS=CS
	call	_ctv_output		; Send it.
	add	sp,8			; Balance stack.
	ret
	endp

Proc	StopSound	near
	push	ds

	push	cs
	pop	ds
	call	_ctv_halt

	pop	ds
	ret
	endp


Proc	DoCallBacks	near
	cmp	[cs:CallBacks],0
	je	@@GOUT
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
@@GOUT: ret
	endp


 ENDIF ; DIG_VBEAI

ENDIF  ; DIG_PAUDIO

IF	DIG_SBLASTER
;** FINDSBLASTER
SMALL_MODEL     equ     1

Macro	CPROC	name		; Macro to establish a C callable procedure.
	public	_&name
IF	SMALL_MODEL
Proc	_&name	near
ELSE
Proc	_&name	far
ENDIF
	endm



ORG_INT_ADDX    dd      ?       ; Original IRQ address.
INT2	DD	?	; Holds address of original interrupt vectors.
INT3	DD	?	; Which we steal to perform autodection.
INT5	DD	?
INT7	DD	?

;---------------------
;      DMA DATA      |
;---------------------
DMA_CURRENT_PAGE    DB	     ?	; Current DMA page we are transmitting.
DMA_CURRENT_ADDX    DW	     ?	; Current DMA low word addresss.
DMA_CURRENT_COUNT   DW	     ?	; DMA current page count.
PAGE_TO_DMA         DB       ?
LEN_L_TO_DMA        DW       ?
LEN_H_TO_DMA        DW       ?
LAST_DMA_OFFSET     DW       ?

WAIT_TIME        EQU    0200H
DMA_VOICE_IN	 EQU	44H
DMA_VOICE_OUT	 EQU	48H

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

DSP_AUTO_OFF		equ	0DAh

DSP_AUTO8               equ     1Ch     ; DSP auto init 8 bit.

DSP_BLK_SIZE		equ	48h	; SES - used for all but low
					; SES -  speed non-auto init

DSP_STEREO_CMD		equ	84h	; DMA stereo!!

CMS_TEST_CODE            EQU         0C6H
RESET_TEST_CODE          EQU         0AAH

CMS_EXIST                EQU         1
FM_MUSIC_EXIST           EQU         2
CTV_VOICE_EXIST          EQU         4

FM_WAIT_TIME             EQU         40H

;; SoundBlaster detection code.....................

PortPossibilities	dw	220h,210h,230h,240h,250h,260h

;; Initialize the sound blaster.
;;
;;	On entry: Nothing.
;;	   exit:  Carry clear, sound blaster found.
;;		  Carry set, sound blaster NOT-FOUND.
CProc	InitBlaster
	PushCREGS

	mov	ax,cs
	mov	ds,ax
	mov	es,ax

	push	cx
	push	di
	call	DetectBlaster	      ; see if there
	pop	di
	pop	cx
	jz	@@FOUND
        stc
        mov     ax,1
        jmp   short @@ERR       ; exit, with error condition.
@@FOUND:
;; Disable MIDI interrupt.
	mov	dx,[cs:_io_addx]
	add	dx,4
	mov	al,83h
	out	dx,al
	inc	dx
	mov	al,0Bh
	out	dx,al		; disable MIDI interrupt.

        clc             ; Carry clear, sound blaster found, at IO_ADDX
@@ERR:
	PopCREGS
	ret
	endp


;; On entry: _io_addx = to the address to search at.
;;    exit: zero condition -> sound blaster found, here.
;;	    non-zero condition, sound blaster not found.
Proc	DetectBlaster  near
	call   reset_dsp		; Reset the DSP
	jnz    @@id90			;
	call   verify_io_chk
	jnz    @@id90
	call   chk_dsp_version
	jnz    @@id90
	MOV    AL,1			; on speaker
	CALL   ON_OFF_SPEAKER
	mov    al,1			; on speaker
	sub    ax,ax
@@id90:
	ret
	endp

;; Verify this IO address.
Proc    verify_io_chk   near
       mov    bx,2
       mov    al,DSP_ID_CMD
       mov    dx,[_io_addx]
       add    dx,0ch
       call   write_dsp_time
       jc     @@vio90

       mov    al,0aah
       call   write_dsp_time
       jc     @@vio90

       call   read_dsp_time
       jc     @@vio90

       cmp    al,055h
       jne    @@vio90

       sub    bx,bx

@@vio90:
       mov    ax,bx
       or     ax,ax
       ret
       endp

AUTOALLOWED    dw      0

Proc	chk_dsp_version 	near
       mov    al,DSP_VER_CMD
       mov    dx,[_io_addx]
       add    dl,0ch
       call   write_dsp
       call   read_dsp
       mov    ah,al
       call   read_dsp
       mov    bx,1
IF	SBCLONE OR STFX
	jmp short @@NOAUTO	; Never allow auto-init dma on clone cards.
ENDIF
       cmp	ax,200h 	; If not version 2.0 and above then we
				; don't support auto-init DMA!
       jb	@@NOAUTO
       mov      [AUTOALLOWED],1 ; Set auto-init dma flag allowed to true.
@@NOAUTO:
       cmp    ax,101h
       jb     @@cdv90
       sub    bx,bx
@@cdv90:
       mov    ax,bx
       or     ax,ax
       ret
       endp

;;

;------------------------------------------------------------------------;
; write_dsp writes al to the Sound Blaster after waiting for last command
; to complete
;------------------------------------------------------------------------; 
Proc	write_dsp	near
	push	cx		; stuff with CX is new timeout code for v2.0
	mov	cx,-1
	mov	ah,al
@@wd10: dec	cx		; if timeout, exit loop
	jz	@@wd11

	in	al,dx
	or	al,al
	js	@@wd10		; Wait while high bit on, busy.
@@wd11:
	mov	al,ah		; Get byte to send.
	out	dx,al		; Send it
	pop	cx		; Restore caller's CX register.
	ret
	endp

Proc	write_dsp_time	near
	push	cx		; Save caller's CX register.

	mov	cx,WAIT_TIME	; Application wait time (dangerous for very fast machines?)
	mov	ah,al		; Save charactrer to send in AH.

@@WDT10:
	in	al,dx
	or	al,al
	jns	@@WDT20
	loop	@@WDT10
	stc
	jmp short @@WDT90
@@WDT20:
	mov	al,ah
	out	dx,al		; Send the damned thing.
	clc
@@WDT90:
	pop	cx		; Restore caller's CX register.
	ret
	endp



Proc	READ_DSP_TIME	near
       PUSH   CX
       PUSH   DX

       MOV    DX,[_io_addx]
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
	endp


Proc	READ_DSP	near
       PUSH   DX
       MOV    DX,[_io_addx]
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
	endp

WCOUNT	dw	?



Proc	RESET_DSP	near
       MOV    DX,[_io_addx]
       ADD    DL,6


       mov al,1 	       ;JCM (USE THIS INSTEAD)
       out dx,al	       ;JCM
                                        ;JCM
       mov cx,20	       ;JCM
@@wait:
	in	al,dx		     ;JCM  ;wait > 3 uS
	loop	@@wait		   ;JCM
                                        ;JCM
	mov	al,0		    ;JCM  ;drop reset
	out	dx,al		    ;JCM

       MOV    CL,20H

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
       endp

BAILOUT dw	1000

Proc   PAUSE_DSP_DMA   near
       PUSHF
       push	ds
       push	cs
       pop	ds		; make certain DS=CS

       MOV    AH,DSP_PAUSE_DMA_CMD
       lea    BX,[_voice_status]
       SUB    CX,CX
       MOV    DX,[_io_addx]
       ADD    DL,0CH

       mov	[BAILOUT],1000
@@PDD10:
       STI		; Enable interupts.
       CMP    CX,[BX]	; Voice status false?
       JE     @@PDD90	; yes, skip.

       CLI		; Turn off hardware interrupts.
       dec	[BAILOUT]
       jnz	@@OK
       mov	[_voice_status],0
       call	reset_dsp
       jmp     @@PDD90
@@OK:
       IN     AL,DX	; Read IO address.
       OR     AL,AL	; Test status.
       JNS    @@PDD10	; if not busy continue.

;; Wait until busy edge, then fall into wait until free, while hardware
;; interrupts are still disabled, send the pause command.
	mov	cx,3000 ;: delay.
@@PDD20:
	dec	cx
	jz	@@GIVEUP
	jmp	$+2	; Pause.
       IN     AL,DX	; Read it.
       OR     AL,AL
       JS     @@PDD20
@@GIVEUP:
       MOV    AL,AH
       OUT    DX,AL

@@PDD90:
       pop     ds
       POPF
       RET
       endp

;--------------------------------------------
; entry: DH = dma mode                      :
;        DL = page                          :
;        AX = current addx                  :
;        CX = current count                 :
;--------------------------------------------

DMA_ADDX_REG	    EQU    02H
DMA_COUNT_REG	    EQU    03H
DMA_MASK_REG	    EQU    0AH
DMA_MODE_REG	    EQU    0BH
;;**DMA_FF_REG		EQU    0CH
DMA_PAGE_REG	    EQU    83H

PAGER	dw	?	; holds dma page
DMAPAG_offset   db 07h,03h,01h,02h,-1,0bh,09h,0ah

Proc   PROG_DMA        near
       PUSH	BX		; Save BX register.
       mov	[cs:PAGER],dx	; Save PAGE and MODE passed.
       MOV	BX,AX		; put transfer address in BX

			 mov	al,[byte cs:DSP_DMA] ; Get dma channel.
       or	al,4h		; or mask bit on.
       OUT	DMA_MASK_REG,AL ; mask it.

;       SUB      AL,AL          ; SES - not neccessary (any write works)
       OUT    DMA_FF_REG,AL	; reset the flip/flop


			 mov	dx,[cs:DSP_DMA]
       shl	dx,1		; address register.

       MOV    AL,BL
       OUT    dx,AL		; send low byte of addresss.

       MOV    AL,BH
       OUT    dx,AL		; send high byte of address.

			 mov	dx,[cs:DSP_DMA]
       shl	dx,1
       add	dx,1
       MOV	AL,CL
       OUT	dx,AL		; send low byte of length.

       MOV	AL,CH
       OUT	dx,AL		; send high byte of length.


	mov	bx,[cs:DSP_DMA]
	mov	dx,80h		    ;DMAPAG: Base address
	add	dl,[cs:DMAPAG_offset+bx]
       MOV	AL,[byte cs:PAGER] ; get page.
       OUT	dx,AL

       MOV    AL,[byte cs:PAGER+1]	      ; get mode passed.
       cmp    [cs:BACKF],1    ; test to see if in backfill mode.
       jne    @@NOTBF
       or     al,16		; Turn DMA back fill mode on.
@@NOTBF:
	or	ax,[cs:DSP_DMA] ; Or bit on for dma channel being set.
       OUT    DMA_MODE_REG,AL

			 MOV    AX,[cs:DSP_DMA]	; Get DMA channel to reset.
       OUT    DMA_MASK_REG,AL

       mov	dx,[cs:PAGER]
       POP    BX
       RET
       endp



Proc	CALC_20BIT_ADDX 	near
       PUSH   CX
       MOV    CL,4
       ROL    DX,CL
       MOV    CX,DX
       AND    DX,0FH
       AND    CX,0FFF0H
       ADD    AX,CX
       ADC    DX,0
       POP    CX
       RET
       endp


PIC0_val	db	?
PIC1_val	db	?
;-------------------------------------------------
; entry: AL = INTERRUPT NUM                      |
;        DX = new vector ofs, seg is alway CS    |
;        BX = offset of store buffer             :
;-------------------------------------------------
IntInstalled	   dw	   0	   ; True when interrupt installed.
Proc	SETUP_INTERRUPT near
       PUSH   BX
       PUSH   CX
       PUSH   DX

       cmp	[cs:IntInstalled],1	   ; Interrupt allready installed?
       je	@@GOUT

       CLI
	xor	ah,ah		; Zero high byte.
       MOV    CL,AL                    ; preserve interrupt number for use
       cmp     al,8
       jb      @@calc_vect
	add	al,60h	       ; index slcae PIC vectors if IRQ > 7
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
       mov     [PIC1_val],al
       and     al,bh
       out     0a1h,al
       in      al,21h
       mov     [PIC0_val],al
       and     al,bl
       out     21h,al
       mov	[cs:IntInstalled],1
@@GOUT:
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
Proc   RESTORE_INTERRUPT       near
       CLI
       cmp     [cs:IntInstalled],1	  ; Installed?
       jne     @@GOUT
       MOV    CL,AL
       push bx		       ;JCM
       mov     bx,1
       shl     bx,cl
       in      al,0a1h
       or      al,bh
       and     al,[PIC1_val]	     ;don't kill any interrupts that were
       out     0a1h,al		   ;initially active
       in      al,21h
       or      al,bl
       and     al,[PIC0_val]
       out     21h,al
       pop bx		       ;JCM

       mov     al,cl	       ; Get back interrupt number.
       xor     ah,ah

       cmp	al,8
       jb	@@calc_vect
       add	al,60h		; index slave PIC if IRQ > 7
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
       mov	[cs:IntInstalled],0	   ; No longer installed.
@@GOUT:
       STI
       RET
       endp


;; SoundBlaster report DMAC routine.
Proc	ReportDMAC
	REPORTDMA DSP_DMA
	endp

MPU401INT   EQU   24h                   ; SES - 3rd bit indicates MPU-401 Int.
INTIDREG    EQU   82h                   ; SES - Interrupt ID register

Proc	DMA_OUT_INTR	far
	SetSemaphore
	push	ax
	push	dx

        mov     dx,[cs:_io_addx]        ; SES - goto mixer chip
	add	dx,4
        mov     al,INTIDREG             ; SES - select interrupt ID register
	out	dx,al
	inc	dx
        in      al,dx                   ; SES - read interrupt ID register
        cmp     al, MPU401INT           ; SES - was it an MPU401 interrupt?
        je      @@VO_INT90              ; SES - yes, skip it

;-----------------------------------------------------------------------------
;        push    bx
;        mov     dx,[cs:DSP_DMA]
;        shl     dx,1
;        add     dx,1
;
;        out     DMA_FF_REG, al      ; SES - reset DMA flip-flop
;        in      al,dx                ;DMAnCNT: Channel n Word Count
;        mov     bl,al
;        in      al,dx
;        mov     ah,al
;        mov     al,bl
;        pop     bx
;
;        cmp     [cs:BACKF],1               ; SES - In backfill mode?
;        jne     @@NO_BACKFILL              ; SES
;        mov     dx, [cs:DMA_CURRENT_COUNT] ; SES
;        sub     dx, 10h                    ; SES - DMA count grace band
;        cmp     ax, dx                     ; SES - DMA has initialized already
;        jmp     @@TEST_IT                  ; SES
;
;@@NO_BACKFILL:                             ; SES
;        cmp     ax, 0ffffh
;
;@@TEST_IT:                                 ; SES
;        jb     @@VO_INT90
;-----------------------------------------------------------------------------

        mov    al,[byte cs:_intr_num]       ; SES - Get interrupt number
        cmp    al, 7                        ; SES - is it IRQ 7 ?
        jne    @@INT_OK                     ; SES - no, then skip test of PIC

        mov    al, 0bh                      ; SES - Select PIC In Service Reg.
        out    20h, al                      ; SES
        in     al, 20h                      ; SES - read In Service Register
        test   al, 80h                      ; SES - was it a valid interrupt?
        jz     @@VO_INT90                   ; SES - no, then skip it

@@INT_OK:
        MOV    DX,[cs:_io_addx]             ; clear interrupt in DSP
	ADD    DL,0EH
	IN     AL,DX

        cmp     [cs:BACKF],1                ; In backfill mode?
        je      @@VO_INT90                  ; yes, Ignore the interrupt.

	MOV    AX,[cs:LEN_L_TO_DMA]
	OR     AX,AX
	JNZ    @@VO_INT10

	CALL   END_DMA_TRANSFER

	JMP    SHORT @@VO_INT90

@@VO_INT10:
       CALL   DMA_OUT_TRANSFER

@@VO_INT90:
       pop      dx
       MOV	AL,20H
       cmp	[cs:_intr_num],7
       jbe	@@NOT
       out	0a0h,al 	; clear PIC1 if IRQ >=8
@@NOT: OUT	20H,AL
       pop	ax
       ClearSemaphoreIRET
       IRET
       endp

Macro	INISR
	push	es		; Save registers that are used
	push	ds
	push	di
	push	si
	push	cx
	push	bx
	cld
	mov	ax,cs
	mov	es,ax
	mov	ds,ax		; Establish data addressability.
	endm

Macro	OUTISR
	pop	bx
	pop	cx
	pop	si
	pop	di
	pop	ds
	pop	es
	endm

;; In an ISR, so all registers need to be saved!! (AX,DX, allready saved though.
Proc	DMA_OUT_TRANSFER	near
	INISR

	MOV    CX,-1			; get current page end address

	CMP    [PAGE_TO_DMA],0		  ; last page to dma ?
	JNZ    @@DOT10			  ; no, skip

	INC	[PAGE_TO_DMA]
	MOV	CX,[LAST_DMA_OFFSET]	   ; get end addx

@@DOT10:
       SUB    CX,[DMA_CURRENT_ADDX]      ; calculate current page addx
       MOV    [DMA_CURRENT_COUNT],CX
       INC    CX
       JZ     @@DOT20

       SUB    [LEN_L_TO_DMA],CX
       SBB    [LEN_H_TO_DMA],0
       JMP    SHORT @@DOT30

@@DOT20:
       DEC    [LEN_H_TO_DMA]

@@DOT30:
	MOV    DH,DMA_VOICE_OUT
	cmp	[cs:RecordMode],1	; In recording mode?
	jne	@@NOT
	mov	DH,DMA_VOICE_IN
@@NOT:
       MOV    DL,[DMA_CURRENT_PAGE]
       MOV    AX,[DMA_CURRENT_ADDX]
       MOV    CX,[DMA_CURRENT_COUNT]
       CALL   PROG_DMA

IF	SBPRO
	mov	dx,[_io_addx]	     ; Base I/O address of sound blaster.
	add	dx,4			; Point to mixer address port.
	mov	al,0eh		    ;select DNFI/VSTC flag set
	out	dx,al
	jmp $+2
	inc	dx		; Point to mixer data.
	mov	ax,0
	cmp	[PlayMode],1
	jne	@@OKP
	mov	ax,2
@@OKP:
	out	dx,al		    ;Set stereo/mono mode; filtering = ON
ENDIF


       DEC    [PAGE_TO_DMA]
       INC    [DMA_CURRENT_PAGE]
       MOV    [DMA_CURRENT_ADDX],0

       MOV    CX,[DMA_CURRENT_COUNT]

       MOV    DX,[_io_addx]
       ADD    DL,0CH

       MOV    AL,DSP_VO8_CMD
	cmp	[RecordMode],1		; In record mode?
	jne	@@NOTR
	mov	al,DSP_VI8_CMD	; Record 8 bit PCM!
	jmp short @@GOCMD	; go command.
@@NOTR:
IF	STFX
       cmp    [PlayMode],PCM_8_MONO
       je     @@GO
       mov    al,DSP_STEREO_CMD
@@GO:
ENDIF
	cmp	[BACKF],1
	jne	@@GOCMD
        mov     AL,DSP_BLK_SIZE              ; send DSP block size command
        CALL    WRITE_DSP

        MOV    AL,CL                         ; send block size
        CALL   WRITE_DSP
        MOV    AL,CH
        CALL   WRITE_DSP

        MOV    AL,DSP_AUTO8                  ; send command
        CALL   WRITE_DSP
        jmp    @@DOT90

@@GOCMD:
       CALL   WRITE_DSP

       MOV    AL,CL
       CALL   WRITE_DSP

       MOV    AL,CH
       CALL   WRITE_DSP


@@DOT90:
	OUTISR			; Restore registers for ISR routines.
	RET
	ENDP



Proc	END_DMA_TRANSFER	near
       INISR
       MOV    AL,5
       OUT    DMA_MASK_REG,AL
       MOV    AL,[byte _intr_num]
       lea    BX,[ORG_INT_ADDX]
       CALL   RESTORE_INTERRUPT
       MOV    [_voice_status],0
       MOV    DX,[_io_addx]
       ADD    DL,0EH
       IN     AL,DX

;; Do Callbacks if ncessary.
       call    DoCallBacks

       OUTISR
       RET
       endp

CPROC	ctv_output
	ARG	DATAL:WORD,DATAH:WORD,SNDLEN:WORD,FREQ:WORD
	PENTER	0
	PushCREGS

	MOV    AX,cs
	MOV    DS,AX
	MOV    ES,AX		; ES=DS=CS

@@WAIT: CMP    [_voice_status],0
	jne    @@WAIT		; Wait until last sound has completed playing.
@@OV10:
       MOV    [_voice_status],1

       MOV    DX,[_io_addx]
       ADD    DL,0CH

       MOV    DX,0FH                   ; calculate sampling rate value for
       MOV    AX,4240H                 ; DSP
       MOV    CX,[FREQ] 	; Get playback frequency.
       DIV    CX

       MOV    CL,AL
       NEG    CL

       MOV    DX,[_io_addx]
       ADD    DL,0CH
       MOV    AL,DSP_TIME_CMD
       CALL   WRITE_DSP

       MOV    AL,CL
       CALL   WRITE_DSP

       MOV	AL,[byte _intr_num]
       lea	dx,[DMA_OUT_INTR]
       lea	BX,[ORG_INT_ADDX]
       CALL	SETUP_INTERRUPT

       mov	dx,[DATAH]
       mov	ax,[DATAL]

       CALL   CALC_20BIT_ADDX

       MOV    [DMA_CURRENT_PAGE],DL
       MOV    [DMA_CURRENT_ADDX],AX

       MOV    CX,[SNDLEN]	; Length of sound.
       MOV    [LEN_L_TO_DMA],CX
       MOV    [LEN_H_TO_DMA],0

       ADD    AX,[SNDLEN]
       ADC    DL,0
       SUB    AX,1
       SBB    DL,0

       MOV    [LAST_DMA_OFFSET],AX
       SUB    DL,[DMA_CURRENT_PAGE]
       MOV    [PAGE_TO_DMA],DL

       CALL   DMA_OUT_TRANSFER

       SUB    AX,AX

@@OV90:
	PopCREGS
	PLEAVE
	ret
	endp

CPROC	ctv_halt
	PushCREGS
	MOV    AX,cs
	MOV    DS,AX
	MOV    ES,AX

	MOV    AX,1

	CMP    [_voice_status],0
	JZ     @@TVP90

        cmp     [BACKF],1       ; In auto-init mode?
	jne	@@NOTBF
	mov	[BACKF],0	; turn backfilling off!
	cli
	mov	dx,[_io_addx]
	add	dx,0ch
	mov	al,DSP_AUTO_OFF ; Turn auto-init dma off.
	call	WRITE_DSP
	CALL   END_DMA_TRANSFER
	call	reset_DSP	;
	mov	[SPEAKERSTATE],-1
	mov	al,1
	call	ON_OFF_SPEAKER
	sti
	mov	[_voice_status],0
	jmp	@@TVP90 	; Get the hell out.
@@NOTBF:
	cli
	CALL   PAUSE_DSP_DMA
	mov	[_voice_status],0	; No longer playing.

	sti
	SUB    AX,AX

@@TVP90:
	PopCREGS
	RET
	endp


CPROC	ctv_uninstall
	PushCREGS
       MOV    AX,cs
       MOV    DS,AX
       MOV    ES,AX

       CMP    [_voice_status],0
       JZ     @@UI90

       CALL   PAUSE_DSP_DMA
       CALL   END_DMA_TRANSFER


@@UI90:
       SUB    AL,AL
       CALL   ON_OFF_SPEAKER


      MOV    AL,[byte _intr_num]	; make certain interrupt is restored.
      lea    BX,[ORG_INT_ADDX]
      CALL   RESTORE_INTERRUPT

      mov     dx,[cs:_io_addx]
      add     dx,4
      mov     al,83h
      out     dx,al
      inc     dx
      mov     al,0Fh
      out     dx,al	      ; disable MIDI interrupt.

       SUB    AX,AX

       PopCREGS
       RET
       endp

CPROC	ctv_status
	mov	ax,[cs:_voice_status]
	ret
	endp

SPEAKERSTATE	db	-1

Proc	ON_OFF_SPEAKER	near
	cmp	al,[SPEAKERSTATE]
	je	@@DONE
	PushAll

	mov	[SPEAKERSTATE],al
	MOV	DX,[_io_addx]
	ADD	DX,0CH

	MOV	AH,DSP_ONSPK_CMD
	OR	AL,AL
	JNZ	@@OOS10

	MOV	AH,DSP_OFFSPK_CMD

@@OOS10:
	MOV	AL,AH
	CALL	WRITE_DSP

	PopAll
@@DONE:
       SUB	AX,AX			 ; inidcate no error
       RET
       endp


;; SoundBlaster PlaySound
Proc	PlaySound	near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; DX ->rate to play at.

	mov	al,1		; Speaker needs to be ON.
	cmp	[RecordMode],1	; Recording?
	jne	@@SET
	xor	al,al		; Speaker OFF while recording.
@@SET:	call	ON_OFF_SPEAKER	; Set speaker state.

IF	SBPRO
	cmp	[PlayMode],0
	je	@@OKF
	shl	dx,1
@@OKF:
ENDIF
	push	dx			; Save sampling rate.
	push	cx			; Number of bytes.
	push	es			; Segment
	push	bx			; Offset

	mov	ax,cs
	mov	ds,ax			; DS=CS
	call	_ctv_output		; Send it.
	add	sp,8			; Balance stack.

	ret
	endp

Proc	StopSound	near
	push	ds
	push	cs
	pop	ds
	call	_ctv_halt
	pop	ds
	ret
	endp


Proc	DoCallBacks	near
	cmp	[cs:CallBacks],0
	je	@@GOUT
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
@@GOUT: ret
	endp

ENDIF

IF	DIG_TANSLTL
tanseg	dw	?		; playing from this segment location.
tanoff	dw	?		; playing from this offset.
tanlen	dw	?		; length remaining to play.
tanfreq dw	?		; frequency, in tandy values.

Old15	FARPTR <>	; Original interupt 15h vector.

Proc	PlaySound	near
	PushAll 	; Save ALL registers.

	push	bx

	mov	bx,dx
	mov	dx,0012h	; High word of 1,193,180.
	mov	ax,34DCh	; Low word of 1,193,180.
	div	bx
	mov	dx,ax		; Interupt rate result into DX.

	pop	bx

;; Fudge factor of times 3 to get at the rate used by the Tandy DMA hardware.
	shl	ax,1		; Times 2
	add	dx,ax		; Times 3.

;; Call the Tandy digitized sound driver but first steal interupt 15h so
;; that we will receive notification of when this is done playing.
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; DX ->rate to play at.

	push	es
	push	dx
	push	cx
	push	bx

	mov	[cs:tanseg],es
	mov	[cs:tanoff],bx
	mov	[cs:tanlen],cx
	mov	[cs:tanfreq],dx


	mov	ah,35h		; Function get interupt vector
	mov	al,15h		; Get interupt vector #15
	int	21h		; Get it.
	mov	[Old15.XPTR.POFF],bx
	mov	[Old15.XPTR.PSEG],es
	lea	dx,[My15]	; Address of my interupt routine
	mov	ah,25h
	mov	al,15h		; Call set interupt vector.
	int	21h		; set it.

	pop	bx
	pop	cx
	pop	dx
	pop	es

	cmp	cx,16384	; Is it too big to send at once?
	jbe	@@OK
	mov	cx,16384
@@OK:	sub	[cs:tanlen],cx	; Ok!
	add	[cs:tanoff],cx

	mov	ah,83h		; Output sound to speaker.
	mov	al,07h		; Volume.
	int	1Ah		; Do the Tandy sound BIOS interupt.
	mov	[cs:PlayingSound],1 ; Set sound playing flag to true!

	PopAll
	ret
	endp

Proc	My15 far
	cmp	ax,91FBh
	jne	@@OLD15
	SetSemaphore
	PushAll
	cmp	[cs:tanlen],0	; Finished sending tandy sound?
	je	@@DONE

	mov	es,[cs:tanseg]
	mov	bx,[cs:tanoff]
	mov	cx,[cs:tanlen]
	mov	dx,[cs:tanfreq]

	cmp	cx,16384	; Is it too big to send at once?
	jbe	@@OK
	mov	cx,16384
@@OK:	sub	[cs:tanlen],cx	; Ok!
	add	[cs:tanoff],cx

	mov	ah,83h		; Output sound to speaker.
	mov	al,07h		; Volume.
	int	1Ah		; Do the Tandy sound BIOS interupt.
	jmp	short	@@LEAVE
@@DONE:
	mov	[cs:PlayingSound],0	; Sound finished playing.
	xor	ax,ax
	mov	ds,ax
	mov	ax,[cs:Old15.XPTR.POFF] ; get offset.
	mov	[ds:15h*4],ax
	mov	ax,[cs:Old15.XPTR.PSEG] ; get old segment
	mov	[ds:15h*4+2],ax
	call	CheckCallback	;
@@LEAVE:
	PopAll
@@EXIT:
	ClearSemaphoreIRET
@@OLD15:
	jmp	[cs:Old15.DPTR] 	     ; Jump to the old vector.
	endp

Proc	StopSound	near
	cli
	cmp	[cs:PlayingSound],1		; Currently playing a sound?
	jne	@@notout
	mov	[cs:tanlen],0	; force cleanup.
	sti
	mov	ah,84h		; Output sound to speaker.
	mov	al,07h		; Volume.
	int	1Ah		; Do the Tandy sound BIOS interupt.
@@notout:
	sti
	ret
	endp

ENDIF

IF	DIG_DIGISP
Proc	TranslateSound	near
	PushAll 		; Save all registers.

	xor	ax,ax		; No changed length, by default.
	cmp	dx,8000 		; <= 8khz?
	jle	@@PLAY			; yes, just play it at 8.
@@DOWNIT:
	mov	di,dx
	xor	dx,dx
	mov	ax,8000 		; base of 8khz.
	mov	dl,ah
	mov	ah,al
	xor	al,al			; Times 256
	div	di

	push	es
	pop	ds
	mov	si,bx		; Starting address of audio data.
	mov	bx,si			; Save start address into BX.
	mov	di,si			; Initial destination address.
	push	ds
	pop	es			; ES=DS
	xor	ah,ah			; Zero build.
@@DOWN: movsb				; Store it.
	add	ah,al			; Add fraction.
	jnc	@@BACK			; If not carry, don't advance DI.
	loop	@@DOWN			; Keep downsampling.
	jmp short @@DON
@@BACK: dec	di			; Don't repeat last byte.
	loop	@@DOWN
@@DON:
@@PLAY:
	PopAll
	mov	[byte es:bx],80h	; PCM needs 80h header byte.
	ret
	endp

Proc	PlaySound	near
	cmp	dx,8000 		; <= 8khz?
	jle	@@PLAY			; yes, just play it at 8.
@@DOWNIT:
	push	bx
	push	dx

	mov	ax,cx
	mov	bx,8000
	mul	bx
	pop	bx
	div	bx
	mov	dx,bx
	pop	bx
	mov	cx,ax
@@PLAY: mov	ax,es
	mov	ds,ax
	mov	si,bx	;
	mov	ax,0601h		; Interupt invokation.
	int	4Dh
	mov	[cs:PlayingSound],0
	ret
	endp

;; Not implemented.
Proc	StopSound	near
	ret
	endp

ENDIF

;; Pretty unique code for IBM sound driver.
IF	DIG_IBMSND
INTmask db	0		; Interupt controller mask.
INTmask2 db	0		; second pic
Proc    PlaySound       near
	mov	si,dx		; Frequency into SI
	mov	dx,0012h	; High word of 1,193,180.
	mov	ax,34DCh	; Low word of 1,193,180.
	div	si		; Divide by frequency passed.
	shr	ax,1		; Two times rate specified!
	mov	dx,ax		; Interupt rate result into DX.

	cli			; Disable hardware interupts while installing.
	in	al,21h			; Get current interupt mask state.
	mov	[cs:INTmask],al 	; Save it.
	mov	al,11111111b		; Now disable them all.
	out	21h,al			; Disable.
	in	al,0A1h
	mov	[cs:INTmask2],al
	mov	al,11111111b
	out	0A1h,al

;;;;*******************************************************************
        mov     al,90h          ; 10010000 means:
                                ; use timer 2, in mode 0 (int on terminal
                                ; count, loading only the low byte
	out	TIME_CNTRL,al


        in      al,61h          ; Get current Port B byte
        or      al,3            ; make shure bits 0,1 are set
                                ; bit 0 = gate for timer 2
                                ; bit 1 = speaker on
        out     61h,al          ; store it back
;;;;*******************************************************************
	push	dx		; Save rate.
	call	tinstall	; Install hardware interupt
	pop	dx		; Get back rate.
	call	trate		; Set the timer rate.
	call	DigPlay

	call	ResetTimer	; Put timer back to normal operation.

	call	CheckCallBack
	ret
	endp

Proc	DigPlay   near
;;; This procedure will play a digitzed sound sample using all of the
;;; processor's CPU.  In the background the Timer interupt is incrementing
;;; the sample load address at the exact frequency of the sampling rate
;;; of this sound sample.
;;; On entry: ES:BX ->address of the sound sample.
;;;		 CX ->length of sound sample.
	cld				; Direction flag forward.
	push	ds			; Save DS
	push	bp			; Save BP

	mov	si,bx			; Address to begin playing at.
	add	bx,cx
	mov	bp,bx			; Ending address.
	mov	ax,es
	mov	ds,ax

;; Setup registers.
	mov	dx,portTIMER2

;; BX->current location inside source buffer.
;; BP->bytes remaing to process.

	mov	ah,20h			; Pre-load non-specific EOI.
;; *************************************************************************
;; ** PLAYING sound sample during these instructions.  This is the ONLY time
;; ** that any kind of interupts should be enabled at all.
;; *************************************************************************
	mov	al,11111110b		; Allow only timer interupt to occur.
	out	21h,al			; set interupt controller mask.
	Dally

	sti				; Allow timer interupt to occur.
	mov	bx,cx			; Initial previous.
@@LOP:	cmp	bx,cx			; Advanced?
	je	@@LOP
	mov	bx,cx
	lodsb
	out	dx,al
@@NXT:	cmp	bx,cx
	je	@@NXT
	mov	bx,cx
	mov	al,[si-1]
	out	dx,al
	cmp	si,bp
	jb	@@LOP


;; *************************************************************************
;; ** Finished playng section.	Kill interupts now!!
;; *************************************************************************
	cli				; Disable interupts.
@@END:
	mov	al,11111111b		; Disable interupts of ALL kinds!!
	out	21h,al			; set interupt controller mask.
	Dally

	call	rtimer

	mov	[cs:PlayingSound],0

	mov	al,[cs:INTmask] 	; Saved interupt enable mask.
	out	21h,al			; reset it.
	mov	al,[cs:INTmask2]
	out	0A1h,al
	Dally
	sti				; Re-enable interupts.

	pop	bp
	pop	ds
	ret
	endp

	ALIGN	4
Proc	Int0	  far
	dec	cx
	mov	al,ah			; 2(2)	 get interupt enable bit
	out	20h,al			; 10(9)  Send a nonspecific EOI
	sti				;  2	 restore hardware interupts.
	ret	2			; 25(25) return from hardware interupt.
	endp

Proc	StopSound
	ret
	endp

command_reg     equ 43h
channel_0       equ 40h
channel_2       equ 42h         ; speaker's frequency oscillator.

Proc	trate  near
; This routine sets the rate at which the timer routine is
; interupted and the cutoff value for one bit sound
; called as:
;
; DX ->rate to play sound at.
        mov     al,00110110b
        out     command_reg,al
        jmp     $+2
	mov	ax,dx		; Get rate into AX
        out     channel_0,al
        jmp     $+2
        mov     al,ah
        out     channel_0,al
        ret
	endp


OldTimer FARPTR <>	; Original timer interupt vector.

Proc	tinstall near
; Install timer interupt routine
        push    es              ; save extra segment
	xor	ax,ax
	mov	es,ax
	mov	ax,[es:INT8OFF]     ; Get offset portion.
	mov	[OldTimer.XPTR.POFF],ax
	mov	ax,[es:INT8SEG]
	mov	[OldTimer.XPTR.PSEG],ax
	mov	[word es:INT8OFF],offset INT0
	mov	[es:INT8SEG],cs
        pop     es
        RET
	ENDP

INT8OFF         equ     8*4
INT8SEG         equ     8*4+2

Proc	rtimer near
; This routine restores the timer interupt to what it was originally.
	push	ds
	push	dx
	push	ax

	mov	dx,[cs:DivisorRate]  ; Set timer rate to zero.
	call	trate		; Set timr rate to zero.
	xor	ax,ax
	mov	ds,ax		; Segment zero
	mov	ax,[cs:OldTimer.XPTR.POFF] ; get offset.
	mov	[ds:INT8OFF],ax      ; Set offset.
	mov	ax,[cs:OldTimer.XPTR.PSEG] ; get segment.
	mov	[ds:INT8SEG],ax

	pop	ax
	pop	dx
	pop	ds
        RET
	ENDP


;----------------------------------------------------------------------------
; ResetTimer
;
; This routine will reset timer 0 back to mormal PC operation
;
; Input:
;
; OutPut:
;----------------------------------------------------------------------------
Proc	ResetTimer    near
;; Reset timer chip to normal operation.

        in      al,61h
        and     al,0fch         ; Turn the speaker off  (mask bits 0,1)
        out     61h,al

	ret
	endp

ENDIF

IF	DIG_ADLIB OR DIG_CVXSND OR DIG_VMSND OR DIG_SMSND OR DIG_TANEXTX OR DIG_SOURCE OR DIG_ECHOII OR DIG_IBMBAK OR DIG_IBM1BIT OR DIG_BIGMOUTH OR DIG_T2500

Proc    PlaySound near
;; CX ->number of bytes in sound sample.
;; DS = Code group.
;; ES:BX -> far address of sound sample to be played.
;; DX ->frequency to play data back at.
IF	FOREGROUND
	push	ds
	push	si

IF	DIG_T2500
	mov	dx,[IO_ADDR]
	mov	al,3
	out	dx,al
	add	dx,2
	xor	al,al
	out	dx,al
	inc	dx
	mov	al,0E0h
	out	dx,al
ENDIF
IF      DIG_SOURCE
;;**	    SourceOn
ENDIF
IF	DIG_TANEXTX
	call	_tinit
ENDIF
IF	DIG_ADLIB
	PushAll
	call	PrepareToSampleOut
	PopAll
ENDIF
IF	DIG_IBM1BIT
	in	al,61h		; Get current Port B byte
	and	al,(NOT 3)
				; 0 and 1 is off.
				; bit 0 = don't gate for timer 2
                                ; bit 1 = speaker on
        out     61h,al          ; store it back
ENDIF
IF	DIG_IBMBAK
        mov     al,90h          ; 10010000 means:
                                ; use timer 2, in mode 0 (int on terminal
                                ; count, loading only the low byte
	out	TIME_CNTRL,al
        in      al,61h          ; Get current Port B byte
        or      al,3            ; make shure bits 0,1 are set
																; bit 0 = gate for timer 2
                                ; bit 1 = speaker on
        out     61h,al          ; store it back
ENDIF

	mov	si,bx
	push	es
	pop	ds

	mov	bx,dx		; Frequency in BX.

	mov	ax,[cs:LoopConstant]
	mov	di,582		; 18.2*32
	mul	di		; Now have long word result.
;; This is equal to the total number of LOOP's per second on this
;; microprocessor.

	div	bx		; Now for this many times per second.
IF	DIG_IBMBAK
	shr	ax,1
ENDIF
	mov	bx,ax


@@GO:	lodsb
IF	DIG_IBMBAK
	out	portTIMER2,al	    ; Send audio sample.
ENDIF
IF	DIG_CVXSND OR DIG_VMSND OR DIG_SMSND OR DIG_SOURCE OR DIG_ADLIB OR DIG_ECHOII OR DIG_BIGMOUTH OR DIG_T2500
;;; Data sample goes out here...............
LABEL	PORTMOD WORD
	mov	dx,0389h	; Data port.
IF	DIG_SOURCE
	OUT	DX,AL		;Send data to SS
	ADD	DX,2		;Set DX to ControlPort
	IN	AL,DX
	OR	AL,00001000b	;Bit 3 on
	OUT	DX,AL
	JMP	$+2		;short delay to settle bus
	IN	AL,DX
	AND	AL,11110111b	;Bit 3 off
	OUT	DX,AL
ENDIF
IF	DIG_ECHOII
	  mov	  ah,al
  ;;; Data sample goes out here...............
	  in	  al,dx 	  ; Get status.
	  mov	  al,ah
	  out	  dx,al 		  ; Send it.
ENDIF
IF	DIG_CVXSND OR DIG_VMSND OR DIG_SMSND OR DIG_ADLIB OR DIG_BIGMOUTH OR DIG_T2500
	  out	  dx,al 		  ; Send it.
ENDIF
ENDIF
IF	DIG_TANEXTX
	out	0C0h,al 	; Send it out to tandy.
ENDIF
IF	DIG_IBM1BIT
	out	61h,al
ENDIF

	mov	di,cx		; Save CX register in DI register.

	mov	cx,bx		; Get loop constant from BX register.

@@WAIT: loop	@@WAIT		; do single sample delay.

IF	DIG_IBMBAK
	out	portTIMER2,al	    ; Send audio sample.
	mov	cx,bx
@@WAIT2:loop	@@WAIT2

ENDIF
	mov	cx,di		; Get back CX register.

	loop	@@GO


	pop	si
	pop	ds

	call	StopSound

ELSE

;; Here we will calculate the interupt rate given the frequency requested.
	mov	si,dx		; Frequency into SI
	mov	dx,0012h	; High word of 1,193,180.
	mov	ax,34DCh	; Low word of 1,193,180.
	div	si		; Divide by frequency passed.
IF	DIG_IBMBAK
	shr	ax,1
ENDIF
	mov	dx,ax		; Interupt rate result into DX.

	push	dx
	push	bx

	mov	bx,dx		; Count down rate in BX
	xor	dx,dx
	mov	ax,[cs:DivisorRate]
	or	ax,ax
	jnz	@@OK1
	inc	dx
@@OK1:	div	bx
	mov	[RateDown],ax
	mov	[tvalue],ax

	pop	bx
	pop	dx

IF	DIG_T2500
	mov	dx,[IO_ADDR]
	mov	al,3
	out	dx,al
	add	dx,2
	xor	al,al
	out	dx,al
	inc	dx
	mov	al,0E0h
	out	dx,al
ENDIF

IF      DIG_SOURCE
;;**	    SourceOn
ENDIF
IF	DIG_TANEXTX
	call	_tinit
ENDIF
IF	DIG_ADLIB
	PushAll
	call	PrepareToSampleOut
	PopAll
ENDIF
IF	DIG_IBM1BIT
	in	al,61h		; Get current Port B byte
	and	al,(NOT 3)
				; 0 and 1 is off.
				; bit 0 = don't gate for timer 2
                                ; bit 1 = speaker on
				out     61h,al          ; store it back
ENDIF
IF	DIG_IBMBAK
        mov     al,90h          ; 10010000 means:
                                ; use timer 2, in mode 0 (int on terminal
                                ; count, loading only the low byte
	out	TIME_CNTRL,al
        in      al,61h          ; Get current Port B byte
        or      al,3            ; make shure bits 0,1 are set
                                ; bit 0 = gate for timer 2
                                ; bit 1 = speaker on
        out     61h,al          ; store it back
ENDIF

	mov	[SEGSAMP],es	; segment.
	mov	[ADDRESS+1],bx	  ; offset
	mov	[STARTADDRESS],bx
	mov	[TOTALLENGTH],cx	;
	add	cx,bx		; Compute ending address.
IF	DIG_IBMBAK
	mov	[COMPARE+4],cx	  ; set for comparison to ending address.
ELSE
	mov	[COMPARE+5],cx	  ; set for comparison to ending address.
ENDIF
	push	dx		; Save rate.
	call	tinstall	; Install hardware interupt
	pop	dx		; Get back rate.
	call	trate		; Set the timer rate.
ENDIF
	ret
	endp

Proc	StopSound	near
	PushCREGS
	push	cs
	pop	ds
	cmp	[PlayingSound],0
	je	@@GOUT
IF	FOREGROUND
ELSE
	call	rtimer		; Restore original timer interupt vector.
ENDIF
IF	DIG_IBM1BIT
        in      al,61h
        and     al,0fch         ; Turn the speaker off  (mask bits 0,1)
        out     61h,al
ENDIF
IF	DIG_IBMBAK
;; Reset timer chip to normal operation.
;;	  mov	  al,34h
;;	  out	  TIME_CNTRL,al
;;	  Dally
;;	  mov	  al,0ffh
;;	  out	  TIMER0,al
;;	  Dally
;;	  out	  TIMER0,al
;;	  Dally

        in      al,61h
        and     al,0fch         ; Turn the speaker off  (mask bits 0,1)
        out     61h,al
ENDIF
IF	DIG_SOURCE
;;**	    SourceOff
ENDIF
	mov	[cs:PlayingSound],0	; Finished playing sound.
	cmp	[cs:CallBacks],0	; Callbacks enabled?
	je	@@GOUT		; no, exit.
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
@@GOUT:
	PopCREGS
	ret
	endp

IF	FOREGROUND
ELSE

command_reg     equ 43h
channel_0       equ 40h
channel_2       equ 42h         ; speaker's frequency oscillator.

Proc	trate  near
; This routine sets the rate at which the timer routine is
; interupted and the cutoff value for one bit sound
; called as:
;
; DX ->rate to play sound at.
        mov     al,00110110b
        out     command_reg,al
        jmp     $+2
	mov	ax,dx		; Get rate into AX
        out     channel_0,al
        jmp     $+2
        mov     al,ah
        out     channel_0,al
        ret
	endp


OldTimer FARPTR <>	; Original timer interupt vector.

Proc	tinstall near
; Install timer interupt routine
        push    es              ; save extra segment
	xor	ax,ax
	mov	es,ax
	mov	ax,[es:INT8OFF]     ; Get offset portion.
	mov	[OldTimer.XPTR.POFF],ax
	mov	ax,[es:INT8SEG]
	mov	[OldTimer.XPTR.PSEG],ax
	mov	[word es:INT8OFF],offset timer2
	mov	[es:INT8SEG],cs
	mov	[flag],0	; Re-entrency flag, starts at 0.
        pop     es
        RET
	ENDP

INT8OFF         equ     8*4
INT8SEG         equ     8*4+2

Proc	rtimer near
; This routine restores the timer interupt to what it was originally.
	push	ds
	push	dx
	push	ax

	mov	dx,[cs:DivisorRate]  ; Set timer rate to zero.
	call	trate		; Set timr rate to zero.
	xor	ax,ax
	mov	ds,ax		; Segment zero
	mov	ax,[cs:OldTimer.XPTR.POFF] ; get offset.
	mov	[ds:INT8OFF],ax      ; Set offset.
	mov	ax,[cs:OldTimer.XPTR.PSEG] ; get segment.
	mov	[ds:INT8SEG],ax

	pop	ax
	pop	dx
	pop	ds
        RET
	ENDP

flag	dw	0
tvalue	dw	?
RateDown	dw	?	; Reload decrement count for servicing 18.2
SEGSAMP dw	?		; Segment of sound sample.

	ALIGN  16
IF	DIG_IBMBAK
TOTALLENGTH	dw	?	;
STARTADDRESS	dw	?	; Starting address of sample
Proc	TIMER2	FAR
	SetSemaphore
        push    ax              ; Save ax
        push    ds              ; Save data segment

@@T3:	mov	ds,[cs:SEGSAMP] ;
LABEL	ADDRESS WORD
	mov	al,[1234h]	; Get sound sample.
	out	portTIMER2,al	    ; Send audio sample.
	mov	ax,cs
	mov	ds,ax
	not	[ADDW+4]     ; Flip/Flop audio sample.
LABEL	ADDW	BYTE
	sub	[ADDRESS+1],0FFFFh
LABEL	COMPARE WORD
	cmp	[ADDRESS+1],1234h      ; Hit end?
	je	@@OUT		; yes, exit.
	dec	[tvalue]
	jz	@@T2
@@GOUT:
        pop     ds
	ClearSemaphore
				mov     al,20h          ; set interupt enable bit
        out     20h,al          ; Send a nonspecific EOI
        pop     ax
	iret
@@T2:
	ClearSemaphore
	;; sti                  ; DO NOT ENABLE
	pushf			; Push flags to fake an Interupt.
	call	[cs:OldTimer.DPTR]     ; Call the original interupt vector
	mov	ax,[cs:RateDown]
	mov	[cs:tvalue],ax
	SetSemaphore
	jmp short @@T3
@@OUT:	call	StopSound
	jmp short @@GOUT
	ENDP
ELSE

IF	BACKFILL
Proc	ReportDMAC
	mov	ax,[cs:TOTALLENGTH]
	mov	bx,[cs:ADDRESS+1]
	sub	bx,[cs:STARTADDRESS]
	sub	ax,bx
	ret
	endp
ENDIF

TOTALLENGTH	dw	?	;
STARTADDRESS	dw	?	; Starting address of sample
Proc    timer2  FAR
	SetSemaphore
	push	ax		; Save ax
IF	DIG_CVXSND OR DIG_VMSND OR DIG_SMSND OR DIG_SOURCE OR DIG_ADLIB OR DIG_ECHOII OR DIG_BIGMOUTH OR DIG_T2500
	push	dx
ENDIF
	push	ds		; Save data segment

@@T3:	mov	ds,[cs:SEGSAMP] ; Place into data segment.
LABEL	ADDRESS WORD
	mov	al,[1234h]	; Get offset of data sampel.
IF	NOSOUND
	jmp	@@NEXT
ENDIF
IF	DIG_CVXSND OR DIG_VMSND OR DIG_SMSND OR DIG_SOURCE OR DIG_ADLIB OR DIG_ECHOII OR DIG_BIGMOUTH OR DIG_T2500
;;; Data sample goes out here...............
LABEL	PORTMOD WORD
	mov	dx,0389h	; Data port.
IF	DIG_SOURCE
	OUT	DX,AL		;Send data to SS
	ADD	DX,2		;Set DX to ControlPort
	IN	AL,DX
	OR	AL,00001000b	;Bit 3 on
	OUT	DX,AL
	JMP	$+2		;short delay to settle bus
	IN	AL,DX
	AND	AL,11110111b	;Bit 3 off
	OUT	DX,AL
ENDIF
IF	DIG_ECHOII
	  mov	  ah,al
  ;;; Data sample goes out here...............
	  in	  al,dx 	  ; Get status.
	  mov	  al,ah
	  out	  dx,al 		  ; Send it.
ENDIF
IF	DIG_CVXSND OR DIG_VMSND OR DIG_SMSND OR DIG_ADLIB OR DIG_BIGMOUTH OR DIG_T2500
	  out	  dx,al 		  ; Send it.
ENDIF
ENDIF
IF	DIG_TANEXTX
	out	0C0h,al 	; Send it out to tandy.
ENDIF
IF	DIG_IBM1BIT
	out	61h,al
ENDIF
;;; Data sample sent to adlib board....
@@NEXT:
	inc	[cs:ADDRESS+1]
LABEL	COMPARE WORD
	cmp	[cs:ADDRESS+1],1234h	  ; Hit end?
	je	@@OUT
@@GOUT:
	dec	[cs:tvalue]	; add
	jz	@@T2		; If not a carry then we didn't over flow.
	pop	ds
IF	DIG_CVXSND OR DIG_VMSND OR DIG_SMSND OR DIG_SOURCE OR DIG_ADLIB OR DIG_ECHOII OR DIG_BIGMOUTH OR DIG_T2500
	pop	dx
ENDIF
	ClearSemaphore
	mov	al,20h
	out	20h,al
	pop	ax
	iret

@@T2:
	ClearSemaphore
IF	ACTIVISION		; If building Bill Volk's version.
	sti   			; Modified by W. Volk 4-7-93
ENDIF
	pushf			; Push flags to fake an Interupt.
	call	[cs:OldTimer.DPTR]     ; Call the original interupt vector
	mov	ax,[cs:RateDown]
	mov	[cs:tvalue],ax
	SetSemaphore
	jmp short @@T3
@@OUT:
IF	BACKFILL
	cmp	[cs:BACKF],0
	je	@@NOTBACK
	mov	ax,[cs:STARTADDRESS]
	mov	[cs:ADDRESS+1],ax
	jmp short @@GOUT
@@NOTBACK:
ENDIF
	call	StopSound
	jmp short @@GOUT
	ENDP
ENDIF

ENDIF

ENDIF

;/*********************************************************************
;
; Here begins code for Aria chipset based sound cards.
;
;*********************************************************************/

IF DIG_ARIA


pan_graph  	  db 0,4,8,12,16,20,24,28         	  ;  0 - 7
							db 32,36,40,44,48,52,56,60     		  ;  8 - 15
							db 64,68,72,76,80,84,88,92 	        ; 16 - 23
							db 96,100,104,108,112,116,120,124 	; 24 - 31
							db 128,132,136,140,144,148,152,156 	; 32 - 39
							db 160,164,168,172,176,180,184,188	; 40 - 47
							db 192,196,200,204,208,212,216,220	; 48 - 55
							db 224,228,232,236,240,244,252,255	; 56 - 63
							db 255,255,255,255,255,255,255,255  ; 64 -
							db 255,255,255,255,255,255,255,255
							db 255,255,255,255,255,255,255,255
							db 255,255,255,255,255,255,255,255
							db 255,255,255,255,255,255,255,255
							db 255,255,255,255,255,255,255,255
							db 255,255,255,255,255,255,255,255
							db 255,255,255,255,255,255,255,255

DSP_DATA      dw ?     ;IO_Addr+0h
DSP_CTRL_STAT dw ?     ;+02h
DSP_DMADDR    dw ?     ;+04h
DSP_DMADATA   dw ?     ;+04h
DSP_IRQ       dw ?

acc		        dw 0     ; error accumulator for up/down sampling
ratio		      dw ?		 ; offset for up/down sampling
ratio_h		    dw ?		 ; highest byte of ratio
sending		    dw ?		 ; number of bytes sent in transfer
irq_busy	    dw ?		 ; flag to indicate IRQ handler is busy

main_volume   dw 100   ; current volume
panpot        dw 64    ; current pan value
old_IRQ_o     dw ?     ; vector for old IRQ
old_IRQ_s     dw ?

DMA_ptr       dd ?     ; current pointer in sample
DMA_len_l     dw ?     ; bytes remaining to play in sample

iv_status     dw ?     ; flag whether IRQ has been revectored
IRQ_confirm   dw ?     ; IRQ checking byte

buff_data_o   dw ?     ; far ptr to sample data
buff_data_s   dw ?
buff_len_l    dw ?     ; length of sample data
buff_freq     dw ?     ; frequency of sample

PIC0_val      db ?     ; saved value of PIC0
PIC1_val      db ?     ; saved value of PIC1

old_freq      dw ?     ; current playing frequency
old_playmode  dw ?     ; current playmode

init_OK       dw 0     ; true if card initialized ok
inimode       dw 0     ; card mode: 0=Aria 1=SB
critical      dw 0     ; true if nearing end of sample


;----------------------------------------------------------------------
;  Procedure: set_sample_rate
;
;  Description:
;       Set the data format for playing and recording digital
;	      audio.
;
;  Input:
;			    AX = New sample rate
;	[PlayMode] = Playing mode.  Bit 0 = 8/16 bit sample 0=8 bit
;                             Bit 1 = mono/stereo     0 = mono
;  Return:
;         AX = 1, sucessful flag
;
;  Remarks:
;	    Aria support the following sample rate:
;                index	  freq	     DSP format      Control Port
;		              0       11025 Hz   00h (11.025kHz) 40h (22.05kHz)
;                 1       22050 Hz   10h (22.050kHz) 40h (22.05kHz)
;                 2       44100 Hz   20h (44.100kHz) 00h (44.10kHz)
;                 3        8850 Hz   10h (22.050kHz) 20h (32   kHz)
;                 4       15750 Hz   10h (22.050kHz) 60h (16   kHz)
;                 5       31500 Hz   00h (11.050kHz) 60h (16   kHz)
;
;          Aria support the following data pack type:
;
;	         DSP format:
;
;                     |_|_|_|_|_|_|_|_|
; sample_rate_index____|_|_|_| | | | |_______ 0:mono, 1:stereo
;      reserved _______________| | |_________ 0:8bit, 1:16bit
;                                |___________ ADPCM(4:1), 0:disable, 1:enable
;
;----------------------------------------------------------------------
proc set_sample_rate near     ;Establish DSP sample rate and playback mode
			mov  dx,[PlayMode]
			cmp  dx,[old_playmode]
			jne  short @@setparms
			cmp  ax,[old_freq]    ;avoid clicks by skipping if were not changing
			je   short @@exit     ;any parameters

@@setparms:
			mov  [old_freq],ax		; save new freq as old
			mov  [old_playmode],dx

			xor  dx,dx		        ; clear dx
			mov  [acc],dx		      ; reset acc
			mov  bx,22050		      ; 22.050kHz
			div  bx			          ; dx:ax / bx = ax == ratio_h
			mov  [ratio_h],ax		  ; save in
			xor  ax,ax		        ; clear ax => remainder * 65536
			div  bx			          ; /fix rate => ax = ratio
			mov  [ratio],ax		    ;

			mov  ax,[PlayMode]    ; Use this.  The bits match the format perfectly
			and  ax,3             ; Mask off unwanted bits just in case
			or   ax,10h
;@@skip2:

			push ax
			cli
			mov  ax,3
			call sendDSP_time
			pop  ax
			call sendDSP_time
			mov  ax,-1
			call sendDSP_time
			sti

			mov  dx,[DSP_CTRL_STAT]	; get control reg
			in   ax,dx		        ; read in control data
			and  ax,0ff9fh		    ; clear sample rate bits
			or   ax,040h		      ; set 22kHz
			out  dx,ax		        ; set it

@@exit:
			mov  ax,1
			ret
ENDP

;----------------------------------------------------------------------
;  Procedure: set_volume
;
;  Description:
;	    Establish digital playback output level with volume and pan
;     position.
;
;  Input: none
;
;  Return: none
;
;  Remarks:
;
;     Stereo volume is determined by panning and volume:
;
;     multiple constant: 0,4,8......128,.....252,255 (in lookup table)
;     is based on 0 - 63 scale.
;
;  pan position:      0  ...     64   ...     127
;           	   left <-------------------------> right
;		 	                         x - right > left
;                                   x - balance, right == left
;                                         x - left > right
;
;     volume scale:      0     ........          127
;                  low   <-------------------------> high
;
;     left output level = pan pos * multiple constant * volume scale
;     right output level = (127-pan pos) * multiple constant * volume scale
;----------------------------------------------------------------------
proc set_volume near
			push si
			push di

			mov  si,127
			sub  si,[panpot]		    ; right side scale
			mov  al,[pan_graph+si]	; get multiple constant fm lookup tbl
			mul  [byte main_volume] ; ax = al * main_volume
			mov  di,ax              ; DI = right volume 0 - 32385

			mov  si,[panpot]		    ; regain panpot
			mov  al,[pan_graph+si]	; get multiple constant fm lookup tbl
			mul  [byte main_volume] ; ax = al * main_volume
			mov  si,ax              ; SI = left volume 0 - 32385

			call set_volume_helper

			pop  di
			pop  si
			ret
ENDP

proc set_volume_helper near
			cli
			mov  ax,4
			call sendDSP_time
			mov  ax,si
			call sendDSP_time
			mov  ax,di
			call sendDSP_time
			mov  ax,-1
			call sendDSP_time
			sti
			ret
endp

proc IRQ_play_buffer far      ;Main IRQ handler
			sti
			push ax
			push bx
			push cx
			push dx
			push si
			push di
			push bp
			push ds
			push es
			cld
			push cs
			pop  ds

			cmp  [irq_busy],1		          ; is in the middle of service?
			je   short @@EOIonly		            ; yes, ignore the interrupt, jmp
																		; nope,
			mov  [irq_busy],1		          ; set in service flag
			cmp  [PlayingSound],1
			je   short @@endbuf

;			xor  ax,ax                    ;this wreaks havoc on unloading and
;			call halt_DMA                 ;reloading the driver with Midpak.

			jmp  short @@EOI

@@endbuf:
			cmp  [PENDING],0              ;always do another chunk if another
			jne  short @@always           ;sound is pending.
			cmp  [DMA_len_l],0
			je   short @@end_of_block

@@always:
			call xfer_chunk               ; no, send next chunk
			jmp  short @@EOI

@@end_of_block:
			call IRQ_rest_vect            ; restore vector back
			mov  [PlayingSound],0

@@EOI:
			mov  al,20h                   ;send EOI to PIC
			cmp  [DSP_IRQ],8              ;clear PIC1 if IRQ >= 8
			jb   short @@master
			out  0a0h,al
@@master:
			out  20h,al

			cmp  [PlayingSound],0
			jne  short @@exit
			call CheckCallBack

@@exit:
			mov  [irq_busy],0
@@exit2:
			pop  es
			pop  ds
			pop  bp
			pop  di
			pop  si
			pop  dx
			pop  cx
			pop  bx
			pop  ax
			iret

@@EOIonly:                          ;no irq_busy reset/call back check
			mov  al,20h                   ;send EOI to PIC
			cmp  [DSP_IRQ],8              ;clear PIC1 if IRQ >= 8
			jb   short @@master2
			out  0a0h,al
@@master2:
			out  20h,al
			jmp  @@exit2
ENDP

proc xfer_chunk near          ;Get addr, size of next chunk; send it
			mov  dx,1024            ; assume 1KBytes length
			cmp  [ratio_h],1		    ; upsampling?
			jb   short @@chkendbuf  ; yes, jmp
			cmp  [ratio],0		      ; nope, is no shifting?
			je   short @@chkendbuf  ; yes, jmp
			mov  dx,2048            ; compensate for rates > 22KHz

@@chkendbuf:
			mov  ax,[DMA_len_l]
			mov  [critical],0		    ; assume length is ok
			cmp  ax,dx              ; nearing end of sample?
			ja   short @@len_OK		  ;
			mov  [critical],1		    ; critical status flag

@@len_OK:
			mov  dx,[DSP_CTRL_STAT]	; DSP control port
			mov  ax,0cah		        ; interrupt PC & DSP at data write
			out  dx,ax		          ; set control port

;			test [PlayMode],1       ; stereo or mono?
;			jz   short @@domono
;			call setpacket_ster     ; up/down sample stereo sample ax=bytes read
;			jmp  short @@done
;@@domono:
			call setpacket_mono     ; up/down sample mono sample, ax=bytes read.
;@@done:

			push ax
			call xfer_packet	      ; transfer packet
			pop  ax

			add  [word DMA_ptr],ax
			sub  [DMA_len_l],ax     ;subtract len of transmitted chunk +1

			ret
ENDP

;---------------------------------------------------------------------
;  Procedure: setpacket()
;
;  Description:
;       set up DSP RAM FIFO address and pitch shifting for different
;       sample rate
;  Input:
;       [critical] - critical buffer flag
;               = 1, the packet size is close to the end of buffer
;                     so each byte process needs to check the boundary
;                     of the buffer.  If it is over buffer boundary
;                     then we send silence for the remaining bytes
;
;  Return:
;       ax = the actual number of bytes read from sample.
;
;  Remarks:
;
;       . In ARIA mode, we need to send 512 words a time, if we hit the
;         end of the buffer we have to fill packet with silence data
;         or append a pending sample.
;
;----------------------------------------------------------------------
proc setpacket_mono near

			call setFIFOaddr	   ; set DMA address ready
			les  si,[DMA_ptr]		 ; get the address of
			;
			;  512 words of data per packet
			;
			mov  [sending],1	   ; start from 1 byte
			test [PlayMode],1    ; stereo?
			jz   short @@no1
			inc  [sending]       ; start at two for stereo
@@no1:
			mov  ax,-1		       ; set flag to indicate not end of buf
			mov  cx,512		       ; 8-bit sample rate, total 1024 byte
			cmp  [DMA_len_l],0   ; just in case we're on even boundary
			jne  short @@nxtword
			xor  dx,dx
			call adv_ptr

@@nxtword:
			mov  bx,8080h        ; assume silence
			xor  dx,dx		       ; assume ->there is no need to move ptr
			or   ax,ax		       ;  because of the end of buffer. Is it?
			jz   short @@mvsi_1	 ; yes -> jmp

			mov  bl,[es:si]		   ; no, load the current byte in bl
			mov  bh,[es:si+1]    ; assume stereo and read right channel data
			mov  ax,[acc]		     ; get accumulator
													 ; dx == 0,  dx:ax == 0:acc
			add  ax,[ratio]		   ; fraction portion
			adc  dx,[ratio_h]		 ; bytes to advance pointer in dx
			test [PlayMode],1    ; are we in stereo?
			jz   short @@no2
			shl  dx,1            ; move ptr by double the amount
@@no2:
			mov  [acc],ax		     ; save fraction
			mov  ax,-1		       ; flag not the end of buffer
													 ; dx == bytes to advance pointer
			cmp  [critical],1		 ; Do we need to check end of buffer?
			jne  short @@mvsi_1	 ; nope,  jmp
			call adv_ptr 		     ; ax = 0 if its the end of the buffer
													 ; ax = -1, switched to pending buffer

@@mvsi_1:
			add  si,dx		       ; move pointer
			add  [sending],dx	   ; actual data move in voice data

			test [PlayMode],1    ; if stereo, skip all this, we have our
			jnz  short @@set1    ; right channel data in BH already.

			mov  bh,80h          ; assume silence
			xor  dx,dx		       ; assume ->there is no need to move ptr
			or   ax,ax		       ; because of the end of buffer, Is it?
			jz   short @@set1	   ; yes -> jmp
													 ; nope
			mov  bh,[es:si]	     ; get one more byte
			mov  ax,[acc]		     ; get accumulator
													 ; dx == 0, dx:ax == 0:acc
			add  ax,[ratio]		   ; fraction portion
			adc  dx,[ratio_h]		 ; bytes to advance pointer in dx
			mov  [acc],ax		     ; save fraction
			mov  ax,-1		       ; flag not the end of buffer
													 ; dx == bytes to advance pointer
			cmp  [critical],1		 ; Do we need to check end of buffer?
			jne  short @@mvsi_2	 ; nope,  jmp
			call adv_ptr 		     ; return:
													 ;   ax = 0, if it's the end of buffer
													 ;   ax = -1, not the end
@@mvsi_2:
			add  si,dx
			add  [sending],dx

@@set1:
			mov  dx,[DSP_DMADATA]
			push ax			         ; save ending of buffer flag
			mov  ax,bx		       ; get value
			out  dx,ax		       ; send out one word
			pop  ax			         ; restore ending flag
			loop @@nxtword

			mov  ax,[sending]		 ; actual block length
@@exit:
			ret
ENDP

;----------------------------------------------------------------------
;  Procedure: adv_ptr()
;
;  Description:
;       Check the end of current playing buffer
;
;  Input:
;
;  Return:
;       ax = 0 - hit the end of buffer, or
;            -1, no change
;	      dx = bytes to advance in pointer
;
;----------------------------------------------------------------------
proc adv_ptr near
			mov  ax,[DMA_len_l]	        ; get low word of left bytes in buf
			cmp  ax,[sending]		        ; more bytes in current playing buffer?
			ja   short @@nochgptr

;// We handle pending sounds here so we don't get any silence inserted in
;// our two sounds.  We ONLY append the sound under these circumstances:
;
;// 1. There IS a pending sound. (PENDING is nonzero)
;
;// 2. The playback frequencies of the two samples are equal.
;
;
;// The CallBacks flag will be cleared if it points to the 'PlayPending'
;// procedure.

			cmp  [PENDING],0
			je   short @@nopending
			lea  di,[PENDSND]
			mov	 ax,[ds:(SOUNDSPEC di).FREQUENCY]
			cmp  ax,[old_freq]
			jne  short @@nopending

			cmp  [CallBacks],0
			je   short @@skip1
			lea  ax,[PlayPending]
			cmp  ax,[word CallBack]
			jne  short @@skip1
			mov  ax,cs
			cmp  ax,[word CallBack+2]
			jne  short @@skip1
			mov  [CallBacks],0          ;clear CallBacks if it points to us
@@skip1:
			mov  [sending],1            ;reset number of bytes sent.
			test [PlayMode],1
			jz   short @@skip2
			inc  [sending]
@@skip2:
			mov  [PENDING],0            ;clear Pending flag

			lea  si,[PENDSND]
			mov  ax,[(SOUNDSPEC si).PLAYLEN]
			mov  [DMA_len_l],ax
			mov  es,[(SOUNDSPEC si).PLAYADR.XPTR.PSEG]
			mov  [word DMA_ptr+2],es
			mov  si,[(SOUNDSPEC si).PLAYADR.XPTR.POFF]
			mov  [word DMA_ptr],si
			mov  [acc],0

			sub  si,dx
			sub  [sending],dx
@@nochgptr:
			mov  ax,-1
			ret

@@nopending:
			mov  [PlayingSound],0       ; set done status
			xor  ax,ax                  ; set end-of-buffer flag
																	;   and no change in pointer
			or   dx,dx	  	            ; any char to move?
			jz   short @@noadj
			sub  [sending],dx
			xor  dx,dx		              ; no ptr advanced
@@noadj:
			ret
ENDP

;----------------------------------------------------------------------
;  Procedure: xfer_packet()
;  Description:
;      To transfer one packet size of digital audio data by sending DSP
;      command 10h
;  Input:
;      none
;  Return:
;      none
;  Remarks:
;
;----------------------------------------------------------------------
proc xfer_packet near
			cli
			mov  ax,10h
			call sendDSP_time
			mov  ax,-1
			call sendDSP_time
			sti
			ret
ENDP

;----------------------------------------------------------------------
;  Procedure: setFIFOaddr()
;
;  Description:
;       To select digital audio FIFO buffer location
;
;  Input:
;	none
;  Return:
;       ax - FIFO buffer location
;
;  Remarks:
;
;       DSP RAM addr:
;                   6100h:   FIFO buffer offset for playback
;                   6101h:   FIFO buffer offset for recording
;           ...
;           7000h - 73FFh:   FIFO - digital audio channel 3
;           7400h - 77FFh:   FIFO - digital audio channel 2
;           7800h - 7BFFh:   FIFO - digital audio channel 1
;           7C00h - 7EFFh:   FIFO - digital audio channel 0
;
;----------------------------------------------------------------------
proc setFIFOaddr near

			mov  dx,[DSP_DMADDR] ; DSP RAM location reg
			mov  ax,6100h		     ; FIFO buffer offset for playback
			out  dx,ax		       ; set locatation

			inc  dx
			inc  dx			         ; DSP RAM data reg
			in   ax,dx		       ; read packetsize
			dec  dx
			dec  dx		  	       ;  DSP RAM address reg
			mov  bx,ax		       ; save in bx

;DMD: The following code seemed irrelevant.  This driver only uses
;Channel 0 so there's no reason to recalculate the offset each time.

;		  mov  cx,1
;		  mov  si,1024		     ; 1k bytes (512 words) per channel
;
;		  xor  ax,ax		       ; start from 0
;__chanFIFO:
;		  add  ax,si
;		  loop __chanFIFO
;		  mov  si,ax		       ; si holds the offset from the top
;
;		  mov  ax,8000h		     ; top of the address of DSP FIFO buffer
;		  sub  ax,si		       ; address for audio channel 0

			mov  ax,7c00h
			add  ax,bx		       ; adjust offset

			out  dx,ax		       ; set buffer offset
			ret
ENDP

;----------------------------------------------------------------------
;  Procedure: sendDSP_time()
;
;  Description:
;       Send a word to DSP with checking DSP write status first.
;	Loop 1000h times for time-out.
;
;  Input:
;       data: word to send
;  Return:
;       ax = 0, indicate DSP is not ready, fail
;       ax = -1, indicate successful sending
;  Remarks:
;
;----------------------------------------------------------------------

proc sendDSP_time near
			mov  bx,ax
			push cx
			mov  cx,1000h		          ; 4000 times
			mov  dx,[DSP_CTRL_STAT]   ; DSP write status
@@poll_cts:
			in   ax,dx		            ; read in
			test ax,8000h		          ; ready to write to DSP?
			jz   short @@cts	        ; yes, jmp
			loop @@poll_cts	    	    ; nope, - to read again
			xor  ax,ax                ; set fail flag
			jmp  short @@seterr
						; DSP is ready to write
@@cts:
			mov  dx,[DSP_DATA]	  	  ; DSP data reg
			mov  ax,bx   		          ; get data
			out  dx,ax		            ; write a byte to DSP
			mov  ax,-1		            ; set successful flag

@@seterr:
			pop  cx
			ret
ENDP

;----------------------------------------------------------------------
;  Procedure: putmem16(UINT memaddr, UINT val)
;
;  Description:
;       put a word value in DSP external RAM area.
;
;  Input:
;	memaddr: word of offset in DSP RAM area
;       val: word to send
;  Return:
;       none
;
;  Remarks:
;
;----------------------------------------------------------------------
proc putmem16 near
			mov  bx,ax
			mov  cx,dx
			mov  dx,[DSP_DMADDR]     ; DSP RAM location reg
			mov  ax,cx	             ; get offset
			out  dx,ax		           ; set locatation
			inc  dx
			inc  dx			             ; DSP RAM data reg
			mov  ax,bx		           ; get data
			out  dx,ax		           ; write data
			ret
ENDP

;----------------------------------------------------------------------
;  Procedure: getmem16(UINT memaddr)
;
;  Description:
;       get a word value from DSP external RAM area.
;
;  Input:
;	memaddr: word of offset in DSP RAM area
;
;  Return:
;       ax: word of value read from DSP
;
;  Remarks:
;
;----------------------------------------------------------------------
proc getmem16 near
			mov  ax,dx
			mov  dx,[DSP_DMADDR] ; DSP RAM location reg
			out  dx,ax		       ; set locatation
			inc  dx
			inc  dx			         ; DSP RAM data reg
			in   ax,dx		       ; get data
			ret
ENDP

;****************************************************************************
;  Procedure: halt_DMA(UINT WaitOpt)
;  Description:
;    To halt data transfer by sending command to DSP in order to stop
;    transfer data from buffer.
;
;  Input:
;    WaitOpt - flag to indicate 'wait optional'
;            = 1:wait for an interrupt, 0:don't need to wait.
;  Return:
;
;  Remarks:
;    1. Aria: to use DSP command ID 12h - deactivates an audio playback
;             channel.
;
;----------------------------------------------------------------------
proc halt_DMA near
			cmp  [PlayingSound],0
			je   short @@nohalt
			push ax
			cli
			mov  ax,12h
			call sendDSP_time   ; stop audio playback
			mov  ax,0
			call sendDSP_time   ; channel
			mov  ax,-1
			call sendDSP_time   ; terminator
			sti

			pop  ax
@@nohalt:
			or   ax,ax          ;optional wait to absorb dummy IRQ
			je   short @@exit
			cmp  [iv_status],0
			jne  short @@exit

			lea  ax,[IRQ_test]  ;enable EOD interrupts from DSP
			call IRQ_set_vect
			mov  ax,10
			call sysex_wait     ;(140 milliseconds)
			call IRQ_rest_vect

@@exit:
			ret
ENDP

proc IRQ_set_vect near     ;Install DMA IRQ handler
			push si
			push di
			cli

			cmp  [iv_status],0         ;avoid redundant settings
			jne  short @@exit

			mov  bx,[DSP_IRQ]          ;index interrupt vector for IRQ
			cmp  bx,8
			jb   short @@calc_vect
			add  bx,60h                ;index slave PIC vectors if IRQ > 7
@@calc_vect:
			add  bx,8                  ;add in common offset
			shl  bx,1
			shl  bx,1

			push ds
			xor  dx,dx
			mov  ds,dx
			les  di,[bx]
			mov  [cs:old_IRQ_s],es
			mov  [cs:old_IRQ_o],di
			mov  [bx],ax
			mov  [bx+2],cs
			pop  ds
						   ; enable hardware interrupts for DSP
			mov  cx,[DSP_IRQ]          ; get irq number
			mov  bx,1
			shl  bx,cl
			cmp  cx,8
			jb   short @@sd1
			or   bx,4                  ; have to reinit PIC 0's daisy chain flag
@@sd1:
			not  bx
			in   al,0a1h
			mov  [PIC1_val],al
			and  al,bh
			out  0a1h,al
			in   al,21h
			mov  [PIC0_val],al
			and  al,bl
			out  21h,al

			mov  [iv_status],1

@@exit:
			pop  di
			pop  si
			sti
			ret
ENDP

proc IRQ_rest_vect near

			push si
			push di
			push ds
			cli

			cmp  [iv_status],1         ;avoid redundant settings
			jne  short @@exit

			mov  cx,[DSP_IRQ]          ;stop hardware interrupts from DSP
			mov  bx,1
			shl  bx,cl
			in   al,0a1h
			or   al,bh
			and  al,[PIC1_val]         ;don't kill any interrupts that were
			out  0a1h,al               ;initially active
			in   al,21h
			or   al,bl
			and  al,[PIC0_val]
			out  21h,al

			mov  bx,[DSP_IRQ]          ;index interrupt vector for IRQ
			cmp  bx,8
			jb   short @@calc_vect
			add  bx,62h                ;index slave PIC vectors if IRQ > 7
			jmp  short @@calc_vec1
@@calc_vect:
			add  bx,8
@@calc_vec1:
			shl  bx,1
			shl  bx,1

			xor  ax,ax
			mov  ds,ax
			mov  ax,[cs:old_IRQ_o]
			mov  dx,[cs:old_IRQ_s]
			mov  [bx],ax
			mov  [bx+2],dx

			mov  [cs:iv_status],0

@@exit:
			pop  ds
			pop  di
			pop  si
			sti
			ret
ENDP

proc IRQ_test far                 ;DMA IRQ handler for IRQ detection
			sti
			push ax
			mov  [cs:IRQ_confirm],1     ;flag interrupt received OK
			mov  al,20h                 ;send EOI to PIC
			cmp  [cs:DSP_IRQ],8         ;clear PIC1 if IRQ >= 8
			jb   short @@master
			out  0a0h,al
@@master:
			out  20h,al
			pop  ax
			iret
ENDP

proc sysex_wait near           ;Machine-independent delay
			push cx
			push ds
			mov  dx,40h              ;wait n VBL periods (14 ms/period min,
			mov  ds,dx               ;requires CGA/EGA/VGA/XGA video)
			mov  dx,[63h]            ;get CRTC Address register location
			add  dl,6                ;get CRTC Status register location
			mov  cx,ax
			jcxz short @@exit
@@sync_1:
			in   al,dx
			test al,8
			jz   @@sync_1
@@sync_2:
			in   al,dx
			test al,8
			jnz  @@sync_2
			loop @@sync_1
@@exit:
			pop  ds
			pop  cx
			ret
ENDP

proc shutdown_driver near
			push cs
			pop  ds
			cmp  [init_OK],0
			je   short @@exit
			call stop_d_pb
			mov  ax,1
			call resetDSP_mode 		        ; reset DSP to Sound Blaster Emulation
			mov  [init_OK],0
@@exit:
			ret
ENDP

proc stop_d_pb near
			cmp  [PlayingSound],0
			je   short @@exit
			call IRQ_rest_vect
			mov  ax,1
			call halt_DMA
			mov  [PlayingSound],0
@@exit:
			ret
ENDP

;----------------------------------------------------------------------
;  Procedure: resetDSP_mode(UINT inimode)
;
;  Description:
;       Initialize system and invoke specific DSP application and
;       module.
;
;       Sequence of sending to DSP,
;          0000 : command id
;          00xx : operation,
;                 xx:00 add task, :01 remove task, :02 load new module to #0
;          xxyy : task #, xx:00 ROM-based task, :01 RAM-based task
;                 yy:00 Aria mode, :01 Sound Blaster emulation
;          xxxx : addr of the entry point for RAM-based task
;                 xxxx:0000 for any ROM-based task
;          ffff : command terminator
;
;       Bit 7 of the DSP CONTOL port must be set to Aria Synthesizer
;       mode before switching any application.
;
;  Input:
;       inimode: task #, :0000 - Aria mode, :0001 - Sound Blaster emulation
;  Return:
;       ax = 0, fail
;	ax > 0,
;  Remarks:
;       . The currently defined ROM-based tasks are Aria and Sound Blaster
;         emulation so the input is task # only.  If there is expanded,
;         the routine should be expanded.
;
;----------------------------------------------------------------------
proc resetDSP_mode near           ;Returns AX=0 if failure

			mov  [inimode],ax
			mov  ax,0c8h		    ; Aria mode, 22kHz, Intrp DSP
			mov  dx,[DSP_CTRL_STAT]
			out  dx,ax

			mov  dx,6102h
			xor  ax,ax
			call putmem16 	    ; clear system initialization flag
			cli
			xor  ax,ax
			call sendDSP_time   ; command id: system initialize
			xor  ax,ax
			call sendDSP_time   ; add a DSP task
			mov  ax,[inimode]
			call sendDSP_time   ; initialization mode
			xor  ax,ax
			call sendDSP_time   ; address
			mov  ax,-1
			call sendDSP_time   ; terminator
			sti
			or   ax,ax		      ; error occured?
			jz   short @@exit		; yes,

			mov  cx,5000		    ; wait for system init
@@loopw:
			push cx
			mov  dx,6102h
			call getmem16       ; get system initialization status
			pop  cx
			cmp  ax,1		        ; initialization done?
			je   short @@set_mode	; yes, jmp
			push cx
			mov  ax,1
			call sysex_wait     ; nope, wait a moment
			pop  cx
			loop @@loopw		    ; try again
			xor  ax,ax   		    ; stop trying: set error code
			jmp  short @@exit

@@set_mode:
			mov  dx,[DSP_CTRL_STAT] ; get control reg
			mov  ax,40h		          ; assume Sound Blaster mode with 22kHz
			cmp  [inimode],1        ; Sound Blaster?
			jz   short @@setctrl
			or   ax,08ah		        ; set Aria mode
@@setctrl:
			out  dx,ax
@@exit:
			ret
ENDP

;----------------------------------------------------------------------
;  Procedure: GenerateInt(VOID)
;
;  Description:
;       Force DSP to generate a PC interrupt
;
;       Sequence of sending to DSP,
;          000A : command id
;          ffff : command terminator
;  Input:
;       none
;  Return:
;       ax = 0, interrupt generated
;	     -1, DSP not responding
;  Remarks:
;
;----------------------------------------------------------------------
proc generateint near			;Returns AX=0
			cli
			mov  ax,0ah
			call sendDSP_time 	; generate PC interrup
			mov  ax,-1
			call sendDSP_time   ;terminator
			sti
			ret
ENDP

proc process_buffer near
			mov  ax,[buff_freq]
			call set_sample_rate
			or   ax,ax
			jz   short @@exit

			lea  ax,[IRQ_play_buffer]  ;enable EOD interrupts from DSP
			call IRQ_set_vect

			mov  ax,[buff_data_o]
			mov  dx,[buff_data_s]
			mov  bx,[buff_len_l]
			mov  [word DMA_ptr],ax
			mov  [word DMA_ptr+2],dx
			mov  [DMA_len_l],bx
			cli
			mov  ax,6
			call sendDSP_time		; select playback mode
			mov  ax,2
			call sendDSP_time		; mode 2, digital playback
			mov  ax,-1
			call sendDSP_time 	; terminator

			mov  ax,11h
			call sendDSP_time		; start digital playback
			mov  ax,0
			call sendDSP_time 	; channel 0
			mov  ax,-1
			call sendDSP_time 	; terminator
			sti

@@exit:
			ret
ENDP

Proc	PlaySound	near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; DX ->rate to play at.
			PushCREGS
			push cs
			pop  ds

			mov  [buff_len_l],cx
			mov  [buff_freq],dx
			mov  [buff_data_o],bx
			mov  [buff_data_s],es
			cmp  [PlayingSound],0
			jne  short @@exit
			call process_buffer
@@exit:
		PopCREGS
		ret
endp

Proc	StopSound	near
			cmp  [cs:PlayingSound],0
			je   short @@exit
			PushCREGS

			push cs
			pop  ds
			call stop_d_pb
			mov  [PlayingSound],0
			PopCREGS
@@exit:
			ret
endp


ENDIF

;; Monochrome monitor debugging.
;;   At EACH vector to INT 66h,
IF	DEBUGGING

Macro	GetKey
	LOCAL	@@RET
        mov     ah,07h
        int     21h
        xor     ah,ah
	or	al,al
	jnz	@@RET
	mov	ah,07h
	int	21h
	xor	ah,ah
	add	ax,256
@@RET:
	endm

Macro   Nibble
	LOCAL	@@OK
	push	eax
	and	eax,0Fh
	add	eax,'0'
	cmp	eax,'9'
	jle	@@OK
	sub	eax,'9'+1
	add	eax,'A'
@@OK:	mov	[es:di],al
	sub	di,2
	pop	eax
	shr	eax,4		 ; down one nibble
	endm

Macro	HEXPRINT2      reg,xloc,yloc
	push	es
	pusha
	mov	eax,reg
	push	eax
	mov	ax,DEBUGADR
	mov	es,ax
	mov	ax,160
	mul	[yloc]
	mov	di,ax
	add	di,xloc*2+7*2
	pop	eax
	Nibble
	Nibble
	Nibble
	Nibble
	Nibble
	Nibble
	Nibble
	Nibble
	popa
	pop	es
	endm


DEBUGADR   equ	0B000h	; Monocrhrome monitor.

LINENO	   dw	0	; Current debug lineno

MSGFUNCT1  db	"AX=688h DigPlay          "
MSGFUNCT2  db	"AX=689h Sound Status     "
MSGFUNCT3  db	"AX=68Ah Massage Audio    "
MSGFUNCT4  db	"AX=68Bh DigPlay2         "
MSGFUNCT5  db	"AX=68Ch Report audio cap "
MSGFUNCT6  db	"AX=68Dh OBSOLETE FUNCTION"
MSGFUNCT7  db	"AX=68Eh Set Callback     "
MSGFUNCT8  db	"AX=68Fh Stop Sound       "
MSGFUNCT9  db	"AX=690h OBSOLETE FUNCTION"
MSGFUNCTA  db	"AX=691h Report callback  "
MSGFUNCTB  db	"AX=692h Restore hardware "
MSGFUNCTC  db	"AX=693h Set Timer Divisor"
MSGFUNCTD  db	"AX=694h OBSOLETE FUNCTION"
MSGFUNCTE  db	"AX=695h Post Pending     "
MSGFUNCTF  db	"AX=696h Report Pending   "
MSGFUNCT10 db	"AX=697h Set Stereo Pan   "
MSGFUNCT11 db	"AX=698h Set Play mode    "
MSGFUNCT12 db	"AX=699h Report Pend Addr "
MSGFUNCT13 db	"AX=69Ah Set Record mode  "
MSGFUNCT14 db	"AX=69Bh OBSOLETE FUNCTION"
MSGFUNCT15 db	"AX=69Ch Set DMA backfill "
MSGFUNCT16 db	"AX=69Dh Report DMAC count"
MSGFUNCT17 db	"AX=69Eh Verify DMA block "
MSGFUNCT18 db	"AX=69Fh Set PCM volume   "
MSGFUNCT19 db	"AX=6A0h Set 32 bit mode  "

MSGCHAIN   db	"AX=OTHR Chaining interupt"

Proc	DebugLine	near
	push	es	; Preserve all registers
	push	ds
	pusha

	cmp	ax,688h
	jb	@@CHAIN
	cmp	ax,6A0h
	ja	@@CHAIN
	sub	ax,688h
	mov	bx,SIZE MSGFUNCT1
	mul	bx
	lea	si,[MSGFUNCT1]
	add	si,ax
	jmp short @@RENT
@@CHAIN:lea	si,[MSGCHAIN]
@@RENT:
	push	cs
	pop	ds
	mov	ax,DEBUGADR
	mov	es,ax

	mov	ax,160
	mul	[LINENO]
	mov	di,ax		; Destination.;
	push	di
	add	di,160
	mov	cx,size MSGFUNCT1
	mov	al,' '
@@ZERO: mov	[es:di],al
	add	di,2
	loop	@@ZERO
	pop	di
	mov	cx,size MSGFUNCT1
@@PRNT: movsb
	inc	di
	loop	@@PRNT

	inc	[LINENO]
	cmp	[LINENO],23
	jne	@@COOL
	mov	[LINENO],0
@@COOL:
	;;GetKey

	popa
	pop	ds
	pop	es
	ret
	endp

R_EAX	dd	?
R_EBX	dd	?
R_ECX	dd	?
R_EDX	dd	?
R_ESI	dd	?
R_EDI	dd	?

;;		 4	   5	     6	       7
;;		 0123456789012345678901234567890123456789
MSGDBUG db	"EAX=00000000 EBX=00000000 ECX=00000000"

Proc	DeburstLine	near
	push	ds
	push	es
	pusha

	mov	[cs:R_EAX],eax
	mov	[cs:R_EBX],ebx
	mov	[cs:R_ECX],ecx
	mov	[cs:R_EDX],edx
	mov	[cs:R_ESI],esi
	mov	[cs:R_EDI],edi

	mov	ax,DEBUGADR
	mov	es,ax
	push	cs
	pop	ds
	mov	ax,160
	mul	[LINENO]
	add	ax,80
	mov	di,ax		; Into DI
	lea	si,[MSGDBUG]
	mov	cx,size MSGDBUG
@@GO:	movsb
	inc	di
	loop	@@GO

	mov	ebx,[R_EAX]
	HEXPRINT2 ebx,44,LINENO
	movsx	ebx,[OLDIN.XPTR.POFF]
	HEXPRINT2 ebx,57,LINENO
	movsx	ebx,[OLDIN.XPTR.PSEG]
	HEXPRINT2 ebx,70,LINENO

	popa
	pop	es
	pop	ds
	ret
	endp



ENDIF


LABEL	SUICIDE byte		;; Where to delete ourselves from memory
IF	DIG_ADLIB
hard	db	'$'
msg0	db	"Adlib DIGPAK Sound Driver"
ENDIF
IF	DIG_CVXSND
hard	db	'$'
IF	LIFESIZE
msg0	db	"Life Size Enhancer DIGPAK Driver"
ELSE
IF	NOSOUND
msg0	db	"No digital sound card"
ELSE
msg0	db	"Covox Speech Thing DIGPAK Driver"
ENDIF
ENDIF
ENDIF
IF	DIG_VMSND
hard	db	'$'
msg0	db	"Voice Master DIGPAK Sound Driver"
ENDIF
IF	DIG_BIGMOUTH
hard	db	'$'
msg0	db	"BigMouth DIGPAK Sound Driver"
ENDIF
IF	DIG_SMSND
hard	db	'$'
msg0	db	"Sound Master DIGPAK Sound Driver"
ENDIF
IF	DIG_IBMSND
hard	db	'$'
;;msg0	  db	  "IBM Internal frgrnd DIGPAK Driver"
msg0	db	"IBM Speaker Sound Driver"
ENDIF
IF	DIG_DIGISP
hard	db	"LWDIGI must be loaded first, consult DIGISPEECH documentation",13,10,'$'
msg0	db	"Digispeech DS201 DIGPAK Driver"
ENDIF
IF	DIG_TANEXTX
hard	db	'$'
msg0	db	"Tandy EX/TX DIGPAK Sound Driver"
ENDIF
IF	DIG_TANSLTL
hard	db	'$'
msg0	db	"Tandy SL/TL/Sensation DIGPAK Sound Driver"
ENDIF

IF      DIG_SBLASTER
hard	db	"SoundBlaster not detected.",13,10,'$'
IF	SBPRO
msg0	db	"SoundBlaster Pro DIGPAK Driver"
ELSE
IF	STFX
msg0	db	"ATI Stereo FX DIGPAK Driver"
ELSE
IF	SBCLONE
msg0	db	"SoundBlaster CLONE Sound Driver"
ELSE
msg0	db	"Creative Labs SoundBlaster "
ENDIF
ENDIF
ENDIF
ENDIF

IF      DIG_SOURCE
hard	db	'$'
msg0	db	"Sound Source DIGPAK Sound Driver"
ENDIF
IF	DIG_ECHOII
hard	db	'$'
msg0	db	"Echo II DIGPAK Sound Driver"
ENDIF
IF	DIG_LANTSND
hard	db	"LANVOICE must be loaded first, consult Lantastic documentation",13,10,'$'
msg0	db	"Lantastic DIGPAK Sound Driver"
ENDIF
IF	DIG_IBMBAK
hard	db	'$'
msg0	db	"IBM Internal bkgrnd DIGPAK Driver"
ENDIF
IF	DIG_IBM1BIT
hard	db	'$'
msg0	db	"IBM Internal 1 bit DIGPAK Driver"
ENDIF
IF	DIG_PAUDIO
IF	DIG_VBEAI
hard	db	"VESA Wave Driver not found.",13,10,'$'
ELSE
hard	db	"ProAudio hardware not found.",13,10,'$'
ENDIF
IF	PAS16
msg0	db	"ProAudio Spectrum 16 Driver"
ELSE
IF	DIG_VBEAI
msg0	db	"VESA Wave Audio DIGPAK Driver"
ELSE
msg0	db	"ProAudio Spectrum 8 Driver"
ENDIF
ENDIF
ENDIF
IF	DIG_MASTER
hard	db	"MediaMaster hardware not found.",13,10,'$'
msg0	db	"MediaMaster DIGPAK Driver"
ENDIF
IF	DIG_ADLIBG
IF	SENSATION
hard	db	"Tandy Sensation not detected.",13,10,'$'
msg0	db	"Tandy Sensation DIGPAK Driver"
ELSE
hard	db	"Adlib Gold not detected.",13,10,'$'
msg0	db	"Adlib Gold DIGPAK Driver"
ENDIF
ENDIF
IF	DIG_T2500
hard	db	'$'
msg0	db	"Tandy 2500 XL DIGPAK Driver"
ENDIF
IF DIG_ARIA
hard db   "Aria card not detected.",13,10,'$'
msg0 db   "Aria, Sierra Semiconductor"
ENDIF
	db	" - Copyright (c) 1993, THE Audio Solution:v3.40",13,10,'$'
msg1	db	"DIGPAK Sound Driver is already resident.",13,10,'$'
msg1a	 db	 "DIGPAK Sound Driver is resident, through MIDPAK.",13,10,'$'
msg1b	 db	 "A Sound Driver cannot be loaded on top of MIDPAK.  Unload MIDPAK first.",13,10,'$'
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
IF	ISEXE
	sub	ax,10h			;;
ENDIF
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
IF	FOREGROUND
	call	LoopCX
ENDIF
	Message msg0
				DosTSR  SUICIDE         ;; Terminate ourselves bud.
	endp

Proc	InstallInterupt 	far
	IN_TSR

	call	HardwareInit	;; Initialize hardware.
	or	ax,ax		;; Error initializing hardware?
	jnz	@@OUT

	mov	[param],KINT		;; The interupt kernel is going into.
	mov	[param+2],offset SoundInterupt ;; offset of interupt routine
	mov	[param+4],cs		;; Our code segment.
	PushEA	param			;; push the address of the parameter list
	call	InstallInt		;; Install the interupt.
	add	sp,2			;; clean up stack
@@OUT:

	OUT_TSR
	ret
	endp

Proc	DeInstallInterupt	far
	IN_TSR
	mov	[param],KINT		;; Interupt requested to be unloaded.
	PushEA	param			;; pass parameter.
	call	UnLoad			;; Unload it
	add	sp,2			;; clean up stack
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
				jz      @@CIOUT         ; exit if zero
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
@@NEX:
	cmp	[word si],454Bh ; equal?
				jne     @@CIOUT         ; exit if not equal
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
				mov     ax,si           ; get offset.
        cli
        stosw
        mov     ax,ds           ; code segment
				stosw                   ; store it.
        sti
				xor     ax,ax           ; Success

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

	mov	ax,68Fh ; Stop sound playback!
	int	KINT	; Invoke interrupt.
	WaitSound
	mov	ax,692h ; Deinstall hardware vectors.
	int	KINT

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
IF	ISEXE
        sub     ax,10h          ; point to program's PSP
ENDIF
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
Proc	HardwareInit	near
	xor	ax,ax		;; success code by default.
IF DIG_ARIA
			call init_driver
			or   ax,ax
			jne  short @@ok
			mov  ax,1
			jmp  short @@done
@@ok:
			xor  ax,ax
@@done:
ENDIF
IF	DIG_ADLIBG
	push	[IO_ADDR]	;; Default address.
	call	_InitAdlibGold	;; Detect adlib gold sound card.
	add	sp,2
	cmp	[DSP_DMA],0	;; Invalid DMA?
	je	@@NXT		;; return failure!!!!!!
	or	ax,ax		;; success?
	jz	@@NXT
	xor	ax,ax		;; Success is zero,
	jmp short @@HOP
@@NXT:	mov	ax,1		;; failer is a one.
@@HOP:
ENDIF

IF      DIG_MASTER
	call	test_card
	jnc	@@OK
	mov	ax,1			; Error.
	jmp short @@ERR
@@OK:	xor	ax,ax
@@ERR:
ENDIF
IF	DIG_ADLIB
ENDIF
IF	DIG_T2500
	mov	ax,[cs:IO_ADDR] ; Get the IO addresss.
	inc	ax
	mov	[cs:PORTMOD+1],ax	; Set it.
	xor	ax,ax
ENDIF
IF	DIG_CVXSND
IF	NOSOUND
ELSE
	push	ds
	xor	ax,ax
	mov	ds,ax
	mov	bx,[cs:BASELPT]
	mov	ax,[ds:bx]		; Get address of LPT1
	pop	ds
	mov	[cs:PORTMOD+1],ax	; modify base address for LPT1 (Covox)
	xor	ax,ax
ENDIF
ENDIF
IF	DIG_VMSND OR DIG_SMSND OR DIG_BIGMOUTH
	mov	ax,[PortAddress]
	mov	[PORTMOD+1],ax	     ; Set address of voice master.
	xor	ax,ax
ENDIF
IF	DIG_IBMSND
ENDIF
IF	DIG_DIGISP
	jmp	CheckDigi
;; Checks the availabilty of the digispeech sound driver.
Compare db	"Digispeech"
CheckDigi:
	push	es			;; Save ES
	xor	ax,ax
	mov	es,ax		; Segment zero, interupt vectors.
	mov	di,04Dh*4	; Address of interupt vector.
	les	di,[es:di]	; Load far address.
	add	di,5		; Plus offset of 5.
	lea	si,[Compare]
	mov	cx,10
	repz	cmpsb
	jnz	@@NOT
	xor	ax,ax		; Found!
	jmp short @@EXT
@@NOT:	mov	ax,1		; ERROR, not found.
@@EXT:
	pop	es
ENDIF
IF	DIG_TANEXTX
ENDIF
IF	DIG_TANSLTL
ENDIF
IF	DIG_SBLASTER
	call	_InitBlaster		 ; Initialize sound blaster.
	jnc	@@OKS
	mov	ax,1
	jmp short @@NOKS
@@OKS:	xor	ax,ax
@@NOKS:
ENDIF
IF	DIG_SOURCE
	push	ds
	xor	ax,ax
	mov	ds,ax
	mov	bx,[cs:BASELPT]
	mov	ax,[ds:bx]		; Get address of LPT1
	pop	ds
	mov	[cs:PORTMOD+1],ax	; modify base address for LPT1 (Covox)
    SourceOn
	xor	ax,ax
ENDIF
IF	DIG_ECHOII
	mov	ax,[cs:PORTADDRESS]
	mov	[PORTMOD+1],ax		; Data port for echo ii.
	mov	dx,ax
	inc	dx			; point at 209h or next whatever.
	xor	al,al
	out	dx,al		; Reset it.

	Dally
	Dally

	mov	al,05h		; Set it to 11khz mode
	out	dx,al		; Set it.

	mov	dx,[cs:PORTADDRESS]
@@B5:	in	al,dx
	cmp	al,0BFh
	jne	@@B5
	mov	dx,[cs:PORTADDRESS]
@@WT:	in	al,dx		; Get status line.
	or	al,al
	jns	@@WT
	mov	al,66h		; Sending 8 bit two's complement data command.
	out	dx,al		; Send it.
	xor	ax,ax		; Report success.
ENDIF
IF	DIG_LANTSND
	xor	ah,ah		; No preference.
	call	check_all_MPXs	; Search for voice adaptor.
	jz	@@NA		; Zero flag is Set, no voice installed.
	jnc	@@DOL2
@@NA:	mov	ax,1		; Return error condition.
	jmp	@@EXIT
@@DOL2:
	mov	[VNUM],ah		;; Adaptor number?
	mov	[LANADR.XPTR.PSEG],cx
	mov	[LANADR.XPTR.POFF],bx	;; Save far address of lantastic audio driver.

	mov	[MY_VCB.VCB_command],VCB_CMD_RESET
	mov	[MY_VCB.VCB_vca_num],0
	lea	bx,[MY_VCB]
	mov	ax,cs
	mov	es,ax
;;	  call	  [LANADR.DPTR]
	xor	ax,ax		; Installed
@@EXIT:
ENDIF
IF	DIG_IBMBAK
ENDIF
IF	DIG_IBM1BIT
	in	al,61h		; Get current Port B byte
	and	al,(NOT 3)
				; 0 and 1 is off.
				; bit 0 = don't gate for timer 2
                                ; bit 1 = speaker on
	out	61h,al		; store it back
	xor	ax,ax
ENDIF
IF	DIG_PAUDIO
	call	_ctv_card_here		;; Is there a card present?
	test	ax,4			;; Access to digitized sound?
	jnz	@@OKS			;; Yes->continue.
	mov	ax,1
	jmp	@@EXT
@@OKS:	call	_ctv_detect		; Detect if it's okay to play.
@@EXT:
ENDIF
	ret
	endp

IF	DIG_LANTSND
;
;----------------
;
; check_MPX_install
;
; MPX interrupt installation checking
;
; Determines whether anything is installed on an MPX function number,
; and if so, if it is a voice driver.
;
;		Input:	AH = MPX function number
;
;		Output: C Set iff non-voice MPX is installed, CX,BX trash
;			C clear, Z set iff MPX is available, CX,BX=0
;			C clear, Z clear, CX:BX = VCB handler iff voice
;			   driver is installed here.
;

;;    include "vpi.inc"


Proc	check_MPX_install  near

    push ax				; MPX int may destroy any register
    push dx
    push si
		push di
    push bp
    push ds
    push es

    mov  al, MPX_installed_status	; MPX subfunction 00h
		xor  bx, bx 			; Clear CX:BX to see if set by MPX
		xor  cx, cx
    int  MPX_interrupt			; Get installation status
    test al, al 			; AL nonzero if MPX is installed
    jnz  CMI_is_used

CMI_nc_ret:
    clc 				; MPX not in use

CMI_ret:
    pop  es
    pop  ds
    pop  bp
    pop  di
    pop  si
		pop  dx
		pop  ax

		ret

CMI_is_used:
    mov  ax, bx
    or	 ax, cx 			; CX:BX still 0, then not Voice MPX
		jnz  CMI_maybe_voice

CMI_c_ret:
    stc 				; Nonvoice MPX is installed here
    jmp  CMI_ret

CMI_maybe_voice:
    mov  es, cx 			; ES:BX should be VCB handler

    cmp  [WORD es:bx-4], 'PV'       ; Make sure preceding 4 = 'VPID'
    jne  CMI_c_ret
    cmp  [WORD es:bx-2], 'DI'
		jne  CMI_c_ret

    or	 al,0ffh			; Clear the Z bit -- It's voice!!!
    jmp  CMI_nc_ret

	ENDP

;
;   check_all_MPXs
;
;	Full MPX installation scanning
;
;	Scans all eligible MPX functions for a preexisting voice
;	driver, or, if one does not exist, an MPX number eligible
;	for installation.
;
;		Input:	AH = preferred MPX number. If a voice driver
;			     is not already installed, and this number is
;			     available for use, it will be the chosen one.
;			     0 --> no preference.
;
;		Output:
;			iff a voice driver is installed:
;			    AH = the existing MPX number for voice
;			    BX:CX = the VCB handler address
;			    Z clear
;			    C clear
;			iff no voice installed, but a free MPX found:
;			    AH = the MPX number to install on
;			    CX:BX = trash
;			    Z set
;			    C clear
;			iff none installed and no free MPX numbers:
;			    AX = trash
;			    CX:BX = trash
;			    C set
;

FIRST_ELIGIBLE_MPX EQU	0C0h
LAST_ELIGIBLE_MPX  EQU	0ffh

Proc	check_all_MPXs	   NEAR

    push dx

    mov  [cs:first_available_MPX], 0	  ; No MPXs found yet

    mov  dh,ah				; Save preferred MPX number

; Begin testing each MPX from FIRST_ELIGIBLE_MPX to LAST_ELIGIBLE_MPX
;

    mov  ah,FIRST_ELIGIBLE_MPX		; start at first possible one

CAMX_lp:
    call check_MPX_install		; give this one a shot
    jc	 CAMX_next			; in use by non-voice--try next one
    jnz  CAMX_driver_found		; This one is the voice driver
		cmp  [cs:first_available_MPX], 0	  ; If an available slot already found
    jne  CAMX_next			;   then don't change it
    mov  [cs:first_available_mpx], ah	  ; Otherwise, mark this as first avail

CAMX_next:
    cmp  ah,LAST_ELIGIBLE_MPX
		jae  CAMX_giveup
    inc  ah				; Advance to next MPX number
    jmp  CAMX_lp

CAMX_giveup:

; No voice driver has yet been installed - check preferred one, if any,
;   for eligibility:
;
    mov  ah, dh 			; AH = preferred MPX number
    test ah, ah 			; 0 --> no preference
		jz	 CAMX_no_preference
    call check_MPX_install
    jc	 CAMX_no_preference		; Preferred is already used -
					;   override
    jnz  CAMX_driver_found		; preferred is already VOICE!

CAMX_new_number:

; An appropriate new number has been found. Set Z bit.
;
    and  dh, 0				; Set Z bit (new MPX)

CAMX_nc_ret:
		clc 				; No error

CAMX_ret:
    pop  dx

		ret

CAMX_driver_found:

; An already-installed voice driver has been found. The MPX # is in AH,
;   and the VCB handler address is in CX:BX
;
		test ah, ah 			; Clear Z bit (existing MPX)
		jmp  CAMX_nc_ret			; no error

CAMX_no_preference:

; No valid preferrred MPX number has been supplied. Give the
;    first_available_mpx, if there is one
;
		mov  ah,[cs:first_available_MPX]
		test ah, ah
		jnz  CAMX_new_number		; an available one was found

; No eligible MPX numbers are available. Return with Carry Set
;
		stc
		jmp  CAMX_ret

first_available_MPX DB	?

	ENDP
ENDIF

IF DIG_ARIA

proc init_driver near

			push cs
			pop  ds
;
; reset status flags
;
			mov  [iv_status],0		  ; no interrupt vector
			mov  [old_freq],-1		  ; no playback
			mov  [old_playmode],-1	; no stereo
			mov  [PlayingSound],0
			mov  [PENDING],0
;
; detect hardware setting
;
			call detect_device
			or   ax,ax
			jz   short @@exit_init   ; verify device, establish addresses
;
; set up volume and reset buffer & DAC status
;
			call set_volume		            ;

			mov  [init_OK],1		          ; initialization is done
			mov  ax,1		                  ; set sucessful flag
@@exit_init:
			ret
ENDP

proc detect_device near   ;Check for presence of supported

			mov [iv_status],0			  ; no interrupt

			mov ax,[ARIA_ADDR]			; get IO input

			mov [DSP_DATA],ax
			add ax,2
			mov [DSP_CTRL_STAT],ax
			add ax,2
			mov [DSP_DMADDR],ax
			add ax,2
			mov [DSP_DMADATA],ax

			mov ax,[ARIA_IRQ]
			mov [DSP_IRQ],ax

			xor  ax,ax
			call resetDSP_mode      ; initialize DSP with Aria mode

			or   ax,ax
			jz   short @@exit       ;(reset failed)

			mov  [IRQ_confirm],0    ;trigger EOD IRQ on selected line
			mov  [PlayMode],PCM_8_MONO
chkirq:
			mov  si,1               ;assume success
			mov  ax,22050
			call set_sample_rate    ;set 22.050 kHz
			lea  ax,[IRQ_test]      ;enable EOD interrupts from DSP
			call IRQ_set_vect
			call generateint
			mov  di,34              ;wait typ. 500 milliseconds
@@poll_confirm:
			mov  ax,1
			call sysex_wait
			cmp  [IRQ_confirm],1      ;EOD interrupt occurred?
			je   short @@end_IRQ_test ;yes, device IRQ valid
			dec  di
			jnz  @@poll_confirm
			xor  si,si              ;IRQ handler never called -- failed
@@end_IRQ_test:
			call IRQ_rest_vect
			mov  ax,si
@@exit:
			ret
ENDP

ENDIF

IF	FOREGROUND
;; This procedure computes the speed of a LOOP instruction on this microproessor.
;;  100*constant = 0.0549 seconds.
;;  constant = 0.0549/100
TimeAdr dw	06Ch,040h
Proc	LoopCX	near
	push	ds
	push	si

	xor	dx,dx		; Number of times.
	lds	si,[cs:(dword TimeAdr)]
	mov	ax,[ds:si]
@@EDGE: cmp	ax,[ds:si]
	je	@@EDGE
	inc	ax		;

@@GO:	mov	cx,32
@@GO2:	loop	@@GO2
	inc	dx
	cmp	ax,[ds:si]
	je	@@GO

	mov	ax,dx		; Time constant. for loop instruction.
	mov	[cs:LoopConstant],ax

	pop	si
	pop	ds
	ret
	endp
ENDIF



	ENDS
	end	START

