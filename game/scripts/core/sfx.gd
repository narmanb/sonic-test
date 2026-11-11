extends Node
## Tiny procedural sound bank: every effect is synthesised at start-up so the
## project ships without any third-party audio.

const RATE := 22050
var bank := {}
var pool: Array[AudioStreamPlayer] = []
var idx := 0
var loops := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	bank["jump"] = _tone(0.16, 320, 760, 0.5, 0.0)
	bank["djump"] = _tone(0.14, 520, 1040, 0.45, 0.0)
	bank["spark"] = _tone(0.09, 1500, 2100, 0.35, 0.0)
	bank["boost"] = _tone(0.45, 180, 900, 0.5, 0.6)
	bank["spring"] = _tone(0.3, 300, 1300, 0.5, 0.0, 14.0)
	bank["hit"] = _tone(0.22, 260, 70, 0.7, 0.7)
	bank["homing"] = _tone(0.13, 700, 1700, 0.4, 0.15)
	bank["stomp"] = _tone(0.35, 150, 40, 0.9, 0.5)
	bank["charge"] = _tone(0.25, 240, 520, 0.4, 0.1, 30.0)
	bank["release"] = _tone(0.3, 900, 250, 0.5, 0.5)
	bank["token"] = _arp([660, 880, 1100, 1320, 1760], 0.09)
	bank["hurt"] = _tone(0.4, 600, 150, 0.6, 0.3, 20.0)
	bank["check"] = _arp([523, 784, 1046], 0.1)
	bank["pad"] = _tone(0.25, 400, 1200, 0.5, 0.4)
	bank["switch"] = _arp([440, 660], 0.08)
	bank["shoot"] = _tone(0.18, 900, 300, 0.4, 0.2)
	bank["warn"] = _arp([880, 880, 880], 0.07)
	bank["break"] = _tone(0.4, 200, 60, 0.8, 0.9)
	bank["win"] = _arp([523, 659, 784, 1046, 1318, 1568], 0.12)
	bank["grind"] = _tone(0.5, 1800, 1700, 0.18, 0.9)
	bank["wind"] = _tone(1.0, 90, 90, 0.0, 1.0)

func _tone(dur: float, f0: float, f1: float, vol: float, noise: float, vib: float = 0.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		if vib > 0.0:
			f *= 1.0 + 0.08 * sin(t * dur * vib * TAU)
		ph += f / RATE
		var s := sin(ph * TAU) * (1.0 - noise) * vol
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)
		s += lp * noise * maxf(vol, 0.5)
		var env := minf(1.0, t * 30.0) * pow(1.0 - t, 1.5)
		data.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 30000.0))
	return _wav(data)

func _arp(freqs: Array, step: float) -> AudioStreamWAV:
	var n := int((freqs.size() * step + 0.25) * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in freqs.size():
			var lt := t - k * step
			if lt >= 0.0:
				s += sin(lt * float(freqs[k]) * TAU) * exp(-lt * 9.0) * 0.35
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	return _wav(data)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w

func play(sound: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not bank.has(sound):
		return
	var p := pool[idx]
	idx = (idx + 1) % pool.size()
	p.stream = bank[sound]
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()

## Continuous loop (wind / grind) whose volume follows `level` 0..1.
func loop(sound: String, level: float, pitch: float = 1.0) -> void:
	if not bank.has(sound):
		return
	var p: AudioStreamPlayer = loops.get(sound)
	if p == null:
		p = AudioStreamPlayer.new()
		var w: AudioStreamWAV = bank[sound].duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_PINGPONG
		w.loop_end = w.data.size() / 2
		p.stream = w
		add_child(p)
		loops[sound] = p
	if level <= 0.01:
		if p.playing:
			p.stop()
		return
	p.volume_db = linear_to_db(level)
	p.pitch_scale = pitch
	if not p.playing:
		p.play()
