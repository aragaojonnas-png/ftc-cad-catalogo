@echo off
rem Abre a janela do instalador e baixa TODOS os arquivos, sem limite de tamanho
start "" wscript.exe "%~dp0ftc.vbs" instalar.ps1 -MaxMB 0
