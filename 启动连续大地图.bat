@echo off
setlocal
set "GAME_ROOT=%~dp0"
set "GODOT_EXE=C:\Users\Administrator\Godot\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_EXE%" (
  "%GODOT_EXE%" --headless --path "%GAME_ROOT%." --import
  start "" "%GODOT_EXE%" --path "%GAME_ROOT%."
) else (
  echo Please import project.godot in Godot 4.7.2 and run the project.
  pause
)
