
digauto.com:	auto.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=2 /ddigauto=1 auto,digauto
		tlink /t digauto
#		 tlink /v digauto
#		 tdstrip -s digauto
#		 exe2bin digauto.exe digauto.com
#		 erase digauto.exe

