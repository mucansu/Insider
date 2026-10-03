extends TestCase
## US-011b core rules (no node, clock injection): NPC visibility gate `SightGate` (AC5: 0.2 s hold, 1.5 s still ghost at the last
## seen position, last 0.3 s fade, no fade with reduced motion, peripheral silhouette alpha 0.5), exposure thresholds and write
## authority (AC7: 0/1/2, >= 30 seen, writes ineffective on a client), vision mode host rule (AC2: host only, before the level
## starts; replicated mode), sound ring draw condition (AC6) and the memory latch.

const DT := 1.0 / 60.0


func _run(gate: SightGate, seconds: float, full: bool, peripheral: bool, pos: Vector2) -> SightGate.Mode:
	var mode: SightGate.Mode = gate.mode()
	for i: int in roundi(seconds / DT):
		mode = gate.step(full, peripheral, pos, DT)
	return mode


# --- SightGate (AC5) ---

func test_gate_hold_then_ghost_then_hidden() -> void:
	var gate := SightGate.new()
	eq(gate.mode(), SightGate.Mode.HIDDEN, "hiç görülmeyen gizli")
	eq(gate.step(false, false, Vector2(1, 1), DT), SightGate.Mode.HIDDEN)
	eq(gate.step(true, false, Vector2(10, 0), DT), SightGate.Mode.FULL, "görünen karo ∧ görüş hattı → tam")
	is_true(gate.is_full())
	eq(gate.alpha(), 1.0)
	# Leaves sight: 0.2 s hold (full draw continues), the NPC walks meanwhile.
	eq(gate.step(false, false, Vector2(20, 0), 0.1), SightGate.Mode.FULL, "0,1 sn: tutma")
	eq(gate.step(false, false, Vector2(30, 0), 0.09), SightGate.Mode.FULL, "0,19 sn: tutma")
	eq(gate.step(false, false, Vector2(40, 0), 0.02), SightGate.Mode.GHOST, "0,21 sn: hayalet")
	eq(gate.ghost_position(), Vector2(10, 0), "hayalet son GÖRÜLEN konumda (tutmadaki canlı konum değil)")
	is_false(gate.is_full(), "hayalette işaret yok")
	near(gate.alpha(), 0.5, 0.0001, "MUTED α 0,5")
	eq(gate.step(false, false, Vector2(90, 0), 1.0), SightGate.Mode.GHOST, "1,21 sn")
	eq(gate.ghost_position(), Vector2(10, 0), "hareketsiz")
	near(gate.alpha(), 0.5, 0.0001, "solma son 0,3 sn'de başlar")
	gate.step(false, false, Vector2(90, 0), 0.34)  # 1.55 s: 0.15 s left of the ghost
	near(gate.alpha(), 0.25, 0.01, "solma yarıda")
	eq(gate.step(false, false, Vector2(90, 0), 0.16), SightGate.Mode.HIDDEN, "0,2 + 1,5 sn sonra gizli")
	eq(gate.alpha(), 0.0)
	eq(gate.step(false, false, Vector2(90, 0), 5.0), SightGate.Mode.HIDDEN, "gizli kalır")


func test_gate_short_gap_and_reseen_ghost() -> void:
	var gate := SightGate.new()
	gate.step(true, false, Vector2.ZERO, DT)
	eq(_run(gate, 0.15, false, false, Vector2(5, 0)), SightGate.Mode.FULL, "0,15 sn kesinti: titreme yok")
	eq(gate.step(true, false, Vector2(6, 0), DT), SightGate.Mode.FULL, "yeniden görüldü, sayaç sıfır")
	eq(_run(gate, 0.15, false, false, Vector2(7, 0)), SightGate.Mode.FULL, "tutma yeniden 0,2 sn")
	eq(_run(gate, 0.5, false, false, Vector2(8, 0)), SightGate.Mode.GHOST)
	eq(gate.step(true, false, Vector2(50, 0), DT), SightGate.Mode.FULL, "hayalet yeniden görülünce biter")
	eq(gate.ghost_position(), Vector2(50, 0))


func test_gate_peripheral_silhouette_and_reduce_motion() -> void:
	var gate := SightGate.new()
	eq(gate.step(false, true, Vector2(3, 3), DT), SightGate.Mode.SILHOUETTE, "çevresel: soluk siluet")
	near(gate.alpha(), 0.5, 0.0001)
	is_false(gate.is_full(), "silüette balon/koni/yay yok")
	eq(gate.step(true, true, Vector2(3, 3), DT), SightGate.Mode.FULL, "tam görünür baskın")
	eq(gate.step(false, true, Vector2(4, 3), DT), SightGate.Mode.SILHOUETTE, "tam → çevresel")
	eq(_run(gate, 0.1, false, false, Vector2(9, 9)), SightGate.Mode.SILHOUETTE, "silüette de 0,2 sn tutma")
	eq(_run(gate, 0.2, false, false, Vector2(9, 9)), SightGate.Mode.GHOST)
	eq(gate.ghost_position(), Vector2(4, 3))
	gate.reduce_motion = true
	_run(gate, 1.25, false, false, Vector2(9, 9))
	eq(gate.mode(), SightGate.Mode.GHOST)
	near(gate.alpha(), 0.5, 0.0001, "hareket azaltmada solma yok (statik)")
	eq(_run(gate, 0.2, false, false, Vector2(9, 9)), SightGate.Mode.HIDDEN, "süre bitince anında")
	eq(SightGate.HOLD_SEC, 0.2)
	eq(SightGate.GHOST_SEC, 1.5)
	eq(SightGate.FADE_SEC, 0.3)


# --- exposure (AC7) ---

func test_exposure_thresholds() -> void:
	eq(VisionRules.exposure_level(false, 0.0), 0, "gizli")
	eq(VisionRules.exposure_level(true, 0.0), 1, "konide ve görüş hattında: görünür")
	eq(VisionRules.exposure_level(true, 29.99), 1, "eşik altı")
	eq(VisionRules.exposure_level(true, 30.0), 2, "≥ 30: görüldü")
	eq(VisionRules.exposure_level(false, 30.0), 2, "şüphe ≥ 30 görüş olmadan da görüldü (şüphe sürer)")
	eq(VisionRules.exposure_level(false, 29.0), 0, "görüş yokken eşik altı şüphe: gizli")
	eq(VisionRules.combine(1, 2), 2, "gözlemcilerin en yükseği")
	eq(VisionRules.SEEN_THRESHOLD, 30.0)
	near(VisionRules.EXPOSURE_INTERVAL_SEC, 0.1, 0.0001, "10 Hz")


func test_session_exposure_write_authority_and_changes() -> void:
	var s := VisionRules.Session.new()
	eq(s.write({2: 1}, false), {}, "istemcide yazma etkisiz")
	eq(s.exposure(2), 0)
	eq(s.write({2: 1, 3: 0}, true), {2: 1}, "host yazar; yalnız değişen döner")
	eq(s.exposure(2), 1)
	eq(s.exposure(3), 0)
	eq(s.apply({2: 1, 3: 0}), {}, "aynı tablo: değişim yok")
	eq(s.apply({2: 2, 3: 7}), {2: 2, 3: 2}, "değer 0..2'ye kenetlenir")
	eq(s.apply({3: 2}), {2: 0}, "tabloda olmayan peer 0")
	eq(s.history()[2], [0, 1, 2, 0], "geçiş geçmişi (ilk öğe 0)")
	eq(s.history()[3], [0, 2])
	eq(s.clear_exposures(), {3: 0})
	eq(s.exposures(), {})


## t2: a leaving peer's exposure and history are deleted; the remaining one's is kept; no change is reported while 0.
func test_session_forget_departed_peer() -> void:
	var s := VisionRules.Session.new()
	s.write({2: 1, 3: 2}, true)
	eq(s.forget(3), {3: 0}, "görülen peer ayrıldı: 0'a düştü bildirilir")
	eq(s.exposures(), {2: 1})
	is_false(s.history().has(3), "geçmiş silindi")
	eq(s.history()[2], [0, 1], "kalanın geçmişi korunur")
	s.apply({2: 0})
	eq(s.forget(2), {}, "gizli peer: değişim yok")
	eq(s.history(), {}, "geçmiş boş")
	eq(s.forget(99), {}, "bilinmeyen peer etkisiz")
	eq(s.apply({}), {}, "ayrılan sonraki tabloda yeniden açılmaz")
	eq(s.history(), {})


func test_session_mode_host_rule() -> void:
	var s := VisionRules.Session.new(VisionGrid.Mode.PERIPHERAL)
	is_false(s.set_mode(VisionGrid.Mode.DIRECTIONAL, false, false), "istemcide etkisiz")
	eq(s.mode(), VisionGrid.Mode.PERIPHERAL)
	is_false(s.set_mode(VisionGrid.Mode.DIRECTIONAL, true, true), "seviye başladıktan sonra etkisiz")
	is_false(s.set_mode(7, true, false), "geçersiz kip")
	is_true(s.set_mode(VisionGrid.Mode.DIRECTIONAL, true, false), "host, seviye başlamadan")
	eq(s.mode(), VisionGrid.Mode.DIRECTIONAL)
	var client := VisionRules.Session.new(VisionGrid.Mode.PERIPHERAL)
	is_true(client.apply_mode(s.mode()), "çoğaltılan kip uygulanır (herkes aynı)")
	eq(client.mode(), s.mode())
	is_false(client.apply_mode(-1), "bozuk değer yok sayılır")
	eq(VisionRules.Session.new(9).mode(), 1, "kurucu kenetler")


# --- sound ring (AC6) and memory ---

func test_ring_shown_rule() -> void:
	is_true(VisionRules.ring_shown(true, 999.0, 10.0, false, 0.5), "kaynak görülüyorsa hep")
	is_true(VisionRules.ring_shown(false, 150.0, 160.0, true, 0.5), "görüş hattında yarıçap içinde")
	is_false(VisionRules.ring_shown(false, 161.0, 160.0, true, 0.5), "yarıçap dışı")
	is_false(VisionRules.ring_shown(false, 81.0, 160.0, false, 0.5), "duvar arkası ×0,5 = 80")
	is_true(VisionRules.ring_shown(false, 79.0, 160.0, false, 0.5), "duvar arkası yakın")


func test_latch_keeps_last_seen_value() -> void:
	var latch := VisionRules.Latch.new()
	is_false(latch.has_value(), "hiç görülmedi")
	eq(latch.update(false, true), null)
	eq(latch.update(true, false), false, "görülünce canlı")
	eq(latch.update(false, true), false, "görülmezken son görülen")
	eq(latch.update(true, true), true)
	is_true(latch.has_value())


func test_above_fog_z_and_group() -> void:
	is_true(VisionRules.ABOVE_FOG_Z > FogLayer.Z_INDEX, "sis üstü z_index > 50 (S3 eki)")
	ne(VisionRules.NPC_VISUAL_GROUP, &"")
