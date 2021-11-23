TARGET : sblaster.com sbpro.com

sblaster.com:	creative.asm soundrv.inc
		tasm -zi /m5	/x /dBUILD=9 /dSBLASTER=1 creative,sblaster
		tlink /x sblaster
		tdstrip -s sblaster
		exe2bin sblaster.exe sblaster.com
		erase sblaster.exe
		erase sblaster.obj

sbpro.com:	creative.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=9 /dSBPRO=1 creative,sbpro
		tlink /x sbpro
		tdstrip -s sbpro
		exe2bin sbpro.exe sbpro.com
		erase sbpro.exe
		erase sbpro.obj

sb16.com:      creative.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=9 /dsb16=1 creative,sb16
		tlink /x sb16
		tdstrip -s sb16
		exe2bin sb16.exe sb16.com
		erase sb16.exe
		erase sb16.obj

