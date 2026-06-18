@echo off
setlocal EnableDelayedExpansion

set command="%~1"

if %command%=="" (
	set input=src
	set executable=learn_opengl.exe
)
if %command%=="ex" (
	set "usage=build.bat exercise <section> <num>"
	if "%~2"=="" (
		echo Missing section
		echo Usage: !usage!
		exit 1
	)

	if "%~3"=="" (
		echo Missing exercise number
		echo Usage: !usage!
		exit 1
	)

	set exercise_name=%~2_ex%~3
	set input=exercises\!exercise_name!.odin -file
	set executable=!exercise_name!.exe
	set defines=^
		-define:OPENGL_EXERCISES_MODE=true
)

set main_flags=^
	-out:.bin\%executable%^
	-o:minimal^
	-linker:radlink^
	-microarch:native^
	-debug

set warnings=^
	-vet^
	-vet-semicolon^
	-vet-style^
	-vet-tabs^
	-warnings-as-errors

set collections=^
	-collection:lib=src\lib^
	-collection:extern=extern

set final_command=odin build %input% %main_flags% %warnings% %collections% %defines%

echo Running: %final_command%
%final_command%

if %ERRORLEVEL% equ 0 (
	.bin\%executable%
) else (
	exit 1
)
