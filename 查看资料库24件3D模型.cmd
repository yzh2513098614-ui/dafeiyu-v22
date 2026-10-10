@echo off
set "MODEL_GODOT=C:\Users\Administrator\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%MODEL_GODOT%" (
 echo Open project.godot with Godot 4, then run district/library_models_viewer.tscn.
 pause
 exit /b 1
)
start "" "%MODEL_GODOT%" --path "%~dp0" res://district/library_models_viewer.tscn
