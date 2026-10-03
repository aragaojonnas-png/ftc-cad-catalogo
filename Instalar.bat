@echo off
rem Instala so o catalogo; cada peca e baixada quando voce clica nela (para baixar tudo de uma vez use Instalar-tudo.bat)
start "" wscript.exe "%~dp0ftc.vbs" instalar.ps1 -SobDemanda
