    @echo off

    if NOT (%1)==() goto runit
    c:\misc\sice\262\msym digvesa.map
    c:\misc\sice\262\ldr  digvesa.sym
    c:\misc\sice\262\ldr  digvesa.com
    goto exit

:runit
    c:\misc\sice\262\msym %1.map
    c:\misc\sice\262\ldr  %1.sym
    c:\misc\sice\262\ldr  %1.exe %2 %3 %4 %5 %6 %7 %8 %9

:exit
