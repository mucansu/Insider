---
name: oyunu-ac
description: Recipe for opening Insiders to play-test (host + joining window), command-line arguments, building a test package for friends (export, zip) and connecting over the internet with Tailscale. Use for "open the game", "let me try it", "can friends connect", "make a package".
---

# Open the game / build a package

## Two local windows (Windows)
**Launch the windows as detached processes** - a process started with Bash `&` can silently die when that shell closes (happened 2026-10-03). PowerShell:
```powershell
$g  = "C:\...\Godot_v4.7.2-stable_win64.exe"   # non-console twin of $env:GODOT
$wd = "<repo or .claude\worktrees\faz2-int>"
Start-Process $g -WorkingDirectory $wd -ArgumentList '--path','.','--','--host','--name=Mustafa','--window-size=1280x720'
Start-Sleep 6   # let the host start listening; an early join gets "could not connect"
Start-Process $g -WorkingDirectory $wd -ArgumentList '--path','.','--','--join=127.0.0.1','--name=Ikinci','--window-size=960x540'
```
Run `"$GODOT" --headless --path . --import` first. Check: `Get-NetUDPEndpoint -LocalPort 7777` shows the host process. When closing old windows, close only the ones you started (inspect command lines via `Get-CimInstance Win32_Process`).
Latest playable branch: `faz2-int` (worktree `.claude/worktrees/faz2-int`).

## Arguments (after `--`; `autoload/args.gd`)
`--host` · `--join=ADDR` · `--port=N` (7777) · `--name=NAME` · `--level=res://...` · `--window-size=WxH` · `--camera-zoom=X` · `--vision-mode=peripheral|directional` · tests: `--bot= --dump= --quit-after= --screenshot-at= --screenshot-dir= --perf`.

## Package for friends
1. `bash tools/export.sh --debug windows` -> `build/windows/Insiders.exe` + `Insiders.console.exe` (first run downloads ~1.3 GB templates if missing).
2. Smoke test on another port if a game is on 7777: `Insiders.console.exe --headless -- --host --port=7791 --quit-after=8` + `--join=127.0.0.1 --port=7791 --quit-after=5`; expect two `INSIDERS_READY` lines.
3. Zip: `Compress-Archive Insiders.exe,Insiders.console.exe build\Insiders-<branch>-<hash>-windows.zip` (`build/` is gitignored). ~34 MB -> exceeds free Discord limit; suggest WeTransfer/Drive/OneDrive sharing.
4. **Everyone uses the same package**: a different PROTOCOL_VERSION is rejected by the host.
Official route: `test-*` tag -> CI Release (`Insiders-<tag>-windows.zip`).

## Over the internet (README "Tailscale", Turkish)
Everyone installs Tailscale, the host invites friends to the tailnet -> host clicks **Host ol**, card shows `100.x.y.z:7777` -> **Kopyala** -> friend **Yapıştır** + **Katıl**. On the firewall prompt tick **both Private and Public**, never cancel. Troubleshoot: `tailscale ping`, `tailscale status` (direct/relay), README steps 5-6. Installing Tailscale and inviting is done by the user.
