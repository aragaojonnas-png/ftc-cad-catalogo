@echo off
chcp 65001 >nul
title Instalador FTC_CAD
echo.
echo  Instalador da biblioteca FTC_CAD
echo  Os arquivos serao baixados para esta pasta: %~dp0
echo  (Arquivos acima de 20 MB sao pulados. Para baixar tudo, rode o Instalar-tudo.bat)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1"
echo.
pause
