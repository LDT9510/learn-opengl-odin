@echo off
setlocal EnableDelayedExpansion

rem NOTE: executables in "output_dir" are not portable
 
set project_name=learn_opengl

set command="%~1"
set output_dir=.bin
set input=src
set executable=%project_name%_dev.exe

set vettable_packages=%project_name%,glc,devui,app

set warnings_flags=^
	-vet^
	-vet-packages:%vettable_packages%^
	-vet-semicolon^
	-vet-style^
	-vet-tabs^
	-warnings-as-errors^
	-strict-style

set collections_flags=^
	-collection:extern=extern^
	-collection:main=src

set opt_flags=^
	-linker:radlink^
	-microarch:native

set defines_flags=^
	-define:CONTENT_ROOT="../"

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
	set executable=%project_name%_debug.exe
	set is_command_known=yes
	set is_debug=yes
	set opt_flags=^
		-debug

	if "%~2"=="attach" (
		set attach_debugger=yes
	)
)
if %command%=="release" (
	set executable=%project_name%.exe
	set is_command_known=yes

	if "%~2"=="" (
		set opt_flags=^
			-o:speed
	)
	if "%~2"=="size" (
		set executable=%project_name%_min.exe
		set opt_flags=^
			-o:size
	)
	set extra_flags=^
		-subsystem:windows^
		-disable-assert^
		-no-type-assert
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
		if "%~5"=="attach" (
			set attach_debugger=yes
		)
	)

	set exercise_section_dir=%~dp0exercises\%~2
	set output_dir=.bin\exercises
	set input=!exercise_section_dir!\ex%~3.odin -file
	set executable=%~2_ex%~3.exe
	set defines_flags=^
		-define:OPENGL_EXERCISES_PATH=!exercise_section_dir!\^
		-define:OPENGL_ROOT_CONTENT_PATH=%~dp0
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

	if not exist %output_dir%\exercises md %output_dir%\exercises

	echo Building all exercices
	for /d /r "exercises\" %%D in (*) do (
		for %%F in ("%%D\*.odin") do (
			set exercise_file=exercises\%%~nD\%%~xnF
			if exist !exercise_file! (
				set output=%output_dir%\exercises\%%~nD_%%~nF.exe
				set ex_build_flags=^
					%collections_flags%^
					%warnings_flags%^
					%opt_flags%^
					%extra_flags%^
					-define:OPENGL_EXERCISES_PATH=%~dp0exercises\%%~nD\^
					-define:OPENGL_ROOT_CONTENT_PATH=%~dp0
				start /b "" cmd /c "echo Building !output! &&  odin build !exercise_file! -file -out:!output! !ex_build_flags!"
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
%final_build_command%

if %ERRORLEVEL%==0 (
	cd %output_dir%
	if %is_debug%==no (
		echo Running A: %executable% on %output_dir%
		.\%executable%
	)
	if %is_debug%==yes (
		if %attach_debugger%==yes (
			set misc_dir=%output_dir%/../misc
			if not exist !misc_dir! md !misc_dir!
			echo Running: raddbg %executable% on %CD%
			raddbg %executable% --project:!misc_dir!/project.raddbg
		)
		if %attach_debugger%==no (
			echo Running: %executable% on %CD%
			.\%executable%
		)
	)
)

exit /b %ERRORLEVEL%
