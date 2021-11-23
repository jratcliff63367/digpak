
        page    63,131
	Title	DIGVESA Sound Interface Module
	Subttl	Copyright (c) 1993. The Audio Solution. All Rights Reserved.

;   /*\
;---|*|------------------------====< MAIN.ASM >====---------------------------
;---|*|
;---|*| This is the TAS VESA interface module
;---|*|
;---|*|  3.0  -> stereo rev.
;---|*|  3.1  -> version number rev, semaphore reporting.
;---|*|  3.11 -> fixed bug halting looped sample, when looped sample
;---|*| 	 wasn't playing.
;---|*|  3.12 -> got rid of the int 3 instructions accidently left in
;---|*| 	 sblaster.
;---|*|  3.2  -> auto-init dma mode functions.
;---|*|  3.3  -> auto-init dma on SBLASTER cards, as well as SBP16 support.
;---|*|  3.4  -> minimal support for 32 bit register passing.
;---|*|
;   \*/

	P386				; Enable 32 bit registers.

MONOSCR 	EQU	1
VERSION_NUMBER	equ	340

	LOCALS				; Enable local labels
	IDEAL				; Use Turbo Assembler's IDEAL mode
	JUMPS

	include "prologue.mac"          ; common prologue
	include "soundrv.inc"

SEGMENT _TEXT PARA PUBLIC 'CODE'
	ENDS
	ASSUME	CS:_TEXT, DS:_TEXT, SS:NOTHING, ES:NOTHING

SEGMENT _TEXT

        org     100h

START:
	jmp	LoadSound		; Load the digitized sound driver
	db	"DIGPAK",0,13,10        ; Digitized Sound Package Identity String

IDENTIFIER:
	db	"VESA DIGPAK Wave Driver",0,13,10
	db	"The Audio Solution, Copyright (c) 1993",0,13,10
	db	"Written by John W. Ratcliff",0,13,10

	org	200h			; Beginning address of jumps.

        jmp     InstallInterupt         ; Install the interupt vector.
	jmp	DeInstallInterupt	; De-install the interupt.

;; Unique data areas to individual hardware implementations.

DUMMYBASE       dw      -1              ; unused
DUMMYIRQ	dw	-1		; No IRQ used.
DUMMYEXTRA	dw	-1		; Nothing extra.
DPMI		dw	 0		; DPMI compliant register usage.

	public	JumpTable
JumpTable       dw      offset  FUNCT1  ; 0688h DigPlay
		dw	offset	FUNCT2	; 0689h Sound Status
		dw	offset	FUNCT3	; 068Ah Massage Audio
		dw	offset	FUNCT4	; 068Bh DigPlay2, pre-massaged audio.
		dw	offset	FUNCT5	; 068Ch Report audio capabilities.
		dw	offset	FUNCT6	; 068Dh Report playback address.
		dw	offset	FUNCT7	; 068Eh Set Callback address.
		dw	offset	FUNCT8	; 068Fh Stop Sound.
		dw	offset	FUNCT9	; 0690h Set Hardware addresses.
		dw	offset	FUNCTA	; 0691h Report Current callback address.
		dw	offset	FUNCTB	; 0692h Restore hardware vectors.
		dw	offset	FUNCTC	; 0693h Set Timer Divisor Sharing Rate
		dw	offset	FUNCTD	; 0694h Play preformatted loop
		dw	offset	FUNCTE	; 0695h Post Pending Audio
		dw	offset	FUNCTF	; 0696h Report Pending Status
		dw	offset	FUNCT10 ; 0697h Set Stereo Panning value.
		dw	offset	FUNCT11 ; 0698h Set DigPak Play mode.
		dw	offset	FUNCT12 ; 0699h Report Address of pending status flag.
		dw	offset	FUNCT13 ; 069Ah Set Recording mode 0 off 1 on.
		dw	offset	FUNCT14 ; 069Bh StopNextLoop
		dw	offset	FUNCT15 ; 069Ch Set DMA backfill mode.
		dw	offset	FUNCT16 ; 069Dh Report current DMAC count.
		dw	offset	FUNCT17 ; 069Eh Verify DMA block.
		dw	offset	FUNCT18 ; 069Fh Set PCM volume.
		dw	offset	FUNCT19 ; 06A0h Set DPMI compliant register usage.

	public	BACKF
BACKF           dw      0       ; Backfill defaults to off
	public	JumpPtr
JumpPtr         dw      ?
	public	CallBacks
CallBacks       dw      0       ; Callback to application flag.

LABEL		CALLBACK  DWORD ; Callback address label.
	public	CallLow
CallLow         dw      0       ; Low word of callback address.
	public	CallHigh
CallHigh        dw      0       ; High word of callback address.

	public	CallDS
CallDS          dw      0       ; Value of DS register at callback time.
	public	DivisorRate
DivisorRate     dw      0       ; Default divisor rate.
	public	RecordMode
RecordMode      dw      0       ; set audio recording flag.
	public	PlayMode
PlayMode        dw      PCM_8_MONO ; Default play mode is 8 bit PCM.

; Data used by Kernel interupt
KJUMP	FARPTR	<>		; Address
OLDIN	FARPTR	<>		; Original interupt vector.
ID      db      'KERN'          ; 4B45524Eh Interupt identifier string.
IND     db      'KR'            ; 4B52h indicates a kernel installed interupt.


;   /*\
;---|*|----------------------======================---------------------------
;---|*|----------------------====< ENTRYPOINT >====---------------------------
;---|*|----------------------======================---------------------------
;   \*/

	public	SoundInterupt
Proc	SoundInterupt far
;
; validate the DIGPAK function number, or chain to the next driver
;
	cmp	ax,0688h		; validate the function number for
	jb	@@CHAIN 		; DIGPAK functionality
	cmp	ax,06A0h
	ja	@@CHAIN
;
; process this command through the jump tables
;
	SetSemaphore			; Set the inside DigPak semaphore
	sti

	sub	ax,0688h

    if MONOSCR
	push	ax			; reports the function # on
	call	reportmono		; the monochrome screen.
    endif

        shl     ax,1
	add	ax,offset JumpTable
	xchg	ax,bx
	mov	bx,[cs:bx]
	xchg	ax,bx
	mov	[cs:JumpPtr],ax
	jmp	[cs:JumpPtr]		; Near jump will be modified!!
;
; chain to the old IRQ vector to process other type of audio functionality
;
@@CHAIN:
	cmp	[OLDIN.XPTR.POFF],0	; validate the link before committing
	jne	@@CHAIN2		; suicide.
	cmp	[OLDIN.XPTR.PSEG],0
	jne	@@CHAIN2

        ClearSemaphoreIRET              ; bail if NULL
;
@@CHAIN2:
	jmp	[cs:OLDIN.DPTR] 	; Chain to original interrupt vector.

	endp

;
;   /*\
;---|*|------------------------====< FUNCT1 >====------------------------------
;---|*|
;---|*| DigPlay, Play an 8 bit digitized sound.
;---|*|
;---|*| INPUT:	AX = 688h    Command number.
;---|*| 	DS:SI	     Point to a sound structure that
;---|*| 		     describes the sound effect to be played.
;---|*|
;   \*/
;
	public	FUNCT1
FUNCT1:
	PushCREGS
	ConvertDPMI ds,esi

	call	CompleteSound		; Complete previous sound.
	call	SetAudio		; Set up regs for this audio transer
	call	PlaySound		; Play the sound.

	PopCREGS
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT2 >====------------------------------
;---|*|
;---|*| SoundStatus, Check current status of sound driver.
;---|*|
;---|*| INPUT:	AX = 689h
;---|*| OUTPUT: AX = 0	     No sound is playing.
;---|*| 	   = 1	     Sound effect currently playing.
;---|*| 	DX = 1	     Looping a sound effect
;---|*| 	BX = Version number, in decimal, times 100, so that 3.00
;---|*| 	     would be 300.  Version number begins with version 3.10
;---|*| 	     which includes the DigPak semaphore.
;---|*|
;   \*/
;
	public	FUNCT2
FUNCT2:
	mov	bx,VERSION_NUMBER	; Return VERSION NUMBER in BX! 3.30
	cmp	[cs:LOOPING],1		; Looping a sample?
	jne	@@REP
	xor	ax,ax
	mov	dx,1			; Return high word looping flag.
	jmp	short f2exit
    ;
    @@REP:
	mov	ax,[cs:PlayingSound]
	xor	dx,dx			; Not looping

 if MONOSCR
	push	24
        call    reportmono              ; the monochrome screen.
    endif

    ;
    f2exit:
        ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT3 >====------------------------------
;---|*|
;---|*| MassageAudio, Preformat audio data into ouptut hardware format.
;---|*|
;---|*|   INPUT:  AX = 68Ah
;---|*| 	  DS:SI        Point to address of sound structure.
;---|*|
;   \*/
;
	public	FUNCT3
FUNCT3:
	PushCREGS
	ConvertDPMI ds,esi

	cmp	[cs:PlayMode],PCM_16_MONO ; Don't massage audio in 16 bit mode!
	je	@@JUSTRET

	mov	ax,(WAVEPREPARE SHR 16)
	test	[word ptr cs:vbefeatures+2],ax
	jz	@@skipfixup

 ;; int 3

	call	SetAudio		; pick up the data

	mov	ax,[cs:RecordMode]
	push	ax			; record or playback

	mov	al,[cs:PCMSize] 	; 8 or 16 bit mode
	push	ax

	mov	al,[cs:StereoMono]	; get the stereo/mono setting
	inc	ax			; make it 1 based
	push	ax			; mono flag

	push	es
	push	bx

	sub	ax,ax
	push	ax
	push	cx

        les     bx,[ServicesPtr]        ; get the services structure
	call	[dword ptr es:bx+wsWavePrepare] ; start the block
;
@@skipfixup:

    ;
    @@JUSTRET:
	PopCREGS
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT4 >====------------------------------
;---|*|
;---|*| Function #4: DigPlay2, Play preformatted audio data.
;---|*|
;---|*|   INPUT:  AX = 68Bh
;---|*| 	  DS:SI        Point to address of sound structure.
;---|*|
;   \*/
;
	public	FUNCT4
FUNCT4:
	PushCREGS
	ConvertDPMI ds,esi

 ;; int 3

        call    CompleteSound
	call	DoSoundPlay
	mov	[cs:FROMLOOP],0 	; Turn from loop semephore off.
	PopCREGS
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT5 >====------------------------------
;---|*|
;---|*| AudioCapabilities, Report capabilities of hardware device.
;---|*|
;---|*|   INPUT:  AX = 68Ch
;---|*|   OUTPUT: AX = Bit 0 -> On, supports background playback.
;---|*| 			Off, driver only plays as a foreground process.
;---|*| 	       Bit 1 -> On, source data is reformatted for output device.
;---|*| 			 Off, device handles raw 8 bit unsigned audio.
;---|*| 	       Bit 2 -> On, Device plays back at a fixed frequency, but
;---|*| 			    the audio driver will downsample input data
;---|*| 			    to fit.
;---|*| 			Off, device plays back at user specified frequency.
;---|*| 			(NOTE: You can still playback an audio sample at
;---|*| 			       whatever frequency you wish.  The driver
;---|*| 			       will simply downsample the data to fit
;---|*| 			       the output hardware.  Currently it does
;---|*| 			       not support upsampling though.)
;---|*| 	       Bit 3 -> On, this device uses the timer interrupt vector
;---|*| 			during sound playback.
;---|*| 	  DX = If this device plays back at a fixed frequency the DX
;---|*| 	       register will contain that fixed frequency playback rate.
;---|*|
;---|*| ********************************************************************
;---|*| ;; *DOUG*  It's very important that the resident VESA driver has been queried
;---|*| ;;	   during the hardware init stage such that we are aware of what
;---|*| ;;	   capabilities this wave driver has, and we report such appropriately.
;---|*| ;;	   Possible audio capbilities bits are:
;---|*| ;;  * PLAYBACK	      0 Driver plays audio as a background task.
;---|*| ;;  * MASSAGE	      1 Driver must massage 8 bit audio data.
;---|*| ;;  * FIXEDFREQ       2 Driver plays back at a fixed frequency.
;---|*| ;;  * USESTIMER       3 Driver uses the 8253 timer interrupt.
;---|*| ;;  * SHARESTIMER     4 True if supports timer sharing.
;---|*| ;;  * LOOPEND	      5 Supports looping,and pending sounds.
;---|*| ;; ** STEREOPAN       6 supports stereo panning.
;---|*| ;;  * STEREOPLAY      7 Supports stereo playback!
;---|*| ;;  * AUDIORECORD     8 support digital sound recording.
;---|*| ;;  * DMABACKFILL     9 supports DMA backfilling.
;---|*| ;;  * PCM16	      10 supports 16 bit PCM!
;---|*| ;;  * PCM16STEREO     11 support 16 bit stereo PCM
;   \*/
;
	public	FUNCT5
FUNCT5:

	MASM

 ;; int 3

; PLAYBACK & DMABACKFILL ( & LOOPEND ) is the base feature set

 if 1
	;; %out is LOOPEND strictly auto-init?

        mov     ax,PLAYBACK+DMABACKFILL+LOOPEND

; MASSAGE

	mov	bx,(WAVEPREPARE SHR 16)
	test	word ptr cs:[vbefeatures+2],bx
	jz	@no01
	or	ax,MASSAGE
    ;
    @no01:

; FIXEDFREQ

	mov	bx,((WAVEVARIPMONO+WAVEVARIPSTER+WAVEVARIRMONO+WAVEVARIRSTER) SHR 16)
	test	word ptr cs:[vbefeatures+2],bx
	jnz	@no02
	or	ax,FIXEDFREQ
    ;
    @no02:

; USETIMER SHARESTIMER

	cmp	word ptr cs:[vbecbrate],0
	jz	@no03
	or	ax,(USESTIMER OR SHARESTIMER)
    ;
    @no03:

; AUDIORECORD

	mov	bx,(WAVEMR8K+WAVESR8K+WAVEMR11K+WAVESR11K+WAVEMR22K+WAVESR22K)
	test	word ptr cs:[vbefeatures+0],bx
	jnz	@yes03a

	mov	bx,((WAVEMR44K+WAVESR44K+WAVEVARIRMONO+WAVEVARIRSTER) SHR 16)
	test	word ptr cs:[vbefeatures+2],bx
	jz	@no04

      @yes03a:
	or	ax,AUDIORECORD
    ;
    @no04:

; STEREOPLAY

	cmp	byte ptr cs:[vbechannels],0 ; set carry if mono (vbechannels
	cmc				    ; is zero based). flip carry
	sbb	bx,bx			    ; to indicate if stereo.
	mov	dx,bx			    ; bx,dx hold TRUE/FALSE
	and	bx,STEREOPLAY
	or	ax,bx			    ; merge stereo play if supported

; PCM16 PCM16STEREO

        test    cs:[vbesamplesize],WAVE16BITPLAY
	jz	@no07
	or	ax,PCM16
	and	dx,PCM16STEREO		    ; merge stereo 16 bit if supported
	or	ax,dx
    ;
    @no07:

 else

	mov	ax,PLAYBACK+DMABACKFILL+LOOPEND+AUDIORECORD+STEREOPLAY+PCM16+PCM16STEREO

 endif

        IDEAL

        mov     bx,cs
	lea	cx,[IDENTIFIER]
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT6 >====------------------------------
;---|*|
;---|*| UNUSED FUNCTION
;---|*|
;---|*|  *DOUG*  This is an unsupported DIGPAK function.
;---|*|
;   \*/
;
	public	FUNCT6
FUNCT6:
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT7 >====------------------------------
;---|*|
;---|*| SetCallBackAddress, sets a user's sound completion callback addess.
;---|*|
;---|*|   INPUT: AX = 068Eh
;---|*| 	 BX = Offset portion of far procedure to callback.
;---|*| 	 DX = Segment portion of far procedure to callback.
;---|*| 	 DS = Data Segment register value to load at callback time.
;---|*|
;---|*|   OUTPUT: None.
;---|*|
;---|*| 	 This function allows the user to specify a callback
;---|*| 	 address of a far procedure to be invoked when a sound
;---|*| 	 effect has completed being played.  This function is
;---|*| 	 disabled by default.  Sending a valid address to this
;---|*| 	 function will cause a callback to occur whenever a sound
;---|*| 	 sample has completed being played.  The callers DS register
;---|*| 	 will be loaded for him at callback time.  Be very careful
;---|*| 	 when using this feature.  The application callback procedure
;---|*| 	 is being invoked typically during a hardware interupt.
;---|*| 	 Your application should spend a small an amount of time
;---|*| 	 as possible during this callback.  Remember that the
;---|*| 	 callback must be a far procedure.  The sound driver
;---|*| 	 preserves ALL registers so your callback function does
;---|*| 	 not need to do so.  Do not perform any DOS functions
;---|*| 	 during callback time because DOS is not re-entrent.
;---|*| 	 Keep in mind that your own application has been interupted
;---|*| 	 by the hardware it this point.  Be very careful when making
;---|*| 	 assumptions about the state of your application during
;---|*| 	 callback time.  Hardware callbacks are generally used
;---|*| 	 to communicate sound event information to the application
;---|*| 	 or to perform a technique called double-buffering, whereby
;---|*| 	 your application immediatly posts another sound effect to
;---|*| 	 be played at the exact time that the last sound effect
;---|*| 	 has completed.
;---|*|
;---|*| 	 WARNING!!! Be sure to turn off hardware callbacks when
;---|*| 	 your application leaves!!! Otherwise, harware callbacks
;---|*| 	 will be pointing off into memory that no longer contains
;---|*| 	 code.	This function is for advanced programmers only.
;---|*|
;   \*/
;
	public	FUNCT7
FUNCT7:

 ;; int 3

        or      bx,bx
	jnz	@@SC1
	or	dx,dx
	jnz	@@SC1
	xor	ax,ax
	mov	[cs:CallBacks],ax	; Callbacks disabled.
	mov	[cs:CallLow],ax 	; Low address.
	mov	[cs:CallHigh],ax
	jmp	@@EXIT
    ;
    @@SC1:
	mov	[cs:CallLow],bx
	mov	[cs:CallHigh],dx
	mov	[cs:CallDS],ds
	mov	[cs:CallBacks],1
    ;
    @@EXIT:
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT8 >====------------------------------
;---|*|
;---|*| StopSound, stop currently playing sound.
;---|*|
;---|*|   INPUT: AX = 68Fh
;---|*|   OUTPUT: None.
;---|*|
;---|*| 	Will cause any currently playing sound effect to be
;---|*| 	terminated.
;   \*/
;
	public	FUNCT8
FUNCT8:

 ;; int 3

	mov	[cs:PENDING],0		; Turn pending flag OFF when
	mov	[word cs:LOOPING],0	; stop-sound called.
	call	StopSound
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT9 >====------------------------------
;---|*|
;---|*| UNUSED FUNCTION
;---|*|
;---|*| *DOUG* Unused function.  Not supported by any driver.
;   \*/
;
	public	FUNCT9
FUNCT9:
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT10 >====------------------------------
;---|*|
;---|*| ReportCallbackAddress
;---|*|
;---|*|   INPUT: AX = 691h
;---|*|   OUTPUT: AX:DX -> far pointer to current callback address.
;---|*| 	  BX -> original caller's DS register.
;---|*|
;---|*|   This function should probably never need to be used by your
;---|*|   application software.  It is provided because the MIDPAK,
;---|*|   MIDI driver, needs to revector hardware callbacks so that
;---|*|   it can handle hardware contention problems between digitized
;---|*|   sound playback and synthesized sound playback.
;   \*/
;
	public	FUNCTA
FUNCTA:

 ;; int 3

        mov     ax,[cs:CallLow]
	mov	dx,[cs:CallHigh]
	mov	bx,[cs:CallDS]
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCTB >====------------------------------
;---|*|
;---|*| RestoreHardware
;---|*|
;---|*| INPUT: AX = 692h
;---|*|
;---|*| OUTPUT:
;---|*|
;---|*|    Put hardware back to initial state.	Invoked by the
;---|*|    DeInstall code.  Not to be called by an application program!
;   \*/
;
	public	FUNCTB
FUNCTB:

 ;; int 3

        mov     [cs:CallBacks],0
	mov	[word cs:CallBack],0
	mov	[word cs:CallBack+2],0

	push	ds
	push	cs
	pop	ds
	call	VesaRemove
	pop	ds

        ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCTC >====------------------------------
;---|*|
;---|*| Set Timer Divsor Rate
;---|*|
;---|*| INPUT: AX = 693h
;---|*|        DX = Countdown timer divisor rate, so that timer based
;---|*| 	    drivers can service application timer interrupts
;---|*| 	    at their previous rate.  Service rate will be an
;---|*| 	    aproximation, that is fairly close.  To reset timer
;---|*| 	    divisor to default of 18.2 pass a 0 in the DX register.
;   \*/
;
	public	FUNCTC
FUNCTC:
	mov	[cs:DivisorRate],dx    ; Set timer divisor rate.
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCTD >====------------------------------
;---|*|
;---|*| DigPlayLoop
;---|*|
;---|*| INPUT: AX = 694h
;---|*|        DS:SI ->sound structure, preformated data.
;---|*|
;---|*|   Here's the process...
;---|*|   Remember the current callback address.
;---|*|   Set new callback address to US!
;---|*|   Save sound structure.
;---|*|   Call DigPlay.
;---|*|   At call back, keep playing.
;---|*|   This gets done until StopSound is called.
;---|*|   Stop sound checks to see if we need to restore the callback address.
;---|*|   If PlaySound is invoked, and we are currently looping a sound then
;---|*|   stopsound is invoked.
;---|*|
;   \*/
;
	public	FUNCTD
FUNCTD:

 ;; int 3

        PushAll         ; Save all registers.
	ConvertDPMI ds,esi

        push    cs
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

        push    cs
	pop	ds
	lea	si,[LOOPSND]
	mov	[word cs:LOOPSOUND],si
	mov	[word cs:LOOPSOUND+2],ds
	mov	[cs:FROMLOOP],1 ; Set from looping semephore
	mov	ax,068Bh	; Do FUNCT4

        jmp     FUNCT4          ; Do a DigPlay2

;
;   /*\
;---|*|-----------------------====< FUNCTE >====------------------------------
;---|*|
;---|*| PostAudioPending
;---|*|
;---|*| INPUT: AX = 695h
;---|*|        DS:SI ->sound structure, preformated data.
;---|*|
;---|*| OUTPUT: AX = 0	Sound was started playing.
;---|*| 	AX = 1	Sound was posted as pending to play.
;   \*/
;
	public	FUNCTE
FUNCTE:

 ;; int 3

        ConvertDPMI ds,esi

	pushf
	cli			; Turn off interupts while making this determination.

        mov     ax,[cs:PlayingSound]
	or	ax,ax		; Currently playing a sound?
	jnz	@@POST		; yes->try to post pending.

	popf			; We can play it now.

	call	DoSoundPlay	;
	xor	ax,ax		; Return, audio sample is now playing.
	ClearSemaphoreIRET
    ;
    @@POST:

        popf                    ; We can play it now.

        cmp     [cs:PENDING],1  ; Already have a pending sound effect?
	jne	@@POST2 	; no, post it for pending play.
	mov	ax,2		; return code of two.
	ClearSemaphoreIRET
    ;
    @@POST2:
	mov	[cs:PENDING],1
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
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCTF >====------------------------------
;---|*|
;---|*| ReportPending status.
;---|*|
;---|*|   INPUT: AX = 696h
;---|*|
;---|*|  OUTPUT: AX = 0 No sound is playing.
;---|*| 	 AX = 1 Sound playing, sound pending.
;---|*| 	 AX = 2 Sound playing, no sound pending.
;   \*/
;
	public	FUNCTF
FUNCTF:

 ;; int 3

        pushf                   ; Clear interrupts while
	cli			; we make this determination.

	mov	ax,[cs:PlayingSound]
	or	ax,ax		; Currently playing a sound?
	jnz	@@POST		; yes->try to post pending.

	popf

	ClearSemaphoreIRET
;
@@POST:
        popf

        cmp     [cs:PENDING],1  ; Have a sound pending?
	je	@@PEND		; yes, return pending status.
	mov	ax,1		; Sound is playing, but no sound is pending.
	ClearSemaphoreIRET
;
@@PEND:
	mov	ax,2
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT10 >====------------------------------
;---|*|
;---|*| Set Stereo Pan
;---|*|
;---|*| INPUT: AX = 697h
;---|*|        DX = stereo pan value. 0 full volume right.
;---|*| 			     64 full volume both.
;---|*| 			    127 full volume left.
;---|*|
;---|*| OUTPUT: AX = 0 command ignored, driver doesn't support stereo panning.
;---|*| 	AX = 1 pan set.
;---|*|
;   \*/
;
	public	FUNCT10
FUNCT10:

;; *DOUG* If you want to support Stereo Panning, here's the layer.
;;	  Remember that if the VESA driver supports stereo panning then you
;;	  must report that capability bit in the Audio Capabilities call.

        xor     ax,ax           ; Doesn't support stereo panning.
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT11 >====------------------------------
;---|*|
;---|*| Set Play Mode
;---|*|
;---|*| INPUT: AX = 698h
;---|*|        DX = Play Mode function.
;---|*|        DX = 0 -> 8 bit PCM
;---|*| 	  = 1 -> 8 bit Stereo PCM (left/right)
;---|*| 	  = 2 -> 16 bit PCM
;---|*| 	  = 3 -> 16 bit PCM stereo.
;---|*|
;---|*| OUTPUT: AX = 1 -> mode set.
;---|*| 	AX = 0 -> mode not supported by this driver.
;---|*|
;   \*/
;

;; *DOUG*  Once again.	If the VESA Wave driver supports this particular
;;	   playback mode it must be set in the Audio Capabilities bit.
;;	   It's important to note how stereo and 16 bit data is passed in
;;	   the sound structure.  The LENGTH passed is always the PHYSICAL
;;	   number of bytes in the transfer.  That means if you have 400
;;	   samples of 16 bit mono data you would pass an 800, the physical
;;	   number of bytes.  Same goes for stereo either 8 or 16 bit.
;;	   However, the frequency passed is the playback frequency.  Meaning
;;	   if you are playing 11khz stereo 8 bit sound the user passes
;;	   11khz as the playback frequency NOT 22khz.

DataTable:	dw	0108h		; 8 bit  mono
		dw	0208h		; 8 bit  stereo
		dw	0110h		; 16 bit mono
		dw	0210h		; 16 bit stereo


        public  FUNCT11
FUNCT11:

 ;; int 3

	mov	[cs:PlayMode],dx	; Set it.

        mov     bx,dx
	shl	bx,1
	mov	ax,[word ptr cs:bx+DataTable]

	cmp	al,8			; 8 bit request?
	jz	@@do8			; yes, continueo on...
	test	[cs:vbesamplesize],022h ; 16 bit modes supported?
	jz	@@donone		; no, it's an error
    ;
    @@do8:
	cmp	ah,2			; stereo mode?
	jnz	@@domono		; no, continue on...
	cmp	[cs:vbechannels],1	; h/w supports stereo?
	jnz	@@donone		; no, bail out...
    ;
    @@domono:
        mov     [cs:PCMSize],al
	mov	[cs:StereoMono],ah

	mov	ax,1
	ClearSemaphoreIRET
    ;
    @@donone:
	sub	ax,ax
        ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT12 >====------------------------------
;---|*|
;---|*| Report Address of Pending Flag
;---|*|
;---|*| INPUT: AX = 699h
;---|*|
;---|*| OUTPUT: AX:DX -> form far address of pending status flag.
;---|*| 	BX:DX -> form address of DigPak interrupt semaphore.
;---|*|
;   \*/
;
	public	FUNCT12
FUNCT12:

 ;; int 3

	mov	dx,cs			; Code segment.
	lea	ax,[PENDING]		; Address of pending flag.
	lea	bx,[INDIGPAK]		; Address of semaphore address.
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT13 >====------------------------------
;---|*|
;---|*| Set audio recording mode.
;---|*|
;---|*| INPUT: AX = 69Ah
;---|*|
;---|*|        DX = 0 turn audio recording ON.
;---|*| 	  = 1 turn audio recording OFF.
;---|*|
;---|*| OUTPUT: AX = 0 sound driver doesn't support audio recording.
;---|*| 	AX = 1 audio recording mode is set.
;---|*|
;   \*/
;
;; * DOUG * Here is where the audio recording mode would get set.  If record
;;	    mode is true, then all calls to DIGPLAY cause data to be recorded
;;	    into that buffer, not played back.	You must set the audio
;;	    record capability bit in the audiocapabilities call, and of course
;;	    respond to the RecordMode flag, which is commented out below.

	public	FUNCT13
FUNCT13:

	mov	ax,(WAVEMR8K+WAVESR8K+WAVEMR11K+WAVESR11K+WAVEMR22K+WAVESR22K)
	test	[word ptr cs:vbefeatures+0],ax
        jnz     @f3norec

        mov     [cs:RecordMode],dx
	mov	ax,1
	jmp	short @f3ret
;
@f3norec:
	mov	ax,0
;
@f3ret:
        ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT14 >====------------------------------
;---|*|
;---|*| Stop Next Loop
;---|*|
;---|*| INPUT: AX = 69Bh
;---|*|
;---|*| OUTPUT: NOTHING, Stop Looped sample, next time around.
;---|*|
;   \*/
;
	public	FUNCT14
FUNCT14:

 ;; int 3

        mov     [cs:CallBacks],0
	mov	[cs:LOOPING],0
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT15 >====------------------------------
;---|*|
;---|*| Set DMA back fill mode.
;---|*|
;---|*| INPUT: AX = 69Ch
;---|*|        DX = backfill mode 0 means turn it off.
;---|*| 	    and a 1 means to turn it on.
;---|*|
;---|*| OUTPUT: AX = 1 -> back fill mode set.
;---|*| 	     0 -> driver doesn't support DMA backfill.
;---|*|
;   \*/
;
	public	FUNCT15
FUNCT15:

 ;; int 3

        push    ds
	push	di
	push	si

	push	cs
	pop	ds

	push	dx
	call	StopSound
	pop	dx

	mov	[cs:BACKF],dx
	mov	ax,1			; Back fill mode was set.

        pop     si
	pop	di
	pop	ds

        ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT16 >====------------------------------
;---|*|
;---|*| Report current DMAC count.
;---|*|
;---|*| INPUT: AX = 69Dh
;---|*|
;---|*|  OUTPUT: AX = Current DMAC count.
;---|*|
;   \*/
;
	public	FUNCT16
FUNCT16:
	call	ReportDMAC

 if MONOSCR
	push	24
        call    reportmono              ; the monochrome screen.
    endif

	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT17 >====------------------------------
;---|*|
;---|*| Verify DMA block, check to see if it crosses a 64k page
;---|*| boundary for the user.
;---|*|
;---|*| INPUT: AX = 69Eh
;---|*|        ES:BX -> address of sound.
;---|*|        CX    -> length of sound effect.
;---|*|
;---|*| OUTPUT: AX = 1 Block is ok, DOESN'T cross 64k bounadary.
;---|*|       AX = 0 block failed, DOES cross 64k boundary.
;---|*|
;   \*/
;
	public	FUNCT17
FUNCT17:
	PushCREGS
	ConvertDPMI es,ebx

	push	cx
	push	es
	push	bx
	call	CheckBoundary
	add	sp,6

	PopCREGS
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT18 >====------------------------------
;---|*|
;---|*| Set PCM volume.
;---|*|
;---|*| INPUT: AX = 69Eh
;---|*|        BX = Left channel volume (or both if mono) 0-256
;---|*|        CX = Right channel volume (or both if mono) 0-256
;---|*|
;---|*| OUTPUT: AX = 1 Volume set
;---|*| 	AX = 0 Device doesn't support volume setting.
;---|*|
;   \*/
;
;; * DOUG * Global wave volume setting goes here.

	public	FUNCT18
FUNCT18:
	xor	ax,ax			; Default, volume not set.
	ClearSemaphoreIRET

;
;   /*\
;---|*|-----------------------====< FUNCT19 >====------------------------------
;---|*|
;---|*| Set/Clear DPMI compliancy flag.
;---|*|
;---|*| INPUT: AX = 69Eh
;---|*|        DX = TRUE(enable)/FALSE(disable)
;---|*|
;---|*| OUTPUT: none
;---|*|
;   \*/
;

	public	FUNCT19
FUNCT19:
	mov	[cs:DPMI],dx		; Set DPMI compliancy flag.
	ClearSemaphoreIRET


;   /*\
;---|*|----------------------======================---------------------------
;---|*|----------------------====< IDEAL MODE >====---------------------------
;---|*|----------------------====< INTERNAL   >====---------------------------
;---|*|----------------------====< FUNCTIONS  >====---------------------------
;---|*|----------------------======================---------------------------
;   \*/

;
;   /*\
;---|*|---------------------====< CheckBoundary >====-------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	CheckBoundary
Proc    CheckBoundary   near
	ARG	SOURCE:DWORD,SLEN:WORD
	PENTER	0

	mov	ax,[word SOURCE]
	mov	dx,[word SOURCE+2]
	GET20BIT			; Into 20 bit mode.
	mov	bx,dx			; Save DMA page.
	mov	ax,[word SOURCE]
	mov	dx,[word SOURCE+2]
	add	ax,[SLEN]		; Point to end.
	GET20BIT
	mov	ax,1			; Default is OK.
	cmp	bl,dl			; Same DMA page?
	je	@@OK
	xor	ax,ax			; Didn't work.
@@OK:
	PLEAVE
	ret

	endp

;
;   /*\
;---|*|----------------------====< PlayPending >====---------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	PlayPending
Proc    PlayPending     far
	cmp	[PENDING],1		; Pending?
	jne	@@not
	mov	[PENDING],0
	mov	[cs:CallBacks],0	; No longer have one pending..
	lea	si,[PENDSND]		; Address of pending sound.
	call	DoSoundPlay		; Do a sound play call.
	ret
@@not:
	mov	[cs:CallBacks],0	; Disable callbacks.
	ret
	endp

;
;   /*\
;---|*|-----------------------====< DoSoundPlay >====--------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	DoSoundPlay
Proc    DoSoundPlay     near
	PushCREGS			; Save all of the important C registers.
	call	SetAudio
	call	PlaySound		; Restore important C registers.
	PopCREGS
	ret
	endp

;
;   /*\
;---|*|---------------------====< CheckCallBack >====--------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	CheckCallBack
Proc    CheckCallBack   near

	cmp	[cs:CallBacks],0	; Callbacks enabled?
	je	@@GOUT			; no, exit.

	PushAll 			; Save all registers
	mov	ds,[cs:CallDS]		; Get DS register.
	call	[cs:CallBack]		; far call to application.
	PopAll				; Restore all registers.
;
@@GOUT:

	ret
	endp

	public	INDIGPAK
INDIGPAK	dw	0		; Inside DigPak semaphore.

	public	FROMLOOP
FROMLOOP        dw      0
	public	SAVECALLBACK
SAVECALLBACK	dd	?		; Saved callback address.
	public	SAVECALLDS
SAVECALLDS      dw      ?
	public	LOOPING
LOOPING 	dw	0		; True if we were looping.

	public	LOOPSOUND
LOOPSOUND       dd      ?
LOOPSND 	SOUNDSPEC	<>

	public	PENDING
PENDING 	dw	0		; True, when second sound is pending.
PENDSND 	SOUNDSPEC <>		; Sound structure of pending sound.

;
;   /*\
;---|*|-----------------------====< LoopBack >====-----------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	LoopBack
Proc    LoopBack        far
	mov	ax,068Bh		; Play preformated data.
	mov	[cs:FROMLOOP],1
	lds	si,[LOOPSOUND]		;
	int	66h			; Start playing the sound again.
	ret
	endp

;
;   /*\
;---|*|----------------------====< SetAudio >====-----------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	SetAudio
Proc    SetAudio        near
	mov	[ds:(SOUNDSPEC ptr si).ISPLAYING.XPTR.POFF],offset PlayingSound
	mov	[ds:(SOUNDSPEC ptr si).ISPLAYING.XPTR.PSEG],cs
	les	bx,[ds:(SOUNDSPEC ptr si).PLAYADR.DPTR]
	mov	cx,[ds:(SOUNDSPEC ptr si).PLAYLEN]
	mov	dx,[ds:(SOUNDSPEC si).FREQUENCY]
	push	cs
	pop	ds			; DS = Code group.
	ret
	endp

;
;   /*\
;---|*|----------------------====< EndLoop >====------------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	EndLoop
Proc    EndLoop near
	mov	[cs:CallBacks],0
	mov	[word cs:CallBack],0
	mov	[word cs:CallBack+2],0
	mov	[word cs:LOOPING],0
	call	StopSound
	ret
	endp

;
;   /*\
;---|*|--------------------====< CompleteSound >====---------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	CompleteSound
Proc    CompleteSound   near

        cmp     [cs:FROMLOOP],1         ; In loop callback?
	jne	@@WT
	call	EndLoop 		; don't wait for loop to complete, end it!
;
@@WT:   cmp     [cs:PlayingSound],0     ; Wait until last sound completed.
	jne	@@WT

        ret
	endp

;
;   /*\
;---|*|-----------------------====< PlaySound >====----------------------------
;---|*|
;---|*| ;; CX ->number of bytes in sound sample.
;---|*| ;; ES:BX -> far address of sound sample to be played.
;---|*| ;; DX ->rate to play at.
;---|*|
;   \*/

	public	PlaySound
Proc    PlaySound       near

;;;;	cmp	[cs:PlayMode],PCM_8_STEREO
;;;;	jne	@@OK
;;;;	shl	dx,1			; X2 playback frequency, when in stereo.
;;;;;
;;;;@@OK:

        push    dx                      ; Save sampling rate.
	push	cx			; Number of bytes.
	push	es			; Segment
	push	bx			; Offset

        call    VesaOutput              ; Send it.
	add	sp,8			; Balance stack.
	ret
	endp

;
;   /*\
;---|*|-----------------------====< StopSound >====----------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	StopSound
Proc    StopSound       near
	push	ds

	push	cs
	pop	ds
	call	VesaHalt		; Halt it baby.

	pop	ds
	ret
	endp

;
;   /*\
;---|*|----------------------====< DoCallBacks >====---------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	DoCallBacks
Proc    DoCallBacks     near

        cmp     [cs:CallBacks],0
	je	@@GOUT

	PushAll 			; Save all registers
	mov	ds,[cs:CallDS]		; Get DS register.
	call	[cs:CallBack]		; far call to application.
	PopAll				; Restore all registers.
;
@@GOUT:
	ret

        endp


;   /*\
;---|*|----------------------=====================---------------------------
;---|*|----------------------====< MASM MODE >====---------------------------
;---|*|----------------------====< INTERNAL  >====---------------------------
;---|*|----------------------====< FUNCTIONS >====---------------------------
;---|*|----------------------=====================---------------------------
;   \*/

        MASM

        include vbeai.inc

TRUE	equ	-1
FALSE	equ	 0

	public	PlayingSound
PlayingSound    dw      0               ; Holds current status:
	public	StereoMono
StereoMono      db      01h             ; Default is mono (1 channel)
	public	PCMSize
PCMSize         db      08h             ; 8 bit PCM
	public	hWAVE
hWAVE           dw      0               ; handle to the wave device
	public	hWAVEsize
hWAVEsize       dw      0               ; size of the WAVE services structure
	public	hVOLserv
hVOLserv        dd      0               ; pointer to the Volume services
	public	CallBackRoutine
CallBackRoutine dd      0               ; User's callback routine
	public	ServicesPtr
ServicesPtr     dd      0               ; holds the original routine

;
; features supported by the VBE/AI device
;

	public	vbefeatures
vbefeatures     dd      0               ; features list
	public	vbecbrate
vbecbrate       dw      0               ; callback rate
	public	vbesamplesize
vbesamplesize   db      0               ; sample sizes supported
	public	vbechannels
vbechannels     db      0               ; number of channels

SERVICESLEN	equ	2048		; size of the services structure
	public	hServices
hServices       db      SERVICESLEN dup(0) ; info & services structure address

;
; back fill variables
;

	public	blockoffset
blockoffset     dw      0

;
;   /*\
;---|*|----------------------====< VesaPresent >====---------------------------
;---|*|
;---|*| Queries the presence of a VESA wave driver.
;---|*|
;---|*|   AX = 0, no VESA Wave driver found.
;---|*|   AX nonzero, VESA Wave driver found.
;---|*|
;   \*/


	public	VesaPresent
VesaPresent     Proc    near
	sub	cx,cx			; query each device
;
crdhr_05:
	inc	cx			; move to the next handle
        mov     ax,VESAFUNCID
	mov	bl,VESAFUNC2
	mov	dx,01			; query #1 get the info struct. length
	int	INTHOOK

        sub     ax,004Fh                ; good?
	jnz	geve_bad		; no, bail out

	mov	cs:[hWAVEsize],di	; save the length

        cmp     di,SERVICESLEN          ; too big?
	ja	crdhr_05		; yes, skip this one...

        mov     ax,VESAFUNCID
	mov	bl,VESAFUNC2
	mov	dx,02			; query #2 get the info structure
	mov	si,cs			; si:di points to the info structure
	mov	di,offset hServices
	int	INTHOOK

        sub     ax,004Fh                ; good call?
	jnz	geve_bad		; no, bail out...

        cmp     cs:[di.gdcclassid],WAVDEVICE ; WAVE device class?
	jnz	crdhr_05		; no, go find another one...

        cmp     cs:[di.gdcu.wimemreq],SERVICESLEN-16 ; enough memory?
	ja	crdhr_05		; no, go find another one...

        mov     ax,VESAFUNCID
	mov	bl,VESAFUNC2
	mov	dx,WAVESETPREFERENCE	; query #2 get the info structure
	mov	si,-1
	mov	di,si
	int	INTHOOK

        or      di,di                   ; highest priority?
	jnz	crdhr_05		; no, go for more...
;
; save all the features and specific data about the VBE/AI device
;
        mov     hWAVE,cx                ; yes, this is our handle
	
 ;; int 3

	mov	ax,cs:[hServices.gdcu.witimerticks] ; save the callback rate
	mov	cs:[vbecbrate],ax

	mov	al,byte ptr cs:[hServices.gdcu.wiSampleSize]
	mov	cs:[vbesamplesize],al

	mov	ax,cs:[hServices.gdcu.wiChannels]
	shr	al,1
	mov	cs:[vbechannels],al	; mono=0,stereo=1

	mov	ax,wptr cs:[hServices.gdcu.wifeatures+0] ; save the features
	mov	wptr cs:[vbefeatures+0],ax

	mov	ax,wptr cs:[hServices.gdcu.wifeatures+2] ; save the features
	mov	wptr cs:[vbefeatures+2],ax
;
; all done, return with FM and DAC found
;
        mov     ax,0110b                ; returns FM and DAC available
	ret
;
geve_bad:
	sub	ax,ax			; not found...
	ret

VesaPresent     endp

;
;   /*\
;---|*|-----------------------====< VesaInit >====-----------------------------
;---|*|
;---|*| Initialize VESA Wave interface.
;---|*|
;---|*|   Returns
;---|*|     NZ failed to init VESA interface.
;---|*|      Z successfully initialized VESA interface.
;---|*|
;   \*/

	public	VesaInit
VesaInit        proc    near
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

	; get a copy of the volume services, if available.

;;;;;;; mov     di,offset hServices     ;
;;;;;;; add	di,cs:[hWAVEsize]	; di points to the end of the block
;;;;;;; shr	di,4			; make a segment with zero offset
;;;;;;; inc	di			; for the volume services structure
;;;;;;; mov	ax,cs
;;;;;;; add	di,ax			; di is now a segment

	sub	ax,ax			; return okay
    ;
    @@LOC4:
	pop	si
	pop	es
	ret

VesaInit endp

;
;   /*\
;---|*|----------------------====< VesaRemove >====----------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	VesaRemove
VesaRemove      proc    near
;
; flush everything.
;
	mov	ax,VESAFUNCID		; close function
	mov	bl,VESAFUNC4
	mov	cx,[hWAVE]		; device handle is required
	sub	dx,dx			; select 16 bit interface
	int	INTHOOK 		; close the device

	mov	[cs:PCMSize],8		; 8 bit mono operation
	mov	[cs:StereoMono],1

	sub	ax,004Fh		; NZ if
	neg	ax
	sbb	ax,ax			; FFFF if not good, else 0000
	neg	ax			; 0001 if not good, else 0000
	ret

VesaRemove endp

;
;   /*\
;---|*|---------------------====< VesaContinue >====---------------------------
;---|*|
;---|*| Continue previous transfer.
;---|*|
;   \*/


	public	VesaContinue
VesaContinue    proc    near
        push    es
	push	di

	mov	ax,1			; prepair for failure
	cmp	wptr [ServicesPtr+2],0	; get the services structure
	jz	@CTCN05

	sub	ax,ax
	push	ax			; push a NULL parameter

        les     di,[ServicesPtr]        ; get the services structure
	call	es:[di.wsResumeIO]
	inc	ax			; go from ffff to 0 or 0 to 01
;
@CTCN05:
        pop     di
	pop	es
	ret

VesaContinue    endp

;
;   /*\
;---|*|-----------------------====< VesaHalt >====-----------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	VesaHalt
VesaHalt        proc    near
        push    es
	push	di

	cmp	[BACKF],1		; In auto-init mode?
	jne	@@NOTBF
	mov	[BACKF],0		; kill backfill mode
    @@NOTBF:

        mov     ax,1                    ; prepair for failure
	cmp	wptr [ServicesPtr+2],0	; get the services structure
	jz	@CTHL05

	sub	ax,ax
	push	ax			; push a NULL parameter

        les     di,[ServicesPtr]        ; get the services structure
	call	es:[di.wsStopIO]

	sub	ax,ax			; it is stopped, no matter what
;
@CTHL05:
        pop     di
	pop	es
	ret

VesaHalt        endp

;
;   /*\
;---|*|-----------------------====< VesaOutput >====---------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	VesaOutput
Proc    VesaOutput      near
	ARG	SOUND:DWORD,SNDLEN:WORD,FREQ:WORD
        push    bp
	mov	bp,sp

        push    es
	push	si

	mov	[cs:PlayingSound],1

	les	si,[ServicesPtr]	; get the services structure
;
; save critical data for the ReportDMA calculations
;
	mov	dx,[word ptr SOUND+2]	; get the buffer far *
	mov	ax,[word ptr SOUND]
        call    near ptr makelinear

	add	ax,[SNDLEN]		; advance to the end of the buffer
	mov	cs:[blockoffset],ax	; save the end of buffer ptr

        mov     ax,1                    ; mono
	cmp	wptr [ServicesPtr+2],0	; get the services structure
	jz	@CTOU10
;
; set the sample rate
;
	mov	al,[cs:StereoMono]	; get the stereo/mono setting
	cbw
	push	ax			; mono flag

        cwd
	push	dx
	push	[FREQ]			; get the sample rate

	push	dx			; no compression
	push	dx			; no compression block sizes

	mov	al,[cs:PCMSize] 	; 8 or 16 bit mode
	cbw
	push	ax

        call    es:[si.wsPCMInfo]       ; set the sample rate
;
; see which type of playback we need
;
	cmp	[BACKF],1		; In DMA backfill mode?
	jz	@CTOU05 		; yes, do circular buffer stuff
;
; start the block by registering it, then playing it via the handle
;
	push	[word ptr SOUND+2]	; far *
	push	[word ptr SOUND]

	sub	ax,ax
	push	ax			; length
	push	[SNDLEN]

	call	es:[si.wsWaveRegister]
	or	ax,ax			; did we get a handle?
	jz	@CTOUBAD		; no, bail out...

	push	ax			; block handle
	sub	ax,ax
	push	ax			; zero long parm
	push	ax

        cmp     cs:[RecordMode],0       ; do a recording?
	jnz	@CTOURB

	call	es:[si.wsPlayBlock]	; start playback
	neg	ax			; FFFF is now 1, 0 is now 0
	jmp	short @CTOUBAD
    ;
    @CTOURB:
	call	es:[si.wsRecordBlock]	; start a recording
        neg     ax                      ; FFFF is now 1, 0 is now 0
	jmp	short @CTOUBAD
;
@CTOU05:
;
; start the circular block process
;

 ;; int 3

	push	[word ptr SOUND+2]	; far *
	push	[word ptr SOUND]

        sub     ax,ax
	push	ax
	push	[SNDLEN]		; full length

	push	ax
	push	[SNDLEN]		; second length

	cmp	cs:[RecordMode],0	; do a recording?
	jnz	@CTOURC

        call    es:[si.wsPlayCont]      ; start playback
	neg	ax			; FFFF is now 1, 0 is now 0
	jmp	short @CTOUBAD
    ;
    @CTOURC:
	call	es:[si.wsRecordCont]	; start a recording
        neg     ax                      ; FFFF is now 1, 0 is now 0
;
@CTOUBAD:
	xor	al,1			; 1=BAD, 0=GOOD
;
@CTOU10:
	pop	si
	pop	es
	pop	bp
	ret

VesaOutput	endp

;
;   /*\
;---|*|-----------------------====< VesaPause >====----------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	VesaPause
VesaPause       proc    near
        push    es
	push	di

	mov	ax,1			; prepair for failure
	cmp	wptr [ServicesPtr+2],0	; get the services structure
	jz	@CTPA05

	sub	ax,ax
	push	ax			; push a NULL parameter

	les	di,[ServicesPtr]	; get the services structure
	call	es:[di.wsPauseIO]
	inc	ax			; go from ffff to 0 or 0 to 01
;
@CTPA05:
        pop     di
	pop	es
	ret

VesaPause       endp

;
;   /*\
;---|*|----------------------====< VBECallback >====---------------------------
;---|*|
;---|*| VBECallback  --  End of block interrupts are handed to this routine
;---|*|
;   \*/

	public	VBECallback
VBECallback     proc    far

	SetSemaphore			; Set the inside DigPak semaphore

        push    ds
	push	es

        push    cs
	pop	ds
;
; don't stop anything if in auto-init mode
;
	cmp	[BACKF],1		; In DMA backfill mode?
	jz	@VBECB05		; yes, we don't do anying
;
; unregister the block now that it's done
;
	pusha

        sub     ax,ax
	mov	PlayingSound,ax 	; the block is now done
	push	ax			; NULL block pointer
	push	ax

	push	ax			; block handle
	push	ax			; huh?

        les     di,[ServicesPtr]        ; get the services structure
	call	es:[di.wsWaveRegister]

	call	CheckCallback		; we only do single block, not
	popa				; continuous blocks needing CBs
;
@VBECB05:
	pop	es
	pop	ds			; no registers modified

        ClearSemaphore
        retf    14                      ; pascal style

VBECallback     endp

;
;   /*\
;---|*|----------------------====< makelinear >====----------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	makelinear
makelinear      proc    near
	push	bx

 int 3

	rol	dx,4
        mov     bx,dx                   ; convert it to a linear address
	and	dx,000fh
	xor	bx,dx			; add offset portion of seg to offset
	add	ax,bx
	adc	dx,0			; increment dx if ax wrapped

	pop	bx
	ret

makelinear      endp

;
;   /*\
;---|*|-----------------------====< reportDMAC >====---------------------------
;---|*|
;---|*|
;---|*|
;   \*/

	public	reportDMAC
reportDMAC      proc    near
	push	bx
	push	cx
	push	dx
	push	es

	sub	ax,ax			; prepair for failure
	cmp	wptr cs:[ServicesPtr+2],0 ; any services?
	jz	@REMD05 		; no, bail out

	mov	ax,WAVEGETCURRENTPOS
	push	ax

	sub	ax,ax
	push	ax			; don't care about the 2nd parm
        push    ax

	les	bx,cs:[ServicesPtr]	; get the services structure
	call	es:[bx.wsDeviceCheck]

	mov	dx,cs:[blockoffset]	; get the ending offset
	sub	dx,ax			; dx holds the total unused amount
	xchg	ax,dx
;
@REMD05:
	pop	es
	pop	dx
	pop	cx
	pop	bx
	ret
 
reportDMAC	endp


;; ***********************************************************************
;; ** Monochrome debugging code.
;; ***********************************************************************
 if MONOSCR

;   /*\
;---|*|---------------------====< mono_output >====-------------------------
;---|*|
;---|*| This routine is included only if DEBUG and MONOSCR are set TRUE.
;---|*| This code allows all calls the driver to be printed on the mono
;---|*| screen for debugging.
;---|*|
;   \*/

	public	dbstr_table
dbstr_table     label   word
	dw	offset dbg_msg0 	;  0 DigPlay
	dw	offset dbg_msg1 	;  1 Sound Status
	dw	offset dbg_msg2 	;  2 Massage Audio
	dw	offset dbg_msg3 	;  3 DigPlay2, pre-massaged audio.
	dw	offset dbg_msg4 	;  4 Report audio capabilities.
	dw	offset dbg_msg5 	;  5 Report playback address.
	dw	offset dbg_msg6 	;  6 Set Callback address.
	dw	offset dbg_msg7 	;  7 Stop Sound.
	dw	offset dbg_msg8 	;  8 Set Hardware addresses.
	dw	offset dbg_msg9 	;  9 Report Current callback address.
	dw	offset dbg_msga 	; 10 Restore hardware vectors.
	dw	offset dbg_msgb 	; 11 Set Timer Divisor Sharing Rate
	dw	offset dbg_msgc 	; 12 Play preformatted loop
	dw	offset dbg_msgd 	; 13 Post Pending Audio
	dw	offset dbg_msge 	; 14 Report Pending Status
	dw	offset dbg_msgf 	; 15 Set Stereo Panning value.
	dw	offset dbg_msg10	; 16 Set DigPak Play mode.
	dw	offset dbg_msg11	; 17 Report Address of pending status flag.
	dw	offset dbg_msg12	; 18 Set Recording mode 0 off 1 on.
	dw	offset dbg_msg13	; 19 StopNextLoop
	dw	offset dbg_msg14	; 20 Set DMA backfill mode.
	dw	offset dbg_msg15	; 21 Report current DMAC count.
	dw	offset dbg_msg16	; 22 Verify DMA block.
	dw	offset dbg_msg17	; 23 Set PCM volume.
	dw	offset dbg_msg18	; 24 report all registers


dbg_msg0	db	'DigPlay     ',0
dbg_msg1	db	'Sound Stat  ',0
dbg_msg2	db	'MassageAudio',0
dbg_msg3	db	'DigPlay2    ',0
dbg_msg4	db	'Get Aud Cap ',0
dbg_msg5	db	'Get PB Addr ',0
dbg_msg6	db	'Set CB Addr ',0
dbg_msg7	db	'Stop Sound  ',0
dbg_msg8	db	'Set HW Addr ',0
dbg_msg9	db	'Get CB Addr ',0
dbg_msga	db	'Rst HW vect ',0
dbg_msgb	db	'Set TMR Div ',0
dbg_msgc	db	'Play loop   ',0
dbg_msgd	db	'PostPendAud ',0
dbg_msge	db	'Get Pnd Stat',0
dbg_msgf	db	'Set Pan val ',0
dbg_msg10	db	'Set Play mde',0
dbg_msg11	db	'Get flag add',0
dbg_msg12	db	'Set RCD mode',0
dbg_msg13	db	'StopNextLoop',0
dbg_msg14	db	'Set BACKF md',0
dbg_msg15	db	'Get DMAC cnt',0
dbg_msg16	db	'CHK DMA blk ',0
dbg_msg17	db	'Set PCM vol ',0
dbg_msg18	db	0

DBG_AX		equ	00000001b
DBG_BX		equ	00000010b
DBG_CX		equ	00000100b
DBG_DX		equ	00001000b
DBG_SI		equ	00010000b
DBG_DI		equ	00100000b
DBG_BP		equ	01000000b
DBG_ES		equ	10000000b

	public	dbrstr_table
dbrstr_table    label   word
	dw	offset dbg_rax	; 0
	dw	offset dbg_rbx	; 1
	dw	offset dbg_rcx	; 2
	dw	offset dbg_rdx	; 3
	dw	offset dbg_rsi	; 4
	dw	offset dbg_rdi	; 5
	dw	offset dbg_rbp	; 6
	dw	offset dbg_res	; 7

dbg_rax 	db	'AX=',0
dbg_rbx 	db	'BX=',0
dbg_rcx 	db	'CX=',0
dbg_rdx 	db	'DX=',0
dbg_rsi 	db	'SI=',0
dbg_rdi 	db	'DI=',0
dbg_rbp 	db	'BP=',0
dbg_res 	db	'ES=',0

; PUSHA stack frame, plus ES & DS

regwset struc
 _regDS dw	?
 _regES dw	?
 _regDI dw	?
 _regSI dw	?
 _regBP dw	?
 _regSP dw	?
 _regBX dw	?
 _regDX dw	?
 _regCX dw	?
 _regAX dw	?
regwset ends

;
; mask indicating which registers to print on the screen
;
	public	dbstr_regs
dbstr_regs      label   word
		dw	0				   ; DigPlay
		dw	0				   ; Sound Status
		dw	DBG_AX				   ; Massage Audio
		dw	DBG_AX+DBG_BX+DBG_CX+DBG_DX	   ; DigPlay2, pre-massaged audio.
		dw	DBG_AX				   ; Report audio capabilities.
		dw	DBG_AX				   ; Report playback address.
		dw	DBG_AX+DBG_BX+DBG_CX+DBG_DX+DBG_SI ; Set Callback address.
		dw	DBG_AX				   ; Stop Sound.
		dw	DBG_AX+DBG_BX+DBG_CX+DBG_DX+DBG_SI ; Set Hardware addresses.
		dw	DBG_AX				   ; Report Current callback address.
		dw	0				   ; Restore hardware vectors.
		dw	0				   ; Set Timer Divisor Sharing Rate
		dw	0				   ; Play preformatted loop
		dw	0				   ; Post Pending Audio
		dw	0				   ; Report Pending Status
		dw	0				   ; Set Stereo Panning value.
		dw	0				   ; Set DigPak Play mode.
		dw	0				   ; Report Address of pending status flag.
		dw	0				   ; Set Recording mode 0 off 1 on.
		dw	0				   ; StopNextLoop
		dw	0				   ; Set DMA backfill mode.
		dw	0				   ; Report current DMAC count.
		dw	0				   ; Verify DMA block.
		dw	0				   ; Set PCM volume.
		dw	DBG_AX+DBG_BX+DBG_CX+DBG_DX+DBG_SI+DBG_DI+DBG_ES

DBG_PARM1       equ     <bp+_regAX+6>

	.286
;   /*\
;---|*|-----------------------====< reportmono >====---------------------------
;---|*|
;---|*| do the screen output
;---|*|
;   \*/

	public	reportmono
reportmono      proc    near ; mono screen output
	pushf
        pusha
	push	es
	push	ds

        mov     bp,sp

	shl	[DBG_PARM1],1		; double the number

        push    cs
        push    cs
	pop	ds
	pop	es

;;  breakpoint

        mov     di,0b000h
	mov	es,di

	call	dbg_scroll		; scroll the screen 1 line

	mov	di,24*80*2		; point to the bottom of the screen

        mov     bx,[DBG_PARM1]
	mov	bx,dbstr_table[bx]

        call    dbg_strout              ; print the string

	mov	si,[DBG_PARM1]
	mov	si,dbstr_regs[si]

	sub	bx,bx
	test	si,DBG_AX
	jz	@F_01
	mov	ax,[bp+_regAX]
	call	dbg_regreport
    ;
    @F_01:
	inc	bx
	test	si,DBG_BX
	jz	@F_02
	mov	ax,[bp+_regBX]
	call	dbg_regreport
    ;
    @F_02:
	inc	bx
        test    si,DBG_CX
	jz	@F_03
	mov	ax,[bp+_regCX]
	call	dbg_regreport
    ;
    @F_03:
	inc	bx
        test    si,DBG_DX
	jz	@F_04
	mov	ax,[bp+_regDX]
	call	dbg_regreport
    ;
    @F_04:
	inc	bx
        test    si,DBG_SI
	jz	@F_05
	mov	ax,[bp+_regSI]
	call	dbg_regreport
    ;
    @F_05:
	inc	bx
        test    si,DBG_DI
	jz	@F_06
	mov	ax,[bp+_regDI]
	call	dbg_regreport
    ;
    @F_06:
	inc	bx
        test    si,DBG_BP
	jz	@F_07
	mov	ax,[bp+_regBP]
	call	dbg_regreport
    ;
    @F_07:
	inc	bx
        test    si,DBG_ES
	jz	@F_08
	mov	ax,[bp+_regES]
	call	dbg_regreport
    ;
    @F_08:
	pop	ds
	pop	es
	popa
	popf
        ret     2
;
;
	public	dbg_regreport
dbg_regreport   label   near
	push	bx
	shl	bx,1
        mov     bx,dbrstr_table[bx]     ; get the register string
	call	dbg_strout		; print the string

	push	ax			; save copies
        push    ax
	xchg	ah,al
	push	ax
	shr	al,4
	call	@dbg_nout		; print the 4th nibble
	pop	ax
	call	@dbg_nout		; print the 3rd nibble
	pop	ax
	shr	al,4
	call	@dbg_nout		; print the 2nd nibble
	pop	ax
	call	@dbg_nout		; print the 1st nibble
	add	di,2

        pop     bx
	ret
;
	public	@dbg_nout
@dbg_nout       label   near
	push	ax
	and	al,0Fh
	add	al,90h
	daa
	adc	al,0
	add	al,40h
	daa
	mov	ah,0Fh
	stosw
	pop	ax
	ret
;
;
	public	dbg_scroll
dbg_scroll      label   near
	push	ds
        push    cx
	push	si

	mov	si,80*2
	sub	di,di
	push	es
	pop	ds
	mov	cx,24*80
	cld
        rep movsw
	sub	ax,ax
	mov	di,24*80*2
	mov	cx,80
	rep stosw

	pop	si
	pop	cx
	pop	ds
        ret
;
;
	public	dbg_strout
dbg_strout      label   near
	push	ax
	push	bx
	mov	ah,0Fh
	cld
    ;
    @F_A1:
	mov	al,cs:[bx]
	inc	bx
	or	al,al
	jz	@F_A2
	stosw
	jmp short @F_A1
    ;
    @F_A2:
	pop	bx
	pop	ax
	ret

reportmono	endp

	.8086
 endif


        IDEAL
;   /*\
;---|*|----------------------=====================---------------------------
;---|*|----------------------====< THROWAWAY >====---------------------------
;---|*|----------------------====<   CODE    >====---------------------------
;---|*|----------------------=====================---------------------------
;   \*/

LABEL	SUICIDE byte		;; Where to delete ourselves from memory

hard    db      "VESA Wave Driver not found.",13,10,'$'
msg0	db	"VESA Wave Audio DIGPAK Driver"
	db	" - Copyright (c) 1993, THE Audio Solution:v3.30",13,10,'$'
msg1	db	"DIGPAK Sound Driver is already resident.",13,10,'$'
msg1a	db	"DIGPAK Sound Driver is resident, through MIDPAK.",13,10,'$'
msg1b	db	"A Sound Driver cannot be loaded on top of MIDPAK.  Unload MIDPAK first.",13,10,'$'
msg2	db	"Unable to install Sound Driver interupt vector",13,10,'$'
msg3    db      "Invalid command line",13,10,'$'
msg4	db	"Sound Driver isn't in memory",13,10,'$'
msg5	db	"DIGPAK Sound Driver unloaded",13,10,'$'
msg5a	db	"Sound Driver can't be unloaded, unload MIDPAK first.",13,10,'$'
param   dw      4 dup(?)        ;; Used for parameter passing.

Installed       dw      0


;   /*\
;---|*|-----------------------====< LoadSound >====----------------------------
;---|*|
;---|*|
;   \*/

	public	LoadSound
Proc    LoadSound near

	mov	ax,cs			;
	mov	ds,ax			; establish data segment
	mov	es,ax			; point ES to PSP

	call	CheckIn
	mov	[Installed],ax		; Save in installed flag.

	call	ParseCommandLine	; Build a command line.
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
;
@@BC:
	Message msg3			; Invalid command line
	DOSTerminate
;
ULOAD:
	mov	ax,[Installed]
	or	ax,ax
	jnz	DOU
	Message msg4			; wasn't loaded.
	DOSTerminate			; Terminate with message.
;
DOU:
	cmp	ax,2
	jne	@@OKU
	Message msg5a
	DOSTerminate
;
@@OKU:
	CALLF	DeInstallInterupt
	Message msg5			; Display message
	DOSTerminate			; terminate
;
NoArg:
	or	ax,ax			; Already loaded?
	jz	@@DOLO			; no->load it.
	cmp	ax,2
	jne	@@TEMP
	Message msg1a
	DOSTerminate
;
@@TEMP:
	cmp	ax,3
	jne	@@TEMPA
	jmp short @@DOLO
	Message msg1b
	DOSTerminate
;
@@TEMPA:
	Message msg1			; message
	DOSTerminate			;
;
@@DOLO:
	CALLF	InstallInterupt
	or	ax,ax			; Was there an error?
	jz	@@HOP1			; no->continue
	Message msg2			; display the error message
	Message hard			; Hardware error message if there is one.
	DOSTerminate			; exit to dos
;
@@HOP1:
	Message msg0
	DosTSR	SUICIDE 		; Terminate ourselves bud.

        endp


;   /*\
;---|*|-------------------====< InstallInterrupt >====-------------------------
;---|*|
;---|*|
;   \*/

	public	InstallInterupt
Proc    InstallInterupt         far
	IN_TSR

	call	HardwareInit		; Initialize hardware.
	or	ax,ax			; Error initializing hardware?
	jnz	@@OUT

	mov	[param],KINT		; The interupt kernel is going into.
	mov	[param+2],offset SoundInterupt ; offset of interupt routine
	mov	[param+4],cs		; Our code segment.
	PushEA	param			; push the address of the parameter list
	call	InstallInt		; Install the interupt.
	add	sp,2			; clean up stack
@@OUT:

	OUT_TSR
	ret
	endp


;   /*\
;---|*|-------------------====< DeInstallInterrupt >====-----------------------
;---|*|
;---|*|
;   \*/

	public	DeInstallInterupt
Proc    DeInstallInterupt       far
	IN_TSR
	mov	[param],KINT		; Interupt requested to be unloaded.
	PushEA	param			; pass parameter.
	call	UnLoad			; Unload it
	add	sp,2			; clean up stack
	OUT_TSR
	ret
	endp


;   /*\
;---|*|------------------------====< CheckIn >====-----------------------------
;---|*|
;---|*|
;   \*/

	public	CheckIn
Proc    CheckIn near
	push	ds			; Save ds register.
	push	si

	mov	si,66h*4h		; get vector number
	xor	ax,ax			; zero
	mov	ds,ax			; point it there
	lds	si,[ds:si]		; get address of interupt vector
	or	si,si			; zero?
	jz	@@CIOUT 		; exit if zero
	sub	si,6			; point back to identifier

	cmp	[word si],'IM'          ; Midi driver?
	jne	@@NEX
	cmp	[word si+2],'ID'        ; full midi driver identity string?
	jne	@@NEX
;
; Ok, a MIDI driver is loaded at this address.
;
        mov     ax,701h                 ; Digitized Sound capabilities request.
	int	66h			; Request.
	or	ax,ax			; digitized sound driver available?
	jnz	@@INMID 		; yes, report that to the caller.
	mov	ax,3			; Not available, but mid pak is in!
	jmp short @@EXT 		; exit with return code.
;
@@INMID:
	mov	ax,2			; Sound driver resident, through MIDPAK.
	jmp short @@EXT
;
@@NEX:
	cmp	[word si],454Bh 	; equal?
	jne	@@CIOUT 		; exit if not equal
	cmp	[word si+2],4E52h	; equal?
        jne     @@CIOUT
;
@@OK:
	mov	ax,1
;
@@EXT:
	pop	si
	pop	ds
	ret

@@CIOUT:
	xor    ax,ax			; Zero return code.
	jmp short @@EXT

	endp


;   /*\
;---|*|-----------------------====< InstallINT >====---------------------------
;---|*|
;---|*|
;   \*/

	public	InstallINT
Proc    InstallINT near
	ARG	DATA:WORD
;
; Usage: IntallINT(&parms)
; offset 0: interupt
;	 2: offset of interupt code
;	 4: segment of interupt code
;
        PENTER  0
	PushCREGS

	mov	bx,[DATA]		; Get address of parameter table
	mov	ax,[bx] 		; get the interupt vector.
	mov	di,ax			; save interupt vector into DI as well
	mov	si,[bx+2]		; get offset
	mov	ds,[bx+4]		; get segment.
	mov	ah,35h			; Get interupt vector
	int	21h			; Do DOS call to get vector.
	mov	[ds:si-10],bx		; Save the old offset.
	mov	[ds:si-8],es		; Save the old segment
        cld
        xor     ax,ax
        mov     es,ax
	ShiftL	di,2
	mov	ax,si			; get offset.
        cli
        stosw
	mov	ax,ds			; code segment
	stosw				; store it.
        sti
	xor	ax,ax			; Success

	PopCREGS
	PLEAVE
	ret
	endp


;   /*\
;---|*|------------------------====< UnLoad >====------------------------------
;---|*|
;---|*|
;   \*/

	public	UnLoad
Proc    UnLoad near
	ARG	DATA:WORD

;
; Usage: UnLoad(&vector)
; Returns: AX = 0 success
;	   AX nonzero, couldn't unload interupt vector.
;

        PENTER  0
	PushCREGS

	mov	ax,68Fh 		; Stop sound playback!
	int	KINT			; Invoke interrupt.
	WaitSound
	mov	ax,692h 		; Deinstall hardware vectors.
	int	KINT

	mov	bx,[DATA]		; get address of interupt vector
	mov	bx,[bx] 		; get the interupt vector.
	mov	dx,bx			; put it into DX as well
	ShiftL	bx,2			;
        xor     ax,ax
	mov	ds,ax			; Segment zero
	lds	si,[ds:bx]		; get address of interupt vector
	or	si,si			; zero?
	jz	@@UOUT			; exit if zero
	cmp	[WORD ds:si-2],524Bh	; 'KR' Is this a kernel installed interupt?
	push	ds			; save DS
	mov	ax,dx			; Get interupt vector.
	mov	ah,25h			; Do DOS 25h set interupt vector.
	mov	dx,[ds:si-10]		; get old offset
	mov	ds,[ds:si-8]		; get old segment
	int	21h			; set interupt vector.
	pop	ax			; get back segment of program.
        mov     es,ax
	push	es
	mov	es,[es:2Ch]		; Environment space.
	mov	ah,49h
	int	21h			; Free it up.
	pop	es
	mov	ah,49h			; free memory.
	int	21h			; free up the memory used by us.
;
@@EXIT:
	PopCREGS
	PLEAVE
        ret
;
@@UOUT:
	mov	ax,1
	jmp short @@EXIT

	endp


;   /*\
;---|*|------------------====< ParseCommandLine >====--------------------------
;---|*|
;---|*| This procedure parses the command line and builds an array of
;---|*| pointers to each argument.  Arguments are seperated by space's.
;---|*| these spaces get replaced by zero bytes.
;---|*|
;   \*/

_argc	dw	0			; The argument count
_argv	dw	16  dup(0)		; Up to 16 arguments.
command db	128 dup(?)

	public	ParseCommandLine
Proc    ParseCommandLine        near

	mov	[_argc],0
	cmp	[byte es:80h],2
	jb	@@END
	xor	cx,cx
	mov	cl,[es:80h]		; Get length.
	SwapSegs
	dec	cx			; Less one
	lea	di,[command]
	mov	si,82h
	rep	movsb
	push	cs
	pop	ds
	lea	di,[_argv]		; Argument list.
	lea	si,[command]		; Start address.
;
@@SET:
	inc	[_argc] 		; Increment argument counter.
	mov	ax,si			; Base argument addres.
	stosw
;
@@NEX:
	lodsb				; Get characters until we hit space of eol
	cmp	al,32
	jne	@@NEX2
	mov	[byte ds:si-1],0	; Turn space into a zero byte.
	jmp short @@SET
;
@@NEX2:
	cmp	al,13
	je	@@END1
	or	al,al
	jnz	@@NEX			; Keep skipping to next arg.
;
@@END1:
	mov	[byte ds:si-1],0	; Zero byte terminate last arg
;
@@END:
	ret
	endp

;   /*\
;---|*|----------------------====< HardwareInit >====--------------------------
;---|*|
;---|*| VESA hardware init code.
;---|*|
;   \*/

	public	HardwareInit
Proc    HardwareInit    near

 ;; int 3

;
; find an appropriate VESA driver
;
        xor     ax,ax                   ; success code by default.
	call	VesaPresent
	shr	ax,2			; Access to digitized sound?
	mov	ax,1
	jz	@@EXT			; bail if no digitized sound
;
; open the driver for our use
;
        call    VesaInit                ; Detect if it's okay to play.
    ;
    @@EXT:
	ret

endp

ends

	end	START

