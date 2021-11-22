;[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[
;[[                                                                        [[
;[[   DMASOUND.ASM                                                         [[
;[[                                                                        [[
;[[   IBM Audio Interface Library                                          [[
;[[                                                                        [[
;[[   Digital sound driver/emulator for Sound Blaster-type audio devices   [[
;[[                                                                        [[
;[[   Version 2.00 of 09-Oct-91: Initial V2.0 version, derived from V1.05  [[
;[[           2.01 of 21-Nov-91: Autodetects Thunderboard as Sound Blaster [[
;[[                              Dual-buffer playback flag checks modified [[
;[[           2.02 of 14-Dec-91: PAS DMA timer pauses/resumes correctly    [[
;[[           2.03 of 18-Dec-91: Standard SB speaker control fixed         [[
;[[           2.04 of 13-Jan-92: Stereo .VOC file support added            [[
;[[           2.05 of 20-Jan-92: I/O timeout w/beep added                  [[
;[[                              Sample rate high byte always cleared      [[
;[[           2.06 of 18-Feb-92: IRQ delay during halt_DMA                 [[
;[[                              sysex_wait() calls replace loops          [[
;[[                              Send >1 bytes during detection            [[
;[[                              Do shutdown only if initialized           [[
;[[           2.07 of  2-Apr-92: Set valid sample rate during detection    [[
;[[           2.10 of  4-Apr-92: Ad Lib Gold support added                 [[
;[[                              AIL_format_VOC_file/_sound_buffer() added [[
;[[                              DMA word count checked in IRQ handlers    [[
;[[           2.11 of 13-May-92: IRQ delay skipped if .VOC playback ended  [[
;[[           2.12 of 29-May-92: PAS default volume reduced                [[
;[[           2.13 of 29-Jun-92: PAS +/16 compatibility issues resolved    [[
;[[                              ALG panning disabled in mono mode         [[
;[[                              SBLASTER silence-packing problems fixed   [[
;[[           2.14 of 17-Aug-92: CHECK_DMAC option added                   [[
;[[           2.15 of 15-Sep-92: WAIT_FALSE_IRQ option added               [[
;[[           2.16 of 14-Nov-92: Alternative fix for unwanted SBlaster     [[
;[[                              IRQs implemented                          [[
;[[                              DMA terminal count of 0 accepted          [[
;[[                                                                        [[
;[[   Author: John Miles                                                   [[
;[[   8086 ASM source compatible with Turbo Assembler v2.0 or later        [[
;[[                                                                        [[
;[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[
;[[                                                                        [[
;[[    Copyright (C) 1991, 1992 Miles Design, Inc.                         [[
;[[                                                                        [[
;[[    Miles Design, Inc.                                                  [[
;[[    10926 Jollyville #308                                               [[
;[[    Austin, TX 78759                                                    [[
;[[    (512) 345-2642 / FAX (512) 338-9630 / BBS (512) 454-9990            [[
;[[                                                                        [[
;[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[

                MODEL MEDIUM,C          ;Procedures far, data near by default
                LOCALS __               ;Enable local labels with __ prefix
                JUMPS                   ;Enable auto jump sizing

                ;
                ;External/configuration equates
                ;

FALSE           equ 0
TRUE            equ -1

PAS_FILTER      equ FALSE               ;TRUE to enable PAS PCM antialiasing
                                        ;(also degrades FM treble response)

CHECK_DMAC      equ TRUE                ;FALSE to inhibit checking for end-
                                        ;of-DMA conditions; may need to be
                                        ;turned off for proper operation with 
                                        ;non-100% IBM-compatible systems and 
                                        ;V86 host software

WAIT_FALSE_IRQ  equ FALSE               ;TRUE to wait 140 ms. after stopping
                                        ;DMA transfers -- original way to     
                                        ;avoid certain Sound Blaster hardware
                                        ;glitches

DAC_STOPPED     equ 0
DAC_PAUSED      equ 1
DAC_PLAYING     equ 2
DAC_DONE        equ 3
; Added DAC_BUFF_REGISTERED to this group.  This is so that I know that UltraMID
; knows about the buffer, but it hasn't played it yet.  I needed a value
; between DAC_STOPPED (registered) and DAC_PLAYING (playing).
DAC_BUFF_REGISTERED equ 4

                ;
                ;Macros, internal equates
                ;

                INCLUDE ail.mac
                INCLUDE ail.inc
		INCLUDE ultramid.inc

VOC_MODE        equ 0                   ;Creative Voice File playback mode
BUF_MODE        equ 1                   ;Dual-buffer DMA playback mode

                .CODE	_TEXT

                dw OFFSET driver_index
                db 'Copyright (C) 1991,1992 Miles Design, Inc.',01ah

driver_index:
                dw AIL_DESC_DRVR,OFFSET describe_driver 
                dw AIL_DET_DEV,OFFSET detect_device   
                dw AIL_INIT_DRVR,OFFSET init_driver     
                dw AIL_SHUTDOWN_DRVR,OFFSET shutdown_driver 
                dw AIL_P_VOC_FILE,OFFSET play_VOC_file       
                dw AIL_START_D_PB,OFFSET start_d_pb      
                dw AIL_STOP_D_PB,OFFSET stop_d_pb       
                dw AIL_PAUSE_D_PB,OFFSET pause_d_pb      
                dw AIL_RESUME_D_PB,OFFSET cont_d_pb       
                dw AIL_VOC_PB_STAT,OFFSET get_VOC_status
                dw AIL_SET_D_PB_VOL,OFFSET set_d_pb_vol    
                dw AIL_D_PB_VOL,OFFSET get_d_pb_vol
                dw AIL_SET_D_PB_PAN,OFFSET set_d_pb_pan
                dw AIL_D_PB_PAN,OFFSET get_d_pb_pan
                dw AIL_INDEX_VOC_BLK,OFFSET index_VOC_blk
                dw AIL_REG_SND_BUFF,OFFSET register_sb
                dw AIL_SND_BUFF_STAT,OFFSET get_sb_status
                dw -1

                ;
                ;Driver Description Table (DDT)
                ;Returned by describe_driver() proc
                ;

DDT             LABEL WORD
min_API_version dw 200                  ;Minimum API version required = 2.00
driver_type     dw 2                    ;Type 2: Sound Blaster DSP emulation
data_suffix     db 'VOC',0              ;Supports .VOC files directly
device_name_o   dw OFFSET devnames      ;Pointer to list of supported devices
device_name_s   dw ?
default_IO      LABEL WORD              ;Factory default I/O parameters
		dw -1
default_IRQ     LABEL WORD
		dw -1
default_DMA     LABEL WORD
                dw -1                   ;(determined from ULTRAMID)
default_DRQ     dw -1
service_rate    dw -1                   ;No periodic service required
display_size    dw 0                    ;No display

devnames        LABEL BYTE
		db 'Forte UltraSound(TM) Digital Sound', 0
                db 0                    ;0 to end list of device names

                ;
                ;Default setup values & internal constants
                ;

default_vol     LABEL WORD
                dw 127

st_mem		db 2*1024 dup (?)

sbuffer         STRUC
pack_type       dw ?
sample_rate     dw ?
data            dd ?
len_l           dw ?
len_h           dw ?
sbuffer         ENDS

                ;
                ;Misc. data
                ;

playing		dw ?
stop_voc_mode	dw ?
db_playing      dw ?
block_ptr       dd ?
packing         dw ?
current_rate    dw ?
current_pan	dw ?
current_volume	dw ?
pack_byte       dw ?
blk_len         dw ?
loop_ptr        dd ?
loop_cnt        dw ?

buff_data_o     dw 2 dup (?)
buff_data_s     dw 2 dup (?)
buff_len_l      dw 2 dup (?)
buff_len_h      dw 2 dup (?)
buff_pack       dw 2 dup (?)
buff_sample     dw 2 dup (?)
buff_status     dw 2 dup (?)
buff_time	dw 2 dup (?)
time		dw ?

buffer_mode     dw ?                   
DAC_status      dw ?

xblk_status     dw ?
xblk_tc         db ?
xblk_pack       db ?

INCLUDE vol.inc

umss	um_sound_struct <>		     ;UltraMID sound structure

chk_hook_str    db 'ULTRAMID',0              ;Stamp to find resident GF1 O.S.

gf1hook     label   dword   		     ;GF1 hook for all UltraMID calls.
hookoff     dw      0
hookseg     dw      0

;****************************************************************************
block_type      PROC                    ;Return AX=current block type
                USES	ds,si,di

                lds	si,block_ptr
                lodsb
                mov 	ah,0

                ret
                ENDP

;****************************************************************************
set_xblk        PROC                    ;Set extended .VOC block parms
                USES	ds,si,di

                lds 	si,block_ptr        
                cmp 	BYTE PTR [si],8
                jne 	__exit            ;(not an extended block)

                mov 	al,[si+5]           ;get extended voice parameters
                mov 	xblk_tc,al       ;high byte of TC = normal sample rate

                mov 	ax,[si+6]           ;get pack (AL) and mode (AH)
                cmp 	ah,1                ;stereo?
                jne 	__set_pack

                or 	al,80h               ;yes, make pack byte negative

__set_pack:     mov 	xblk_pack,al

                mov 	xblk_status,1       ;flag extended block override

__exit:         ret
                ENDP

;****************************************************************************
marker_num      PROC                    ;Return AX=block's marker #
                USES	ds,si,di

                lds 	si,block_ptr
                cmp 	BYTE PTR [si],4
                mov 	ax,-1       
                jne 	__exit              ;(not a marker block)
                mov 	ax,[si+4]           ;return marker #

__exit:         ret
                ENDP

;****************************************************************************
;double buffer callback from UltraMID
um_callback	PROC C FAR,reason,voice,buff:FAR PTR,bufflen:FAR PTR,bufrate:FAR PTR
                USES	ds,si,di
                     
		cmp	reason, UM_STOP_SOUND
		je	__stop
		cmp	reason, UM_MORE_DATA
		je	__more_data
		cmp	reason, UM_BUFFER_DONE
		je	__buffer_done
		jmp	__exit
__more_data:
                cmp 	buffer_mode,VOC_MODE        
		jne	__db_mode
		cmp	stop_voc_mode, 1
		je	__exit
                call 	next_block         
                call 	process_block C, OFFSET umss, cs
		cmp	ax, 0
		jne	__send_next
		mov	stop_voc_mode, 1
		jmp	__exit
__send_next:
		les	di,buff
		lds	si,umss.um_sound_data
		mov	word ptr es:[di], si
		mov	word ptr es:[di+2], ds
		les	di,bufflen
		lds	si,umss.um_sound_len
		mov	word ptr es:[di], si
		mov	word ptr es:[di+2], ds
		les	di,bufrate
		mov	bx, umss.um_sample_rate
		mov	word ptr es:[di], bx
		mov	ax, 1
		jmp	__keep_going

__db_mode:
		call	next_buffer
		cmp	ax,-1
		je	__exit
		mov	si, ax
		shl	si, 1
		push	ax
		call	process_buffer, ax, OFFSET umss, cs
		pop	ax
		mov	buff_status[si], DAC_BUFF_REGISTERED
		cmp	db_playing, -1
		jne	__send_next
		mov	db_playing, ax
		jmp	__send_next
__buffer_done:
                cmp 	buffer_mode,VOC_MODE
		je	__exit
		mov	bx, db_playing
		shl	bx, 1
                mov 	buff_status[bx],DAC_DONE
; now that this buffer is done, check to see if other buffer is registered.
; if it is, then it will start playing.
		or	bx, bx
		jne	__check_b0
		mov	bx, 2
		mov	si, 1
		jmp	__check_other
__check_b0:	mov	bx, 0
		mov	si, 0
__check_other:	cmp	buff_status[bx],DAC_BUFF_REGISTERED
		jne	__not_registered
		mov	buff_status[bx],DAC_PLAYING
		mov	db_playing, si
		jmp	__exit
__not_registered:
		mov	db_playing, -1
		jmp	__exit
__stop:
		mov	playing, 0
		mov	db_playing, -1
		cmp	buff_status[0*2],DAC_STOPPED
		je	__stop_buff_1
		mov	buff_status[0*2],DAC_DONE
__stop_buff_1:
		cmp	buff_status[1*2],DAC_STOPPED
		je	__stopped
		mov	buff_status[1*2],DAC_DONE
__stopped:
		cmp	buffer_mode,VOC_MODE
		jne	__exit
 		mov 	DAC_status,DAC_DONE
		mov	stop_voc_mode, 0
__exit:			
; Tell the O.S. to stop buffering.
		mov	ax, 0
__keep_going:
                ret
                ENDP

;****************************************************************************
next_block      PROC                    ;Index next block in voice data
                USES	ds,si,di

                lds 	si,block_ptr
                inc 	si                  ;skip block type
                lodsw                   
                mov 	dl,[si]
                mov 	dh,0           ;blk len: AL=LSB, AH=KSB, DL=MSB, DH=0
                inc 	si

                ADD_PTR ax,dx,ds,si     ;point to next block

                mov 	WORD PTR block_ptr,si
                mov 	WORD PTR block_ptr+2,ds

                ret
                ENDP

;****************************************************************************
process_block   PROC C,ssp:FAR PTR      ;Process current block in voice data
                USES 	ds,di           ;(May be called from IRQ handler)

__do_block:     call 	block_type
                cmp 	ax,0            ;terminator?
                je 	__terminate
                cmp 	ax,1            ;new voice block?
                je 	__new_voice
                cmp 	ax,2            ;continued voice block?
                je 	__cont_voice
                cmp 	ax,3            ;silence period?
                je 	__silence
                cmp 	ax,4            ;marker (end of data?)
                je 	__terminate
                cmp 	ax,6            ;beginning of repeat loop?
                je 	__rept_loop
                cmp 	ax,7            ;end of repeat loop?
                je 	__end_loop
                cmp 	ax,8            ;extended block type?
                je 	__extended
                jmp 	__skip_block    ;else unrecognized block type, skip it

__extended:     call 	set_xblk
                jmp 	__skip_block

__terminate:    
		mov	ax, 0
                jmp 	__exit

__skip_block:   call 	next_block
                jmp 	__do_block

__rept_loop:    lds 	si,block_ptr
                mov 	ax,[si+4]
                mov 	loop_cnt,ax
                call 	next_block
                lds 	si,block_ptr
                mov 	WORD PTR loop_ptr,si
                mov 	WORD PTR loop_ptr+2,ds
                jmp 	__do_block

__end_loop:     cmp 	loop_cnt,0
                je 	__skip_block
                lds 	si,loop_ptr
                mov 	WORD PTR block_ptr,si
                mov 	WORD PTR block_ptr+2,ds
                cmp 	loop_cnt,0ffffh
                je 	__do_block
                dec 	loop_cnt
                jmp 	__do_block

__silence:
; We should implement a silence play back for timedelay and irq.
                jmp 	__skip_block

__cont_voice: 
		les	di,[ssp]
		mov	ax, current_rate
		mov	es:[di].um_sample_rate,ax
                lds 	si,block_ptr     ;continue output from new voice block
                mov 	ax,[si+1]
		mov	word ptr es:[di].um_sound_len, ax
                mov 	al,[si+3]
                mov 	ah,0
		mov	word ptr es:[di].um_sound_len+2, ax
                ADD_PTR 4,0,ds,si       ;DS:SI -> start-of-data
		mov	es:[di].um_sound_data_seg, ds
		mov	es:[di].um_sound_data_off, si
		mov	ax, 1
                jmp 	__exit

__new_voice:    lds 	si,block_ptr     ;initiate output from new voice block
		les	di,[ssp]
                mov 	bl,[si+4]
                mov 	al,[si+5]
                mov 	bh,0
                mov 	ah,0

                cmp 	xblk_status,0       ;previous extended block overrides
                je 	__use_vd            ;data block values
                mov 	al,xblk_pack
                mov 	bl,xblk_tc
                mov 	xblk_status,0

__use_vd:       mov 	pack_byte,ax
                mov 	packing,ax
                and 	packing,7fh
                and 	ax,80h
                mov 	cx,6
                shr 	ax,cl
                and 	ax,10b
		mov	al, UM_8BIT OR UM_INVERT_MSB
		jne	__stereo
		jmp	short __data_type
__stereo:	or	al, UM_STEREO
__data_type:	mov	es:[di].um_data_type, al
		mov	bh, 0		; convert sb code to sample rate
		mov	ax, 256
		xchg	ax, bx
		sub	bx,ax
		mov	dx,0fh
		mov	ax,4240h
		div	bx
                mov 	current_rate,ax
		mov	es:[di].um_sample_rate, ax

; Now play block...
                mov 	ax,[si+1]
                mov 	dl,[si+3]
                mov 	dh,0                
                sub 	ax,2                
                sbb 	dx,0            ;DX:AX = voice len
		mov	word ptr es:[di].um_sound_len,ax
		mov	word ptr es:[di].um_sound_len+2,dx
                ADD_PTR 6,0,ds,si       ;DS:SI -> start-of-data

		mov	ax, ds
		mov	es:[di].um_sound_data_seg, ax
		mov	es:[di].um_sound_data_off, si
		mov	ax, 1

__exit:         ret
                ENDP

;****************************************************************************
next_buffer     PROC                    ;Find a registered, unplayed buffer
                USES ds,si,di

                cmp buff_status[0*2],DAC_STOPPED
		je __b0_registered
                cmp buff_status[1*2],DAC_STOPPED
		je __b1_registered
                mov DAC_status,DAC_DONE ;else signal playback complete and
                mov ax,-1               ;return AX=-1
		jmp __return
__b0_registered:
                cmp buff_status[1*2],DAC_STOPPED
		je __both_registered
		mov ax, 0		; buffer 0 was registered
		jmp __return
__b1_registered:
		mov ax, 1		; buffer 1 (only) was registered
		jmp __return
__both_registered:
		mov ax, buff_time[0*2]
		cmp ax, buff_time[1*2]
		ja __b1_registered
		mov ax, 0

__return:       ret
                ENDP

;****************************************************************************
process_buffer  PROC C,Buf,ssp:FAR PTR  ;Play specified buffer
                USES 	ds,di

		les	di,[ssp]
                mov 	si,[Buf]            ;get buffer handle 
                shl 	si,1                ;derive index

                mov 	ax,buff_pack[si]
                mov 	pack_byte,ax
                mov 	packing,ax
                and 	packing,7fh
                and 	ax,80h
                mov 	cx,6
                shr 	ax,cl
                and 	ax,10b
		mov	al, UM_8BIT OR UM_INVERT_MSB
		jne	__stereo
		jmp	short __data_type
__stereo:	or	al, UM_STEREO
__data_type:	mov	es:[di].um_data_type, al
		mov	ax,buff_sample[si]
		mov	bx, 256
		sub	bx,ax
		mov	dx,0fh
		mov	ax,4240h
		div	bx
                mov 	current_rate,ax
		mov	es:[di].um_sample_rate, ax
		mov	dx,buff_len_h[si];
		mov	bx,buff_len_l[si];
		mov	word ptr es:[di].um_sound_len,bx
		mov	word ptr es:[di].um_sound_len+2,dx
		mov	bx,buff_data_s[si];
		mov	dx,buff_data_o[si];	
		mov	es:[di].um_sound_data_seg,bx
		mov	es:[di].um_sound_data_off,dx

__exit:         ret
                ENDP

;****************************************************************************
;*                                                                          *
;*  Public (API-accessible) procedures                                      *
;*                                                                          *
;****************************************************************************

describe_driver PROC H                  ;Return far ptr to DDT
                USES 	ds,si,di

                pushf
                cli

                mov 	dx,cs
                mov 	device_name_s,dx
                lea 	ax,DDT

                POP_F
                ret
                ENDP

;****************************************************************************
shutdown_driver PROC H,SignOff:FAR PTR
                USES 	ds,si,di

                pushf
                cli

                call 	stop_d_pb 

		mov	ax,TSR_FREE_MEMORY
		mov	dx,word ptr umss.um_gf1mem
		mov	bx,word ptr umss.um_gf1mem+2
		call	cs:gf1hook

		mov	ax,TSR_APP_END
		call	[cs:gf1hook]

__exit:         POP_F
                ret
                ENDP

;****************************************************************************
set_d_pb_pan    PROC H,Pan              ;Set digital playback panpot 0-127
                USES 	ds,si,di           

                pushf
                cli

		mov	ax, [Pan]
		mov	current_pan, ax
		mov	ax, 127
		sub	ax, [Pan]
		mov	cl,3
		shr	ax,cl
		mov	umss.um_pan, al
                cmp 	playing,0
		je	__ret
		mov	bx, ax
		mov	ax, TSR_SET_PAN
		mov	cx, playing
		dec	cx
		call	gf1hook

__ret:
                POP_F
                ret
                ENDP

;****************************************************************************
get_d_pb_pan    PROC H                  ;Get digital playback panpot 0-127
                USES 	ds,si,di           

                pushf
                cli

		mov	ax, current_pan

                POP_F
                ret
                ENDP

;****************************************************************************
set_d_pb_vol    PROC H,Vol              ;Set digital playback volume 0-127
                USES 	ds,si,di           ;(0=off; anything else=on)

                pushf
                cli

; gf1 volume is a 12-bit number.
                mov 	bx,[Vol]
		mov	current_volume,bx
		shl	bx,1
		mov	ax, gf1_volumes[bx]
                mov 	umss.um_volume,ax
                cmp 	playing,0
		je	__ret
		mov	bx, ax
		mov	ax, TSR_SET_VOLUME
		mov	cx, playing
		dec	cx
		call	gf1hook
__ret:
                POP_F
                ret
                ENDP

;****************************************************************************
get_d_pb_vol    PROC H                  ;Get digital playback volume 0-127        
                USES 	ds,si,di          

                pushf
                cli

                mov 	ax,current_volume

                POP_F
                ret
                ENDP

;****************************************************************************
detect_device   PROC H,IO_ADDR,IRQ,DMA,DRQ  ;Check for presence of supported
                USES 	ds,si,di               ;device


GF1_AIL_STR_SIZE	EQU		8
GF1_VECTORS		EQU		8
HOOK_STR_SIZE		EQU		7

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

		mov	ax,1
		jmp	ok_detect
gf1ail_not_found:
		pop	ds

		mov	ax,0h
ok_detect:
                ret
                ENDP

;****************************************************************************
init_driver     PROC H,IO_ADDR,IRQ,DMA,DRQ  
                USES 	ds,si,di

		mov	playing, 0
		mov	db_playing, -1
		mov	stop_voc_mode, 0
		mov	time, 0

		mov	umss.um_stereo_mem_seg, cs
		mov	umss.um_stereo_mem_off, OFFSET st_mem

		mov	umss.um_callback_addr_seg, cs
		mov	umss.um_callback_addr_off, OFFSET um_callback

		mov	umss.um_pan, 7
	        mov	umss.um_volume, 4095
		mov	current_volume, 127

                mov	loop_cnt,0
                mov	DAC_status,DAC_STOPPED
                mov	buffer_mode,BUF_MODE

                mov	buff_status[0*2],DAC_DONE
                mov	buff_status[1*2],DAC_DONE

		mov	ax,TSR_APP_START
		call	[cs:gf1hook]

		; allocate 8K of GF1 DRAM for double_buffering
		xor	bx,bx
		mov	dx,8*1024
		mov	ax,TSR_ALLOCATE_MEMORY
		call	cs:gf1hook
		mov	word ptr umss.um_gf1mem,ax
		mov	word ptr umss.um_gf1mem+2,dx
                or	ax,dx

                ret
                ENDP

;****************************************************************************
index_VOC_blk   PROC H,File:FAR PTR,Block,SBuf:FAR PTR
                USES 	ds,si,di
                LOCAL 	x_status,x_pack:BYTE,x_tc:BYTE

                pushf
                cli
                cld

                mov 	x_status,0

                lds 	si,[File]
                mov 	ax,[si+14h]     ;get offset of data block
                ADD_PTR ax,0,ds,si

                mov 	bx,[Block]

__get_type:     mov 	al,[si]         ;get block type
                mov 	ah,0
                cmp 	ax,0            ;terminator block?
                je 	__exit          ;yes, return AX=0 (block not found)

                cmp 	ax,8            ;extended voice data?
                jne 	__chk_voice     ;no

                mov 	al,[si+5]       ;get extended voice parameters
                mov 	x_tc,al         ;high byte of TC = normal sample rate
                mov 	ax,[si+6]       ;get pack (AL) and mode (AH)
                cmp 	ah,1            ;stereo?
                jne 	__set_pack
                or 	al,80h          ;yes, make pack byte negative
__set_pack:     mov 	x_pack,al
                mov 	x_status,1      ;flag extended block override
                jmp 	__next_blk

__chk_voice:    cmp 	ax,1            ;voice data block?
                jne 	__chk_marker    ;no

                cmp 	bx,-1           ;marker found (or disregarded)?
                je 	__vblk_found    ;yes, use this voice data block
                jmp 	__next_blk      ;no, keep looking

__chk_marker:   cmp 	ax,4            ;marker block?
                jne 	__next_blk      ;no, keep looking

                cmp 	bx,[si+4]       ;yes, compare marker numbers
                jne 	__next_blk

                mov 	bx,-1           ;marker found, use next voice block

__next_blk:     inc 	si
                lodsw
                mov 	dl,[si]
                mov 	dh,0            ;blk len: AL=LSB, AH=KSB, DL=MSB, DH=0
                inc 	si

                ADD_PTR ax,dx,ds,si     ;point to next block
                jmp 	__get_type

__vblk_found:   les	di,[SBuf]  	    ;get pointer to output structure

                mov 	bl,[si+4]       ;copy sampling rate
                mov 	al,[si+5]       ;copy packing type
                mov 	bh,0
                mov 	ah,0

                cmp 	x_status,0      ;previous extended block overrides
                je 	__use_vd        ;data block values
                mov 	al,x_pack
                mov 	bl,x_tc
                mov 	x_status,0

__use_vd:       mov 	es:[di].sample_rate,bx
                mov 	es:[di].pack_type,ax

                mov 	ax,[si+1]           ;copy voice data length
                mov 	dl,[si+3]
                mov 	dh,0
                sub 	ax,2
                sbb 	dx,0
                mov 	es:[di].len_l,ax
                mov 	es:[di].len_h,dx

                mov 	dx,ds               ;copy pointer to voice data
                mov 	ax,si
                ADD_PTR 6,0,dx,ax       
                mov 	WORD PTR es:[di].data,ax
                mov 	WORD PTR es:[di].data+2,dx

                mov 	ax,1

__exit:         POP_F
                ret
                ENDP

;****************************************************************************
register_sb     PROC H,BufNum,SBuf:FAR PTR
                USES 	ds,si,di

                pushf
                cli

                cmp 	buffer_mode,VOC_MODE        
                jne 	__get_bufnum        ;not in VOC mode, proceed
                call 	stop_d_pb           ;else stop VOC file output first
                mov 	buffer_mode,BUF_MODE

__get_bufnum:   mov 	di,[BufNum]         ;get buffer #0-1
                shl 	di,1

                lds 	si,[SBuf]           ;copy structure data to buffer 
                mov 	ax,[si].pack_type   ;descriptor fields
                mov 	buff_pack[di],ax
                mov 	ax,[si].sample_rate
                mov 	buff_sample[di],ax

                les 	bx,[si].data
                mov 	buff_data_o[di],bx
                mov 	buff_data_s[di],es

                mov 	ax,[si].len_l
                mov 	buff_len_l[di],ax
                mov 	ax,[si].len_h
                mov 	buff_len_h[di],ax
	
		mov	ax,time		   ; need to know order in which
		inc	time		   ; buffers were registered so that
		mov	buff_time[di],ax   ; playback happens in correct order
                
                mov 	buff_status[di],DAC_STOPPED

__exit:         POP_F                  
                ret
                ENDP

;****************************************************************************
get_sb_status   PROC H,HBuffer
                USES 	ds,si,di

                pushf
                cli

	        mov 	bx,[HBuffer]         ;get buffer #0-1
                shl 	bx,1
                mov	ax,buff_status[bx]
; the applcation doesn't understand DAC_BUFF_REGISTERED, it uses DAC_STOPPED.
; Sound-blaster style devices don't do real double buffering, and didn't need
; this extra info
		cmp	ax, DAC_BUFF_REGISTERED
		jne	__exit
		mov	ax, DAC_STOPPED

__exit: 	POP_F
                ret
                ENDP

;****************************************************************************
play_VOC_file   PROC H,File:FAR PTR,Block
                LOCAL block_file:DWORD
                USES 	ds,si,di

                pushf
                cli

                mov 	xblk_status,0

                call 	stop_d_pb      ;assert VOC mode
                mov 	buffer_mode,VOC_MODE

                les 	di,[File]
                mov 	WORD PTR block_file,di
                mov 	WORD PTR block_file+2,es

                mov 	DAC_status,DAC_DONE 
                      
                lds 	si,block_file
                mov 	ax,[si+14h]         ;get offset of data block
                ADD_PTR ax,0,ds,si
                mov 	WORD PTR block_ptr,si
                mov 	WORD PTR block_ptr+2,ds

                cmp 	[Block],-1    ;play 1st block if no marker specified
                je 	__do_it

__find_blk:
	        call 	block_type 

                cmp 	ax,0                ;terminator block?
                je 	__exit               ;yes, exit (block not found)
                call 	set_xblk
                call 	marker_num         ;get marker # (or -1 if non-marker)
                mov 	si,ax
                call	next_block
                cmp 	si,[Block]
                jne 	__find_blk

__do_it:        mov 	DAC_status,DAC_STOPPED         
                ;return w/block_ptr -> 1st file block
__exit:         POP_F                       
                ret

                ENDP

;****************************************************************************
start_d_pb      PROC H
                USES 	ds,es,si,di

                pushf
                cli

                cmp 	playing, 0
                jne 	__exit               ;bail out if already playing

                cmp 	buffer_mode,VOC_MODE
                je 	__voc_mode    ;start Creative Voice File playback

		call	next_buffer	     ;start dual-buffer playback
                cmp 	ax,-1
                je 	__exit               ;no buffers registered, exit
                mov 	DAC_status,DAC_PLAYING
		mov	si, ax
		call	process_buffer C,ax,OFFSET umss,cs
		mov	db_playing, si	     ;mark which buffer is playing
		shl	si,1
                mov 	buff_status[si],DAC_PLAYING
__start_pb:	mov	ax, cs
		mov	es, ax
		mov	di, OFFSET umss
		mov	ax, TSR_START_DIGITAL
		call	gf1hook
		add	ax,1
		mov	playing, ax
		jnz	__exit
; something went wrong.
		mov	DAC_status, DAC_STOPPED
		mov	playing, 0
                jmp 	__exit

__voc_mode:
		mov	stop_voc_mode, 0
                mov 	DAC_status,DAC_PLAYING
                call	process_block C, OFFSET umss, cs
		jmp	__start_pb

__exit:         POP_F
                ret
                ENDP

;****************************************************************************
stop_d_pb       PROC H
                USES 	ds,si,di

                pushf
                cli

                cmp 	playing,0
                jne 	__stop_DMA          ;if in .VOC mode and no longer
		jmp	__stopped

__stop_DMA:	mov	cx,playing
		dec	cx
		mov	ax,TSR_STOP_DIGITAL
		call	gf1hook
__stopped: 	mov 	DAC_status,DAC_STOPPED
                mov 	buff_status[0*2],DAC_DONE
                mov 	buff_status[1*2],DAC_DONE

                POP_F
                ret
                ENDP

;****************************************************************************
pause_d_pb      PROC H
                USES 	ds,si,di

                pushf
                cli

		mov	ax,TSR_PAUSE_DIGITAL
		mov	cx,umss.um_voice
		call    cs:gf1hook

                mov 	DAC_status,DAC_PAUSED

__exit:         POP_F
                ret
                ENDP

;****************************************************************************
cont_d_pb       PROC H
                USES 	ds,si,di

                pushf
                cli

                cmp 	DAC_status,DAC_PAUSED

		mov	ax,TSR_RESTART_DIGITAL
		mov	cx,umss.um_voice
		call    cs:gf1hook

__exit:         POP_F
                ret
                ENDP

;****************************************************************************
get_VOC_status  PROC H
                USES 	ds,si,di

                pushf
                cli

                mov 	ax,DAC_status

                POP_F
                ret
                ENDP

;****************************************************************************
          	END
