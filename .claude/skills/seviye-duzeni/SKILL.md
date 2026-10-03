---
name: seviye-duzeni
description: Insiders seviye düzeni reçetesi — levels/layouts/*.txt ASCII ızgarası, işaret/bölge satırları, build_levels.gd ile .tscn üretimi, korunan elle eklenen düğümler, S4 düğüm düzeni. Harita, kapı, işaret, bölge eklerken ya da değiştirirken kullan.
---

# Seviye düzeni

**.tscn'nin üretilen kısmını elle düzenleme.** Düzen `levels/layouts/<ad>.txt`, sahne üretici çıktısı.

## Akış
1. `levels/layouts/<ad>.txt` düzenle.
2. `"$GODOT" --headless --path . -s res://levels/tools/build_levels.gd -- <ad>` (ad yoksa hepsi; çıkış 1 = hata).
3. `bash tools/ci_local.sh import unit` — `test_levels*.gd` sahne-ızgara tutarlılığını denetler.
4. store_a değiştiyse ilgili ağ senaryolarını koş (`ag-senaryosu`).

## Sözdizimi
- `;` yorum.
- `@ <harf> <İşaretAdı> <zemin>` — harf ızgarada **tam bir kez**; `Spawn*` → SpawnPoints, diğerleri → Markers. Örnek `@ R Register T`.
- `= <harf> <BölgeAdı> <zemin>` — harf hücreleri dolu dikdörtgen; `Zones/<ad>` Area2D. Örnek `= X EscapeZone _`.
- `= <BölgeAdı> <sütun> <satır> <gen> <yük>` — boyamasız parça; ad tekrarı = çok parçalı.
- Kalan satırlar eşit genişlikte ızgara (karo 32 px).

Lejant (`levels/level_layout.gd` LEGEND): `%` sınır · `#` duvar · `w` vitrin camı (görüş geçer) · `+` kapı boşluğu · `.` iç zemin · `:` arka oda · `,` kaldırım · `_` cadde · `S` raf · `T` tezgâh · `I` dolap (görüş keser) · `G` koli (görüş keser).

## Üretilen ↔ korunan
- Üretilen (her seferinde yeniden): `Tiles, Walls, SpawnPoints, Markers, Zones, Navigation` (her kapı işaretine `Navigation/<Kapı>` NavigationLink2D).
- **Korunan** (elle eklenir): `Players, Props, NPCs` ve diğer kök düğümler (EscapeMarker, Owner, StoreAlert, Population/PopulationSpawner, ChaserSpawner, kapı örnekleri).
- Her kapı işaretinin `Props` altında aynı adlı kapı örneği olmalı (`entities/props/door.tscn`) — IS-086'da D eksikti.

## S4 düzeni (mimari.md S4)
Kök `Level` (`levels/level.gd`); sıra Tiles, Walls, SpawnPoints (≥ Spawn1..4), Players, Props, NPCs, Markers, Zones, Navigation. Erişim yalnız Level API'si (`marker`, `marker_sequence`, `zone`, `spawn_position`, `door_link`, `map_rect`, `tier`, `attach_fog`…).
Yeni işaret/bölge eklersen `tests/unit/test_levels_population.gd` tablolarını (SINGLES/SEQUENCES/MARKER_ZONES) güncelle.

## store_a işaretleri
FrontDoor, BackDoor, BackroomDoor, Register, Counter, ClerkSpot, BackroomSafe, BackroomCash, Exit, StreetRoute1..6, NeighbourSpawn, WindowLook1..3, ShopSpot1..5, QueueSpot1..2, RestockSpot1..3, PhoneSpot, BackroomSpot, ShelfProp1..3, Spawn1..4; bölgeler EscapeZone, CustomerArea, StaffArea, Backroom.
