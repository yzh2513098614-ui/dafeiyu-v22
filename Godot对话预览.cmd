@echo off
cd /d "%~dp0"
start "" "C:\Users\Administrator\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --script res://tools/preview_gal_dialogue.gd -- --test-session-ui --test-dialogue --show-dialogue
