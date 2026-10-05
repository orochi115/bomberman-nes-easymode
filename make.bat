@ECHO OFF
REM Usage: make.bat [us|jp]   (default: us)
SET DEF=
SET OUT=BOMBER
SET CHR=BOMBER.CHR
IF /I "%1"=="jp" (
    SET DEF=-DREGION_JP
    SET OUT=BOMBER_JP
    SET CHR=BOMBER_JP.CHR
)
DEL %OUT%.NES 2>NUL
DEL %OUT%*.prg 2>NUL
python breakasm.py %DEF% BMAN.NAS %OUT%.PRG > out.txt
IF %ERRORLEVEL% NEQ 0 (
    TYPE out.txt
    EXIT /B 1
)
python split.py %OUT%.PRG
COPY /B NES_Header.bin + %OUT%003.PRG + %CHR% /B %OUT%.NES
python crc32.py %OUT%003.PRG
python crc32.py %CHR%
