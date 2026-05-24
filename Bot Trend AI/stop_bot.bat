@echo off
title GIA CAT SECURE STOP
set PYTHONIOENCODING=utf-8
cd /d "%~dp0"
python stop_bot.py
pause
