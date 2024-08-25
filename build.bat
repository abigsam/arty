@ECHO OFF
CLS
ECHO.
ECHO #########################################################
ECHO # Build Vivado project for Arty A7 32T
ECHO # Part: XC7A35TICSG324-1L
ECHO # Author: abigsam@gmail.com
ECHO # Vivado version: 2023.1
ECHO #########################################################
set vivado_path=C:\Xilinx\Vivado\2023.1
set build_type="create_empty_bd"
set board_name="arty_a7_35t"
set project_folder_name=%board_name:"=%_bd
ECHO.
ECHO Avaliable options:
ECHO [1] Build Empty block design project
ECHO [2] Build Microblaze block design project
ECHO [3] Build RTL project
ECHO [4] Cleanup Git repository
ECHO [5] Exit
ECHO.

CHOICE /C 12345 /N /M "Enter your choice:"
IF ERRORLEVEL 5 GOTO END
IF ERRORLEVEL 4 GOTO RUN_CLEANUP_PRJ
IF ERRORLEVEL 3 GOTO RUN_BUILD_RTL
IF ERRORLEVEL 2 GOTO RUN_BUILD_MICROBLAZE_BD
IF ERRORLEVEL 1 GOTO RUN_BUILD_EMPTY_BD

:RUN_CLEANUP_PRJ
ECHO Cleanup project folder...
rmdir /s /q "%~dp0\vivado_bd"
rmdir /s /q "%~dp0\vivado_rtl"
del "%~dp0\*.log"

:RUN_CLEANUP
ECHO Cleanup Vivado files...
del "%~dp0\*.jou"
del "%~dp0\*.dmp"
rmdir /s /q "%~dp0\.Xil"
goto END

:RUN_BUILD_RTL
set build_type="create_rtl"
set project_folder_name=%board_name:"=%_rtl
goto BUILD

:RUN_BUILD_EMPTY_BD
set build_type="create_empty_bd"
set project_folder_name=%board_name:"=%_bd
goto BUILD

:RUN_BUILD_MICROBLAZE_BD
set build_type="create_microblaze_bd"
set project_folder_name=%board_name:"=%_bd_microblaze
goto BUILD

:BUILD
rem Run Vivado batch file with Tcl build script
rem Tcl script has two arguments:
rem - run Vivado GUI
rem - use derictive "exit" at Tcl script
rem After this, batch file changes run directory to the vivado project ("vivado/" by default) and call for Vivado with GUI
ECHO Run Tcl build script...
CALL :RUN_VIVADO_SCRIPT "%~dp0\scripts\build.tcl" %board_name% %build_type% %project_folder_name%
CALL :OPEN_VIVADO_PROJECT %project_folder_name% %board_name%
goto RUN_CLEANUP

:END
rem pause


:RUN_VIVADO_SCRIPT
    set vivado_bat_path=%vivado_path%\bin\vivado.bat
    if not exist %vivado_bat_path% (
        echo ERROR! Path %vivado_bat_path% did not found
        pause
        exit
    )
    if not exist %~1 (
        echo ERROR! Script file %~1 did not found
        pause
        exit
    )
    
    rem Cleanup old logs
    del "%~dp0\*.jou"
    del "%~dp0\*.log"
    
    call %vivado_bat_path% -mode batch -nojournal -notrace -source %~1 -tclargs %~2 %~3 %~4 %~5

    if %errorlevel% equ 0 (
        echo Vivado executed script without errors
    ) else (
        echo Vivado return error: %ERRORLEVEL%
        pause
        exit
    )

EXIT /B 0


:OPEN_VIVADO_PROJECT
    if "%~2"=="" (
        set xpr_name=%~1.xpr
    ) else (
        set xpr_name=%~2.xpr
    )
    set prj_path=%~dp0\%~1\%xpr_name%
    set vivado_bat_path=%vivado_path%\bin\vivado.bat
    set vivado_vvgl_path=%vivado_path%\bin\unwrapped\win64.o\vvgl.exe
    if not exist %vivado_bat_path% (
        echo ERROR! Path %vivado_bat_path% did not found
        pause
        exit
    )
    if not exist %prj_path% (
        echo ERROR! Vivado project file %prj_path% did not found
        pause
        exit
    )
    pushd "%~dp0\%~1"
    call %vivado_vvgl_path% %vivado_bat_path% -project %prj_path%
    popd
EXIT /B 0