	P386
        LOCALS                  ;; Enable local labels

VERSION_NUMBER equ 340

        IDEAL                   ;; Use Turbo Assembler's IDEAL mode
	JUMPS

        INCLUDE "PROLOGUE.MAC"          ;; common prologue

ISCOM		equ	1
ISEXE		equ	0

PLAYBACK	equ	1	;0
MASSAGE 	equ	2	;1
FIXEDFREQ	equ	4	;2
USESTIMER	equ	8	;3
SHARESTIMER	equ	16	;4 True if supports timer sharing.
LOOPEND 	equ	32	;5 Supports looping,and pending sounds.
STEREOPAN	equ	64	;6 supports stereo panning.
STEREOPLAY	equ	128	;7 Supports stereo playback!
AUDIORECORD	equ	256	;8 support digital sound recording.


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

KINT	equ	66h

SEGMENT  _TEXT PARA PUBLIC 'CODE'
        ENDS

	ASSUME	CS: _TEXT, DS: _TEXT, SS: NOTHING, ES: NOTHING


SEGMENT _TEXT
IF	ISCOM
	org	100h
ENDIF

EXTRN LoadSound:NEAR
EXTRN InstallInterupt:NEAR
EXTRN DeInstallInterupt:NEAR

;
; CODEC interface functions
;

EXTRN CODEC_ACK_SingleXfer_IRQ:NEAR
EXTRN CODEC_SetBlockSize:NEAR
EXTRN CODEC_SetDACAttenuation:NEAR
EXTRN CODEC_SetFormat:NEAR
EXTRN CODEC_StartDACDMA:NEAR

START:
	jmp	LoadSound		; Load the digitized sound driver
	db	"DIGPAK",0,13,10        ; Digitized Sound Package Identity String
IDENTIFIER:
;; =============[*][	     1	       2	 3	    ]
;; =============[*][1234567890123456789012345678901234567890]
        db      "Microsoft Windows Sound System",0,13,10
	db	"The Audio Solution, Copyright (c) 1993",0,13,10
	db	"Written by John W. Ratcliff",0,13,10

IF	ISCOM
	org	200h		; Beginning address of jumps.
	jmp	InstallInterupt 	; Install the interupt vector.
	jmp	DeInstallInterupt	; De-install the interupt.
ENDIF
;; Unique data areas to individual hardware implementations.
_io_addx	DW	530h	    ; Default I/O address.
_intr_num	DW	7	    ; Default is interupt #7
fixed_dma	dw	-1	    ; hard coded to dma #1 righ now.

BACKFILL	equ	0
DPMI		dw	0

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
		dw	offset	FUNCT19

JumpPtr         dw      ?
_voice_status	dw	0
CallBacks	dw	0	; Callback to application flag.
LABEL		CALLBACK	DWORD	     ; Callback address label.
CallLow 	dw	0	; Low word of callback address.
CallHigh	dw	0	; High word of callback address.
CallDS		dw	0	; Value of DS register at callback time.

DivisorRate	dw	0	; Default divisor rate.

RecordMode	dw	0	; set audio recording flag.
PlayMode	dw	PCM_8_MONO	; Default play mode is 8 bit PCM.

INDIGPAK	dw	0

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

;; Data used by Kernel interupt
KJUMP	FARPTR	<>		; Address
OLDIN	FARPTR	<>		; Original interupt vector.
ID      db      'KERN'          ; 4B45524Eh Interupt identifier string.
IND     db      'KR'            ; 4B52h indicates a kernel installed interupt.

        public SoundInterupt
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
;; FUNCT19 AX = 6A0h	 Set DPMI mode.
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
	jne	@@CHAIN
	cmp	[cs:OLDIN.XPTR.PSEG],0
	je	@@IRET
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
;;		  BX = Version numer, in decimal, times 100, so that 3.20
;;		       would be 300.  Version number begins with version 3.10
;;		       which includes the DigPak semaphore.
;;**************************************************************************
	mov	bx,VERSION_NUMBER  ; Return VERSION NUMBER in BX! 3.40
	cmp	[cs:LOOPING],1	; Looping a sample?
	jne	@@REP
	xor	ax,ax
	mov	dx,1		; Return high word looping flag.
	ClearSemaphoreIRET
@@REP:
	mov	ax,[cs:_voice_status]
	xor	dx,dx		; Not looping
	ClearSemaphoreIRET
FUNCT3:
;;**************************************************************************
;:Function #3: MassageAudio, Preformat audio data into ouptut hardware format.
;:
;:	  INPUT:  AX = 68Ah
;:		  DS:SI        Point to address of sound structure.
;;**************************************************************************
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
	mov	ax,(PLAYBACK OR STEREOPLAY)
        mov     bx,cs
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
	call	StopSound
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
	mov	ax,[cs:_voice_status]
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
	mov	ax,[cs:_voice_status]
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
	xor	ax,ax
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
	mov	[cs:PlayMode],dx
	mov	ax,1		; Set!
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
	mov	ax,0
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
;;		  BX = backfill mode 0 means turn it off.
;;		       and a 1 means to turn it off.
;;
;;	   OUTPUT: AX = 1 -> back fill mode set.
;;			0 -> driver doesn't support DMA backfill.
;;
;;**************************************************************************
	xor	ax,ax		; Not a backfill driver.
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
	ClearSemaphoreIRET
FUNCT19:
	mov	[cs:DPMI],dx	; Set it.
	ClearSemaphoreIRET

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
	PushCREGS
	call	SetAudio
	call	PlaySound
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
	mov	[ds:(SOUNDSPEC ptr si).ISPLAYING.XPTR.POFF],offset _voice_status
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
@@WT:	cmp	[cs:_voice_status],0	 ; Wait until last sound completed.
	jne	@@WT
	ret
	endp


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

DMA_VOICE_IN     EQU    45H
DMA_VOICE_OUT    EQU    49H

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
DMA_FF_REG	    EQU    0CH
DMA_PAGE_REG	    EQU    83H

Proc	PROG_DMA	near

       PUSH   BX

       MOV    BX,AX

       MOV    AL,5
       OUT    DMA_MASK_REG,AL

       SUB    AL,AL
       OUT    DMA_FF_REG,AL

       MOV    AL,DH
       OUT    DMA_MODE_REG,AL

       MOV    AL,BL
       OUT    DMA_ADDX_REG,AL

       MOV    AL,BH
       OUT    DMA_ADDX_REG,AL

       MOV    AL,CL
       OUT    DMA_COUNT_REG,AL

       MOV    AL,CH
       OUT    DMA_COUNT_REG,AL

       MOV    AL,DL
       OUT    DMA_PAGE_REG,AL

       MOV    AL,1
       OUT    DMA_MASK_REG,AL

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


;-------------------------------------------------
; entry: AL = INTERRUPT NUM                      |
;        DX = new vector ofs, seg is alway CS    |
;        BX = offset of store buffer             :
;-------------------------------------------------
Proc	SETUP_INTERRUPT near
       PUSH   BX
       PUSH   CX
       PUSH   DX

       CLI

       MOV    CL,AL                    ; preserve interrupt number for use

       ADD    AL,8                     ; calculate interrupt vector addx
       CBW
       SHL    AL,1
       SHL    AL,1
       MOV    DI,AX

       PUSH   ES                       ; setup and preserve interrupt

       SUB    AX,AX
       MOV    ES,AX
       MOV    AX,[ES:DI]
       MOV    [BX],AX
       MOV    [ES:DI],DX

       MOV    AX,[ES:DI+2]
       MOV    [BX+2],AX
       MOV    [ES:DI+2],CS

       POP    ES

       MOV    AH,1                     ; enable interrupt control mask-bit
       SHL    AH,CL

       NOT    AH
       IN     AL,21H
       AND    AL,AH
       OUT    21H,AL
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
Proc	RESTORE_INTERRUPT	near

       CLI

       MOV    CL,AL

       ADD    AL,8                      ; calculate interrupt vector addx
       CBW
       SHL    AL,1
       SHL    AL,1
       MOV    DI,AX

       PUSH   ES                       ; restore interrupt vector
       SUB    AX,AX
       MOV    ES,AX
       MOV    AX,[BX]
       MOV    [ES:DI],AX

       MOV    AX,[BX+2]
       MOV    [ES:DI+2],AX

       POP    ES

       MOV    AH,1
       SHL    AH,CL

       IN     AL,21H
       OR     AL,AH
       OUT    21H,AL

       STI
       RET
       endp

Proc	DMA_OUT_INTR	far
	SetSemaphore
	push	ax
	push	dx
        push    ds
        push    cs
        pop     ds

	call	DMAC_word_cnt	   ;see if DMA transfer is truly over
	cmp	ax,0ffffh
	jne	@@VO_INT90

        call    CODEC_ACK_SingleXfer_IRQ

	MOV     AX,[cs:LEN_L_TO_DMA]
	OR      AX,AX
	JNZ     @@VO_INT10

	CALL    END_DMA_TRANSFER

	JMP     SHORT @@VO_INT90

@@VO_INT10:
        CALL    DMA_OUT_TRANSFER

@@VO_INT90:
        pop     ds
        pop	dx
        MOV     AL,20H
        OUT     20H,AL
        pop	ax
	ClearSemaphoreIRET
        endp

DSP_DMA dw	1

Proc	DMAC_word_cnt near
	push	bx

	pushf
	cli

	mov dx,[cs:DSP_DMA]
	shl dx,1
	add dx,1
	in al,dx		;DMAnCNT: Channel n Word Count
	mov bl,al
	in al,dx
	mov ah,al
	mov al,bl

	popf

	pop	bx
	ret
	ENDP


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
       SUB    CX,[DMA_CURRENT_ADDX]	 ; calcutate current page addx
       MOV    [DMA_CURRENT_COUNT],CX
       INC    CX
       JZ     @@DOT20

       SUB    [LEN_L_TO_DMA],CX
       SBB    [LEN_H_TO_DMA],0
       JMP    SHORT @@DOT30

@@DOT20:
       DEC      [LEN_H_TO_DMA]

@@DOT30:
        MOV     DH,DMA_VOICE_OUT
        cmp	[cs:RecordMode],1	; In recording mode?
        jne	@@NOT
        mov	DH,DMA_VOICE_IN
@@NOT:
        MOV      DL,[DMA_CURRENT_PAGE]
        MOV      AX,[DMA_CURRENT_ADDX]
        MOV      CX,[DMA_CURRENT_COUNT]
        CALL     PROG_DMA

        MOV      AX,[DMA_CURRENT_COUNT]

        ;
        ; WARNING!  This assumes the current format of the bit
        ;           alignment for mono, stereo, 16-bit mono,
        ;           16-bit stereo.
        ;

        mov      cx,[PlayMode]
        shr      ax, cl

        push     ax
        call     CODEC_SetBlockSize

        call     CODEC_StartDACDMA

        DEC      [PAGE_TO_DMA]
        INC      [DMA_CURRENT_PAGE]
        MOV      [DMA_CURRENT_ADDX],0

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

       call     CODEC_ACK_SingleXfer_IRQ

;; Do Callbacks if ncessary.
	call	DoCallBacks

       OUTISR
       RET
       endp
                 
SPEAKERSTATE	db	-1

Proc	ON_OFF_SPEAKER	near
	cmp	al,[SPEAKERSTATE]
	je	@@DONE
	PushAll

	mov	[SPEAKERSTATE],al

	PopAll
@@DONE:
       SUB	AX,AX			 ; inidcate no error
       RET
       endp


Proc	PlaySound	near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; DX ->rate to play at.

	mov	al,1		; Speaker needs to be ON.
	cmp	[RecordMode],1	; Recording?
	jne	@@SET
	xor	al,al		; Speaker OFF while recording.
@@SET:	call	ON_OFF_SPEAKER	; Set speaker state.


@@WAIT: CMP    [_voice_status],0
	jne    @@WAIT		; Wait until last sound has completed playing.
@@OV10:
        MOV    [_voice_status],1

        push    dx
        push    [PlayMode]
        call    CODEC_SetFormat
        push    0505h
        call    CODEC_SetDACAttenuation

        push    es
        push    bx

        MOV	AL,[byte _intr_num]
        lea	dx,[DMA_OUT_INTR]
        lea	BX,[ORG_INT_ADDX]
        CALL	SETUP_INTERRUPT

        pop     ax
        pop     dx

        CALL   CALC_20BIT_ADDX

        MOV    [DMA_CURRENT_PAGE],DL
        MOV    [DMA_CURRENT_ADDX],AX

        MOV    [LEN_L_TO_DMA],CX
        MOV    [LEN_H_TO_DMA],0

        ADD    AX, CX
        ADC    DL,0
        SUB    AX,1
        SBB    DL,0

        MOV    [LAST_DMA_OFFSET],AX
        SUB    DL,[DMA_CURRENT_PAGE]
        MOV    [PAGE_TO_DMA],DL

        CALL   DMA_OUT_TRANSFER

        SUB    AX,AX

	ret
	endp

EXTRN CODEC_StopDACDMA:NEAR

Proc	StopSound	near

        push    ds
        push    cs
        pop     ds

        mov     ax, 1
        CMP     [_voice_status], 0
        JZ      @@SS90

        call    CODEC_StopDACDMA
        CALL    END_DMA_TRANSFER

	call	CheckCallBack	; Check callbacks.
	mov	[_voice_status],0	; No longer playing.

	SUB    AX,AX

@@SS90:
        pop     ds
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

	ENDS

	end	START

