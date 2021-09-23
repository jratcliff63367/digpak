# Builds all of the digpak drivers from SHELL.ASM BUT does not build the
# orphan drivers.  Run ORPHAN.MAK to build the orphan sound drivers that
# neither me nor you, or nearly anyone for that matter, cares about.

pas16.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=15 /dPAS16=1 shell,pas16
		tlink /v pas16
		tdstrip -s pas16
		exe2bin pas16.exe pas16.com
		erase pas16.exe


paudio.com:	 shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=15 shell,paudio
		tlink /v paudio
		tdstrip -s paudio
		exe2bin paudio.exe paudio.com
		erase paudio.exe

adlibg.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=18 shell,adlibg
		tlink /v adlibg
		tdstrip -s adlibg
		exe2bin adlibg.exe adlibg.com
		erase adlibg.exe


aria.com:         shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=20 shell,aria
		tlink /v aria
		tdstrip -s aria
		exe2bin aria.exe aria.com
		erase aria.exe


sblaster.com:	shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=9 shell,sblaster
		tlink /v sblaster
		tdstrip -s sblaster
		exe2bin sblaster.exe sblaster.com
		erase sblaster.exe

nosound.com:	shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=2 /dNOSOUND=1 shell,nosound
		tlink /v nosound
		tdstrip -s nosound
		exe2bin nosound.exe nosound.com
		erase nosound.exe


sbclone.com:	shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=9 /dSBCLONE=1 shell,sbclone
		tlink /v sbclone
		tdstrip -s sbclone
		exe2bin sbclone.exe sbclone.com
		erase sbclone.exe

# Uses the Tandy ROM BIOS calls for digital audio available on the
# SL/TL line of Tandy machines.

tansltl.com:	  shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=8 shell,tansltl
		tlink /v tansltl
		tdstrip -s tansltl
		exe2bin tansltl.exe tansltl.com
		erase tansltl.exe

lsize.com:	shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=2 /dLIFESIZE=1 shell,lsize
		tlink /v lsize
		tdstrip -s lsize
		exe2bin lsize.exe lsize.com
		erase lsize.exe

sbpro.com:	shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=9 /dSBPRO=1 shell,sbpro
		tlink /v sbpro
		tdstrip -s sbpro
		exe2bin sbpro.exe sbpro.com
		erase sbpro.exe



cvxsnd.com:	 shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=2 shell,cvxsnd
		tlink /v cvxsnd
		tdstrip -s cvxsnd
		exe2bin cvxsnd.exe cvxsnd.com
		erase cvxsnd.exe

source.com:	 shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=10 shell,source
		tlink /v source
		tdstrip -s source
		exe2bin source.exe source.com
		erase source.exe

STFX.com:	shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=9 /dSTFX=1 shell,STFX
		tlink /v STFX
		tdstrip -s STFX
		exe2bin STFX.exe STFX.com
		erase STFX.exe

