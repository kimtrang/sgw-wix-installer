@echo off
::
::    run by Jenkins Windows build jobs:
::
::        sync_gateway_windows_builds
::
::    with required paramters:
::
::          branch_name   git_commit  version  build_number  Edition  platform
::
::    This script only supports branches 1.2.0 and older
::
::    e.g.: master         123456   0.0.0 0000   community    windows-x64
::          release/1.0.0  123456   1.1.0 1234   enterprise   windows-x64
::
set THIS_SCRIPT=%0

set  REL_VER=%1
if "%REL_VER%" == "" call :usage 22

set  BLD_NUM=%2
if "%BLD_NUM%" == "" call :usage 33

set  EDITION=%3
if "%EDITION%" == "" call :usage 44

set  PLATFRM=%4
if "%PLATFRM%" == "" call :usage 55

:: Sample TEST_OPTIONS "-cpu 4 -race"
set  TEST_OPTIONS=%5
set  REPO_SHA=%6
set  GO_RELEASE=%7

if not defined GO_RELEASE (
    set GO_RELEASE=1.5.3
)

set VERSION=%REL_VER%-%BLD_NUM%
set LATESTBUILDS_SGW="http://latestbuilds.hq.couchbase.com/couchbase-sync-gateway/0.0.1/%REL_VER%/%VERSION%"
if "%REL_VER%" == "0.0.0" set LATESTBUILDS_SGW="http://latestbuilds.hq.couchbase.com/couchbase-sync-gateway/%REL_VER%/%VERSION%"
if "%REL_VER%" GEQ "1.3.0" set LATESTBUILDS_SGW="http://latestbuilds.hq.couchbase.com/couchbase-sync-gateway/%REL_VER%/%VERSION%"

for /f "tokens=1-2 delims=-" %%A in ("%PLATFRM%") do (
    set OS=%%A
    set PROC_ARCH=%%B
)

set "SG_PRODUCT_NAME=Couchbase Sync Gateway"
set "ACCEL_PRODUCT_NAME=Couchbase SG Accel"

set GOOS=%OS%
set SGW_EXEC=sync_gateway.exe
set SGW_NAME=sync-gateway
set ACCEL_EXEC=sg_accel.exe
set ACCEL_NAME=sg-accel
set COLLECTINFO_NAME=sgcollect_info

if "%PROC_ARCH%" == "x64" (
    set ARCH=amd64
    set PARCH=x86_64
    set GOARCH=amd64
    set GOHOSTARCH=%GOARCH%
)
if "%PROC_ARCH%" == "x86" (
    set ARCH=x86
    set PARCH=x86
    set GOARCH=386
    set GOHOSTARCH=%GOARCH%
)

set ARCHP=%ARCH%

set GOPLAT=%GOOS%-%GOARCH%
set PLATFORM=%OS%-%ARCH%

set PKGR=package-win.rb
set PKGTYPE=exe

set PKG_NAME=setup_couchbase-sync-gateway_%VERSION%_%ARCHP%.%PKGTYPE%
set NEW_PKG_NAME=couchbase-sync-gateway-%EDITION%_%VERSION%_%PARCH%.%PKGTYPE%

set ACCEL_PKG_NAME=setup_couchbase-sg-accel_%VERSION%_%ARCHP%.%PKGTYPE%
set ACCEL_NEW_PKG_NAME=couchbase-sg-accel-%EDITION%_%VERSION%_%PARCH%.%PKGTYPE%

set GOROOT=c:\usr\local\go\%GO_RELEASE%\go
set PATH=%PATH%;%GOROOT%\bin\

set
echo ============================================== %DATE%

:: package-win is tightly coupled to Jenkins workspace.
:: Changes needed to support concurrent builds later
set TARGET_DIR=%WORKSPACE%
set BIN_DIR=%TARGET_DIR%\godeps\bin
set LIC_DIR=%TARGET_DIR%\cbbuild\license\sync_gateway

if NOT EXIST %TARGET_DIR% (
    echo FATAL: Missing source...
    exit
)
cd %TARGET_DIR%

set SRC_DIR=godeps\src\github.com\couchbase\sync_gateway
set SGW_DIR=%TARGET_DIR%\%SRC_DIR%
set BLD_DIR=%SGW_DIR%\build

set PREFIX=\opt\couchbase-sync-gateway
set PREFIXP=.\opt\couchbase-sync-gateway
set STAGING=%BLD_DIR%\opt\couchbase-sync-gateway
set SGW_INSTALL_DIR=%TARGET_DIR%\sgw_install
set SGWACCEL_INSTALL_DIR=%TARGET_DIR%\sgw_accel_install

if EXIST %PREFIX%  del /s/f/q %PREFIX%
if EXIST %STAGING% del /s/f/q %STAGING%

echo ======== sync sync_gateway ===================

if NOT EXIST %STAGING%           mkdir %STAGING%
if NOT EXIST %STAGING%\bin       mkdir %STAGING%\bin
if NOT EXIST %STAGING%\tools     mkdir %STAGING%\tools
if NOT EXIST %STAGING%\examples  mkdir %STAGING%\examples
if NOT EXIST %STAGING%\service   mkdir %STAGING%\service

set  REPO_FILE=%WORKSPACE%\revision.bat
if EXIST %REPO_FILE% (
    del /f %REPO_FILE%
)
echo set REPO_SHA=%REPO_SHA% > %REPO_FILE%
call %REPO_FILE%

set  TEMPLATE_FILE="godeps\src\github.com\couchbase\sync_gateway\rest\api.go"
if EXIST "godeps\src\github.com\couchbase\sync_gateway\base\version.go"  set TEMPLATE_FILE="godeps\src\github.com\couchbase\sync_gateway\base\version.go"
if EXIST %TEMPLATE_FILE%.orig	del %TEMPLATE_FILE%.orig
if EXIST %TEMPLATE_FILE%.new	del %TEMPLATE_FILE%.new

set PRODUCT_NAME=%SG_PRODUCT_NAME%

echo ======== insert %PRODUCT_NAME% build meta-data ==============

setlocal disabledelayedexpansion
for /F "usebackq tokens=1* delims=]" %%I in (`type %TEMPLATE_FILE% ^| find /V /N ""`) do (
    if "%%J"=="" (echo.>> %TEMPLATE_FILE%.new) else (
    set LINEA=%%J
    setlocal enabledelayedexpansion
    set LINEB=!LINEA:@PRODUCT_NAME@=%PRODUCT_NAME%!
    set LINEC=!LINEB:@PRODUCT_VERSION@=%VERSION%!
    set LINED=!LINEC:@COMMIT_SHA@=%REPO_SHA%!
    echo !LINED!>> %TEMPLATE_FILE%.new
    endlocal )
    )
endlocal

dos2unix %TEMPLATE_FILE%.new
move     %TEMPLATE_FILE%       %TEMPLATE_FILE%.orig
move     %TEMPLATE_FILE%.new   %TEMPLATE_FILE%

echo ======== build %PRODUCT_NAME% ===============================
set    DEST_DIR=%SGW_DIR%\bin
if EXIST %DEST_DIR%     del /s/f/q %DEST_DIR%
mkdir %DEST_DIR%

set CGO_ENABLED=1
set GOPATH=%cd%\godeps
echo GOOS=%GOOS% GOARCH=%GOARCH% GOPATH=%GOPATH%

:: Clean up stale objects before switching GO version
if EXIST %SGW_DIR%\pkg           rmdir /s/q %SGW_DIR%\pkg

echo go install github.com\couchbase\sync_gateway\...
go install github.com\couchbase\sync_gateway\...
::go build -v github.com\couchbase\sync_gateway

if NOT EXIST %BIN_DIR%\%SGW_EXEC% (
    echo "############################# Sync-Gateway FAIL! no such file: %BIN_DIR%\%SGW_EXEC%"
    exit 1
)
move   %BIN_DIR%\%SGW_EXEC% %DEST_DIR%
echo "..................................Sync-Gateway Success! Output is: %DEST_DIR%\%SGW_EXEC%"

if "%REL_VER%" == "0.0.0" GOTO build_sg_accel
if "%REL_VER%" GEQ "1.3.0" GOTO build_sg_accel

GOTO skip_build_sg_accel

:build_sg_accel

    if "%EDITION%" == "community" GOTO skip_build_sg_accel

    set PRODUCT_NAME=%ACCEL_PRODUCT_NAME%

    echo ======== remove build meta-data ==============
    move  %TEMPLATE_FILE%.orig  %TEMPLATE_FILE%

    echo ======== insert %PRODUCT_NAME% build meta-data ==============

    setlocal disabledelayedexpansion
    for /F "usebackq tokens=1* delims=]" %%I in (`type %TEMPLATE_FILE% ^| find /V /N ""`) do (
        if "%%J"=="" (echo.>> %TEMPLATE_FILE%.new) else (
        set LINEA=%%J
        setlocal enabledelayedexpansion
        set LINEB=!LINEA:@PRODUCT_NAME@=%PRODUCT_NAME%!
        set LINEC=!LINEB:@PRODUCT_VERSION@=%VERSION%!
        set LINED=!LINEC:@COMMIT_SHA@=%REPO_SHA%!
        echo !LINED!>> %TEMPLATE_FILE%.new
        endlocal )
        )
    endlocal

    dos2unix %TEMPLATE_FILE%.new
    move     %TEMPLATE_FILE%       %TEMPLATE_FILE%.orig
    move     %TEMPLATE_FILE%.new   %TEMPLATE_FILE%

    echo ======== build %PRODUCT_NAME% ===============================
    
    echo go install github.com\couchbaselabs\sync-gateway-accel\...
    go install github.com\couchbaselabs\sync-gateway-accel\...

    if NOT EXIST %BIN_DIR%\sync-gateway-accel.exe (
        echo "############################# SG-ACCEL FAIL! no such file: %BIN_DIR%\%ACCEL_EXEC%"
        exit 1
    )
    move   %BIN_DIR%\sync-gateway-accel.exe %DEST_DIR%\%ACCEL_EXEC%
    echo "..................................SG-ACCEL Success! Output is: %DEST_DIR%\%ACCEL_EXEC%"

:skip_build_sg_accel

echo ======== remove build meta-data ==============
move  %TEMPLATE_FILE%.orig  %TEMPLATE_FILE%

echo ======== build service wrappers ==============
set SG_SERVICED=%SGW_DIR%\service\sg-windows
set SG_SERVICE=%SG_SERVICED%\sg-windows.exe
set ACCEL_SERVICE=%SG_SERVICED%\sg-accel-service.exe

if "%REL_VER%" == "0.0.0" GOTO build_service_wrapper
if "%REL_VER%" GEQ "1.3.0" GOTO build_service_wrapper

GOTO skip_build_service_wrapper

:build_service_wrapper
    cd %SG_SERVICED%
    if EXIST build.cmd (
        call build.cmd
    ) else (
        echo "############################# WINDOWS SERVICE WRAPPER build FAIL! no such file: %SG_SERVICED%\build.cmd"
        exit 1
    )

    if NOT EXIST %SG_SERVICE% (
        echo "############################# SG-SERVICE FAIL! no such file: %SG_SERVICE%"
        exit 1
    )

    if NOT EXIST %ACCEL_SERVICE% (
        echo "############################# SG-ACCEL-SERVICE FAIL! no such file: %ACCEL_SERVICE%"
        exit 1
    )

:skip_build_service_wrapper

echo ======== build sgcollect_info ===============================
set COLLECTINFO_DIR=%SGW_DIR%\tools
set COLLECTINFO_DIST=%COLLECTINFO_DIR%\dist\%COLLECTINFO_NAME%.exe

set CWD=%cwd%
cd %COLLECTINFO_DIR%
pyinstaller --onefile %COLLECTINFO_NAME%
if EXIST %COLLECTINFO_DIST% (
    echo "..............................SGCOLLECT_INFO Success! Output is: %COLLECTINFO_DIST%"
) else (
    echo "############################# SGCOLLECT-INFO FAIL! no such file: %COLLECTINFO_DIST%"
    exit 1
)
cd %CWD%

echo ======== sync-gateway package ==========================
echo ".................staging sgw files to %STAGING%"
copy  %DEST_DIR%\%SGW_EXEC%             %STAGING%\bin\
copy  %COLLECTINFO_DIST%                %STAGING%\tools\
copy  %BLD_DIR%\README.txt              %STAGING%\README.txt
echo  %VERSION%                       > %STAGING%\VERSION.txt
copy  %LIC_DIR%\LICENSE_%EDITION%.txt   %STAGING%\LICENSE.txt
copy  %LIC_DIR%\LICENSE_%EDITION%.rtf   %STAGING%\LICENSE.rtf

xcopy /s %SGW_DIR%\examples             %STAGING%\examples
xcopy /s %SGW_DIR%\service              %STAGING%\service

unix2dos  %STAGING%\README.txt
unix2dos  %STAGING%\VERSION.txt
unix2dos  %STAGING%\LICENSE.txt

echo ".................staging sgw files to wix_install dir %SGW_INSTALL_DIR%"
copy  %STAGING%\tools\         %SGW_INSTALL_DIR%\tools\
copy  %STAGING%\README.txt     %SGW_INSTALL_DIR%\README.txt
copy  %STAGING%\VERSION.txt    %SGW_INSTALL_DIR%\VERSION.txt
copy  %STAGING%\LICENSE.txt    %SGW_INSTALL_DIR%\LICENSE.txt

xcopy /s %SGW_DIR%\examples    %STAGING%\examples

echo  ======= start wix install  ==============================
cd sgw-wix-installer
set WIX_INSTALLER='create-installer.bat'
echo %BLD_DIR%' => ' .\%WIX_INSTALLER% %SGW_INSTALL_DIR% %VERSION% %EDITION% "%SGW_NAME%"
                     .\%WIX_INSTALLER% %SGW_INSTALL_DIR% %VERSION% %EDITION% "%SGW_NAME%"

if %ERRORLEVEL% NEQ 0 (
    echo "############################# Sync-Gateway Installer warning!"
    )

exit 0


echo ============================================== %DATE%

goto :EOF
::##########################


::############# usage
:usage
    set ERR_CODE=%1
    echo.
    echo "use:  %THIS_SCRIPT%   branch_name  rel_ver build_num  edition  platform  commit_sha [ GO_VERSION ]"
    echo.
    echo "exiting ERROR code: %ERR_CODE%"
    echo.
    exit %ERR_CODE%
    goto :EOF

::#############
