@echo off
chcp 65001 >nul
title Instalador FTC_CAD
echo.
echo  Instalador da biblioteca FTC_CAD
echo  Os arquivos serao baixados para esta pasta: %~dp0
echo  (Baixando TUDO, inclusive arquivos grandes - ocupa bem mais espaco)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1" -MaxMB 0
echo.
pause
