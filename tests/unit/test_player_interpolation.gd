extends TestCase
## US-004 AC4: SnapshotBuffer — uzak kopya ~100 ms geriden, gönderen saatine göre ara değerlenir; titreşim
## (jitter) emilir, eski paket atılır, tampon tükenince beklenir (ileri tahmin yok).

const DELAY := 0.1
const SEND_INTERVAL := 0.05
const SPEED := 140.0


func test_interpolates_between_snapshots() -> void:
	var buffer := SnapshotBuffer.new(DELAY)
	# Gönderen saati 0'dan, yerel saat 10'dan: saat farkı 10 sn (ağ gecikmesi 0).
	for i: int in 3:
		buffer.push(i * SEND_INTERVAL, 10.0 + i * SEND_INTERVAL, Vector2(7.0 * i, 0), Vector2.RIGHT, PlayerMotion.Mode.WALK)
	near(buffer.clock_offset(), 10.0, 0.0001)
	var frame: SnapshotBuffer.Frame = buffer.sample(10.175)  # gönderen anı 0,075
	near(frame.position, Vector2(10.5, 0), 0.0001, "0,05 ile 0,10 arası ortada")
	near(frame.velocity, Vector2(SPEED, 0), 0.001, "hız iki görüntü arası")
	eq(frame.facing, Vector2.RIGHT)


func test_facing_slerps_and_mode_comes_from_earlier_snapshot() -> void:
	var buffer := SnapshotBuffer.new(DELAY)
	buffer.push(0.0, 0.0, Vector2.ZERO, Vector2.RIGHT, PlayerMotion.Mode.WALK)
	buffer.push(0.05, 0.05, Vector2.ZERO, Vector2.DOWN, PlayerMotion.Mode.SNEAK)
	var frame: SnapshotBuffer.Frame = buffer.sample(0.125)
	near(frame.facing, Vector2(1, 1).normalized(), 0.001, "yön ara değerlenir")
	eq(frame.mode, PlayerMotion.Mode.WALK, "kip önceki görüntüden")
	frame = buffer.sample(0.2)
	eq(frame.mode, PlayerMotion.Mode.SNEAK)


func test_holds_before_first_and_after_last_without_extrapolation() -> void:
	var buffer := SnapshotBuffer.new(DELAY)
	is_true(buffer.sample(1.0) == null, "boş tampon: null (konuma dokunulmaz)")
	buffer.push(5.0, 5.0, Vector2(10, 10), Vector2.UP, PlayerMotion.Mode.WALK)
	var first: SnapshotBuffer.Frame = buffer.sample(5.0)
	near(first.position, Vector2(10, 10), 0.0001, "ilk görüntüde beklenir")
	eq(first.velocity, Vector2.ZERO)
	eq(buffer.underrun_count(), 0, "tampon dolarken bekleme tükenme sayılmaz")
	buffer.push(5.05, 5.05, Vector2(17, 10), Vector2.UP, PlayerMotion.Mode.WALK)
	var late: SnapshotBuffer.Frame = buffer.sample(6.0)
	near(late.position, Vector2(17, 10), 0.0001, "son görüntüden öteye tahmin yok")
	eq(late.velocity, Vector2.ZERO)
	eq(buffer.underrun_count(), 1)


func test_stale_and_reordered_snapshots_are_dropped() -> void:
	var buffer := SnapshotBuffer.new(DELAY)
	is_true(buffer.push(0.10, 0.10, Vector2(14, 0), Vector2.RIGHT, 0))
	is_false(buffer.push(0.05, 0.11, Vector2(7, 0), Vector2.RIGHT, 0), "geç gelen eski görüntü")
	is_false(buffer.push(0.10, 0.12, Vector2(99, 0), Vector2.RIGHT, 0), "aynı an")
	eq(buffer.size(), 1)


func test_non_finite_snapshots_are_dropped() -> void:
	var buffer := SnapshotBuffer.new(DELAY)
	is_true(buffer.push(1.0, 11.0, Vector2(10, 0), Vector2.RIGHT, 0))
	var bad: Array = [
		[NAN, 11.05, Vector2(17, 0), Vector2.RIGHT, "gönderen anı NaN"],
		[INF, 11.05, Vector2(17, 0), Vector2.RIGHT, "gönderen anı +INF"],
		[-INF, 11.05, Vector2(17, 0), Vector2.RIGHT, "gönderen anı -INF"],
		[1.05, NAN, Vector2(17, 0), Vector2.RIGHT, "yerel an NaN"],
		[1.05, 11.05, Vector2(NAN, 0), Vector2.RIGHT, "konum NaN"],
		[1.05, 11.05, Vector2(0, INF), Vector2.RIGHT, "konum INF"],
		[1.05, 11.05, Vector2(17, 0), Vector2(NAN, NAN), "yön NaN"],
	]
	for row: Array in bad:
		is_false(buffer.push(float(row[0]), float(row[1]), row[2] as Vector2, row[3] as Vector2, 0), str(row[4]))
	eq(buffer.size(), 1, "bozuk paketler tampona girmez")
	near(buffer.clock_offset(), 10.0, 0.0001, "saat farkı bozulmaz")
	# INF gönderen anı sonraki geçerli paketleri "eski" saydırmaz; çizim sonlu kalır.
	is_true(buffer.push(1.05, 11.05, Vector2(17, 0), Vector2.RIGHT, 0), "ardından gelen geçerli paket kabul")
	var frame: SnapshotBuffer.Frame = buffer.sample(11.125)
	is_true(frame.position.is_finite() and frame.velocity.is_finite() and frame.facing.is_finite())
	near(frame.position, Vector2(13.5, 0), 0.0001)


func test_clock_offset_resets_on_large_jump() -> void:
	var buffer := SnapshotBuffer.new(DELAY)
	buffer.push(0.0, 10.0, Vector2.ZERO, Vector2.DOWN, 0)
	buffer.push(0.05, 10.06, Vector2.ZERO, Vector2.DOWN, 0)
	near(buffer.clock_offset(), 10.0, 0.001, "küçük fark yumuşatılır")
	buffer.push(0.10, 12.0, Vector2.ZERO, Vector2.DOWN, 0)
	near(buffer.clock_offset(), 11.9, 0.0001, "0,5 sn üstü sıçramada yeniden kurulur")


## 20 Hz gönderim, 75 ms ± 30 ms titreşimli varış (GDD §12 sert ağ, tek yön), 60 Hz çizim: çizim düzgün ve
## tek yönlü ilerler, hız gerçeğe yakın, gecikme ~ ortalama ağ gecikmesi + tampon, ısınmadan sonra tükenme yok.
func test_jitter_is_absorbed() -> void:
	var buffer := SnapshotBuffer.new(DELAY)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4004
	var arrivals: Array = []  # [yerel varış, gönderen anı]
	for i: int in 120:
		var sent: float = i * SEND_INTERVAL
		arrivals.append([100.0 + sent + 0.075 + rng.randf_range(-0.03, 0.03), sent])
	arrivals.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var next: int = 0
	var previous: Vector2 = Vector2.INF
	var worst_step: float = 0.0
	var backwards: int = 0
	var lags: Array[float] = []
	var underruns_after_warmup: int = -1
	var frame_dt: float = 1.0 / 60.0
	var local: float = 100.0
	while local < 100.0 + 5.5:
		while next < arrivals.size() and float(arrivals[next][0]) <= local:
			var sent: float = arrivals[next][1]
			buffer.push(sent, arrivals[next][0], Vector2(SPEED * sent, 0), Vector2.RIGHT, 0)
			next += 1
		var frame: SnapshotBuffer.Frame = buffer.sample(local)
		if frame == null:
			local += frame_dt
			continue
		if local > 101.0:
			if underruns_after_warmup < 0:
				underruns_after_warmup = buffer.underrun_count()
			var step: float = frame.position.x - previous.x
			if step < -0.0001:
				backwards += 1
			worst_step = maxf(worst_step, absf(step - SPEED * frame_dt))
			lags.append((local - 100.0) - frame.position.x / SPEED)
		previous = frame.position
		local += frame_dt
	eq(backwards, 0, "çizim geri gitmez")
	is_true(worst_step < SPEED * frame_dt * 0.25, "kare başı adım sabite yakın (en kötü sapma %.3f px)" % worst_step)
	var mean_lag: float = 0.0
	for lag: float in lags:
		mean_lag += lag / lags.size()
	near(mean_lag, 0.075 + DELAY, 0.02, "gecikme ≈ ortalama ağ + tampon")
	eq(buffer.underrun_count() - underruns_after_warmup, 0, "±30 ms titreşimde tampon tükenmez")
