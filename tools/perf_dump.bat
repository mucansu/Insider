@echo off
rem Insiders performans dokumu (IS-067; mimari.md S6 --perf). Build klasorunde Insiders.exe'nin yaninda durur
rem (tools/export.sh kopyalar). Cift tiklayin: oyun ~25 sn kendi kendine acilip kapanir, ayni klasore
rem perf_BILGISAYARADI.json yazar; o dosyayi gelistiriciye gonderin. Kisisel veri yok: GPU/surucu adi, ekran
rem cozunurlugu ve kare olcumleri. Ilk kez host olunca Windows Guvenlik Duvari sorarsa "Ozel aglar"a izin verin.
rem Ayar: PERF_SECONDS (olcum penceresi, sn; varsayilan 20). Not: dosya ASCII'dir (cmd kod sayfasi), goto yok.
setlocal
cd /d "%~dp0"
if "%PERF_SECONDS%"=="" set PERF_SECONDS=20
set /a PERF_QUIT=%PERF_SECONDS%+4
set "PERF_OUT=%~dp0perf_%COMPUTERNAME%.json"
if not exist "Insiders.exe" (
	echo Insiders.exe bulunamadi. Bu dosyayi build klasorune, Insiders.exe'nin yanina koyun.
	pause
	exit /b 1
)
if exist "%PERF_OUT%" del "%PERF_OUT%"
echo Insiders performans olcumu: yaklasik %PERF_QUIT% sn surer. Pencere kendiliginden kapanacak; dokunmayin.
start "" /wait "Insiders.exe" -- --host --port=7787 --name=perf --perf --perf-seconds=%PERF_SECONDS% --quit-after=%PERF_QUIT% --dump="%PERF_OUT%"
if exist "%PERF_OUT%" (
	echo Bitti: %PERF_OUT%
	echo Bu dosyayi gelistiriciye gonderin. Tesekkurler!
) else (
	echo Dokum yazilamadi. Insiders.console.exe ile ayni komutu calistirip ciktiyi gonderin:
	echo Insiders.console.exe -- --host --perf --quit-after=%PERF_QUIT% --dump="%PERF_OUT%"
)
pause
