---
name: oyunu-ac
description: Insiders'ı denemek için açma (host + katılan pencere), komut satırı argümanları, arkadaşlara deneme paketi (export, zip) çıkarma ve Tailscale ile internet üzerinden bağlanma reçetesi. "Oyunu aç", "deneyeyim", "arkadaşlar bağlanabilir mi", "paket çıkar" isteklerinde kullan.
---

# Oyunu aç / paket çıkar

## Yerelde iki pencere (Windows)
**Pencereleri bağımsız süreç olarak aç** — Bash `&` ile açılan süreç, kabuk kapanınca sessizce ölebilir (2026-10-03'te yaşandı). PowerShell:
```powershell
$g  = "C:\…\Godot_v4.7.2-stable_win64.exe"   # $env:GODOT'un konsolsuz eşi
$wd = "<repo ya da .claude\worktrees\faz2-int>"
Start-Process $g -WorkingDirectory $wd -ArgumentList '--path','.','--','--host','--name=Mustafa','--window-size=1280x720'
Start-Sleep 6   # host dinlemeye başlasın; erken katılan "bağlanılamadı" alır
Start-Process $g -WorkingDirectory $wd -ArgumentList '--path','.','--','--join=127.0.0.1','--name=Ikinci','--window-size=960x540'
```
Önce `"$GODOT" --headless --path . --import`. Doğrulama: `Get-NetUDPEndpoint -LocalPort 7777` host sürecini göstermeli. Eski pencereleri kapatırken yalnız kendi açtıklarını kapat (`Get-CimInstance Win32_Process` komut satırına bak).
En güncel oynanabilir dal: `faz2-int` (worktree `.claude/worktrees/faz2-int`).

## Argümanlar (`--` sonrası; `autoload/args.gd`)
`--host` · `--join=ADDR` · `--port=N` (7777) · `--name=AD` · `--level=res://…` · `--window-size=GxY` · `--camera-zoom=X` · `--vision-mode=peripheral|directional` · test: `--bot= --dump= --quit-after= --screenshot-at= --screenshot-dir= --perf`.

## Arkadaşlara paket
1. `bash tools/export.sh --debug windows` → `build/windows/Insiders.exe` + `Insiders.console.exe` (şablonlar yoksa ilk koşu ~1,3 GB indirir).
2. Duman: açık oyun 7777'deyse farklı port: `Insiders.console.exe --headless -- --host --port=7791 --quit-after=8` + `--join=127.0.0.1 --port=7791 --quit-after=5`; iki `INSIDERS_READY` satırı.
3. Zip: `Compress-Archive Insiders.exe,Insiders.console.exe build\Insiders-<dal>-<hash>-windows.zip` (`build/` git'te yok sayılır). ~34 MB → Discord ücretsiz sınırını aşar; WeTransfer/Drive/OneDrive paylaşımı öner.
4. **Herkes aynı paketi** kullanmalı: PROTOCOL_VERSION farklıysa host reddeder.
Resmî yol: `test-*` etiketi → CI Release (`Insiders-<etiket>-windows.zip`).

## İnternet üzerinden (README "Tailscale")
Herkes Tailscale kurar, host arkadaşlarını tailnet'e davet eder → host **Host ol**, kartta `100.x.y.z:7777` → **Kopyala** → arkadaş **Yapıştır** + **Katıl**. Güvenlik duvarı sorusunda **Özel ve Ortak** ikisi de işaretli, iptal etme. Sorun: `tailscale ping`, `tailscale status` (direct/relay), README 5-6. adım. Tailscale kurulumu ve davetleri kullanıcı yapar.
