@echo off
chcp 65001 >nul
rem Abre a janela do instalador (arquivos acima de 20 MB sao pulados; para baixar tudo use Instalar-tudo.bat)
start "" powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0instalar.ps1"
