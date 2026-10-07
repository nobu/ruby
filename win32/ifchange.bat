@echo off
:: usage: ifchange target temporary

@setlocal EnableExtensions DisableDelayedExpansion || exit /b -1

:: @set PROMPT=$T:$S
for %%I in (%0) do set progname=%%~nI
set timestamp=
set keepsuffix=
set empty=
set color=auto
set quiet=
:optloop
set optarg=
:optnext
for %%I in (%1) do set opt=%%~I
    if not "%opt:~0,2%" == "--" (
        if not "%optarg%" == "" (
            call set %optarg%=%%opt%%
            shift
            goto :optloop
        )
        goto :optend
    )
    if "%opt%" == "--" (
        shift
        goto :optend
    )
    if "%opt%" == "--timestamp" (
        set timestamp=.
        set optarg=timestamp
        shift
        goto :optnext
    )
    if "%opt:~0,12%" == "--timestamp=" (
        set timestamp=%opt:~12%
        shift
        goto :optloop
    )
    if "%opt%" == "--keep" (
        set keepsuffix=.old
        set optarg=keep
        shift
        goto :optnext
    )
    if "%opt:~0,7%" == "--keep=" (
        set keepsuffix=%opt:~7%
        shift
        goto :optloop
    )
    if "%opt%" == "--empty" (
        set empty=yes
        shift
        goto :optloop
    )
    if "%opt%" == "--color" (
        set color=always
        set optarg=color
        shift
        goto :optnext
    )
    if "%opt:~0,8%" == "--color=" (
        set color=%opt:~8%
        shift
        goto :optloop
    )
    if "%opt%" == "--quiet" (
        set quiet=true
        shift
        goto :optloop
    )
    if "%opt%" == "--debug" (
        shift
        set "PROMPT=$e[34m+$e[m"
        echo on
        goto :optloop
    )
    if "%opt%" == "--help" (
        call :help
        exit /b
    )
    echo %progname%: unknown option: %1 1>&2
    exit /b 1
:optend

if "%2" == "" (
    call :help 1>&2
    exit /b 1
)

set "dest=%1"
set "src=%2"
set "dest=%dest:/=\%"
set "src=%src:/=\%"

if "%color%" == "always" (
    set "color=yes"
) else if "%color%" == "never" (
    set "color=no"
) else if not "%color%" == "auto" (
    echo "unknown --color option: %color%" 1>&2
    exit /b 1
)
if not "%quiet%" == "" set "color=no"
if not "%NO_COLOR%" == "" set "color=no"

if "%color%" == "auto" (
    powershell -NoProfile -Command "exit [Console]::IsOutputRedirected"
    if errorlevel 1 (set "color=no") else (set "color=yes")
)

set msg_begin=
set msg_unchanged=
set msg_updated=
set msg_reset=
if "%color%" == "no" goto :no_color
    set "msg_begin=["
    set "msg_unchanged=%msg_begin%32m"
    set "msg_updated=%msg_begin%31;1m"
    set "msg_reset=%msg_begin%m"
:no_color

if not "%src%" == "-" goto :srcfile
    if not "%TMPDIR%" == "" (
        set src=%TMPDIR%\ifchange%RANDOM%.tmp
    ) else if not "%TEMP%" == "" (
        set src=%TEMP%\ifchange%RANDOM%.tmp
    ) else if not "%TMP%" == "" (
        set src=%TMP%\ifchange%RANDOM%.tmp
    ) else (
        set src=.\ifchange%RANDOM%.tmp
    )
    set src=%src:/=\%
    findstr -r -c:"^" > "%src%"
:srcfile

if exist %dest% (
    if not exist %src% goto :nt_unchanged1
    if not "%empty%" == "" for %%I in (%src%) do if %%~zI == 0 goto :nt_unchanged
    fc.exe %dest% %src% > nul && (
      :nt_unchanged
	del %src%
      :nt_unchanged1
	if "%quiet%" == "" for %%I in (%1) do echo %%~I %msg_unchanged%unchanged%msg_reset%
	goto :nt_end
    )
)
if "%quiet%" == "" for %%I in (%1) do echo %%~I %msg_updated%updated%msg_reset%
del /f %dest% 2> nul
copy %src% %dest% > nul || (
    echo %progname%: failed to copy %src% to %dest% 1>&2
    del %src%
    exit /b 1
)
del %src%

:nt_end
if "%timestamp%" == "" goto :end
    if "%timestamp%" == "." (
        for %%I in ("%dest%") do set timestamp=%%~dpI.time.%%~nxI
    )
    goto :end > "%timestamp%"

:help
    for %%I in (
        "usage: %progname% [options] target new-file"
        "options:"
        "   --timestamp[=file] touch timestamp file. (default: prefixed with '.time')"
        "                      under the directory of the target)"
        "   --keep[=suffix]    keep old file with suffix. (default: '.old')"
        "   --empty            assume unchanged if the new file is empty."
        "   --color[=always|auto|never] colorize output."
        "   --quiet            suppress result"
    ) do echo.%%~I
    goto :eof

:end
