@echo off
cd /d "%~dp0"
echo Running Full Game Test Suite...
Godot_v4.7.2-stable_win64_console.exe --headless -s tests/test_full_game.gd
echo.
pause
