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
const ADULT_XP := 4000.0
const FORM := {"exp": "explorer", "cud": "cuddly", "che": "cheeky", "slp": "sleepy"}
const BODY := {"baby": Color("#8be8c9"), "child": Color("#8be8c9"), "explorer": Color("#7fc8ff"), "cuddly": Color("#ffb3a1"), "cheeky": Color("#e9f06a"), "sleepy": Color("#dcd7ff")}
const MARKS := {
	"plus": [".#.", "###", ".#."],
	"explorer": ["..#..", ".#.#.", "#...#", ".#.#.", "..#.."],
	"cuddly": [".#.#.", "#####", "#####", ".###.", "..#.."],
	"cheeky": ["...##", "..##.", ".####", ".##..", "##..."],
	"sleepy": [".###.", "##...", "##...", "##...", ".###."],
}
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

const GEMS := [Color("#ff7ac8"), Color("#7ad8ff"), Color("#ffd34e"), Color("#9aff9a"), Color("#c49aff"), Color("#ff9a6b")]
const NIGHT := Color("#10153a")
const SLOTS := [[22, 84, true], [88, 98, true], [95, 133, false], [13, 133, false], [46, 78, true], [28, 50, true]]
const NOTE := [".##", ".#.", ".#.", "##.", "##."]
const QM := ["###", "..#", ".#.", "...", ".#."]
const ICONS := {
	"circle": ["..###..", ".#...#.", "#.....#", "#.....#", "#.....#", ".#...#.", "..###.."],
	"square": ["#######", "#.....#", "#.....#", "#.....#", "#.....#", "#.....#", "#######"],
	"line": [".......", ".......", "#######", "#.....#", "#######", ".......", "......."],
	"blob": [".##.##.", "#######", "#######", ".#####.", "#######", ".##.##.", "..###.."],
	"stripes": ["#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#"],
	"busy": ["#..#..#", "..#.#..", ".#...#.", "#..#..#", ".#...#.", "..#.#..", "#..#..#"],
	"qmark": [".#####.", "#.....#", ".....#.", "...##..", "...#...", ".......", "...#..."],
}
const PLACE_NAMES := ["the upside-down tree", "the floating door", "the spiral tower", "the eye stone", "the stairs to nowhere", "the whale cloud"]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const VW := 28
const VH := 36
const CW := 96
const CH := 120
const CAM_SHADER := """
shader_type canvas_item;
uniform sampler2D tex0 : filter_linear;
uniform sampler2D tex1 : filter_linear;
uniform int ycbcr = 0;
uniform int rot = 0;
uniform int mirror = 0;
uniform vec2 crop = vec2(1.0, 1.0);
void fragment() {
	vec2 q = (UV - 0.5) * crop;
	if (mirror == 1) { q.x = -q.x; }
	vec2 s = q;
	if (rot == 1) { s = vec2(q.y, -q.x); }
	else if (rot == 2) { s = -q; }
	else if (rot == 3) { s = vec2(-q.y, q.x); }
	vec2 uv = s + 0.5;
	vec3 c;
	if (ycbcr == 1) {
		float y = texture(tex0, uv).r;
		vec2 cc = texture(tex1, uv).rg - vec2(0.5);
		c = vec3(y + 1.402 * cc.y, y - 0.344136 * cc.x - 0.714136 * cc.y, y + 1.772 * cc.x);
	} else {
		c = texture(tex0, uv).rgb;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

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
var cer = null
var cer_l: Label
var sing := 0.0
var watch := 0.0
var tint := Color.WHITE
var tint_t := 0.0
var step_acc := 0.0
var step_pending := 0
var cur_place := -1
var face_last := -99.0

# sensors
var m_ema := 9.8
var m_last_step := 0
var m_last_shake := 0
var m_spikes: Array = []
var m_tilt := 50.0
var m_got := false
var mic_on := false
var mic_cap: AudioEffectCapture
var mic_player: AudioStreamPlayer
var mic_lvl := 0.0
var mic_base := 0.02
var mic_quiet := 0.0
var mic_voice := 0.0
var mic_contour: Array = []
var mic_last_samp := 0.0
var mic_last_loud := -9.0
var geo_on := false
var geo_cls = null
var geo_t := 0.0
var perm_wait := {}
var svc_ok := false
var svc_steps := false
var svc_cls = null
var svc_t := 0.0
var bg_asking := false
const UPDATE_URL := "https://squigglyshotda-lang.github.io/Digivi/downloads/version.json"
const UPDATE_BASE := "https://squigglyshotda-lang.github.io/Digivi/downloads/"
var upd_panel: Panel
var upd_btn: Button
var upd_status: Label
var upd_action: Button
var upd_info := {}
var upd_phase := "idle"   # idle, checking, available, downloading, downloaded, error, current
var upd_t := 0.0
var upd_auto_done := false
var bg_wait := 0.0
var bg_poll_t := 0.0
var diag_t := 0.0
var diag_text := ""
var status_labels := {}
var stats_l: Label

# camera
var cam_mode := "auto"
var cam_on := false
var cam_feed: CameraFeed = null
var cam_facing := "back"
var cam_posture := "up"
var cam_want_t := 0.0
var cam_starting := false
var cam_t := 0.0
var cam_ft := 0.0
var cam_steady := 0.0
var cam_prev := PackedFloat32Array()
var cam_bright := 0.0
var cam_last_sig := PackedFloat32Array()
var cam_vp: SubViewport
var cam_mat: ShaderMaterial
var cam_big := PackedByteArray()
var vf_tex: ImageTexture
var vf_ok := false
var vf_rect: TextureRect
var vf_flash: ColorRect
var cam_rot := {"back": 1, "front": 3}
var cam_flip := {"back": false, "front": true}
var show := {"open": 0.0, "steady": 0.0, "last_keep": -99.0, "flash": 0.0, "freeze": 0.0, "bubble": null, "bubble_t": 0.0, "tilt": 0.0, "tilt_dir": 1}
var taking := false
var sens_panel: Panel
var album_panel: Panel
var album_grid: GridContainer
var album_detail: Panel
var album_detail_img: TextureRect
var album_detail_l: Label
var album_empty: Label


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
		"steps": 0, "faces": 0, "places": [], "collection": [], "album": [], "shows": 0, "sens": {"motion": true, "mic": false, "cam": false, "geo": false}, "neglectH": 0.0, "last": Time.get_unix_time_from_system(),
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
			"note":
				bitmap(p["x"] - 1, p["y"] - 2, NOTE, p["c"])
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
	draw_places(n, false)
	draw_island(54, GROUND, 48, Color("#5fcf8a"), Color("#7a6aa6"), 26, n)
	draw_places(n, true)
	for k in S["places"].size():
		var tx := toy_x(k)
		var gc: Color = GEMS[k % 6]
		rect(tx - 1, GROUND + 3, 3, 3, gc)
		px(tx - 1, GROUND + 3, mixc(gc, Color.WHITE, 0.6))
		rect(tx - 1, GROUND + 5, 3, 1, mixc(gc, Color.BLACK, 0.3))
	for fd in food:
		disc(fd["x"], roundf(fd["y"]), 1, Color("#ff5a6e"))
		px(fd["x"] + 1, fd["y"] - 2, Color("#4fc47e"))
	var ci := 0
	for hx in S["collection"]:
		var cc2 := Color(hx)
		rect(3 + ci * 8, H - 8, 6, 6, INK)
		rect(4 + ci * 8, H - 7, 4, 4, cc2)
		px(4 + ci * 8, H - 7, mixc(cc2, Color.WHITE, 0.55))
		ci += 1


# ------------------------------------------------------------------- pet
func draw_mark(cx: float, y: float, key: String, col: Color) -> void:
	var rows: Array = MARKS[key]
	var w: int = rows[0].length()
	ga = 0.25 + 0.12 * sin(t * 3.0)
	disc(cx, y + rows.size() / 2.0, ceili(w / 2.0) + 2, col)
	ga = 1.0
	bitmap(cx - w / 2.0, y, rows, col)
	px(cx, y + floorf(rows.size() / 2.0), Color.WHITE)


func blob_shape(cx: float, cy: float, rx: float, ry: float, wob: float, col: Color, shear: float = 0.0) -> void:
	for y in range(-int(ry), int(ry) + 1):
		var k := sqrt(maxf(0.0, 1.0 - (y * y) / (ry * ry + 0.01)))
		var w := maxi(0, roundi(rx * k * (1.0 + wob * sin(t * 2.6 + y * 0.55))))
		var off := roundi(wob * 3.0 * sin(t * 1.9 + y * 0.3) + shear * y * 0.15)
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


func draw_face(cx: float, cy: float, rx: float, ry: float, m: String, singing: bool = false) -> void:
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
	if singing or m == "excited":
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


func dims(stage: String, form: String) -> Vector3:
	if stage == "baby":
		return Vector3(9, 8, 0)
	if stage == "child":
		return Vector3(11, 10, 0)
	match form:
		"explorer": return Vector3(10, 10, 3)
		"cuddly": return Vector3(17, 15, 0)
		"cheeky": return Vector3(12, 11, 0)
	return Vector3(15, 10, 6)


func draw_pet(stage: String, form: String, x: float, gy: float, sq: float, dormant: bool, still: bool, mood_over: String = "") -> void:
	var m := mood() if mood_over == "" else mood_over
	var mc: Color = MARKCOL.get(m, Color("#ffe08a"))
	if stage == "egg":
		draw_egg(roundf(x), gy, mc)
		return
	var d := dims(stage, form)
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
	var bob := 0.0 if still else sin(t * (1.2 if form == "sleepy" else 3.0))
	var cx := roundf(x)
	var cy := roundf(gy - ry - d.z - hop - bob)
	var col: Color = BODY[form if form != "" else stage]
	if tint_t > 0.0:
		col = mixc(col, tint, 0.4 * minf(1.0, tint_t))
	if dormant:
		col = mixc(col, Color("#8a86a8"), 0.4)
	var belly := mixc(col, Color.WHITE, 0.35)
	ga = 0.28
	ell(cx, gy + 1, roundi(rx * 0.9), 2, Color.BLACK)
	ga = 1.0
	var wob := 0.14 if stage == "child" else (0.04 if stage == "baby" else 0.03)
	if form == "explorer":
		var fl := sin(t * (9.0 if act == "wander" else 5.0)) * 0.5 + 0.2
		for sd in [-1, 1]:
			for i in range(1, 12):
				var xx: float = cx + sd * (rx + i - 1)
				var top := cy - 1 - roundi(i * (0.7 + fl * 0.5))
				var bot := cy + 3 - roundi(i * 0.25 * (1.0 - fl * 0.3))
				if bot < top:
					continue
				rect(xx, top - 1, 1, 2, INK)
				rect(xx, bot + 1, 1, 1, INK)
				rect(xx, top + 1, 1, bot - top, Color.WHITE if i % 3 == 0 else Color("#9fd4ff"))
	if form == "cuddly":
		for sd in [-1, 1]:
			var ex: float = cx + sd * roundi(rx * 0.6)
			disc(ex, cy - ry + 1, 4, INK)
			disc(ex, cy - ry + 1, 3, col)
			px(ex, cy - ry + 2, Color("#ff9aa8"))
	if form == "cheeky":
		for i in 8:
			var ang := PI * (1.1 + 0.8 * i / 7.0)
			var dx := cos(ang)
			var dy := sin(ang)
			var ln := 4 + (i % 2) * 2
			for k in ln:
				px(cx + dx * (rx + 1 + k), cy + dy * (ry + 1 + k), INK if k > ln - 2 else Color("#b8a800"))
	var face_x := cx
	var face_y := cy
	var ry_eff: float = ry
	var rx_eff: float = rx
	if form == "sleepy":
		var discs := [[-9, 3, 6], [-3, -2, 8], [5, -1, 8], [11, 3, 5], [1, 4, 7]]
		for dd in discs:
			disc(cx + dd[0], cy + dd[1], dd[2] + 1, INK)
		for dd in discs:
			disc(cx + dd[0], cy + dd[1], dd[2], col)
		ell(cx + 1, cy + 6, 9, 3, mixc(col, Color("#9a8ae6"), 0.25))
		px(cx - 5, cy - 7, Color.WHITE)
		px(cx - 4, cy - 7, Color.WHITE)
		face_x = cx + 1
		face_y = cy + 1
		ry_eff = 10
		rx_eff = 13
	else:
		var shr: float = show["tilt_dir"] * 7.0 * minf(1.0, show["tilt"]) if show["tilt"] > 0.0 else 0.0
		blob_shape(cx, cy, rx + 1, ry + 1, wob, INK, shr)
		blob_shape(cx, cy, rx, ry, wob, col, shr)
		blob_shape(cx, cy + roundi(ry * 0.35), roundi(rx * 0.62), roundi(ry * 0.5), wob, belly)
		var hl := mixc(col, Color.WHITE, 0.7)
		px(cx - roundi(rx * 0.5), cy - roundi(ry * 0.55), hl)
		px(cx - roundi(rx * 0.5) + 1, cy - roundi(ry * 0.55), hl)
		if form == "cuddly":
			var a := 0.0
			while a < 6.28:
				px(cx + (rx + 1) * cos(a), cy + (ry + 1) * sin(a), mixc(col, Color.WHITE, 0.5) if int(floorf(a / 0.45)) % 2 == 1 else INK)
				a += 0.45
	if show["tilt"] > 0.0:
		face_x += show["tilt_dir"] * 2
		face_y += 1
	draw_face(face_x, face_y, rx_eff, ry_eff, m, sing > 0.0)
	if stage == "adult":
		draw_mark(face_x, face_y + roundi(ry_eff * 0.35), form, mc)
	else:
		draw_mark(face_x, face_y + roundi(ry_eff * 0.4), "plus", mc)
	if form == "cheeky":
		for j in 5:
			if int(floorf(t * 10.0 + j)) % 3 == 0:
				continue
			var aa := t * 2.0 + j * 1.26
			var rr := rx + 5 + sin(t * 5.0 + j) * 2.0
			px(cx + cos(aa) * rr, cy + sin(aa) * (ry + 4), Color("#fff7a0"))
	bbox = Rect2(cx - rx - 2, cy - ry - 4, rx * 2 + 4, gy - (cy - ry - 4))
	has_bbox = true


# ------------------------------------------------------------ landmarks
func draw_lm(i: int, x: float, y: float, n: float) -> void:
	match i:
		0:
			draw_island(x, y, 9, Color("#6fd69a"), Color("#7a6aa6"), 6, n)
			rect(x - 1, y + 4, 3, 9, Color("#8a5a3a"))
			disc(x, y + 16, 6, mixc(Color("#3fae6e"), NIGHT, n * 0.5))
			disc(x - 3, y + 14, 3, mixc(Color("#4fc47e"), NIGHT, n * 0.5))
			disc(x + 4, y + 15, 3, mixc(Color("#4fc47e"), NIGHT, n * 0.5))
		1:
			rect(x - 5, y - 16, 11, 17, Color("#e8d7a8"))
			rect(x - 4, y - 15, 9, 16, mixc(Color("#8a4b7a"), NIGHT, n * 0.4))
			px(x + 2, y - 7, Color("#ffd34e"))
			rect(x - 1, y - 14, 3, 1, mixc(Color("#ffd34e"), Color("#8a4b7a"), 0.4 + 0.3 * sin(t * 2.0)))
			rect(x - 7, y + 3, 5, 1, Color("#cfc3ee"))
			rect(x + 1, y + 6, 5, 1, Color("#cfc3ee"))
		2:
			var cols := [Color("#f2a6c4"), Color("#a6d8f2"), Color("#f2e2a6"), Color("#c4a6f2")]
			for k in 7:
				var w := 7 - int(floorf(k * 0.6))
				var c := mixc(cols[k % 4], NIGHT, n * 0.45)
				var ox := roundf(sin(k * 0.9) * 1.5)
				rect(x - w + ox, y - k * 6 - 6, w * 2 + 1, 6, c)
				rect(x - w + ox, y - k * 6 - 6, w * 2 + 1, 1, mixc(c, Color.WHITE, 0.35))
			rect(x, y - 52, 1, 8, INK)
			rect(x + 1, y - 52, 4, 3, Color("#ff7a7a"))
		3:
			var sc := mixc(Color("#8b86a8"), NIGHT, n * 0.4)
			ell(x, y - 9, 10, 9, sc)
			ell(x, y - 10, 6, 4, Color.WHITE)
			var ix := x + clampf((pet_x - x) / 30.0, -1.0, 1.0) * 3.0
			disc(ix, y - 10, 2, Color("#46c2a0"))
			px(ix, y - 10, INK)
			if int(floorf(t * 2.0)) % 7 == 0:
				rect(x - 6, y - 14, 13, 5, sc)
		4:
			for k in 8:
				rect(x + k * 3, y - k * 2, 4, 2, mixc(Color("#cfc3ee"), NIGHT, n * 0.4))
				rect(x + k * 3, y - k * 2 + 2, 4, 1, Color("#8c7fc0"))
		5:
			var c := mixc(Color("#f4f1ff"), Color("#2c2560"), n * 0.6)
			ell(x, y, 12, 5, c)
			ell(x + 10, y - 1, 4, 3, c)
			rect(x + 13, y - 5, 2, 3, c)
			rect(x + 15, y - 7, 3, 2, c)
			px(x - 7, y - 1, INK)
			if int(floorf(t * 3.0)) % 2 == 1:
				px(x - 8, y - 7, Color("#bfe6ff"))
				px(x - 9, y - 9, Color("#bfe6ff"))
				px(x - 7, y - 10, Color("#bfe6ff"))


func toy_x(k: int) -> float:
	return 16.0 + float((k * 29) % 72)


func draw_places(night: float, front: bool) -> void:
	var cnt := mini(S["places"].size(), 6)
	for i in cnt:
		var sl: Array = SLOTS[i]
		if sl[2] == front:
			continue
		var yy: float = sl[1] + (roundf(sin(t * 0.8 + i) * 2.0) if sl[2] else 1.0)
		draw_lm(i, sl[0], yy, night)


# --------------------------------------------------------------- events
func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func on_step(n: int = 1) -> void:
	S["steps"] += n
	S["xp"]["exp"] += 0.02 * n
	need("hun", 0.02 * n)
	wake_from_neglect()
	step_acc += n
	while step_acc >= 50.0:
		step_acc -= 50.0
		if S["stage"] != "egg" and food.size() < 5:
			spawn_food()


func on_shake() -> void:
	if S["stage"] == "egg":
		egg_shake = 1.0
		return
	startle = 1.2
	S["xp"]["che"] += 5.0
	need("cur", 2)
	wake = 20.0
	boing()
	toast("Whoa! That startled it.")


func on_loud() -> void:
	if S["stage"] == "egg":
		egg_shake = 1.0
		return
	startle = 1.4
	S["xp"]["che"] += 3.0
	wake = 20.0
	sfx(90, 0.25, "sawtooth", 0.06, -30)
	toast("That was loud.")


func on_new_place(key: String) -> void:
	S["places"].append(key)
	need("cur", 30)
	S["xp"]["exp"] += 20.0
	excited = 3.0
	burst(54, 70, 14, [Color("#fff7a0"), Color("#ff9ad9"), Color("#8bf0ff")], 40.0)
	sfx(660, 0.15, "square", 0.04, 220)
	get_tree().create_timer(0.14).timeout.connect(func(): sfx(990, 0.2, "square", 0.04, 0))
	toast("A new place. Something appeared in its world." if S["places"].size() <= 6 else "A new place. It found a toy.")
	save_state()


func on_colour(c: Color) -> void:
	need("cur", 8)
	tint = c
	tint_t = 5.0
	excited = maxf(excited, 1.5)
	var hx := "#" + c.to_html(false)
	if not S["collection"].has(hx):
		S["collection"].append(hx)
		if S["collection"].size() > 12:
			S["collection"].pop_front()
	chirp()
	toast("It likes that colour.")


func on_face() -> void:
	var n := now()
	if n - face_last < 5.0:
		return
	face_last = n
	S["faces"] += 1
	watch = 5.0
	wake = 20.0
	if S["faces"] >= 5:
		happy = 3.0
		excited = 1.2
		chirp()
		toast("It knows that face.")
	else:
		toast("It is looking at you.")


func copy_back(contour: Array) -> void:
	var stp := maxi(1, contour.size() / 9)
	var notes: Array = []
	for i in contour.size():
		if i % stp == 0 and notes.size() < 9:
			notes.append(contour[i])
	sing = notes.size() * 0.11 + 0.4
	dance = maxf(dance, 0.5)
	for i in notes.size():
		var f: float = clampf(notes[i] * 1.6, 300.0, 2000.0)
		get_tree().create_timer(0.25 + i * 0.11).timeout.connect(func(): sfx(f, 0.1, "triangle", 0.06, 0))
	var i := 0
	while i < notes.size():
		get_tree().create_timer(0.25 + i * 0.11).timeout.connect(func(): add_part("note", pet_x + rnd(-8, 8), GROUND - 28, rnd(-3, 3), -16, 1.3, Color("#8bf0ff")))
		i += 2
	need("cur", 3)
	toast("It copied what it heard.")


# ---------------------------------------------------------- permissions
func has_perm(p: String) -> bool:
	if not OS.has_feature("android"):
		return true
	var c = perm_cls()
	if c != null:
		return bool(c.hasPerm(Engine.get_singleton("AndroidRuntime").getActivity(), p))
	return ("android.permission." + p) in OS.get_granted_permissions()


var perm_cls_cache = null
var perm_wait_t := 0.0
var perm_poll_t := 0.0
var perm_paused := false
var perm_resumed := false


func perm_cls():
	if perm_cls_cache == null and OS.has_feature("android") and Engine.has_singleton("AndroidRuntime"):
		perm_cls_cache = JavaClassWrapper.wrap("com.pierrejoshua.digivi.Native")
	return perm_cls_cache


func ask_perm(p: String, cb: Callable) -> void:
	if has_perm(p):
		cb.call(true)
		return
	perm_wait[p] = cb
	perm_wait_t = 0.0
	perm_paused = false
	perm_resumed = false
	var c = perm_cls()
	if c != null:
		var list := p
		if p == "ACCESS_FINE_LOCATION":
			list = "ACCESS_FINE_LOCATION,ACCESS_COARSE_LOCATION"
		c.requestPerms(Engine.get_singleton("AndroidRuntime").getActivity(), list)
	else:
		OS.request_permission(p)


func perm_poll(dt: float) -> void:
	if perm_wait.is_empty():
		return
	perm_wait_t += dt
	perm_poll_t += dt
	if perm_poll_t < 0.4:
		return
	perm_poll_t = 0.0
	for k in perm_wait.keys():
		var granted := has_perm(k)
		var denied := (perm_resumed and perm_wait_t > 1.5) or perm_wait_t > 90.0
		if granted or denied:
			var cb: Callable = perm_wait[k]
			perm_wait.erase(k)
			cb.call(granted)


func on_perm_result(permission: String, granted: bool) -> void:
	for k in perm_wait.keys():
		if permission.ends_with(k):
			var cb: Callable = perm_wait[k]
			perm_wait.erase(k)
			cb.call(granted)


func set_status(name: String, text: String) -> void:
	if status_labels.has(name):
		status_labels[name].text = text
		var bad := text.contains("blocked") or text.contains("unavailable") or text.contains("no ")
		status_labels[name].add_theme_color_override("font_color", Color("#7be0a8") if text.begins_with("on") else (Color("#ff9170") if bad else Color("#a99fd0")))


func mark_sensor(k: String, v: bool) -> void:
	S["sens"][k] = v


# --------------------------------------------------------------- motion
func motion_frame() -> void:
	var a := Input.get_accelerometer()
	if a == Vector3.ZERO:
		return
	if not m_got:
		m_got = true
		set_status("motion", "on")
	var mag := a.length()
	if mag > 3.0:
		m_tilt += (rad_to_deg(acos(clampf(absf(a.z) / mag, 0.0, 1.0))) - m_tilt) * 0.1
	m_ema += (mag - m_ema) * 0.05
	var d := mag - m_ema
	var tms := Time.get_ticks_msec()
	if svc_ok:
		if not svc_steps and d > 2.2 and tms - m_last_step > 320 and absf(d) <= 16.0:
			m_last_step = tms
			on_step(1)
		return
	if absf(d) > 16.0:
		m_spikes = m_spikes.filter(func(s): return tms - s < 900)
		m_spikes.append(tms)
		if m_spikes.size() >= 3 and tms - m_last_shake > 1500:
			m_last_shake = tms
			m_spikes.clear()
			on_shake()
		return
	if d > 2.2 and tms - m_last_step > 320:
		m_last_step = tms
		on_step(1)


func enable_motion() -> void:
	mark_sensor("motion", true)
	set_status("motion", "waiting")
	get_tree().create_timer(2.5).timeout.connect(func(): if not m_got: set_status("motion", "no data (needs a real phone)"))


# ------------------------------------------------------------------ mic
func enable_mic() -> void:
	if mic_on:
		return
	set_status("mic", "asking")
	ask_perm("RECORD_AUDIO", func(ok: bool):
		if not ok:
			set_status("mic", "blocked")
			return
		start_mic())


func start_mic() -> void:
	var idx := AudioServer.get_bus_index("Mic")
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Mic")
		mic_cap = AudioEffectCapture.new()
		AudioServer.add_bus_effect(idx, mic_cap)
		AudioServer.set_bus_mute(idx, true)
	else:
		mic_cap = AudioServer.get_bus_effect(idx, 0)
	if mic_player == null:
		mic_player = AudioStreamPlayer.new()
		mic_player.stream = AudioStreamMicrophone.new()
		mic_player.bus = "Mic"
		add_child(mic_player)
	mic_player.play()
	mic_on = true
	mark_sensor("mic", true)
	set_status("mic", "on")
	refresh_service()


func peak_freq(buf: PackedFloat32Array, rate: float) -> float:
	var n := buf.size()
	var min_lag := int(rate / 1600.0)
	var max_lag := mini(int(rate / 150.0), n / 2)
	var e0 := 0.0
	for i in n - max_lag:
		e0 += buf[i] * buf[i]
	if e0 < 0.0001:
		return 0.0
	var best := 0.0
	var best_lag := 0
	for lag in range(min_lag, max_lag):
		var s := 0.0
		for i in range(0, n - max_lag, 2):
			s += buf[i] * buf[i + lag]
		if s > best:
			best = s
			best_lag = lag
	if best_lag == 0 or best < e0 * 0.5 * 0.5:
		return 0.0
	return rate / best_lag


func mic_frame(dt: float) -> void:
	if not mic_on or mic_cap == null:
		return
	var avail := mic_cap.get_frames_available()
	if avail <= 0:
		return
	var frames := mic_cap.get_buffer(avail)
	if sing > 0.0:
		return
	var take := mini(frames.size(), 1024)
	var buf := PackedFloat32Array()
	buf.resize(take)
	var s := 0.0
	for i in take:
		var v: float = frames[frames.size() - take + i].x
		buf[i] = v
		s += v * v
	var lvl := sqrt(s / maxf(1.0, take))
	mic_lvl = lvl
	mic_base += (minf(lvl, 0.1) - mic_base) * 0.01
	if lvl > 0.45 and lvl > mic_base * 4.0 and t - mic_last_loud > 1.5:
		mic_last_loud = t
		if not svc_ok:
			on_loud()
		return
	if lvl > 0.06 and lvl <= 0.45:
		mic_quiet = 0.0
		mic_voice += dt
		dance = 0.5
		wake = 15.0
		if t - mic_last_samp > 0.08:
			mic_last_samp = t
			var f := peak_freq(buf, AudioServer.get_mix_rate())
			if f > 150.0 and f < 1600.0:
				mic_contour.append(f)
				if mic_contour.size() > 40:
					mic_contour.pop_front()
	else:
		mic_quiet += dt
		if mic_quiet > 0.7:
			if mic_voice > 0.5 and mic_contour.size() >= 5:
				copy_back(mic_contour.duplicate())
			mic_voice = 0.0
			mic_contour.clear()


# ----------------------------------------------------- background service
func enable_bg() -> void:
	if svc_ok or bg_asking:
		return
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		set_status("bg", "unavailable here")
		return
	svc_cls = JavaClassWrapper.wrap("com.pierrejoshua.digivi.Native")
	if svc_cls == null:
		set_status("bg", "unavailable (helper missing)")
		return
	var act = Engine.get_singleton("AndroidRuntime").getActivity()
	if bool(svc_cls.hasPerm(act, "ACTIVITY_RECOGNITION")):
		start_service()
		return
	set_status("bg", "asking")
	svc_cls.requestPerms(act, "ACTIVITY_RECOGNITION,POST_NOTIFICATIONS")
	bg_asking = true
	bg_wait = 0.0


func bg_poll(dt: float) -> void:
	if not bg_asking:
		return
	bg_wait += dt
	bg_poll_t += dt
	if bg_poll_t < 0.5:
		return
	bg_poll_t = 0.0
	var act = Engine.get_singleton("AndroidRuntime").getActivity()
	if bool(svc_cls.hasPerm(act, "ACTIVITY_RECOGNITION")):
		bg_asking = false
		start_service()
	elif bg_wait > 45.0:
		bg_asking = false
		start_service()
		set_status("bg", "on, but no Physical activity permission (allow it in Android settings)")


func start_service() -> void:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		set_status("bg", "unavailable here")
		return
	var rt = Engine.get_singleton("AndroidRuntime")
	svc_cls = JavaClassWrapper.wrap("com.pierrejoshua.digivi.Native")
	if svc_cls == null:
		set_status("bg", "unavailable (helper missing)")
		return
	var r := str(svc_cls.startService(rt.getActivity()))
	if r == "ok":
		svc_ok = true
		svc_steps = bool(svc_cls.hasStepCounter(rt.getActivity()))
		mark_sensor("bg", true)
		set_status("bg", "on (%s)" % ("step counter" if svc_steps else "no step counter, using motion"))
	else:
		set_status("bg", "unavailable: " + r)


func refresh_service() -> void:
	if svc_ok:
		start_service()


func apply_pending() -> void:
	if not svc_ok or svc_cls == null:
		return
	var rt = Engine.get_singleton("AndroidRuntime")
	var p := str(svc_cls.takePending(rt.getActivity())).split(",", true, 3)
	if p.size() < 4:
		return
	var steps := int(p[0])
	var shakes := int(p[1])
	var louds := int(p[2])
	if steps > 0:
		on_step(steps)
	if shakes > 0:
		S["xp"]["che"] += 5.0 * (shakes - 1)
		on_shake()
	if louds > 0:
		S["xp"]["che"] += 3.0 * (louds - 1)
		on_loud()
	for k in p[3].split(";", false):
		if not S["places"].has(k):
			on_new_place(k)


# ------------------------------------------------------------- location
func enable_geo() -> void:
	if geo_on:
		return
	set_status("geo", "asking")
	ask_perm("ACCESS_FINE_LOCATION", func(ok: bool):
		if not ok:
			set_status("geo", "blocked")
			return
		start_geo())


func start_geo() -> void:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		set_status("geo", "unavailable here")
		return
	var rt = Engine.get_singleton("AndroidRuntime")
	geo_cls = JavaClassWrapper.wrap("com.pierrejoshua.digivi.Native")
	if geo_cls == null:
		set_status("geo", "unavailable (helper missing)")
		return
	var r = geo_cls.startLocation(rt.getActivity())
	if str(r) == "ok":
		geo_on = true
		mark_sensor("geo", true)
		set_status("geo", "on (waiting for a fix)")
		refresh_service()
	else:
		set_status("geo", "unavailable: " + str(r))


func geo_frame(dt: float) -> void:
	if not geo_on or geo_cls == null:
		return
	geo_t += dt
	if geo_t < 5.0:
		return
	geo_t = 0.0
	var fix := str(geo_cls.lastFix())
	if fix == "":
		return
	var p := fix.split(",")
	if p.size() < 3:
		return
	set_status("geo", "on")
	if float(p[2]) > 150.0:
		return
	var key := "%d,%d" % [roundi(float(p[0]) * 1000.0), roundi(float(p[1]) * 1000.0)]
	if not S["places"].has(key):
		on_new_place(key)
	cur_place = S["places"].find(key)


func place_name(i: int) -> String:
	if i < 0:
		return "its island"
	return "near " + PLACE_NAMES[i] if i < 6 else "a far-off place"


# --------------------------------------------------------------- camera
func quant(raw: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h * 4)
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			var th: float = (BAYER[(y & 3) * 4 + (x & 3)] / 16.0 - 0.5) * 85.0
			for c in 3:
				out[i + c] = int(roundf(clampf(raw[i + c] + th, 0.0, 255.0) / 85.0)) * 85
			out[i + 3] = 255
	return out


func colour_name(r: float, g: float, b: float) -> String:
	var mx := maxf(r, maxf(g, b))
	var mn := minf(r, minf(g, b))
	var l := (mx + mn) / 510.0
	if mx - mn < 28.0:
		return "white" if l > 0.8 else ("black" if l < 0.2 else "grey")
	var d := mx - mn
	var h := 0.0
	if mx == r:
		h = fposmod((g - b) / d, 6.0)
	elif mx == g:
		h = (b - r) / d + 2.0
	else:
		h = (r - g) / d + 4.0
	h = fposmod(h * 60.0 + 360.0, 360.0)
	if h < 15.0 or h >= 335.0:
		return "pink" if l > 0.7 else "red"
	if h < 45.0:
		return "orange"
	if h < 70.0:
		return "yellow"
	if h < 165.0:
		return "green"
	if h < 200.0:
		return "teal"
	if h < 255.0:
		return "blue"
	if h < 290.0:
		return "purple"
	return "pink"


func sig_of(raw: PackedByteArray) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	for cy in 4:
		for cx in 4:
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var n := 0.0
			for y in range(cy * 9, cy * 9 + 9):
				for x in range(cx * 7, cx * 7 + 7):
					var i := (y * VW + x) * 4
					r += raw[i]
					g += raw[i + 1]
					b += raw[i + 2]
					n += 1.0
			s.append(r / n)
			s.append(g / n)
			s.append(b / n)
	return s


func describe(raw: PackedByteArray) -> Dictionary:
	var w := VW
	var h := VH
	var n := w * h
	var gray := PackedFloat32Array()
	gray.resize(n)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for i in n:
		var rr: float = raw[i * 4]
		var gg: float = raw[i * 4 + 1]
		var bb: float = raw[i * 4 + 2]
		r += rr
		g += gg
		b += bb
		gray[i] = 0.3 * rr + 0.59 * gg + 0.11 * bb
	r /= n
	g /= n
	b /= n
	var gx := 0.0
	var gy := 0.0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			gx += absf(gray[i + 1] - gray[i - 1])
			gy += absf(gray[i + w] - gray[i - w])
	var edge := (gx + gy) / float((w - 2) * (h - 2)) / 255.0
	var pattern := "plain"
	if edge > 0.16:
		var ratio := gx / (gy + 1.0)
		pattern = "stripes" if (ratio > 1.8 or ratio < 0.55) else "busy"
	var br := 0.0
	var bg := 0.0
	var bb2 := 0.0
	var bn := 0.0
	var border: Array = []
	for x in w:
		border.append(x)
		border.append((h - 1) * w + x)
	for y in range(1, h - 1):
		border.append(y * w)
		border.append(y * w + w - 1)
	for idx in border:
		br += raw[idx * 4]
		bg += raw[idx * 4 + 1]
		bb2 += raw[idx * 4 + 2]
		bn += 1.0
	br /= bn
	bg /= bn
	bb2 /= bn
	var x0 := w
	var x1 := -1
	var y0 := h
	var y1 := -1
	var area := 0
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			if absf(raw[i] - br) + absf(raw[i + 1] - bg) + absf(raw[i + 2] - bb2) > 70.0:
				area += 1
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	var shape := "none"
	if area > n * 0.04 and area < n * 0.85:
		var bw := x1 - x0 + 1
		var bh := y1 - y0 + 1
		var fill := float(area) / (bw * bh)
		var aspect := float(maxi(bw, bh)) / float(mini(bw, bh))
		shape = "long" if aspect > 1.9 else ("square" if fill > 0.9 else ("round" if fill > 0.68 else "lumpy"))
	return {"bright": (r + g + b) / 765.0, "col": Color(r / 255.0, g / 255.0, b / 255.0), "col_name": colour_name(r, g, b), "pattern": pattern, "shape": shape}


func a_or_an(w: String) -> String:
	return ("an " if w[0] in "aeiou" else "a ") + w


func wanted_facing() -> String:
	if cam_mode == "back":
		return "back"
	if cam_mode == "front":
		return "front"
	if not m_got:
		return "back"
	if m_tilt >= 60.0:
		cam_posture = "up"
	elif m_tilt <= 40.0:
		cam_posture = "flat"
	return "front" if cam_posture == "flat" else "back"


func can_show() -> bool:
	var ns := neglect_state()
	return S["stage"] != "egg" and cer == null and ns != "away" and ns != "lost"


func enable_cam() -> void:
	if cam_on or cam_starting:
		return
	cam_starting = true
	set_status("cam", "asking")
	ask_perm("CAMERA", func(ok: bool):
		if not ok:
			cam_starting = false
			set_status("cam", "blocked")
			return
		start_cam())


func start_cam() -> void:
	CameraServer.monitoring_feeds = true
	set_status("cam", "looking for cameras")
	for i in 20:
		if CameraServer.feeds().size() > 0:
			break
		await get_tree().create_timer(0.4).timeout
	if CameraServer.feeds().is_empty():
		cam_starting = false
		set_status("cam", "unavailable (no camera found)")
		return
	setup_cam_view()
	cam_starting = false
	if open_stream(wanted_facing()):
		mark_sensor("cam", true)


func setup_cam_view() -> void:
	if cam_vp != null:
		return
	cam_vp = SubViewport.new()
	cam_vp.size = Vector2i(CW, CH)
	cam_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cam_vp.transparent_bg = false
	add_child(cam_vp)
	var cr := ColorRect.new()
	cr.size = Vector2(CW, CH)
	cam_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CAM_SHADER
	cam_mat.shader = sh
	cr.material = cam_mat
	cam_vp.add_child(cr)
	vf_rect = TextureRect.new()
	vf_rect.texture = cam_vp.get_texture()
	vf_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	vf_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vf_rect.stretch_mode = TextureRect.STRETCH_SCALE
	vf_rect.size = Vector2(28, 36)
	vf_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vf_rect.visible = false
	add_child(vf_rect)
	vf_flash = ColorRect.new()
	vf_flash.color = Color.WHITE
	vf_flash.size = Vector2(28, 36)
	vf_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vf_flash.modulate.a = 0.0
	vf_rect.add_child(vf_flash)


func pick_format(feed: CameraFeed) -> int:
	var fm := feed.get_formats()
	var best := -1
	var best_score := 1.0e9
	for i in fm.size():
		var w: int = fm[i]["width"]
		var h: int = fm[i]["height"]
		var nm: String = str(fm[i]["format"])
		if w < 320 or w > 1000:
			continue
		var score := absf(float(w) / h - 1.3333) * 100.0 + absf(w - 640) / 10.0 + (0.0 if nm.begins_with("RGB") else 25.0)
		if score < best_score:
			best_score = score
			best = i
	if best < 0 and fm.size() > 0:
		best = 0
	return best


func open_stream(facing: String) -> bool:
	var want := CameraFeed.FEED_FRONT if facing == "front" else CameraFeed.FEED_BACK
	var feed: CameraFeed = null
	for f in CameraServer.feeds():
		if f.get_position() == want:
			feed = f
			break
	if feed == null:
		feed = CameraServer.feeds()[0]
	if cam_feed != null and cam_feed != feed:
		cam_feed.feed_is_active = false
	var idx := pick_format(feed)
	if idx < 0:
		set_status("cam", "unavailable (no usable format)")
		return false
	feed.set_format(idx, {})
	feed.feed_is_active = true
	cam_feed = feed
	cam_facing = facing
	var t0 := CameraTexture.new()
	t0.camera_feed_id = feed.get_id()
	t0.which_feed = CameraServer.FEED_Y_IMAGE
	var t1 := CameraTexture.new()
	t1.camera_feed_id = feed.get_id()
	t1.which_feed = CameraServer.FEED_CBCR_IMAGE
	cam_mat.set_shader_parameter("tex0", t0)
	cam_mat.set_shader_parameter("tex1", t1)
	apply_cam_params()
	cam_on = true
	cam_prev = PackedFloat32Array()
	cam_steady = 0.0
	set_status("cam", "on (%s)" % ("front, greets faces" if facing == "front" else "back, shows things"))
	return true


func apply_cam_params() -> void:
	if cam_mat == null or cam_feed == null:
		return
	var yc := 1 if cam_feed.get_datatype() == CameraFeed.FEED_YCBCR_SEP else 0
	cam_mat.set_shader_parameter("ycbcr", yc)
	cam_mat.set_shader_parameter("rot", cam_rot[cam_facing])
	cam_mat.set_shader_parameter("mirror", 1 if cam_flip[cam_facing] else 0)
	var out_ar := float(CW) / CH
	var src_ar := 0.75
	var crop := Vector2(1, 1)
	if src_ar > out_ar:
		crop.x = out_ar / src_ar
	else:
		crop.y = src_ar / out_ar
	cam_mat.set_shader_parameter("crop", crop)


var cam_flat_t := 0.0
var cam_restarts := 0
var cam_diag := ""


# True when the frame is a flat colour (feed not delivering). Restarts the stream if it stays that way.
func cam_flat_check(im: Image, step: float) -> bool:
	var tiny := im.duplicate()
	tiny.resize(12, 12, Image.INTERPOLATE_NEAREST)
	var d := tiny.get_data()
	var n := 144
	var sr := 0.0
	var sg := 0.0
	var sb := 0.0
	var ls := PackedFloat32Array()
	ls.resize(n)
	for i in n:
		var r := float(d[i * 4])
		var g := float(d[i * 4 + 1])
		var b := float(d[i * 4 + 2])
		sr += r
		sg += g
		sb += b
		ls[i] = 0.3 * r + 0.59 * g + 0.11 * b
	var ml := 0.0
	for v in ls:
		ml += v
	ml /= n
	var vr := 0.0
	for v in ls:
		vr += (v - ml) * (v - ml)
	var sd := sqrt(vr / n)
	var lit := ml > 25.0
	cam_diag = "cam %d %d %d sd%d r%d" % [int(sr / n), int(sg / n), int(sb / n), int(sd), cam_restarts]
	if sd < 3.0 and lit:
		cam_flat_t += step
		vf_ok = false
		cam_steady = 0.0
		show["steady"] = 0.0
		if cam_flat_t > 2.5:
			cam_flat_t = 0.0
			cam_restarts += 1
			restart_stream()
		return true
	cam_flat_t = 0.0
	return false


func restart_stream() -> void:
	if cam_feed == null:
		return
	cam_feed.feed_is_active = false
	var f := cam_facing
	cam_on = false
	open_stream(f)


func cam_frame(dt: float) -> void:
	if not cam_on or cam_vp == null:
		return
	var want := wanted_facing()
	if want != cam_facing:
		cam_want_t += dt
		if cam_want_t > 1.5:
			cam_want_t = 0.0
			open_stream(want)
			return
	else:
		cam_want_t = 0.0
	cam_t += dt
	if cam_t < 0.08:
		return
	var step := cam_t
	cam_t = 0.0
	if show["freeze"] > 0.0 or taking:
		return
	var im := cam_vp.get_texture().get_image()
	if im == null or im.is_empty():
		return
	im.convert(Image.FORMAT_RGBA8)
	if cam_flat_check(im, step):
		return
	cam_big = im.get_data()
	if cam_facing == "front":
		show["steady"] = 0.0
		vf_ok = false
		cam_ft += step
		if cam_ft > 1.0 and can_show():
			cam_ft = 0.0
			if geo_cls == null and OS.has_feature("android") and Engine.has_singleton("AndroidRuntime"):
				geo_cls = JavaClassWrapper.wrap("com.pierrejoshua.digivi.Native")
			if geo_cls != null and int(geo_cls.faces(cam_big, CW, CH)) > 0:
				on_face()
		return
	var small := im.duplicate()
	small.resize(VW, VH, Image.INTERPOLATE_BILINEAR)
	var raw: PackedByteArray = small.get_data()
	vf_ok = true
	var n := VW * VH
	var sum := 0.0
	var diff := 0.0
	var had := cam_prev.size() == n
	var cur := PackedFloat32Array()
	cur.resize(n)
	for i in n:
		var l: float = 0.3 * raw[i * 4] + 0.59 * raw[i * 4 + 1] + 0.11 * raw[i * 4 + 2]
		cur[i] = l
		sum += l
		if had:
			diff += absf(l - cam_prev[i])
	cam_prev = cur
	cam_bright = sum / n / 255.0
	if cam_bright < 0.1:
		need("ene", 0.005)
	if had and diff / n < 6.0 and cam_bright > 0.1:
		cam_steady += step
	else:
		cam_steady = 0.0
	show["steady"] = cam_steady
	if cam_steady > 1.2 and t - show["last_keep"] > 6.0 and can_show():
		var sg := sig_of(raw)
		var dist := 999.0
		if cam_last_sig.size() == sg.size():
			dist = 0.0
			for i in sg.size():
				dist += absf(sg[i] - cam_last_sig[i])
		cam_steady = 0.0
		if dist > 90.0:
			cam_last_sig = sg
			show["last_keep"] = t
			take_in(im, false)


func make_sprite(big: Image) -> String:
	var s := mini(big.get_width(), big.get_height())
	var crop := big.get_region(Rect2i((big.get_width() - s) / 2, (big.get_height() - s) / 2, s, s))
	crop.resize(16, 16, Image.INTERPOLATE_BILINEAR)
	crop.convert(Image.FORMAT_RGBA8)
	var q := Image.create_from_data(16, 16, false, Image.FORMAT_RGBA8, quant(crop.get_data(), 16, 16))
	return Marshalls.raw_to_base64(q.save_png_to_buffer())


func take_in(big: Image, fake: bool) -> void:
	if taking:
		return
	taking = true
	show["flash"] = 0.15
	show["freeze"] = 4.0
	var small := big.duplicate()
	small.convert(Image.FORMAT_RGBA8)
	small.resize(VW, VH, Image.INTERPOLATE_BILINEAR)
	var info := describe(small.get_data())
	var sprite := make_sprite(big)
	react_to_show(info, sprite)
	taking = false
	show["freeze"] = minf(show["freeze"], 1.0)


func react_to_show(info: Dictionary, sprite: String) -> void:
	var said := ""
	var md := "curious"
	var bubble = null
	var puzzled := false
	var stg: String = S["stage"]
	if stg == "baby":
		if info["bright"] > 0.72:
			said = "something very bright"
			md = "dazzled"
			startle = 0.7
		elif info["bright"] < 0.18:
			said = "something dark"
			md = "calm"
		else:
			said = a_or_an(info["col_name"]) + " colour"
			md = "delighted"
			excited = 2.0
			tint = info["col"]
			tint_t = 5.0
		bubble = {"c": info["col"]}
	else:
		var key = null
		if info["pattern"] != "plain":
			key = info["pattern"]
		elif info["shape"] != "none":
			key = info["shape"]
		if key == null:
			puzzled = true
		elif stg == "child":
			said = {"round": "something round", "square": "something square", "long": "something long", "lumpy": "something lumpy", "stripes": "something stripy", "busy": "something busy"}[key]
			excited = 1.8
			bubble = {"icon": {"round": "circle", "long": "line", "lumpy": "blob"}.get(key, key)}
		else:
			var shp: String = {"round": "round", "square": "square", "long": "long", "lumpy": "lumpy", "stripes": "stripy", "busy": "busy"}[key]
			said = "something %s and %s" % [shp, info["col_name"]]
			md = "pleased"
			excited = 1.8
			bubble = {"icon": {"round": "circle", "long": "line", "lumpy": "blob"}.get(key, key)}
	if puzzled:
		said = "something it can't make out"
		md = "puzzled"
		bubble = {"icon": "qmark", "q": true}
		show["tilt"] = 1.6
		show["tilt_dir"] = 1 if randf() < 0.5 else -1
	show["bubble"] = bubble
	show["bubble_t"] = 3.4
	show["flash"] = 0.18
	show["freeze"] = 1.0
	wake = 20.0
	S["shows"] += 1
	need("cur", 10)
	S["xp"]["exp"] += 1.0
	if S["album"].size() >= 80:
		S["album"].pop_front()
	S["album"].append({"t": Time.get_unix_time_from_system(), "img": sprite, "place": cur_place, "said": said, "mood": md, "stage": S["stage"]})
	toast(("It tilts its head. " if puzzled else "It sees ") + said + ".")
	sfx(300 if puzzled else 700, 0.12, "square", 0.04, -60 if puzzled else 200)
	save_state()
	refresh_album()


func draw_viewfinder() -> void:
	var o: float = show["open"]
	if o < 0.05 or cer != null:
		if vf_rect != null:
			vf_rect.visible = false
		return
	var x0 := 64
	var y0 := roundi(50 + sin(t * 1.5) * 1.5)
	var pale := Color("#f4ecff")
	ga = o
	rect(x0, y0, 36, 44, INK)
	rect(x0 + 1, y0 + 1, 34, 42, pale)
	rect(x0 + 3, y0 + 3, 30, 38, INK)
	rect(x0 - 1, y0 + 21, 1, 3, pale)
	rect(x0 - 2, y0 + 22, 1, 1, pale)
	rect(x0 + 4, y0 + 4, 28, 36, Color("#2a2450"))
	if vf_rect != null:
		vf_rect.visible = vf_ok
		vf_rect.position = Vector2(x0 + 4, y0 + 4)
		vf_rect.modulate.a = o
		vf_flash.modulate.a = minf(1.0, show["flash"] / 0.15) if show["flash"] > 0.0 else 0.0
	ga = o
	var sw := roundi(28.0 * minf(1.0, show["steady"] / 1.2))
	if sw > 0:
		rect(x0 + 4, y0 + 41, sw, 1, Color("#ff9a3c"))
	ga = 1.0


func draw_bubble() -> void:
	var b = show["bubble"]
	if b == null or show["bubble_t"] <= 0.0 or not has_bbox:
		return
	ga = minf(1.0, show["bubble_t"] / 0.4)
	var bx := clampf(roundf(bbox.position.x + bbox.size.x / 2.0) - 7.0, 2.0, W - 17.0)
	var by := maxf(2.0, bbox.position.y - 19.0)
	rect(bx + 1, by, 13, 15, INK)
	rect(bx, by + 1, 15, 13, INK)
	rect(bx + 1, by + 1, 13, 13, Color.WHITE)
	rect(bx + 6, by + 15, 3, 1, INK)
	rect(bx + 7, by + 16, 1, 1, INK)
	px(bx + 7, by + 15, Color.WHITE)
	if b.has("c"):
		var c: Color = b["c"]
		rect(bx + 4, by + 4, 7, 7, INK)
		rect(bx + 5, by + 5, 5, 5, c)
		px(bx + 5, by + 5, mixc(c, Color.WHITE, 0.6))
	else:
		bitmap(bx + 4, by + 4, ICONS.get(b["icon"], ICONS["qmark"]), INK)
	if b.has("q"):
		bitmap(bx + 11, by + 1, QM, Color("#ff5a6e"))
	ga = 1.0


func fake_show() -> void:
	var im := Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	var base := Color.from_hsv(randf(), 0.4, 0.8)
	im.fill(base)
	var fg := Color.from_hsv(fposmod(base.h + 0.4, 1.0), 0.8, 0.6)
	if randf() < 0.5:
		for y in CH:
			for x in CW:
				if Vector2(x - 48, y - 60).length() < 28:
					im.set_pixel(x, y, fg)
	else:
		im.fill_rect(Rect2i(24, 25, 48, 70), fg)
	take_in(im, true)


# ------------------------------------------------------------ album UI
func refresh_album() -> void:
	if album_grid == null:
		return
	for c in album_grid.get_children():
		c.queue_free()
	album_empty.visible = S["album"].is_empty()
	for i in range(S["album"].size() - 1, -1, -1):
		var e: Dictionary = S["album"][i]
		var b := TextureButton.new()
		b.texture_normal = entry_tex(e)
		b.custom_minimum_size = Vector2(20, 20)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.pressed.connect(func(): show_detail(e))
		album_grid.add_child(b)


func entry_tex(e: Dictionary) -> ImageTexture:
	var im := Image.new()
	im.load_png_from_buffer(Marshalls.base64_to_raw(e["img"]))
	return ImageTexture.create_from_image(im)


func show_detail(e: Dictionary) -> void:
	album_detail.visible = true
	album_detail_img.texture = entry_tex(e)
	var d := Time.get_datetime_dict_from_unix_time(int(e["t"]) + int(Time.get_time_zone_from_system()["bias"]) * 60)
	var said: String = e["said"]
	album_detail_l.text = "%s\n%02d/%02d %02d:%02d\nSeen %s\nIt felt %s" % [said.substr(0, 1).to_upper() + said.substr(1), d["day"], d["month"], d["hour"], d["minute"], place_name(int(e["place"])), e["mood"]]


# -------------------------------------------------------- sensor/album UI
func small_btn(text: String, pos: Vector2, size: Vector2, fs: int, cb: Callable, parent: Node) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs)
	b.pressed.connect(cb)
	parent.add_child(b)
	b.position = pos
	b.size = size
	return b


func small_label(text: String, pos: Vector2, size: Vector2, fs: int, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.position = pos
	l.size = size
	return l


func build_sensor_ui(ui: CanvasLayer) -> void:
	small_btn("sns", Vector2(2, 2), Vector2(20, 9), 5, func(): toggle_panel(sens_panel), ui).flat = true
	small_btn("alb", Vector2(24, 2), Vector2(20, 9), 5, func(): toggle_panel(album_panel), ui).flat = true
	upd_btn = small_btn("upd", Vector2(46, 2), Vector2(20, 9), 5, func(): toggle_panel(upd_panel), ui)
	upd_btn.flat = true
	build_update_ui(ui)
	sens_panel = Panel.new()
	sens_panel.position = Vector2(3, 14)
	sens_panel.size = Vector2(102, 190)
	sens_panel.visible = false
	ui.add_child(sens_panel)
	var rows := [["motion", "Motion", "steps, shaking", enable_motion], ["mic", "Microphone", "noise, voice", enable_mic], ["cam", "Camera", "show it things", enable_cam], ["geo", "Location", "new places", enable_geo], ["bg", "Background", "steps, places while closed", enable_bg]]
	var y := 3.0
	for r in rows:
		small_label(r[1], Vector2(3, y), Vector2(50, 7), 6, sens_panel)
		status_labels[r[0]] = small_label("off", Vector2(3, y + 7), Vector2(66, 12), 5, sens_panel)
		small_btn("Enable", Vector2(70, y + 2), Vector2(28, 11), 5, r[3], sens_panel)
		y += 20.0
	small_label("Camera view", Vector2(3, y), Vector2(60, 7), 6, sens_panel)
	var vx := 3.0
	for m in ["auto", "back", "front"]:
		small_btn(m.capitalize(), Vector2(vx, y + 8), Vector2(24, 10), 5, func(): cam_mode = m, sens_panel)
		vx += 26.0
	small_btn("Rotate", Vector2(3, y + 28), Vector2(32, 10), 5, func():
		cam_rot[cam_facing] = (cam_rot[cam_facing] + 1) % 4
		apply_cam_params(), sens_panel)
	small_btn("Flip", Vector2(37, y + 28), Vector2(24, 10), 5, func():
		cam_flip[cam_facing] = not cam_flip[cam_facing]
		apply_cam_params(), sens_panel)
	stats_l = small_label("", Vector2(3, y + 46), Vector2(96, 36), 4, sens_panel)
	set_status("motion", "off")

	album_panel = Panel.new()
	album_panel.position = Vector2(3, 14)
	album_panel.size = Vector2(102, 150)
	album_panel.visible = false
	ui.add_child(album_panel)
	small_label("Things it has seen", Vector2(3, 3), Vector2(96, 8), 6, album_panel)
	album_empty = small_label("Nothing yet. Enable the camera and hold something steady in front of the back camera.", Vector2(3, 14), Vector2(96, 30), 5, album_panel)
	var sc := ScrollContainer.new()
	sc.position = Vector2(3, 14)
	sc.size = Vector2(96, 132)
	album_panel.add_child(sc)
	album_grid = GridContainer.new()
	album_grid.columns = 4
	album_grid.add_theme_constant_override("h_separation", 2)
	album_grid.add_theme_constant_override("v_separation", 2)
	sc.add_child(album_grid)
	album_detail = Panel.new()
	album_detail.position = Vector2(2, 14)
	album_detail.size = Vector2(98, 70)
	album_detail.visible = false
	album_panel.add_child(album_detail)
	album_detail_img = TextureRect.new()
	album_detail_img.position = Vector2(4, 4)
	album_detail_img.size = Vector2(40, 40)
	album_detail_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	album_detail_img.stretch_mode = TextureRect.STRETCH_SCALE
	album_detail_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	album_detail.add_child(album_detail_img)
	album_detail_l = small_label("", Vector2(48, 3), Vector2(48, 50), 5, album_detail)
	small_btn("Close", Vector2(33, 54), Vector2(32, 11), 5, func(): album_detail.visible = false, album_detail)
	refresh_album()


func build_update_ui(ui: CanvasLayer) -> void:
	upd_panel = Panel.new()
	upd_panel.position = Vector2(3, 14)
	upd_panel.size = Vector2(102, 90)
	upd_panel.visible = false
	ui.add_child(upd_panel)
	small_label("Updates", Vector2(3, 3), Vector2(60, 8), 6, upd_panel)
	upd_status = small_label("", Vector2(3, 13), Vector2(96, 44), 5, upd_panel)
	upd_action = small_btn("Check now", Vector2(3, 62), Vector2(60, 12), 5, upd_press, upd_panel)
	small_btn("Close", Vector2(66, 62), Vector2(32, 12), 5, func(): upd_panel.visible = false, upd_panel)
	upd_refresh_ui()


func upd_cls():
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		return null
	return JavaClassWrapper.wrap("com.pierrejoshua.digivi.Updater")


func upd_activity():
	return Engine.get_singleton("AndroidRuntime").getActivity()


func upd_current_code() -> int:
	var c = upd_cls()
	return int(c.versionCode(upd_activity())) if c != null else 0


func upd_current_name() -> String:
	var c = upd_cls()
	return str(c.versionName(upd_activity())) if c != null else "desktop"


func upd_check() -> void:
	var c = upd_cls()
	if c == null:
		upd_phase = "error"
		upd_msg = "Updates only work on the phone."
		upd_refresh_ui()
		return
	upd_phase = "checking"
	c.check(UPDATE_URL)
	upd_refresh_ui()


func upd_press() -> void:
	var c = upd_cls()
	match upd_phase:
		"available":
			upd_phase = "downloading"
			upd_pct = 0
			c.download(upd_activity(), UPDATE_BASE + str(upd_info.get("apk", "digivi-latest.apk")))
		"downloaded":
			save_state()
			var r := str(c.install(upd_activity()))
			if r == "permission":
				upd_msg = "Allow Digivi to install apps on the screen that opened, then come back and tap Install."
			elif r != "ok":
				upd_msg = "Could not start install: " + r
		"checking", "downloading":
			pass
		_:
			upd_check()
	upd_refresh_ui()


var upd_msg := ""
var upd_pct := 0


func upd_poll(dt: float) -> void:
	if not upd_auto_done and OS.has_feature("android"):
		upd_t += dt
		if upd_t > 4.0:
			upd_auto_done = true
			upd_check()
	if upd_phase != "checking" and upd_phase != "downloading":
		return
	var c = upd_cls()
	if c == null:
		return
	var st := str(c.state())
	if upd_phase == "checking":
		if st.begins_with("info:"):
			var j = JSON.parse_string(st.substr(5))
			if typeof(j) == TYPE_DICTIONARY:
				upd_info = j
				if int(j.get("code", 0)) > upd_current_code():
					upd_phase = "available"
				else:
					upd_phase = "current"
			else:
				upd_phase = "error"
				upd_msg = "Update info was not readable."
			upd_refresh_ui()
		elif st.begins_with("error:"):
			upd_phase = "error"
			upd_msg = "Could not check: " + st.substr(6)
			upd_refresh_ui()
	elif upd_phase == "downloading":
		if st == "downloaded":
			upd_phase = "downloaded"
			upd_refresh_ui()
		elif st.begins_with("error:"):
			upd_phase = "error"
			upd_msg = "Download failed: " + st.substr(6)
			upd_refresh_ui()
		elif st.begins_with("downloading:"):
			var p := int(st.substr(12))
			if p != upd_pct:
				upd_pct = p
				upd_refresh_ui()


func upd_refresh_ui() -> void:
	if upd_status == null:
		return
	var cur := "Version %s" % upd_current_name()
	match upd_phase:
		"idle":
			upd_status.text = cur
			upd_action.text = "Check now"
		"checking":
			upd_status.text = cur + "\nChecking..."
			upd_action.text = "..."
		"current":
			upd_status.text = cur + "\nYou have the latest."
			upd_action.text = "Check now"
		"available":
			upd_status.text = "%s\nNew: %s\n%s" % [cur, str(upd_info.get("name", "?")), str(upd_info.get("notes", ""))]
			upd_action.text = "Download"
		"downloading":
			upd_status.text = "%s\nDownloading %d%%" % [cur, upd_pct]
			upd_action.text = "..."
		"downloaded":
			upd_status.text = "%s\nReady. Your pet is saved. Tap Install, then Update on Android's screen." % cur
			upd_action.text = "Install"
		"error":
			upd_status.text = cur + "\n" + upd_msg
			upd_action.text = "Try again"
	if upd_msg != "" and upd_phase == "downloaded":
		upd_status.text += "\n" + upd_msg
	if upd_btn != null:
		upd_btn.text = "upd!" if (upd_phase == "available" or upd_phase == "downloaded") else "upd"


func toggle_panel(p: Panel) -> void:
	var was := p.visible
	sens_panel.visible = false
	album_panel.visible = false
	album_detail.visible = false
	upd_panel.visible = false
	p.visible = not was


func update_stats() -> void:
	if sens_panel != null and sens_panel.visible:
		stats_l.text = "steps %d  places %d  faces %d\ncamera %s  tilt %d  shown %d\nmic %.2f\n%s\n%s" % [S["steps"], S["places"].size(), S["faces"], (cam_facing if cam_on else "off"), int(m_tilt), S["shows"], mic_lvl, diag_text, cam_diag]
		diag_t += 0.25
		if diag_t > 2.0 and svc_cls != null and OS.has_feature("android"):
			diag_t = 0.0
			diag_text = str(svc_cls.diag(Engine.get_singleton("AndroidRuntime").getActivity()))


# ---------------------------------------------------------------- growth
func total_xp() -> float:
	var x: Dictionary = S["xp"]
	return x["exp"] + x["cud"] + x["che"] + x["slp"]


func dominant() -> String:
	var best := "exp"
	for k in S["xp"]:
		if S["xp"][k] > S["xp"][best]:
			best = k
	return best


func check_growth() -> void:
	if cer != null or S["name"] == "":
		return
	var tx := total_xp()
	if S["stage"] == "baby" and tx >= CHILD_XP:
		start_ceremony("child", "")
	elif S["stage"] == "child" and tx >= ADULT_XP:
		start_ceremony("adult", dominant())


func start_ceremony(to: String, form_key: String) -> void:
	if cer != null:
		return
	cer = {"t": 0.0, "from_stage": S["stage"], "from_form": S.get("form", ""), "to": to, "form_key": form_key, "done": false}
	sfx(330, 0.5, "triangle", 0.05, 330)
	cer_l.text = "%s is changing..." % (S["name"] if S["name"] != "" else "It")
	cer_l.modulate.a = 1.0


func update_ceremony(dt: float) -> void:
	cer["t"] += dt
	var c: Dictionary = cer
	if c["t"] >= 3.0 and not c["done"]:
		c["done"] = true
		S["stage"] = c["to"]
		if c["form_key"] != "":
			S["form"] = c["form_key"]
		burst(54, 100, 36, [Color("#fff7a0"), Color("#ff9ad9"), Color("#8bf0ff"), Color.WHITE], 70.0)
		boing()
		get_tree().create_timer(0.12).timeout.connect(func(): sfx(1040, 0.3, "square", 0.05, 200))
		var nm: String = S["name"] if S["name"] != "" else "It"
		cer_l.text = nm + (" is growing up." if c["to"] == "child" else " has grown up.")
		save_state()
	if c["t"] >= 6.0:
		cer = null
		cer_l.modulate.a = 0.0


func draw_ceremony() -> void:
	var c: Dictionary = cer
	var ct: float = c["t"]
	ga = 0.5
	rect(0, 0, W, H, Color.BLACK)
	ga = 1.0
	var stg: String = c["from_stage"] if ct < 3.0 else c["to"]
	var fk: String = c["from_form"] if ct < 3.0 else (c["form_key"] if c["form_key"] != "" else S.get("form", ""))
	var fm: String = FORM.get(fk, "") if stg == "adult" else ""
	var shake := sin(ct * 60.0) * 1.5 if ct > 2.0 and ct < 2.6 else 0.0
	var sc := 1.0 + 0.06 * sin(ct * 8.0) if ct < 3.0 else 1.0
	draw_pet(stg, fm, 54 + shake, 118, sc, false, ct < 3.0, "excited" if ct < 3.0 else "happy")
	var cols := [Color("#fff7a0"), Color("#ff9ad9"), Color("#8bf0ff")]
	if ct < 5.2:
		for i in 14:
			var ang := ct * 4.0 + i * 0.45
			var r := 0.0
			if ct < 2.0:
				r = lerpf(46.0, 22.0, ct / 2.0)
			elif ct < 3.4:
				r = 22.0
			else:
				r = 22.0 + (ct - 3.4) * 26.0
			px(54 + cos(ang) * r, 100 + sin(ang) * r * 0.8, cols[i % 3])
	var a := 0.0
	if ct >= 2.6 and ct < 3.0:
		a = (ct - 2.6) / 0.4
	elif ct >= 3.0 and ct < 3.5:
		a = 1.0 - (ct - 3.0) / 0.5
	if a > 0.0:
		ga = a
		rect(0, 0, W, H, Color.WHITE)
		ga = 1.0


func force_stage(stage: String, key: String) -> void:
	if S["stage"] == "egg":
		start_hatch()
	if S["name"] == "":
		S["name"] = "Test"
		namer.visible = false
		namer_shown = true
	if stage == "child":
		S["xp"]["exp"] = maxf(S["xp"]["exp"], 300.0)
	start_ceremony(stage, key)


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
	var keep: Array = S["places"]
	S = fresh()
	S["places"] = keep
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
	check_growth()


func update_pet(dt: float) -> void:
	var ns := neglect_state()
	if S["stage"] == "egg" or ns == "away" or ns == "lost":
		return
	if is_sleeping() or ns == "dormant":
		act = "rest"
		return
	var busy := dance > 0.0 or startle > 0.0
	if show["open"] > 0.5 or show["bubble_t"] > 0.0:
		pet_tx = 30.0
		act = "watch"
		look_x = 1.0
	elif watch > 0.0:
		pet_tx = 54.0
		act = "watch"
		look_x = 0.0
	elif not busy:
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
			if S["places"].size() > 0 and r < 0.25:
				act = "toy"
				pet_tx = toy_x(randi() % S["places"].size())
			elif r < 0.75:
				act = "wander"
				pet_tx = rnd(22, 86)
			else:
				act = "rest"
	var speed := (16.0 if act == "food" else 10.0) * (0.6 if S.get("form", "") == "slp" else 1.0)
	if act != "rest":
		var dx := pet_tx - pet_x
		if absf(dx) > 1.0:
			pet_x += signf(dx) * minf(absf(dx), speed * dt)
			pet_dir = signf(dx)


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	t += dt
	for k in ["startle", "happy", "excited", "dance", "wake", "funny", "egg_shake", "sing", "watch", "tint_t"]:
		if get(k) > 0.0:
			set(k, maxf(0.0, get(k) - dt))
	squish += (1.0 - squish) * minf(1.0, dt * 8.0)
	if funny > 0.0:
		squish = 1.0 + 0.22 * sin(t * 14.0) * (funny / 2.2)
	look_x *= 0.9
	update_parts(dt)
	for k in ["flash", "freeze", "bubble_t", "tilt"]:
		if show[k] > 0.0:
			show[k] = maxf(0.0, show[k] - dt)
	var want_open := 1.0 if (cam_on and cam_facing == "back" and can_show()) else 0.0
	show["open"] += (want_open - show["open"]) * minf(1.0, dt * 6.0)
	if want_open == 0.0 and show["open"] < 0.02:
		show["open"] = 0.0
		vf_ok = false
	bg_poll(dt)
	perm_poll(dt)
	upd_poll(dt)
	svc_t += dt
	if svc_t > 1.0:
		svc_t = 0.0
		apply_pending()
	if cer == null:
		mic_frame(dt)
		cam_frame(dt)
		geo_frame(dt)
	for fd in food:
		fd["y"] = minf(GROUND + 4.0, fd["y"] + 70.0 * dt)
	if cer != null:
		update_ceremony(dt)
	else:
		update_pet(dt)
		acc += dt
		while acc >= 1.0:
			acc -= 1.0
			tick_1s()
		save_acc += dt
		if save_acc > 5.0:
			save_acc = 0.0
			save_state()
		if S["stage"] == "adult" and S.get("form", "") == "slp" and neglect_state() != "away":
			spark_acc += dt
			if spark_acc > 0.35:
				spark_acc = 0.0
				add_part("px", pet_x + rnd(-10, 10), GROUND - 12, 0, 12, 1.2, Color("#bfe6ff"))
	if S["stage"] != "egg" and S["name"] == "" and not namer_shown and funny <= 0.0:
		show_namer()
	if toast_t > 0.0:
		toast_t -= dt
		if toast_t <= 0.0:
			toast_l.modulate.a = 0.0
	update_hud()
	update_stats()
	queue_redraw()
	if shot_dir != "":
		shot_tick()


func _physics_process(_dt: float) -> void:
	if S.get("sens", {}).get("motion", true):
		motion_frame()


func _draw() -> void:
	draw_world()
	has_bbox = false
	var ns := neglect_state()
	if cer != null:
		draw_ceremony()
	elif ns != "away" and ns != "lost":
		var dormant := ns == "dormant"
		var fm: String = FORM.get(S.get("form", ""), "") if S["stage"] == "adult" else ""
		draw_pet(S["stage"], fm, pet_x, GROUND + 1, 0.82 if dormant else squish, dormant, dormant or is_sleeping())
	elif ns == "lost":
		ell(54, GROUND + 1, 14, 3, Color("#7a5a3a"))
		ell(54, GROUND, 12, 2, Color("#a07a4a"))
	if S["stage"] != "egg" and (is_sleeping() or ns == "dormant") and randf() < 0.01:
		add_part("z", pet_x + 8, GROUND - 24, 4, -8, 1.8)
	draw_viewfinder()
	draw_parts()
	draw_bubble()


# ----------------------------------------------------------------- input
func in_box(p: Vector2) -> bool:
	return has_bbox and bbox.has_point(p)


func _unhandled_input(e: InputEvent) -> void:
	if namer.visible or cer != null:
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
	cer_l = make_label(8, 42, 24)
	cer_l.modulate.a = 0.0
	ui.add_child(cer_l)
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

	build_sensor_ui(ui)

	# debug panel
	var db := Button.new()
	db.text = "dbg"
	db.add_theme_font_size_override("font_size", 5)
	db.flat = true
	db.position = Vector2(W - 22, 2)
	db.size = Vector2(20, 9)
	ui.add_child(db)
	dbg_panel = PanelContainer.new()
	dbg_panel.position = Vector2(W - 62, 12)
	dbg_panel.visible = false
	ui.add_child(dbg_panel)
	var vb := VBoxContainer.new()
	dbg_panel.add_child(vb)
	var items := [
		["Drop food", func(): spawn_food()],
		["+100 steps", func(): on_step(100)],
		["Shake", func(): on_shake()],
		["Loud noise", func(): on_loud()],
		["Sing to it", func(): sing_debug()],
		["Show a colour", func(): on_colour(Color.from_hsv(randf(), 0.7, 0.9))],
		["It sees a face", func(): face_last = -99.0; on_face()],
		["New place", func(): on_new_place("dbg%d" % randi())],
		["Show it something", func(): if S["stage"] == "egg": toast("Hatch it first.") else: fake_show()],
		["Hatch now", func(): if S["stage"] == "egg": start_hatch()],
		["Grow: child", func(): force_stage("child", "")],
		["Adult: explorer", func(): force_stage("adult", "exp")],
		["Adult: cuddly", func(): force_stage("adult", "cud")],
		["Adult: cheeky", func(): force_stage("adult", "che")],
		["Adult: sleepy", func(): force_stage("adult", "slp")],
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
	var th := make_theme()
	for c in ui.get_children():
		if c is Control:
			c.theme = th


func sing_debug() -> void:
	dance = 1.2
	wake = 15.0
	get_tree().create_timer(1.1).timeout.connect(func(): copy_back([300, 340, 380, 340, 300, 420, 460, 420]))


func set_needs(v: float) -> void:
	for k in ["hun", "aff", "cur"]:
		S["needs"][k] = v
	if v >= 100.0:
		S["needs"]["ene"] = 100.0
		S["neglectH"] = 0.0
		dbg_neglect = ""


func make_theme() -> Theme:
	var th := Theme.new()
	var states := {"normal": Color("#2a2450"), "hover": Color("#3a3270"), "pressed": Color("#ffcf5a"), "disabled": Color("#1d1940")}
	for k in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[k]
		sb.set_border_width_all(1)
		sb.border_color = Color("#4a3f8a")
		sb.content_margin_left = 2
		sb.content_margin_right = 2
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		th.set_stylebox(k, "Button", sb)
	th.set_color("font_color", "Button", Color("#f4ecff"))
	th.set_color("font_pressed_color", "Button", Color("#241a05"))
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color("#1d1940")
	pb.set_border_width_all(1)
	pb.border_color = Color("#4a3f8a")
	th.set_stylebox("panel", "Panel", pb)
	th.set_stylebox("panel", "PanelContainer", pb)
	var le := StyleBoxFlat.new()
	le.bg_color = Color("#120f26")
	le.set_border_width_all(1)
	le.border_color = Color("#4a3f8a")
	le.content_margin_left = 2
	le.content_margin_right = 2
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", le)
	return th


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
		5: start_hatch()
		40: S["name"] = "Pip"; namer.visible = false; namer_shown = true
		45: fake_cam()
		120: save_shot("viewfinder")
		121: get_tree().quit()


func fake_cam() -> void:
	var path := OS.get_environment("DIGIVI_PHOTO")
	if path == "":
		return
	setup_cam_view()
	var im := Image.load_from_file(path)
	cam_mat.set_shader_parameter("tex0", ImageTexture.create_from_image(im))
	cam_mat.set_shader_parameter("ycbcr", 0)
	cam_mat.set_shader_parameter("rot", 0)
	cam_mat.set_shader_parameter("mirror", 0)
	cam_mat.set_shader_parameter("crop", Vector2(0.78, 1.0))
	cam_on = true


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
	get_tree().on_request_permissions_result.connect(on_perm_result)
	enable_motion()
	if S["sens"].get("mic", false):
		enable_mic()
	if S["sens"].get("geo", false):
		enable_geo()
	if S["sens"].get("cam", false):
		enable_cam()
	if S["sens"].get("bg", false):
		enable_bg()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not perm_wait.is_empty():
			perm_paused = true
		save_state()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if perm_paused:
			perm_resumed = true
		if cam_on:
			restart_stream()
		var hrs := clampf((Time.get_unix_time_from_system() - float(S["last"])) / 3600.0, 0.0, 24.0 * 30.0)
		if S["stage"] != "egg" and hrs > 0.01:
			decay(hrs, true)
		S["last"] = Time.get_unix_time_from_system()
