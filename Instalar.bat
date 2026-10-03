@echo off
rem Abre a janela do instalador sem terminal (arquivos acima de 20 MB sao pulados; para baixar tudo use Instalar-tudo.bat)
start "" wscript.exe "%~dp0ftc.vbs" instalar.ps1
