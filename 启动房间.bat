@echo off
cd /d "%~dp0"
if exist "godot.exe" (
  "godot.exe" --path "%~dp0"
  exit /b
)
where godot >nul 2>nul
if not errorlevel 1 (
  godot --path "%~dp0"
  exit /b
)
echo Open project.godot with Godot 4.6.2 and press F5.
pause
