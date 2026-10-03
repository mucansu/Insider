---
name: npc-ekle
description: Insiders'a yeni NPC ya da NPC davranışı ekleme reçetesi — sahne + brain_*.gd, bileşenler (agenda, perception, suspicion, hearing, mover, visual), yalnız host'ta çalışma, 15 Hz çoğaltma, authority RPC olayları, MultiplayerSpawner, data/npc ayarları, döküm. Sivil, sahip, kovalayan, muhafız gibi NPC işlerinde kullan.
---

# NPC ekle / değiştir

İlke (mimari.md S11): **yeni NPC = sahne + beyin betiği; algı kodu değişmez.** Kurallar düğümsüz `core/` altında (`civilian_rules.gd`, `population_rules.gd`, `fsm.gd`…); sahne yalnız uygular.

## Yapı (`entities/npc/`)
`owner/` (store_owner, brain_owner, owner_reaction) · `civilian/` · `chaser/` · `population.gd` (üretici) · `store_alert.gd` · `components/`: `agenda` (+`agenda_task`; tohumlu, kesmeler, `setup_route` lineer rota), `perception`, `suspicion` (0-100, `threshold_reached`), `hearing` (`noise_listener` grubu), `sight_line`, `civilian_senses`, `npc_mover` (nav + kapı açma), `npc_visual` (balon, rol).

## Yalnız host'ta çalışır
```gdscript
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
```
`_ready`: host'ta `brain.setup(...)`. `step(delta)`: host → beyin → `move_and_slide` → `net_*` yaz; istemci → `net_position`'a üstel yumuşatma, > 96 px ise ışınla. `@export var auto_step := true` (testler false yapıp `step()` sürer).

## Çoğaltma ve olaylar
- Çocuk `MultiplayerSynchronizer`, 15 Hz (`replication_interval = delta_interval = 0.0667`): `net_position`, `net_facing` ALWAYS (unreliable); `net_state` ON_CHANGE (reliable). Sürekli değerleri 1/16 adıma yuvarla.
- Olay: `@rpc("authority", "call_local", "reliable") func _rpc_event(kind: StringName, peer_id: int)`; izinli türler `EVENT_KINDS` listesinde. İstemci → host istekleri `any_peer` + `get_remote_sender_id()` doğrulaması (S2). Tek RPC ≤ 1 KB.
- **Kablo düzeni değişirse `Game.PROTOCOL_VERSION` artır** (mimari.md S2).

## Üretim ve ayar
- `MultiplayerSpawner` (spawn_path = NPCs) + `spawn_function`; host `spawner.spawn(data)`; geç katılan mevcut NPC'leri alır. Sahnede `levels/<seviye>.tscn` NPCs altına elle eklenir (build_levels korur).
- Ayar `data/npc/<ad>_tuning.tres` + `<ad>_tuning.gd` (`class_name XTuning extends Resource`); kodda sihirli sayı yok.
- Döküm: `if not Args.dump_path.is_empty(): Game.register_dump_provider(DUMP_KEY, dump_state)`; host-özel alanlar `_host_side()` dalında.
- Balon/olay metni: `metin-ve-tema` skill'i (`BALLOON_KEYS`, `EVENT_*`).

## Bitirmeden
- Birim test (`test-yaz`; NpcStage) + en az bir `tests/net` senaryosu 0/150 ms (`ag-senaryosu`).
- Mevcut senaryoları bozuyorsa fikstürde kapat (`active=false`) — sessizce senaryo değiştirme, raporda yaz.
- `test_deps.gd` katman matrisi (core → hiçbir proje dizini), mimari.md S11/döküm eki.
