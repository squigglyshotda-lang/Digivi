extends Node2D
## Digivi, stage A: world, egg, baby, needs, touch.
## A direct port of the web prototype. Everything is drawn as 1-pixel rectangles
## on a 108x192 canvas that Godot scales up, so the look matches the prototype.

const W := 108
const H := 192
const GROUND := 133
const INK := Color("#1a1330")
const SAVE_PATH := "user://pet.json"
const CHILD_XP := 900.0
const BODY := {"baby": Color("#8be8c9"), "child": Color("#8be8c9")}
const MARKCOL := {
	"happy": Color("#ffb347"), "calm": Color("#ffe08a"), "excited": Color("#fff7a0"),
	"sad": Color("#5aa0ff"), "sleepy": Color("#9a8ae6"), "startled": Color("#ffffff"), "dizzy": Color("#ff9ad9"),
}
const SKY := [
	[0.0, Color("#0b0f2e"), Color("#1c1a4a")], [5.0, Color("#1a1f4d"), Color("#5a3b6e")],
	[7.0, Color("#6fa8ff"), Color("#ffb98a")], [12.0, Color("#4aa0ff"), Color("#bfe6ff")],
	[17.0, Color("#5b8fe0"), Color("#ffc27a")], [19.0, Color("#4a3c8a"), Color("#ff8a6b")],
	[21.0, Color("#171a45"), Color("#2c2560")], [24.0, Color("#0b0f2e"), Color("#1c1a4a")],
]
const HEART := [".#.#.", "#####", "#####", ".###.", "..#.."]
const ZZ := ["###", "..#", ".#.", "#..", "###"]
const PLUS := [".#.", "###", ".#."]
const CRACK := [[0, -13], [1, -12], [0, -11], [-1, -10], [0, -9], [1, -8], [2, -7], [1, -6], [0, -5], [-1, -4], [-2, -3], [-3, -2], [-4, -1], [-3, 0], [-2, 1], [-1, 2], [0, 3], [1, 4], [2, 5], [3, 6]]

# ---------------------------------------------------------------- state
var S := {}
var t := 0.0
var acc := 0.0
var save_acc := 0.0
var squish := 1.0
var startle := 0.0
var happy := 0.0
var excited := 0.0
var dance := 0.0
var wake := 0.0
var funny := 0.0
var egg_shake := 0.0
var pet_x := 54.0
var pet_tx := 54.0
var pet_dir := 1.0
var act := "rest"
var act_t := 1.0
var eat_t := 0.0
var food: Array = []
var parts: Array = []
var bbox := Rect2()
var has_bbox := false
var touching := false
var stroke_len := 0.0
var moved := 0.0
var last_p := Vector2.ZERO
var look_x := 0.0
var spark_acc := 0.0
var dbg_hour := -1.0
var dbg_neglect := ""
var ga := 1.0
var mute := false
var hint_key := ""
var namer_shown := false

# sky cache
var sky_img: Image
var sky_tex: ImageTexture
var sky_stamp := -999.0
var stars: Array = []

# ui
var title_l: Label
var hint_l: Label
var toast_l: Label
var toast_t := 0.0
var new_egg_b: Button
var namer: Panel
var name_edit: LineEdit
var name_go: Button
var dbg_panel: PanelContainer
var players: Array = []
var player_i := 0


func fresh() -> Dictionary:
	return {
		"stage": "egg", "name": "", "taps": 0,
		"xp": {"exp": 0.0, "cud": 0.0, "che": 0.0, "slp": 0.0},
		"needs": {"hun": 70.0, "aff": 70.0, "ene": 80.0, "cur": 60.0},
		"steps": 0, "faces": 0, "places": [], "neglectH": 0.0, "last": Time.get_unix_time_from_system(),
	}


func load_state() -> void:
	S = fresh()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				S[k] = d[k]


func save_state() -> void:
	S["last"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(S))


# -------------------------------------------------------------- helpers
func mixc(a: Color, b: Color, k: float) -> Color:
	return a.lerp(b, k)


func px(x: float, y: float, c: Color) -> void:
	if ga < 1.0:
		c.a *= ga
	draw_rect(Rect2(roundf(x), roundf(y), 1, 1), c)


func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	if ga < 1.0:
		c.a *= ga
	draw_rect(Rect2(roundf(x), roundf(y), w, h), c)


func disc(cx: float, cy: float, r: int, c: Color) -> void:
	cx = roundf(cx)
	cy = roundf(cy)
	for y in range(-r, r + 1):
		var w := int(floorf(sqrt(r * r - y * y + 0.5)))
		rect(cx - w, cy + y, w * 2 + 1, 1, c)


func ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	cx = roundf(cx)
	cy = roundf(cy)
	var iry := int(ry)
	for y in range(-iry, iry + 1):
		var w := int(floorf(rx * sqrt(maxf(0.0, 1.0 - (y * y) / (ry * ry + 0.01))) + 0.5))
		rect(cx - w, cy + y, w * 2 + 1, 1, c)


func bitmap(x: float, y: float, rows: Array, c: Color) -> void:
	x = roundf(x)
	y = roundf(y)
	for j in rows.size():
		var r: String = rows[j]
		for i in r.length():
			if r[i] == "#":
				px(x + i, y + j, c)


func rnd(a: float, b: float) -> float:
	return randf_range(a, b)


# ------------------------------------------------------------ clock / sky
func hour_now() -> float:
	if dbg_hour >= 0.0:
		return dbg_hour
	var d := Time.get_time_dict_from_system()
	return float(d["hour"]) + float(d["minute"]) / 60.0


func is_night() -> bool:
	var h := hour_now()
	return h >= 21.0 or h < 6.0


func sky_at(h: float) -> Array:
	for i in SKY.size() - 1:
		var a: Array = SKY[i]
		var b: Array = SKY[i + 1]
		if h >= a[0] and h <= b[0]:
			var k: float = (h - a[0]) / (b[0] - a[0])
			return [mixc(a[1], b[1], k), mixc(a[2], b[2], k)]
	return [SKY[0][1], SKY[0][2]]


func nightness(h: float) -> float:
	if h >= 21.0 or h < 5.0:
		return 1.0
	if h < 7.0:
		return (7.0 - h) / 2.0
	if h >= 19.0:
		return (h - 19.0) / 2.0
	return 0.0


func rebuild_sky(h: float) -> void:
	var cols := sky_at(h)
	var top: Color = cols[0]
	var bot: Color = cols[1]
	var bands := ceili(H / 4.0)
	for i in bands:
		var c1 := mixc(top, bot, minf(1.0, i / (bands * 0.8)))
		var c2 := mixc(top, bot, minf(1.0, (i + 1) / (bands * 0.8)))
		for y in 4:
			for x in W:
				var yy: int = i * 4 + y
				if yy >= H:
					continue
				sky_img.set_pixel(x, yy, c2 if (y == 3 and x % 2 == i % 2) else c1)
	sky_tex.update(sky_img)
	sky_stamp = h


# ----------------------------------------------------------------- needs
func decay(h: float, away: bool) -> void:
	var n: Dictionary = S["needs"]
	n["hun"] = clampf(n["hun"] - 3.0 * h, 0, 100)
	n["aff"] = clampf(n["aff"] - 3.0 * h, 0, 100)
	n["cur"] = clampf(n["cur"] - 2.0 * h, 0, 100)
	if away:
		n["ene"] = clampf(n["ene"] + 6.0 * h, 0, 100)
	else:
		n["ene"] = clampf(n["ene"] + (10.0 if is_sleeping() else -3.0) * h, 0, 100)
	var avg: float = (n["hun"] + n["aff"] + n["cur"]) / 3.0
	if avg < 30.0:
		S["neglectH"] += h
	else:
		S["neglectH"] = maxf(0.0, S["neglectH"] - h * 2.0)
	S["neglectH"] = minf(S["neglectH"], 400.0)


func is_sleeping() -> bool:
	return S["stage"] != "egg" and wake <= 0.0 and (S["needs"]["ene"] < 18.0 or (is_night() and S["needs"]["ene"] < 92.0))


func neglect_state() -> String:
	if S["stage"] == "egg":
		return "ok"
	if dbg_neglect != "":
		return dbg_neglect
	var n: float = S["neglectH"]
	if n >= 168.0:
		return "lost"
	if n >= 36.0:
		return "away"
	if n >= 12.0:
		return "dormant"
	if (S["needs"]["hun"] + S["needs"]["aff"] + S["needs"]["cur"]) / 3.0 < 35.0:
		return "sad"
	return "ok"


func wake_from_neglect() -> void:
	var s := neglect_state()
	if s == "dormant" or s == "away":
		S["neglectH"] = minf(S["neglectH"], 6.0)
		dbg_neglect = ""


func mood() -> String:
	if funny > 0.0:
		return "dizzy"
	if startle > 0.0:
		return "startled"
	if excited > 0.0:
		return "excited"
	var ns := neglect_state()
	if ns == "dormant" or is_sleeping():
		return "sleepy"
	if ns == "sad":
		return "sad"
	if happy > 0.0:
		return "happy"
	var n: Dictionary = S["needs"]
	var avg: float = (n["hun"] + n["aff"] + n["cur"]) / 3.0
	if avg < 35.0:
		return "sad"
	if n["ene"] < 25.0:
		return "sleepy"
	return "happy" if avg > 65.0 else "calm"


func need(k: String, d: float) -> void:
	S["needs"][k] = clampf(S["needs"][k] + d, 0, 100)


# ----------------------------------------------------------------- audio
func make_players() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func sfx(freq: float, dur: float, kind: String = "square", vol: float = 0.04, slide: float = 0.0) -> void:
	if mute or players.is_empty():
		return
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += (freq + slide * k) / rate
		var ph := fposmod(phase, 1.0)
		var v := 0.0
		match kind:
			"square":
				v = 1.0 if ph < 0.5 else -1.0
			"triangle":
				v = 4.0 * absf(ph - 0.5) - 1.0
			"sawtooth":
				v = 2.0 * ph - 1.0
			_:
				v = sin(ph * TAU)
		v *= vol * 6.0 * (1.0 - k)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	var p: AudioStreamPlayer = players[player_i]
	player_i = (player_i + 1) % players.size()
	p.stream = w
	p.play()


func chirp() -> void:
	sfx(rnd(520, 760), 0.12, "square", 0.035, rnd(120, 300))


func boing() -> void:
	sfx(220, 0.22, "triangle", 0.07, 260)


# ------------------------------------------------------------- particles
func add_part(kind: String, x: float, y: float, vx: float, vy: float, life: float, c: Color = Color.WHITE) -> void:
	parts.append({"kind": kind, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "max": life, "c": c})


func burst(x: float, y: float, n: int, cols: Array, spd: float) -> void:
	for i in n:
		var a := rnd(0.0, TAU)
		var s := rnd(spd * 0.4, spd)
		add_part("px", x, y, cos(a) * s, sin(a) * s - spd * 0.3, rnd(0.6, 1.3), cols[i % cols.size()])


func update_parts(dt: float) -> void:
	for p in parts:
		p["life"] -= dt
		p["x"] += p["vx"] * dt
		p["y"] += p["vy"] * dt
		if p["kind"] == "px":
			p["vy"] += 60.0 * dt
	parts = parts.filter(func(p): return p["life"] > 0.0)


func draw_parts() -> void:
	for p in parts:
		ga = clampf(p["life"] / p["max"] * 1.6, 0.0, 1.0)
		match p["kind"]:
			"heart":
				bitmap(p["x"] - 2, p["y"] - 2, HEART, Color("#ff7ac8"))
			"z":
				bitmap(p["x"] - 1, p["y"] - 2, ZZ, Color("#cfc9ff"))
			_:
				px(p["x"], p["y"], p["c"])
	ga = 1.0


# --------------------------------------------------------------- scenery
func draw_island(cx: float, y: float, w: int, gcol: Color, rcol: Color, depth: int, n: float) -> void:
	var night := Color("#10153a")
	var gc := mixc(gcol, night, n * 0.55)
	var rc := mixc(rcol, night, n * 0.5)
	for i in depth:
		var ww := roundi(w * (1.0 - float(i) / depth) * 0.95) + 1
		rect(cx - ww, y + 3 + i, ww * 2, 1, mixc(rc, Color.BLACK, 0.2) if i % 3 == 0 else rc)
	ell(cx, y + 1, w, 3, mixc(gc, Color.BLACK, 0.3))
	ell(cx, y, w, 3, gc)
	var i := -w + 3
	while i < w - 2:
		px(cx + i, y - 2, mixc(gc, Color.WHITE, 0.25))
		i += 6


func cloud(x: float, y: float, c: Color) -> void:
	ell(x, y, 8, 3, c)
	ell(x - 5, y + 1, 5, 2, c)
	ell(x + 6, y + 1, 5, 2, c)
	ell(x + 1, y - 2, 5, 3, c)


func draw_world() -> void:
	var h := hour_now()
	var n := nightness(h)
	if absf(h - sky_stamp) > 0.03 or sky_stamp < 0.0:
		rebuild_sky(h)
	draw_texture(sky_tex, Vector2.ZERO)
	var cols := sky_at(h)
	var top: Color = cols[0]
	var bot: Color = cols[1]
	if n > 0.15:
		ga = n
		for s in stars:
			if sin(t * 2.0 + s[2]) > -0.5:
				px(s[0], s[1], Color.WHITE)
		ga = 1.0
	var day := h >= 6.0 and h < 18.0
	var f := (h - 6.0) / 12.0 if day else ((h - 18.0 if h >= 18.0 else h + 6.0) / 12.0)
	var sx := roundf(10.0 + (W - 20) * f)
	var sy := roundf(78.0 - sin(PI * f) * 54.0)
	if day:
		disc(sx, sy, 6, Color("#ffe28a"))
		disc(sx, sy, 4, Color("#fff6c8"))
	else:
		disc(sx, sy, 5, Color("#f2f0ff"))
		disc(sx + 2, sy - 1, 4, mixc(top, bot, sy / H))
	var cc := mixc(Color.WHITE, top, n * 0.75)
	for i in 3:
		cloud(fposmod(t * (2.5 + i * 1.3) + i * 53.0, W + 40.0) - 20.0, 26 + i * 24, cc)
	draw_island(12, 110 + sin(t * 0.6) * 2, 9, Color("#7fe0a0"), Color("#7a6aa6"), 7, n)
	draw_island(98, 104 + sin(t * 0.5 + 2.0) * 2, 8, Color("#7fe0a0"), Color("#7a6aa6"), 6, n)
	draw_island(54, GROUND, 48, Color("#5fcf8a"), Color("#7a6aa6"), 26, n)
	for fd in food:
		disc(fd["x"], roundf(fd["y"]), 1, Color("#ff5a6e"))
		px(fd["x"] + 1, fd["y"] - 2, Color("#4fc47e"))


# ------------------------------------------------------------------- pet
func draw_mark(cx: float, y: float, col: Color) -> void:
	var w := 3
	ga = 0.25 + 0.12 * sin(t * 3.0)
	disc(cx, y + 1.5, 4, col)
	ga = 1.0
	bitmap(cx - w / 2.0, y, PLUS, col)
	px(cx, y + 1, Color.WHITE)


func blob_shape(cx: float, cy: float, rx: float, ry: float, wob: float, col: Color) -> void:
	for y in range(-int(ry), int(ry) + 1):
		var k := sqrt(maxf(0.0, 1.0 - (y * y) / (ry * ry + 0.01)))
		var w := maxi(0, roundi(rx * k * (1.0 + wob * sin(t * 2.6 + y * 0.55))))
		var off := roundi(wob * 3.0 * sin(t * 1.9 + y * 0.3))
		rect(cx - w + off, cy + y, w * 2 + 1, 1, col)


func draw_eye(ex: float, ey: float, kind: String, s: int, lx: int) -> void:
	match kind:
		"open":
			rect(ex - 1 + lx, ey, 2, 3, INK)
			px(ex - 1 + lx, ey, Color.WHITE)
		"happy":
			px(ex - 2, ey + 2, INK)
			px(ex - 1, ey + 1, INK)
			px(ex, ey + 1, INK)
			px(ex + 1, ey + 2, INK)
		"closed":
			rect(ex - 2, ey + 1, 4, 1, INK)
		"startled":
			rect(ex - 2, ey - 1, 4, 5, Color.WHITE)
			rect(ex - 1 + lx, ey + 1, 2, 2, INK)
		"excited":
			px(ex, ey, INK)
			px(ex - 1, ey + 1, INK)
			px(ex, ey + 1, INK)
			px(ex + 1, ey + 1, INK)
			px(ex, ey + 2, INK)
		"sad":
			rect(ex - 1 + lx, ey + 1, 2, 3, INK)
			px(ex - 1 + lx, ey + 1, Color.WHITE)
			if s < 0:
				px(ex - 2, ey, INK)
				px(ex - 1, ey - 1, INK)
			else:
				px(ex + 1, ey, INK)
				px(ex, ey - 1, INK)
		"dizzy":
			px(ex - 1, ey, INK)
			px(ex + 1, ey, INK)
			px(ex, ey + 1, INK)
			px(ex - 1, ey + 2, INK)
			px(ex + 1, ey + 2, INK)


func draw_face(cx: float, cy: float, rx: float, ry: float, m: String) -> void:
	var sp := maxi(3, roundi(rx * 0.42))
	var ey := cy - roundi(ry * 0.3)
	var my := cy + roundi(ry * 0.08)
	var blink := int(floorf(t * 10.0)) % 47 == 0
	var kind: String = {"happy": "happy", "calm": "open", "excited": "excited", "sad": "sad", "sleepy": "closed", "startled": "startled", "dizzy": "dizzy"}[m]
	if blink and kind == "open":
		kind = "closed"
	var lx := roundi(look_x)
	draw_eye(cx - sp, ey, kind, -1, lx)
	draw_eye(cx + sp, ey, kind, 1, lx)
	var mc := Color("#7a2a4a")
	if m == "excited":
		rect(cx - 1, my, 3, 2, mc)
	elif m == "happy":
		px(cx - 2, my, INK)
		px(cx + 2, my, INK)
		rect(cx - 1, my + 1, 3, 1, INK)
	elif m == "calm":
		rect(cx - 1, my + 1, 3, 1, INK)
	elif m == "sad":
		px(cx - 2, my + 2, INK)
		rect(cx - 1, my + 1, 3, 1, INK)
		px(cx + 2, my + 2, INK)
	elif m == "startled":
		rect(cx - 1, my, 2, 2, mc)
	elif m == "dizzy":
		px(cx - 2, my + 1, INK)
		px(cx - 1, my, INK)
		px(cx, my + 1, INK)
		px(cx + 1, my, INK)
		px(cx + 2, my + 1, INK)
	if m == "happy" or m == "excited":
		px(cx - sp - 2, my, Color("#ff9aa8"))
		px(cx + sp + 2, my, Color("#ff9aa8"))


func draw_egg(cx: float, gy: float, mc: Color) -> void:
	var rx := 11
	var ry := 14
	var cy := gy - ry - 1
	var tilt := sin(t * 40.0) * minf(1.0, egg_shake) * 1.8 if egg_shake > 0.0 else sin(t * 1.5) * 0.15
	var shell := Color("#f4ecff")
	var shade := Color("#d9ccf0")
	ell(cx, gy + 1, rx, 2, Color(0, 0, 0, 0.3))
	for pass_i in 2:
		var e := 1 if pass_i == 0 else 0
		for y in range(-ry - e, ry + e + 1):
			var k := sqrt(maxf(0.0, 1.0 - (y * y) / float((ry + e) * (ry + e))))
			var w := roundi((rx + e) * k * (0.78 + 0.3 * ((y + ry) / float(2 * ry))))
			var off := roundi(-tilt * (y / float(ry)) * 3.0)
			var c := INK if pass_i == 0 else (shade if y > ry * 0.4 else shell)
			rect(cx - w + off, cy + y, w * 2 + 1, 1, c)
	var spots := [[-4, -6], [3, -2], [-3, 3], [5, 6]]
	for i in 4:
		ga = 0.5 + 0.5 * sin(t * 2.0 + i)
		disc(cx + spots[i][0], cy + spots[i][1], 1, mc)
	ga = 1.0
	var n := mini(CRACK.size(), int(S["taps"]) * 4)
	for i in n:
		px(cx + CRACK[i][0], cy + CRACK[i][1], Color("#5a4a86"))
	bbox = Rect2(cx - rx, cy - ry, rx * 2, ry * 2 + 15)
	has_bbox = true


func dims(stage: String) -> Vector2:
	return Vector2(9, 8) if stage == "baby" else Vector2(11, 10)


func draw_pet(stage: String, x: float, gy: float, sq: float, dormant: bool, still: bool) -> void:
	var m := mood()
	var mc: Color = MARKCOL.get(m, Color("#ffe08a"))
	if stage == "egg":
		draw_egg(roundf(x), gy, mc)
		return
	var d := dims(stage)
	var hop := 0.0
	if not still:
		if dance > 0.0:
			hop = absf(sin(t * 9.0)) * 5.0
		elif startle > 0.0:
			hop = maxf(0.0, sin(startle * 12.0)) * 6.0
		elif act == "toy" and absf(pet_x - pet_tx) < 3.0:
			hop = absf(sin(t * 6.0)) * 3.0
		if funny > 0.0:
			hop = absf(sin(t * 8.0)) * 4.0
	var rx := roundi(d.x / sqrt(sq))
	var ry := roundi(d.y * sq)
	var bob := 0.0 if still else sin(t * 3.0)
	var cx := roundf(x)
	var cy := roundf(gy - ry - hop - bob)
	var col: Color = BODY[stage]
	if dormant:
		col = mixc(col, Color("#8a86a8"), 0.4)
	var belly := mixc(col, Color.WHITE, 0.35)
	ga = 0.28
	ell(cx, gy + 1, roundi(rx * 0.9), 2, Color.BLACK)
	ga = 1.0
	var wob := 0.14 if stage == "child" else 0.04
	blob_shape(cx, cy, rx + 1, ry + 1, wob, INK)
	blob_shape(cx, cy, rx, ry, wob, col)
	blob_shape(cx, cy + roundi(ry * 0.35), roundi(rx * 0.62), roundi(ry * 0.5), wob, belly)
	var hl := mixc(col, Color.WHITE, 0.7)
	px(cx - roundi(rx * 0.5), cy - roundi(ry * 0.55), hl)
	px(cx - roundi(rx * 0.5) + 1, cy - roundi(ry * 0.55), hl)
	draw_face(cx, cy, rx, ry, m)
	draw_mark(cx, cy + roundi(ry * 0.4), mc)
	bbox = Rect2(cx - rx - 2, cy - ry - 4, rx * 2 + 4, ry + 4 + (gy - cy))
	has_bbox = true


# --------------------------------------------------------------- actions
func toast(msg: String) -> void:
	toast_l.text = msg
	toast_l.modulate.a = 1.0
	toast_t = 2.6


func spawn_food() -> void:
	food.append({"x": rnd(20, 88), "y": 0.0})


func eat_food() -> void:
	need("hun", 8)
	happy = 2.0
	chirp()
	for i in 3:
		add_part("heart", pet_x + rnd(-6, 6), GROUND - 18, rnd(-4, 4), -14, 1.2)


func stroke() -> void:
	need("aff", 2)
	S["xp"]["cud"] += 1.0
	happy = 2.5
	wake = 30.0
	squish = 0.86
	S["neglectH"] = maxf(0.0, S["neglectH"] - 0.5)
	if neglect_state() == "dormant":
		wake_from_neglect()
	add_part("heart", pet_x + rnd(-8, 8), GROUND - 22, rnd(-3, 3), -14, 1.1)
	if randf() < 0.4:
		sfx(rnd(300, 380), 0.18, "sine", 0.05, 60)


func tap() -> void:
	if S["stage"] == "egg":
		S["taps"] += 1
		egg_shake = 0.6
		sfx(200 + S["taps"] * 60, 0.12, "square", 0.05, 0)
		if S["taps"] >= 5:
			start_hatch()
		save_state()
		return
	squish = 0.8
	wake = 15.0
	happy = 1.2
	boing()
	need("aff", 0.5)
	wake_from_neglect()


func start_hatch() -> void:
	S["stage"] = "baby"
	S["taps"] = 0
	funny = 2.2
	squish = 1.3
	pet_x = 54.0
	pet_tx = 54.0
	burst(54, GROUND - 14, 22, [Color("#f4ecff"), Color("#d9ccf0"), Color("#fff7a0"), Color("#ff9ad9")], 55.0)
	boing()
	get_tree().create_timer(0.16).timeout.connect(func(): sfx(880, 0.2, "square", 0.05, 300))
	save_state()


func new_egg() -> void:
	S = fresh()
	namer_shown = false
	dbg_neglect = ""
	food.clear()
	save_state()


# ------------------------------------------------------------------ loop
func tick_1s() -> void:
	if S["stage"] != "egg":
		decay(1.0 / 3600.0, false)
		if is_sleeping():
			S["xp"]["slp"] += 1.0 / 60.0
	if dance > 0.0:
		need("aff", 0.3)


func update_pet(dt: float) -> void:
	var ns := neglect_state()
	if S["stage"] == "egg" or ns == "away" or ns == "lost":
		return
	if is_sleeping() or ns == "dormant":
		act = "rest"
		return
	var busy := dance > 0.0 or startle > 0.0
	if not busy:
		act_t -= dt
		var landed = null
		for f in food:
			if f["y"] >= GROUND + 3:
				landed = f
				break
		if landed != null:
			act = "food"
			pet_tx = landed["x"]
			if absf(pet_x - landed["x"]) < 3.0:
				eat_t += dt
				if eat_t > 0.6:
					food.erase(landed)
					eat_t = 0.0
					eat_food()
					act_t = 0.0
		elif act_t <= 0.0:
			act_t = rnd(2.5, 6.0)
			var r := randf()
			if r < 0.75:
				act = "wander"
				pet_tx = rnd(22, 86)
			else:
				act = "rest"
	var speed := 16.0 if act == "food" else 10.0
	if act != "rest":
		var dx := pet_tx - pet_x
		if absf(dx) > 1.0:
			pet_x += signf(dx) * minf(absf(dx), speed * dt)
			pet_dir = signf(dx)


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	for k in ["startle", "happy", "excited", "dance", "wake", "funny", "egg_shake"]:
		if get(k) > 0.0:
			set(k, maxf(0.0, get(k) - dt))
	squish += (1.0 - squish) * minf(1.0, dt * 8.0)
	if funny > 0.0:
		squish = 1.0 + 0.22 * sin(t * 14.0) * (funny / 2.2)
	look_x *= 0.9
	update_parts(dt)
	for fd in food:
		fd["y"] = minf(GROUND + 4.0, fd["y"] + 70.0 * dt)
	update_pet(dt)
	acc += dt
	while acc >= 1.0:
		acc -= 1.0
		tick_1s()
	save_acc += dt
	if save_acc > 5.0:
		save_acc = 0.0
		save_state()
	if S["stage"] != "egg" and S["name"] == "" and not namer_shown and funny <= 0.0:
		show_namer()
	if toast_t > 0.0:
		toast_t -= dt
		if toast_t <= 0.0:
			toast_l.modulate.a = 0.0
	update_hud()
	queue_redraw()
	if shot_dir != "":
		shot_tick()


func _draw() -> void:
	draw_world()
	has_bbox = false
	var ns := neglect_state()
	if ns != "away" and ns != "lost":
		var dormant := ns == "dormant"
		draw_pet(S["stage"], pet_x, GROUND + 1, 0.82 if dormant else squish, dormant, dormant or is_sleeping())
	elif ns == "lost":
		ell(54, GROUND + 1, 14, 3, Color("#7a5a3a"))
		ell(54, GROUND, 12, 2, Color("#a07a4a"))
	if S["stage"] != "egg" and (is_sleeping() or ns == "dormant") and randf() < 0.01:
		add_part("z", pet_x + 8, GROUND - 24, 4, -8, 1.8)
	draw_parts()


# ----------------------------------------------------------------- input
func in_box(p: Vector2) -> bool:
	return has_bbox and bbox.has_point(p)


func _unhandled_input(e: InputEvent) -> void:
	if namer.visible:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			last_p = e.position
			moved = 0.0
			stroke_len = 0.0
			touching = in_box(e.position)
		else:
			if touching and moved < 5.0:
				tap()
			touching = false
	elif e is InputEventMouseMotion and touching:
		var d := (e.position as Vector2).distance_to(last_p)
		last_p = e.position
		moved += d
		if S["stage"] == "egg":
			return
		if in_box(e.position):
			stroke_len += d
			look_x = clampf((e.position.x - pet_x) / 6.0, -1.0, 1.0)
			if stroke_len > 14.0:
				stroke_len = 0.0
				stroke()


# -------------------------------------------------------------------- UI
func make_label(size: int, y: float, h: float) -> Label:
	var l := Label.new()
	l.position = Vector2(4, y)
	l.size = Vector2(W - 8, h)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	title_l = make_label(9, 3, 14)
	ui.add_child(title_l)
	toast_l = make_label(6, 17, 22)
	toast_l.modulate.a = 0.0
	ui.add_child(toast_l)
	hint_l = make_label(6, 150, 36)
	hint_l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ui.add_child(hint_l)
	new_egg_b = Button.new()
	new_egg_b.text = "Find a new egg"
	new_egg_b.add_theme_font_size_override("font_size", 6)
	new_egg_b.position = Vector2(24, 128)
	new_egg_b.size = Vector2(60, 12)
	new_egg_b.visible = false
	new_egg_b.pressed.connect(new_egg)
	ui.add_child(new_egg_b)

	namer = Panel.new()
	namer.position = Vector2(8, 70)
	namer.size = Vector2(92, 52)
	namer.visible = false
	ui.add_child(namer)
	var nl := Label.new()
	nl.text = "What will you call it?"
	nl.position = Vector2(4, 4)
	nl.size = Vector2(84, 10)
	nl.add_theme_font_size_override("font_size", 6)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	namer.add_child(nl)
	name_edit = LineEdit.new()
	name_edit.position = Vector2(6, 17)
	name_edit.size = Vector2(80, 14)
	name_edit.max_length = 14
	name_edit.placeholder_text = "Type a name"
	name_edit.add_theme_font_size_override("font_size", 7)
	name_edit.text_changed.connect(func(s: String): name_go.disabled = s.strip_edges() == "")
	name_edit.text_submitted.connect(func(_s: String): submit_name())
	namer.add_child(name_edit)
	name_go = Button.new()
	name_go.text = "Name it"
	name_go.position = Vector2(26, 34)
	name_go.size = Vector2(40, 13)
	name_go.disabled = true
	name_go.add_theme_font_size_override("font_size", 6)
	name_go.pressed.connect(submit_name)
	namer.add_child(name_go)

	# debug panel
	var db := Button.new()
	db.text = "dbg"
	db.add_theme_font_size_override("font_size", 5)
	db.position = Vector2(W - 16, 2)
	db.size = Vector2(14, 9)
	ui.add_child(db)
	dbg_panel = PanelContainer.new()
	dbg_panel.position = Vector2(W - 62, 12)
	dbg_panel.visible = false
	ui.add_child(dbg_panel)
	var vb := VBoxContainer.new()
	dbg_panel.add_child(vb)
	var items := [
		["Drop food", func(): spawn_food()],
		["Hatch now", func(): if S["stage"] == "egg": start_hatch()],
		["Needs low", func(): set_needs(10.0)],
		["Needs full", func(): set_needs(100.0)],
		["Sad", func(): dbg_neglect = "sad"],
		["Dormant", func(): dbg_neglect = "dormant"],
		["Run away", func(): dbg_neglect = "away"],
		["Lost", func(): dbg_neglect = "lost"],
		["Auto neglect", func(): dbg_neglect = ""],
		["Hour +3", func(): dbg_hour = fposmod((hour_now() if dbg_hour < 0.0 else dbg_hour) + 3.0, 24.0)],
		["Real clock", func(): dbg_hour = -1.0],
		["Sound", func(): mute = not mute],
		["Reset all", func(): new_egg()],
	]
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.add_theme_font_size_override("font_size", 5)
		b.custom_minimum_size = Vector2(50, 8)
		b.pressed.connect(it[1])
		vb.add_child(b)
	db.pressed.connect(func(): dbg_panel.visible = not dbg_panel.visible)


func set_needs(v: float) -> void:
	for k in ["hun", "aff", "cur"]:
		S["needs"][k] = v
	if v >= 100.0:
		S["needs"]["ene"] = 100.0
		S["neglectH"] = 0.0
		dbg_neglect = ""


func show_namer() -> void:
	namer_shown = true
	namer.visible = true
	name_edit.grab_focus()


func submit_name() -> void:
	var v := name_edit.text.strip_edges()
	if v == "":
		return
	S["name"] = v
	namer.visible = false
	name_edit.release_focus()
	chirp()
	save_state()


func update_hud() -> void:
	var ns := neglect_state()
	var key := ""
	var txt := ""
	var lost := false
	if S["stage"] == "egg":
		key = "egg"
		txt = "Keep tapping." if S["taps"] > 0 else "Tap the egg."
	elif ns == "lost":
		key = "lost"
		txt = "%s has gone." % (S["name"] if S["name"] != "" else "It")
		lost = true
	elif ns == "away":
		key = "away"
		txt = "%s wandered off. Walk with your phone to bring it back." % (S["name"] if S["name"] != "" else "It")
	elif ns == "dormant":
		key = "dormant"
		txt = "%s is curled up asleep. Stroke it to wake it." % (S["name"] if S["name"] != "" else "It")
	var k2: String = key + str(S["taps"]) + str(S["name"])
	if k2 != hint_key:
		hint_key = k2
		hint_l.text = txt
	new_egg_b.visible = lost
	title_l.text = "Egg" if S["stage"] == "egg" else (S["name"] if S["name"] != "" else "New pet")


# ----------------------------------------------------- test screenshots
var shot_dir := OS.get_environment("DIGIVI_SHOT")
var shot_n := 0


func shot_tick() -> void:
	shot_n += 1
	match shot_n:
		20: save_shot("egg")
		21: tap(); tap(); tap(); tap(); tap()
		60: save_shot("baby")
		61:
			S["name"] = "Pip"
			namer.visible = false
			spawn_food()
		120: save_shot("food")
		121: set_needs(10.0); dbg_neglect = "sad"
		150: save_shot("sad")
		151: dbg_neglect = ""; set_needs(100.0); dbg_hour = 22.0
		200: save_shot("night")
		201: get_tree().quit()


func save_shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shot_dir, n])


# ------------------------------------------------------------------ boot
func _ready() -> void:
	for i in 34:
		stars.append([(i * 37 + 11) % W, (i * 53 + 7) % 92, i * 1.7])
	sky_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	sky_tex = ImageTexture.create_from_image(sky_img)
	load_state()
	make_players()
	build_ui()
	var hrs := clampf((Time.get_unix_time_from_system() - float(S["last"])) / 3600.0, 0.0, 24.0 * 30.0)
	if S["stage"] != "egg" and hrs > 0.01:
		decay(hrs, true)
	S["last"] = Time.get_unix_time_from_system()
	if S["name"] != "":
		namer_shown = true
	get_tree().root.focus_exited.connect(save_state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_state()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		var hrs := clampf((Time.get_unix_time_from_system() - float(S["last"])) / 3600.0, 0.0, 24.0 * 30.0)
		if S["stage"] != "egg" and hrs > 0.01:
			decay(hrs, true)
		S["last"] = Time.get_unix_time_from_system()
