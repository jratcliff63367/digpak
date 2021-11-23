
vector.com:    vector.asm
	       tasm -zi /m5  /x /dBUILD=2 /dvector=1 vector,vector
	       tlink /v vector
	       tdstrip -s vector
	       exe2bin vector.exe vector.com
	       erase vector.exe

