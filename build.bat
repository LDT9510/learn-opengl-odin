@echo off

odin build src^
	-out:.bin\learn_opengl.exe^
	-o:minimal^
	-linker:radlink^
	-microarch:native^
	-debug^

	-vet^
	-vet-semicolon^
	-vet-style^
	-vet-tabs^
	-warnings-as-errors^
	
if %ERRORLEVEL% equ 0 (
	.bin\learn_opengl.exe
)
