@echo off

if "%~1"=="" (
    echo Missing section
    echo Usage: build_exercise section exercise
    exit /b 1
)
if "%~2"=="" (
    echo Missing exercise number
    echo Usage: build_exercise section exercise
    exit /b 1
)

set "section=%1"
set "exercise=%2"

odin build exercises\%section%\ex%exercise%.odin -file^
	-out:.bin\%section%_ex%exercise%.exe^
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

	-define:OPENGL_LEARN_EXERCISES=true
	
if %ERRORLEVEL% equ 0 (
	.bin\%section%_ex%exercise%.exe
) else (
	exit 1
)
