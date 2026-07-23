@echo off
setlocal EnableDelayedExpansion

set command="%~1"

set output_dir=.bin
set input=src
set executable=learn_opengl_dev.exe

set warnings_flags=^
	-vet^
	-vet-semicolon^
	-vet-style^
	-vet-tabs^
	-warnings-as-errors^
	-strict-style

set collections_flags=^
	-collection:lib=src\lib^
	-collection:extern=extern

set opt_flags=^
	-linker:radlink^
	-microarch:native

set is_command_known=no
set build_all=no
set is_debug=no
set attach_debugger=no

if %command%=="" (
	set is_command_known=yes
)
if %command%=="build-all" (
	set is_command_known=yes
	set build_all=yes
)
if %command%=="format" (
	set is_command_known=yes
	odinfmt src -w
	odinfmt exercises -w
	exit /b 0
)
if %command%=="debug" (
	set executable=learn_opengl_debug.exe
	set is_command_known=yes
	set is_debug=yes
	set opt_flags=^
		-debug

	if "%~2"=="attach" (
		set attach_debugger=yes
	)
)
if %command%=="release" (
	set executable=learn_opengl.exe
	set is_command_known=yes
	set opt_flags=^
		-o:speed
	set extra_flags=^
		-subsystem:windows
)
if %command%=="release-size" (
	set executable=learn_opengl_min.exe
	set is_command_known=yes
	set opt_flags=^
		-o:size
	set extra_flags=^
		-subsystem:windows
)
if %command%=="ex" (
	set is_command_known=yes
	set "usage=build.bat exercise <section> <num>"
	if "%~2"=="" (
		echo Missing section
		echo Usage: !usage!
		exit /b 1
	)


	if "%~3"=="" (
		echo Missing exercise number
		echo Usage: !usage!
		exit /b 1
	)

	if "%~4"=="debug" (
		set is_debug=yes
		set opt_flags=^
			-debug
	)

	set exercise_section_dir=exercises\%~2
	set output_dir=.bin\exercises
	set input=!exercise_section_dir!\ex%~3.odin -file
	set executable=%~2_ex%~3.exe
	set defines_flags=^
		-define:OPENGL_EXERCISES_PATH=!exercise_section_dir!\
)

if %is_command_known%==no (
	echo Unknown command %command%
	exit /b 1
)

set build_flags=^
	%collections_flags%^
	%warnings_flags%^
	%opt_flags%^
	%extra_flags%^
	%defines_flags%

set final_build_command=odin build %input% -out:%output_dir%\%executable% %build_flags%

if not exist %output_dir% md %output_dir%

if %build_all%==yes (
	echo Building main program
	%final_build_command%
	
	echo Building all exercices
	for /d /r "exercises\" %%D in (*) do (
		for %%F in ("%%D\*.odin") do (
			set exercise_file=exercises\%%~nD\%%~xnF
			if exist !exercise_file! (
				set output=%output_dir%\exercises\%%~nD_%%~nF.exe
				set defines_flags=^
					-define:OPENGL_EXERCISES_PATH=exercises\%%~nD\
				start /b "" cmd /c "echo Building !output! && odin build !exercise_file! -file -out:!output! %build_flags%" %defines_flags%
			)
		)
	)

	:wait_loop
	tasklist | find /i "odin.exe" >nul
	if %errorlevel% equ 0 (
		rem wait for 1 second
		ping -n 1 127.0.0.1 >nul
		goto wait_loop
	)

	exit /b 0
)

echo Running: %final_build_command%

if %is_debug%==no (
	%final_build_command% && %output_dir%\%executable%
)
if %is_debug%==yes (
	if %attach_debugger%==yes (
		%final_build_command% && raddbg %output_dir%\%executable% --project:./misc/project.raddbg
	)
	if %attach_debugger%==no (
		%final_build_command% && %output_dir%\%executable%
	)
)
