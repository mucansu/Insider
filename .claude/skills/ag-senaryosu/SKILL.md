---
name: ag-senaryosu
description: Insiders'ta çok süreçli ağ testi (tests/net/*.json senaryosu + bot dosyası) yazma ve koşma reçetesi. Ağ davranışı değişen her işte, yeni etkileşim/NPC/olay eklerken, "0 ve 150 ms'de yeşil" kanıtı gerektiğinde kullan.
---

# Ağ senaryosu (net_smoke)

Kural (surec.md §9): ağ davranışı testsiz birleşmez — en az bir `tests/net` senaryosu **0 ve 150 ms**'de yeşil.
Şemanın tek kaynağı `tools/net_smoke.py` docstring'i (satır 1-82); burada özet var, şüphede orayı oku.

## Senaryo dosyası `tests/net/<ad>.json`
Anahtarlar (bilinmeyen anahtar = FAIL): `_doc`, `level` (zorunlu), `player_scene`, `clients` (vars. 2: c1..cN), `duration` (vars. 8 sn; ortak döküm anı), `start_delay` ({"c2":14}), `quit_after`, `bots`, `names`, `exit_codes`, `allow_log` (regex), `deny_warnings`, `mem_sample_sec`, `timeout`, `expect` (zorunlu, boş olamaz).

```json
{
  "_doc": "US-040: iki oyuncu ganimetsiz kaçışa → aborted. Biçim: tools/net_smoke.py docstring.",
  "level": "res://tests/fixtures/store_a_nopop.tscn",
  "duration": 14,
  "bots": {"host": "res://tests/net/bots/abort_walk.json", "c1": "res://tests/net/bots/abort_walk.json"},
  "expect": [
    {"eq": ["host.heist.result.outcome", "aborted"]},
    {"same": ["host.heist.result.outcome", "c1.heist.result.outcome"]}
  ]
}
```

- `_doc`: kalem kimliği + ne sınandığı + "Biçim: tools/net_smoke.py docstring."
- Yol ifadesi: `<süreç>.<anahtar>…` (süreç `host|c1..cN|*`; liste indisi `c1.events.0.kind`; `$host`/`$c1` peer_id'ye çevrilir).
- İddialar: `eq ne same all_equal near len has lacks between samples_players samples_near mem_stable`; `between` sınırı `"$rtt"`, `"$rtt+200"` olabilir.
- Log'da `ERROR:`/`SCRIPT ERROR:` otomatik FAIL (`allow_log` hariç).

## Bot dosyası `tests/net/bots/<ad>.json`
`{"steps":[{"t":SN, …}]}` — saat yerel oyuncunun ilk fizik adımından:
`{"t":1,"move":[x,y]}` · `{"t":2,"hold":"sprint|sneak|interact|intimidate","dur":3}` · `{"t":4,"press":"intimidate"}` · `{"t":5,"look":[x,y]}` · host kancası `{"t":6,"heist":"alert|police|caught|shout|restart","data":{}}` · `"loop":{"from":F,"period":P}`.
Konumlar için `levels/layouts/<seviye>.txt` işaretlerine bak (karo 32 px).

## Fikstür seç (`tests/fixtures/`)
- `store_a_nopop.tscn` — nüfus kapalı (çoğu senaryo için varsayılan; müşteri rastlantısı yok)
- `store_a_quiet.tscn` — sahipsiz + nüfussuz + D kapısı açık
- `store_a_busy.tscn`, `store_a_late_customer.tscn`, `store_a_backroom_door.tscn`, `store_a_backroom_first.tscn` — özel durumlar
Tohum: oturum tohumu henüz yok (IS-058); `owner_tuning.agenda_seed`, `population.tres population_seed` ya da fikstürde `agenda_seed_override`.

## Dökümde ne var
Taban: `peer_id is_host peers players team_cash level player_nodes events host_lost ping_ms ping alert vision`.
Sağlayıcılar (yalnız `--dump` verildiyse kaydolur): `heist`, `owner`, `population`, `chasers`, `player_states`, `interaction`, `noise`, `props`. Yeni alan: `Game.register_dump_provider(KEY, callable)` (taban anahtar ezilemez).

## Koş
```bash
PYTHONUTF8=1 python tools/net_smoke.py tests/net/<ad>.json
PYTHONUTF8=1 python tools/net_smoke.py tests/net/<ad>.json --latency-ms 150
```
`--keep -v` dökümleri saklar. Port serbest seçilir; açık oyun pencereleriyle çakışmaz. `tools/ci_local.sh net` `tests/net/*.json` glob'unu iki gecikmede koşar — yeni dosya eklemek yeter. Bir senaryo ~15-100 sn.
