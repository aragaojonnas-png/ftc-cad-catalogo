@echo off
chcp 65001 >nul
rem Abre a janela do instalador e baixa TODOS os arquivos, sem limite de tamanho
start "" powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0instalar.ps1" -MaxMB 0
