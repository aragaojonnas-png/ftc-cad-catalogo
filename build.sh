#!/bin/sh
# Compila o aplicativo (precisa do Mono: apt install mono-mcs) e copia FTC_CAD.exe para a raiz do repositorio.
# Depois de compilar: aumente a versao em versao.txt (senao os PCs nao baixam o .exe novo) e faca commit + push.
set -e
cd "$(dirname "$0")"
mcs -target:winexe -out:FTC_CAD.exe -win32icon:src/ftc.ico \
  -r:System.Windows.Forms.dll -r:System.Drawing.dll -r:System.Web.Extensions.dll \
  -r:System.IO.Compression.dll -r:System.IO.Compression.FileSystem.dll src/FtcCad.cs
echo "FTC_CAD.exe compilado. Lembre de atualizar versao.txt."
