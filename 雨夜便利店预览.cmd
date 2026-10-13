@echo off
set "GODOT_EXE=%USERPROFILE%\Godot\Godot_v4.7.2-stable_win64.exe"
start "" "%GODOT_EXE%" --path "%~dp0" --audio-driver Dummy res://dioramas/rainy_konbini/scenes/main.tscn
