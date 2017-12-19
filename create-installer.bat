setlocal
set installdir=%1
set version=%2
set edition=%3
set productname=%~4
set service_dir=%5

if "%productname%"=="" set productname="SGW"

:: Use -ag to have light auto-generate GUIDs, as that way they'll be
:: based on full filename and therefore consistent from build to build.
heat dir %installdir% -srd -suid -ag -sreg -ke -cg SyncGateway -dr INSTALLDIR -out Files.wxs || goto :error

:: Unfortunately -ag and -ke don't work together - it generates an
:: illegal .wxs. Post-process here to provide random GUIDs for empty
:: diretories.
::python fix-empty-dir-guids.py Files.wxs || goto :error

:: Compile .wxs files to intermediate objects, specifying version
candle -dVersion=%version% -dProductName="%productname%" -arch x64 -ext WixUtilExtension *.wxs || goto :error

:: Create RTF version of License file - our license text is close enough
:: to Markdown to pass
::pandoc ..\LICENSE-%edition%.txt -f markdown -t rtf -s -o License.rtf

:: Light it up!
light -ext WixUIExtension -ext WixUtilExtension -b %installdir% -b %service_dir% -dWixUILicenseRtf=License.rtf -o SGW.msi *.wixobj || goto :error

:end
exit /b 0

:error
@echo Previous command failed with error #%errorlevel%.
exit /b %errorlevel%
