$gameProject = Split-Path -Parent $PSScriptRoot
$gameEngine = Join-Path $env:USERPROFILE 'Godot\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $gameEngine)) {
    $gameEngine = Join-Path $env:USERPROFILE 'Godot\4.6.2\Godot_v4.6.2-stable_win64.exe'
}
if (-not (Test-Path -LiteralPath $gameEngine)) {
    throw 'Open project.godot in Godot 4.7.2 (or 4.6.2) to run this project.'
}
Start-Process -FilePath $gameEngine -ArgumentList @('--path', ('"' + $gameProject + '"')) -WorkingDirectory $gameProject -WindowStyle Normal -RedirectStandardOutput (Join-Path $gameProject 'play_stdout.log') -RedirectStandardError (Join-Path $gameProject 'play_stderr.log')
