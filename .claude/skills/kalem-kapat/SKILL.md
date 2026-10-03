---
name: kalem-kapat
description: Insiders'ta bir backlog kalemini (US-/IS-) bitirme, doğrulama ve birleştirme reçetesi — KR-028 hafif kontrol kipi, CI adımları, commit biçimi, worktree → faz2-int birleştirme, çakışma dosyaları, PROTOCOL_VERSION, pano güncellemesi. İş bitince, birleştirmeden önce ve "nasıl teslim ederim" sorusunda kullan.
---

# Kalem kapat

Süreç kaynakları: `docs/surec/surec.md` (§4 DoD, §6 worktree), `docs/surec/kararlar.md` KR-028, `docs/notes/ajanlar.md`.

## Geçerli kip: KR-028 (hafif, geçici)
| Kalem | Kanıt | Bağımsız denetim |
|---|---|---|
| Ağ/yetki/kablo düzeni dokunan | AC'ler + `ci_local.sh import unit tools` + ilgili net senaryoları 0/150 ms | hafif (RPC yönü/yetki, senaryolar) |
| Diğer | AC'ler komut çıktısıyla + `import unit tools` | yok; diff okuması |
- Düzeltme turu yalnız **blocker**'da (çökme, çalışmayan AC, yetki açığı, oyuncunun hemen göreceği bozukluk). Gerisi `docs/surec/nit-havuzu.md`'ye, ayrı kalem açılmaz.
- Tam `tools/ci_local.sh` (≈18 dk) günde bir ve test-N öncesi.

## CI
`bash tools/ci_local.sh [godot|import|unit|tools|net|export]` — argümansız `godot import unit tools net`. import iki geçiş (ikincide WARNING/ERROR = kırmızı); unit sızıntı kapılı; tools Python araç testleri + `warn_count --gate`; net `tests/net/*.json` × {0, 150 ms}.

## Ajan isen
- Commit/push/branch değiştirme yok (`.claude/hooks/agent_guard.py` engeller); pano dosyalarına dokunma.
- Rapor ilk satırı `Kalem: US-nnn`; başlıklar **Yapılan / Test / Açık kalan (Nit) / Karar gereken / Sınır dışı** + "nasıl denenir".
- Kapsam dışı bulgu → "Sınır dışı"; karar → "Karar gereken" (seçenek + öneri). Kullanıcıya soru sorma.

## Birleştirme (koordinatör)
1. Worktree'de: `git add -A` (scratch yoksa) → `git commit -m "US-nnn: <özet>"` (sonda Co-Authored-By satırı).
2. `.claude/worktrees/faz2-int` içinde: `git merge --no-ff -q worktree-agent-<id> -m "faz2-int: US-nnn birleştir"`.
3. Çakışma sık dosyalar: `autoload/game.gd` (döküm anahtarları, PROTOCOL_VERSION), `i18n/texts.csv`, `levels/store_a.tscn` (ext_resource satırları), `ui/hud.gd`, `docs/notes/mimari.md` (aynı satıra ek) → **iki tarafın eklemesini koru**.
4. Birleşik ağaçta `ci_local.sh import unit tools` + dokunulan net senaryoları → `git push origin faz2-int`.
5. Pano (dev, ana checkout): backlog satırı `Bitti (faz2-int <hash>; kanıt)`, nit'ler nit-havuzu'na, kararlar günlüğe → `pano: …` commit'i (toplu).

## Kurallar
- **PROTOCOL_VERSION:** RPC/eşitleyici/handshake düzeni değişince `Game.PROTOCOL_VERSION` +1 (sözlüğe alan eklemek değiştirmez). Eski build'li arkadaş bağlanamaz → yeni paket gerekir (`oyunu-ac`).
- Commit öneki: `US-nnn:` / `IS-nnn:` / birleştirme `faz2-int: X birleştir` / yalnız süreç dosyası `pano:`.
- Faz kapanışı: `main` yalnız ff + `faz-N` etiketi; kullanıcı "devam" demeden sonraki faz başlamaz.
