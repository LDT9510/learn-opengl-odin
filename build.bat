@echo off

odin build src^
	-out:.bin\learn_opengl.exe^
	-o:minimal^
	-linker:radlink^

	-vet^
	-vet-semicolon^
	-vet-style^
	-vet-tabs^
	-warnings-as-errors

.bin\learn_opengl.exe
