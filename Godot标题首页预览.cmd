@echo off
cd /d "%~dp0"
start "" "C:\Users\Administrator\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --audio-driver Dummy --script res://tools/preview_title_home.gd -- --test-session-ui --test-candy-title
