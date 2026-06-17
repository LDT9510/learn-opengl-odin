@echo off

odin build src^
	-out:.bin\learn_opengl.exe^
	-o:minimal^
	-linker:radlink^
	-microarch:native^
	-debug^

	-collection:lib=src\lib^
	-collection:extern=extern^

	-vet^
	-vet-semicolon^
	-vet-style^
	-vet-tabs^
	-warnings-as-errors^
	
if %ERRORLEVEL% equ 0 (
	.bin\learn_opengl.exe
) else (
	exit 1
)
