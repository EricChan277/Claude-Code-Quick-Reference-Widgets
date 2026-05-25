@echo off
REM Double-click to install the ClaudeUsage Rainmeter skin.
REM Runs install.ps1 with execution policy bypassed for this process only.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
