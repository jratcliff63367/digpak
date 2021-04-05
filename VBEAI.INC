
;   /*\
;---|*|--------------------====< VESA AI Include >====--------------------
;---|*|
;---|*| Copyright (c) 1993,1994  V.E.S.A, Inc. All Rights Reserved.
;---|*|
;---|*| VBE/AI 1.0 Specification
;---|*|    February 2, 1994. 1.00 release
;---|*|
;---|*| Additional Changes:
;---|*|   03/03 - Added the full list of Volume feature bit as EQUs
;---|*|
;   \*/

VBEAI_VERSION   equ     10h     ; first VBE/AI version

;   /*\
;---|*|----====< VESA Services Definitions >====----
;   \*/

INTHOOK         equ     0010h

;   // VAI query interface functions

VESAFUNCID      equ     04f13h  ; function ID

VESAFUNC0       equ     0000h   ; VESA Function #0 -- Validate VBE/AI presence
VESAFUNC1       equ     0001h   ; VESA Function #1 -- Locate the device
VESAFUNC2       equ     0002h   ; VESA Function #2 -- Query the device
VESAFUNC3       equ     0003h   ; VESA Function #3 -- Open the device
VESAFUNC4       equ     0004h   ; VESA Function #4 -- Close the device
VESAFUNC5       equ     0005h   ; VESA Function #5 -- Driver Unload
VESAFUNC6       equ     0006h   ; VESA Function #6 -- Driver Chain/Unchain

;   // VAI function 2 queries

VESAQUERY1      equ     0001h   ; return length of GeneralDeviceClass
VESAQUERY2      equ     0002h   ; return copy   of GeneralDeviceClass
VESAQUERY3      equ     0003h   ; return length of Volume Info Structure
VESAQUERY4      equ     0004h   ; return copy   of Volume Info Structure
VESAQUERY5      equ     0005h   ; return length of Volume Services Structure
VESAQUERY6      equ     0006h   ; return copy   of Volume Services Structure
VESAENDQUERY    equ     000fh   ; subfunctions 6 - 15 are reserved
                                ; subfunctions 16+ are used by the devices
;   // VAI Device types

WAVDEVICE       equ     01h
MIDDEVICE       equ     02h
VOLDEVICE       equ     03h

;#define WAVESERVICES    0x57415653 // ascii "WAVS"
;#define MIDISERVICES    0x4D494453 // ascii "MIDS"


;   /*\
;---|*|----====< Volume Services >====----
;   \*/

        VolumeInfo struc

            ;; housekeeping

            viname          db      4 dup(?)  ;; name of the structure
            vilength        dd      ?         ;; structure length

            ;; hardware vendor name

            viversion       dd      0         ;; driver software version
            vivname         db      32 dup(?) ;; vendor name, etc. (ASCIIZ string)
            viprod          db      32 dup(?) ;; vendor product name
            vichip          db      32 dup(?) ;; vendor chip/hardware description
            viboardid       db      0         ;; installed board #
            viunused        db      3  dup(?) ;; unused data

            vicname         db      24 dup(?) ;; text name of the mixer channel

            vifeatures      dd      ?         ;; bits of features

            vimin           dw      ?         ;; minimum volume setting
            vimax           dw      ?         ;; maximum volume setting
            vicross         dw      ?         ;; attenuation/gain crossover

        VolumeInfo ends

;  // Volume feature bits

VOLSTEREO       equ     0001h           ;; Stereo Volume control available
VOLLOPASS       equ     0004h           ;; Low Pass Filter is available
VOLHIPASS       equ     0008h           ;; High Pass Filter is available
VOLPARATC       equ     0010h           ;; Parametric Tone Control is available
VOLSELOUT       equ     0020h           ;; selectable output paths
VOLAZIMUTH      equ     0100h           ;; Azimuth Field positioning supported
VOLPHIMUTH      equ     0200h           ;; Phi Field positioning supported
VOLMASTER       equ     80000000h       ;; Master Volume device

;   // VOL device check messages

VOLFILTERRANGE          equ    0011h
VOLFILTERSETTING        equ    0012h
VOLFILTERCURRENT        equ    0013h
VOLTONERANGE            equ    0014h
VOLTONESETTING          equ    0015h
VOLTONECURRENT          equ    0016h
VOLPATH                 equ    0017h
VOLGETIOADDRESS         equ    0018h
VOLOEMSTARTINGDC        equ    0080h    ;; vendors can add DevChks above 0x80


;   /*\
;---|*|----====< Volume services Structure >====----
;   \*/

        VolumeService struc

            ;; housekeeping

            vsname          db      4 dup(?)  ;; name of the structure
            vslength        dd      ?         ;; structure length

            vsfuture        db      16 dup(?) ;; 16 bytes for future expansion

            vsDeviceCheck   dd      ?         ;; device check
            vsSetVolume     dd      ?         ;; set vol to an absolute setting
            vsSetFieldVol   dd      ?         ;; set 3D volume
            vsToneControl   dd      ?         ;;
            vsFilterControl dd      ?         ;;
            vsOutputPath    dd      ?         ;;
            vsResetChannel  dd      ?         ;;
            vsGetLastError  dd      ?         ;;

        VolumeService ends

;   // VOL SetVolume message

VOL_USERSETTING equ     01h                   ;; User master volume setting
VOL_APPSETTING  equ     02h                   ;; application master volume setting

;   // VOL error message

VOL_NOSUPPORT   equ     01h                   ;; unsupported feature/function
VOL_BADVALUE    equ     02h                   ;; out of range parameter value
VOL_HWFAILURE   equ     80h                   ;; vendors specific errors


;   /*\
;---|*|----====< WAVE Info Structure >====----
;   \*/

        WAVEInfo struc

            ;; housekeeping

            winame          db      4 dup(?)  ;; name of the structure
            wilength        dd      ?         ;; structure length

            ;; hardware vendor name

            wiversion       dd      0         ;; driver software version
            wivname         db      32 dup(?) ;; vendor name, etc. (ASCIIZ string)
            wiprod          db      32 dup(?) ;; vendor product name
            wichip          db      32 dup(?) ;; vendor chip/hardware description
            wiboardid       db      0         ;; installed board #
            wiunused        db      3  dup(?) ;; unused data

            ;; device specific information

            wifeatures      dd      ?         ;; feature bits
            widevpref       dw      ?         ;; user determined preference field
            wimemreq        dw      ?         ;; memory required for driver use.
            witimerticks    dw      ?         ;; # of timer tick callbacks per second

            wiChannels      dw      ?         ;; 1 = mono, 2 = stereo. Stereo is
                                              ;; assumed to be interleaved data.
            wiSampleSize    dw      ?         ;; Bit field of max sample sizes

        WAVEInfo ends

;   // WAVE feature bit definitions

WAVEMP8K        equ     00000001h       ;; 8000hz Mono Playback.
WAVEMR8K        equ     00000002h       ;; 8000hz Mono Record.
WAVESR8K        equ     00000004h       ;; 8000hz Stereo Record.
WAVESP8K        equ     00000008h       ;; 8000hz Stereo Playback.
WAVEFD8K        equ     00000010h       ;; 8000hz Full Duplex Play/Record.

WAVEMP11K       equ     00000020h       ;; 11025hz Mono Playback.
WAVEMR11K       equ     00000040h       ;; 11025hz Mono Record.
WAVESR11K       equ     00000080h       ;; 11025hz Stereo Record.
WAVESP11K       equ     00000100h       ;; 11025hz Stereo Playback.
WAVEFD11K       equ     00000200h       ;; 11025hz Full Duplex Play/Record.

WAVEMP22K       equ     00000400h       ;; 22050hz Mono Playback.
WAVEMR22K       equ     00000800h       ;; 22050hz Mono Record.
WAVESR22K       equ     00001000h       ;; 22050hz Stereo Record.
WAVESP22K       equ     00002000h       ;; 22050hz Stereo Playback.
WAVEFD22K       equ     00004000h       ;; 22050hz Full Duplex Play/Record.

WAVEMP44K       equ     00008000h       ;; 44100hz Mono Playback.
WAVEMR44K       equ     00010000h       ;; 44100hz Mono Record.
WAVESR44K       equ     00020000h       ;; 44100hz Stereo Record.
WAVESP44K       equ     00040000h       ;; 44100hz Stereo Playback.
WAVEFD44K       equ     00080000h       ;; 44100hz Full Duplex Play/Record.

WAVEPREPARE     equ     08000000h       ;; driver must pre handle the data
WAVEVARIPMONO   equ     10000000h       ;; Variable Sample mono   playback
WAVEVARIPSTER   equ     20000000h       ;; Variable Sample stereo playback
WAVEVARIRMONO   equ     40000000h       ;; Variable Sample mono   record
WAVEVARIRSTER   equ     80000000h       ;; Variable Sample stereo record

;   // WAVE device check messages

WAVECOMPRESSION         equ     11h
WAVEDRIVERSTATE         equ     12h
WAVEGETCURRENTPOS       equ     13h
WAVESAMPLERATE          equ     14h
WAVESETPREFERENCE       equ     15h
WAVEGETDMAIRQ           equ     16h
WAVEGETIOADDRESS        equ     17h
WAVEGETMEMADDRESS       equ     18h
WAVEGETMEMFREE          equ     19h
WAVEFULLDUPLEX          equ     1Ah
WAVEGETBLOCKSIZE        equ     1Bh
WAVEGETPCMFORMAT        equ     1Ch
WAVEENAPCMFORMAT        equ     1Dh
WAVEOEMSTARTINGDC       equ     80h     ;; vendors can add DevChks above 0x80

;   // types of compression

WAVEIMAPLAY             equ     01h
WAVEALAWPLAY            equ     02h
WAVEULAWPLAY            equ     03h

WAVEIMARECORD           equ     11h
WAVEALAWRECORD          equ     12h
WAVEULAWRECORD          equ     13h

;   // sample data sizes

WAVE08BITPLAY           equ     01h
WAVE16BITPLAY           equ     02h
WAVE08BITREC            equ     10h
WAVE16BITREC            equ     20h


;   /*\
;---|*|----====< WAVE Audio Services >====----
;   \*/

;   ;;  The following is a description of the contents of the WAVE Audio
;   ;;  Services. For the most part, this structure is read-only to
;   ;;  the application. The only two fields the application can write
;   ;;  are the callback fields.

        WAVEService struc

            ;; housekeeping

            wsname          db      4 dup(?)  ;; name of the structure
            wslength        dd      ?         ;; structure length

            wsfuture        db      16 dup(?) ;; 16 bytes for future expansion

            ;; device driver supplied function

            wsDeviceCheck   dd      ?         ;;
            wsPCMInfo       dd      ?         ;;
            wsPlayBlock     dd      ?         ;;
            wsPlayCont      dd      ?         ;;

            wsRecordBlock   dd      ?         ;;
            wsRecordCont    dd      ?         ;;
            wsPauseIO       dd      ?         ;;
            wsResumeIO      dd      ?         ;;

            wsStopIO        dd      ?         ;;
            wsWavePrepare   dd      ?         ;;
            wsWaveRegister  dd      ?         ;;

            wsGetLastError  dd      ?         ;;
            wsTimerTick     dd      ?         ;;

            ;; device driver run-information time data

            wsApplPSyncCB   dd      ?         ;; play filled in by the app
            wsApplRSyncCB   dd      ?         ;; rec filled in by the app

        WAVEService ends

        ;; error messages

WAV_NOSUPPORT           equ     1h      ;; unsupported feature/function
WAV_BADSAMPLERATE       equ     2h
WAV_BADBLOCKLENGTH      equ     3h
WAV_BADBLOCKADDR        equ     4h
WAV_BADLOSTIRQ          equ     5h      ;; app. missed an IRQ
WAV_BADPCMDATA          equ     6h      ;; don't understand the PCM size/format
WAV_HWFAILURE           equ    80h      ;; vendors specific errors


;   /*\
;---|*|----====< MIDI Info Structure >====----
;   \*/

        MIDIInfo struc

            ;; housekeeping

            miname          db      4 dup(?)  ;; name of the struc
            milength        dd      ?         ;; structure length

            ;; hardware vendor name

            miversion       dd      0         ;; driver software version
            mivname         db      32 dup(?) ;; vendor name, etc. (ASCIIZ string)
            miprod          db      32 dup(?) ;; vendor product name
            michip          db      32 dup(?) ;; vendor chip/hardware description
            miboardid       db      0         ;; installed board #
            miunused        db      3  dup(?) ;; unused data

            milibrary       db      14 dup(?) ;; the patch library name. file name

            ;; Feature list

            mifeatures      dd      ?         ;; feature bits
            midevpref       dw      ?         ;; user determined preference field
            mimemreq        dw      ?         ;; memory required for driver use
            mitimerticks    dw      ?         ;; # of timer tick callbacks per second

            miactivetones   dw      ?         ;; max # of tones (voices, partials)

        MIDIInfo ends

;   // MIDI feature bits

MIDIFRESVD1             equ     0001h   ;; reserved for GM extensions
MIDIFRESVD2             equ     0002h   ;; reserved for GM extensions
MIDIFRESVD3             equ     0004h   ;; reserved for GM extensions
MIDIFRESVD4             equ     0008h   ;; reserved for GM extensions
MIDIFXMITR              equ     0010h   ;; Transmitter/Receiver only.
MIDIFPRELD              equ     0020h   ;; Patches preloaded.
MIDIFTIMEST             equ     0040h   ;; MIDI receive has time stamp.
MIDIINTR                equ     0100h   ;; MIDI interrupt driven input supported
MIDIPOLL                equ     0200h   ;; MIDI polled input supported
MIDIREMOTELD            equ     0400h   ;; MIDI remote patches supported

;   // MIDI device check messages

MIDITONES               equ     11h     ;; return available tones
MIDIPATCHTYPE           equ     12h     ;; return TRUE/FALSE if patch is understood
MIDISETPREFERENCE       equ     13h     ;; set the preference
MIDIVOICESTEAL          equ     14h     ;; allow/disallow voice stealing
MIDIGETFIFOSIZES        equ     15h
MIDIGETDMAIRQ           equ     16h
MIDIGETIOADDRESS        equ     17h
MIDIGETMEMADDRESS       equ     18h
MIDIGETMEMFREE          equ     19h
MIDIOEMSTARTINGDC       equ     80h     ;; vendors can add DevChks above 0x80

;   // MIDI Registered Patch Types

MIDI_PATCH_OPL2         equ     10h
MIDI_PATCH_OPL3         equ     11h


;   /*\
;---|*|----====< Synthesizer Audio Services Structure >====----
;   \*/

            ;; Synthesizer Services Structure

        MIDIService struc

            ;; housekeeping

            msname         db      4 dup(?)  ;; name of the struc
            mslength       dd      ?         ;; structure length

            ;; runtime data

            mspatches      dw      16 dup(?) ;; patches loaded table bit field
            msfuture       db      16 dup(?) ;; 16 bytes for future expansion

            ;; device driver supplied function

            msDeviceCheck  dd      ?          ;;
            msGlobalReset  dd      ?          ;;
            msMIDImsg      dd      ?          ;;
            msPollMIDI     dd      ?          ;;
            msPreLoadPatch dd      ?          ;;
            msUnloadPatch  dd      ?          ;;
            msTimerTick    dd      ?          ;;
            msGetLastError dd      ?          ;;

            ;; application supplied functions

            msApplFreeCB   dd      ?          ;; Patch Block free cb
            msApplMIDIIn   dd      ?          ;; MIDI byte avail.

        MIDIService ends

MID_NOSUPPORT           equ     1h      ;; unsupported feature/function
MID_UNKNOWNPATCH        equ     2h      ;; unknown patch type
MID_ALLTONESUSED        equ     3h      ;; all tones are used
MID_BADMIDIMSG          equ     4h      ;; messages are out of sync
MID_PATCHINCOMP         equ     5h      ;; an incoming patch was incomplete
MID_PATCHINFULL         equ     6h      ;; an incoming patch couldn't be stored
MID_BADLOSTIRQ          equ     7h      ;; had to drop an incoming byte
MID_PATCHINFAIL         equ     8h      ;; driver is failing a patch download
MID_HWFAILURE           equ    80h      ;; vendors specific errors


;   /*\
;---|*|----====< General Device Class structure for all devices >====----
;   \*/

;   ;;  When a device is queried via function #1, it will return the
;   ;;  following structure. The entire structure contents are read-only
;   ;;  for the application. There are no fields that the application
;   ;;  may modify.

 gdcpad = SIZE MIDIInfo
 if (SIZE VolumeInfo) GT (SIZE MIDIInfo)
   gdcpad = SIZE VolumeInfo
 endif
 if (SIZE WAVEInfo) GT (SIZE MIDIInfo)
   gdcpad = SIZE WAVEInfo
 endif

        GeneralDeviceClass struc

            ;; housekeeping...

            gdcname         db      4 dup(?)  ;; name of the struc
            gdclength       dd      ?         ;; structure length

            ;; generalities...

            gdcclassid      dw      ?         ;; type of device
            gdvbever        dw      ?         ;; version of VESA driver support

            ;; unions follow...

            gdcu            db   gdcpad dup(?);; version of VESA driver support

        GeneralDeviceClass ends

wiunion equ <gdcvesaver+2>
miunion equ <gdcvesaver+2>
viunion equ <gdcvesaver+2>

    ;;
    ;; patch file format structures
    ;;

        RIFFhdr struc
            rifftype    db      4 dup(0);; structure type holds "RIFF"
            riffrcount  dd      0       ;; length of the RIFF block
        RIFFhdr ends

        VAILhdr struc
            vailtype    db      4 dup(0);; structure type holds "vail"
            vailpcount  dd      0       ;; count of patches in the file
        VAILhdr ends

        ZSTRhdr struc
            zstrtype    db      4 dup(0);; structure type holds "ZSTR"
            zstrtlen    dd      0       ;; length of text following this field
        ZSTRhdr ends

        VAIPhdr struc
            vaiptype    db      4 dup(0);; structure type holds "vaip"
            vaiplen     dd      0       ;; VBE/AI Patch data table
        VAIPhdr ends

        VAIIhdr struc
            vaiitype    db      4 dup(0);; structure type holds "vaii", index
            vaiilen     dd      0       ;; vaii structure length
            vailpoffset dd      0       ;; holds offset to "vaid" from "vaip"
            vailvaidln  dd      0       ;; holds length of the corresponding patch
        VAIIhdr ends

        VAIDhdr struc
            vaidtype    db      4 dup(0);; structure type holds "vaid"
            vaidlen     dd      ?       ;; holds length of this patch
        VAIDhdr ends


;   /*\
;---|*|----====< PC Hardware specific Definitions >====----
;   \*/

; Interrupt Controller #1 Port Addresses and Interrupt Masks

IRQ1MASKREG     EQU     021h            ;; 8259 mask register
IRQ1ACKREG      EQU     020h            ;; 8259 INT acknowledge register

INT0MSK         EQU     00000001B       ;; interrupt 0 mask
INT1MSK         EQU     00000010B       ;; interrupt 1 mask
INT2MSK         EQU     00000100B       ;; interrupt 2 mask
INT3MSK         EQU     00001000B       ;; interrupt 3 mask
INT4MSK         EQU     00010000B       ;; interrupt 4 mask
INT5MSK         EQU     00100000B       ;; interrupt 5 mask
INT6MSK         EQU     01000000B       ;; interrupt 6 mask
INT7MSK         EQU     10000000B       ;; interrupt 7 mask

; Interrupt Controller #2 Port Addresses and Interrupt Masks

IRQ2MASKREG     EQU     0A1h            ;; 8259 mask register
IRQ2ACKREG      EQU     0A0h            ;; 8259 INT acknowledge register

INT8MSK         EQU     00000001B       ;; interrupt 8 mask
INT9MSK         EQU     00000010B       ;; interrupt 9 mask
INTAMSK         EQU     00000100B       ;; interrupt A mask
INTBMSK         EQU     00001000B       ;; interrupt B mask
INTCMSK         EQU     00010000B       ;; interrupt C mask
INTDMSK         EQU     00100000B       ;; interrupt D mask
INTEMSK         EQU     01000000B       ;; interrupt E mask
INTFMSK         EQU     10000000B       ;; interrupt F mask

EOI             EQU     020h            ;; non specific end of interrupt

; dma controller #1 port addresses

DMAC0ADDR       EQU     000h            ;; DMA channel 0 Base & Current Address
DMAC0COUNT      EQU     001h            ;; DMA channel 0 Base & Current Count
DMAC1ADDR       EQU     002h            ;; DMA channel 1 Base & Current Address
DMAC1COUNT      EQU     003h            ;; DMA channel 1 Base & Current Count
DMAC2ADDR       EQU     004h            ;; DMA channel 2 Base & Current Address
DMAC2COUNT      EQU     005h            ;; DMA channel 2 Base & Current Count
DMAC3ADDR       EQU     006h            ;; DMA channel 3 Base & Current Address
DMAC3COUNT      EQU     007h            ;; DMA channel 3 Base & Current Count

DMA2C4ADDR      EQU     0C0h            ;; DMA channel 4 Base & Current Address
DMA2C4COUNT     EQU     0C2h            ;; DMA channel 4 Base & Current Count
DMA2C5ADDR      EQU     0C4h            ;; DMA channel 5 Base & Current Address
DMA2C5COUNT     EQU     0C6h            ;; DMA channel 5 Base & Current Count
DMA2C6ADDR      EQU     0C8h            ;; DMA channel 6 Base & Current Address
DMA2C6COUNT     EQU     0CAh            ;; DMA channel 6 Base & Current Count
DMA2C7ADDR      EQU     0CCh            ;; DMA channel 7 Base & Current Address
DMA2C7COUNT     EQU     0CEh            ;; DMA channel 7 Base & Current Count

DMARDSTAT       EQU     008h            ;; DMA read status
DMAWRCNTRL      EQU     008h            ;; DMA write command register
DMAWREQ         EQU     009h            ;; DMA write request register
DMAWRSMR        EQU     00Ah            ;; DMA write single mask register
DMAWRMODE       EQU     00Bh            ;; DMA write mode register
DMACLEAR        EQU     00Ch            ;; DMA clear low/high flip-flop
DMARDTEMP       EQU     00Dh            ;; DMA read temp register
DMAWRCLR        EQU     00Dh            ;; DMA write master clear
DMACLRMSK       EQU     00Eh            ;; DMA clear mask register
DMAWRALL        EQU     00Fh            ;; DMA write all mask register bits

DMA2RDSTAT      EQU     0D0h            ;; DMA read status
DMA2WRCNTRL     EQU     0D0h            ;; DMA write command register
DMA2WREQ        EQU     0D2h            ;; DMA write request register
DMA2WRSMR       EQU     0D4h            ;; DMA write single mask register
DMA2WRMODE      EQU     0D6h            ;; DMA write mode register
DMA2CLEAR       EQU     0D8h            ;; DMA clear low/high flip-flop
DMA2RDTEMP      EQU     0DAh            ;; DMA read temp register
DMA2WRCLR       EQU     0DAh            ;; DMA write master clear
DMA2CLRMSK      EQU     0DCh            ;; DMA clear mask register
DMA2WRALL       EQU     0DEh            ;; DMA write all mask register bits

CH0PAGEREG      EQU     087h            ;; Channel 0 Page Register
CH1PAGEREG      EQU     083h            ;; Channel 1 Page Register
CH2PAGEREG      EQU     081h            ;; Channel 2 Page Register
CH3PAGEREG      EQU     082h            ;; Channel 3 Page Register

CH5PAGEREG      EQU     08Bh            ;; Channel 5 Page Register
CH6PAGEREG      EQU     089h            ;; Channel 6 Page Register
CH7PAGEREG      EQU     08Ah            ;; Channel 7 Page Register

SYSSPKRTMR      EQU     00042h          ;; System Speaker Timer Address
SYSTMRCTLR      EQU     00043h          ;; System Timer Control Register
SYSSPKRREG      EQU     00061h          ;; System Speaker Register
JOYSTICK        EQU     00201h          ;; Joystick Register

;   /*\
;---|*|----====< Assember Miscellaneous Definitions >====----
;   \*/

TRUE    equ     -1
FALSE   equ      0

wptr    equ     <word ptr>
bptr    equ     <byte ptr>
dptr    equ     <dword ptr>

; PUSHA stack frame, plus ES & DS

regwset struc
 _regDS dw      ?
 _regES dw      ?
 _regDI dw      ?
 _regSI dw      ?
 _regBP dw      ?
 _regSP dw      ?
 _regBX dw      ?
 _regDX dw      ?
 _regCX dw      ?
 _regAX dw      ?
regwset ends

; stack frame accesses

_DI     equ     <word ptr [bp+_regDI]>
_SI     equ     <word ptr [bp+_regSI]>
_BP     equ     <word ptr [bp+_regBP]>
_SP     equ     <word ptr [bp+_regSP]>
_BX     equ     <word ptr [bp+_regBX]>
_BL     equ     <byte ptr [bp+_regBX]>
_BH     equ     <byte ptr [bp+_regBX+1]>
_DX     equ     <word ptr [bp+_regDX]>
_DL     equ     <byte ptr [bp+_regDX]>
_DH     equ     <byte ptr [bp+_regDX+1]>
_CX     equ     <word ptr [bp+_regCX]>
_CL     equ     <byte ptr [bp+_regCX]>
_CH     equ     <byte ptr [bp+_regCX+1]>
_AX     equ     <word ptr [bp+_regAX]>
_AL     equ     <byte ptr [bp+_regAX]>
_AH     equ     <byte ptr [bp+_regAX+1]>


if @codesize
  @ret equ 4
  FFAR  equ     <far>
  if1
    %out compiling LARGE code segments
  endif
else
  @ret equ 2
  FFAR  equ     <near>
  if1
    %out compiling SMALL code segments
  endif
endif

if @datasize
  @ptr equ 4
  if1
    %out compiling LARGE data segments
  endif
else
  @ptr equ 2
  if1
    %out compiling SMALL data segments
  endif
endif

@farret  equ 4
@nearret equ 2
@farptr  equ 4
@nearptr equ 2


;
; NEAR branches
;
jjnz    macro   addr
        LOCAL   jjmp
        jz      jjmp
        jmp     addr
     jjmp:
        endm

jjz     macro   addr
        LOCAL   jjmp
        jnz     jjmp
        jmp     addr
     jjmp:
        endm

jjc     macro   addr
        LOCAL   jjmp
        jnc     jjmp
        jmp     addr
     jjmp:
        endm

jjnc    macro   addr
        LOCAL   jjmp
        jc      jjmp
        jmp     addr
     jjmp:
        endm

jjb     macro   addr
        LOCAL   jjmp
        jae     jjmp
        jmp     addr
     jjmp:
        endm

jjbe    macro   addr
        LOCAL   jjmp
        ja      jjmp
        jmp     addr
     jjmp:
        endm

jjl     macro   addr
        LOCAL   jjmp
        jge     jjmp
        jmp     addr
     jjmp:
        endm

jjle    macro   addr
        LOCAL   jjmp
        jg      jjmp
        jmp     addr
     jjmp:
        endm

jjge    macro   addr
        LOCAL   jjmp
        jl      jjmp
        jmp     addr
     jjmp:
        endm

jjg     macro   addr
        LOCAL   jjmp
        jle     jjmp
        jmp     addr
jjmp:
        endm

jja     macro   addr
        LOCAL   jjmp
        jbe     jjmp
        jmp     addr
jjmp:
        endm

breakpoint      macro
 if DEBUG
 if1
        %out Take this Out
 endif
        int 3
 endif
                endm

;   /*\
;---|*| end of DRIVER.INC
;   \*/


