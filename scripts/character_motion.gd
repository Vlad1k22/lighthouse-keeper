extends RefCounted

const LOOPS := ["idle", "walk", "run", "watch", "fish_hold", "jog"]
## Во сколько раз усилить размах костей в процедурной «трусце» (на основе клипа run).
const STRIDE := {"Thigh":1.5, "Shin":1.45, "Foot":1.35, "UpperArm":1.7, "Forearm":1.5, "Spine":1.4, "Chest":1.4}
var animator: AnimationPlayer
## Темп зацикленных клипов: подгоняется под скорость персонажа, чтобы ноги не скользили.
var rate := 1.0
var skeleton: Skeleton3D
var lantern_glow: MeshInstance3D
var current := ""

func bind(model: Node3D) -> void:
	if model == null:
		return
	animator = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
		break
	lantern_glow = model.find_child("LanternGlow", true, false) as MeshInstance3D
	if animator != null:
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if animator.has_animation("run") and not animator.has_animation("jog"):
			_build_jog()
		for clip in LOOPS:
			if animator.has_animation(clip):
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

## Широкий беговой шаг: размах ног и рук вокруг средней позы усиливается.
func _build_jog() -> void:
	var source := animator.get_animation("run")
	var jog := source.duplicate(true) as Animation
	for track in jog.get_track_count():
		if jog.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(jog.track_get_path(track).get_concatenated_subnames())
		var factor := 1.0
		for key in STRIDE:
			if bone.begins_with(key):
				factor = STRIDE[key]
		if factor == 1.0:
			continue
		var count := jog.track_get_key_count(track)
		if count < 2:
			continue
		var first: Quaternion = jog.track_get_key_value(track, 0)
		var sum := Vector4.ZERO
		for k in count:
			var q: Quaternion = jog.track_get_key_value(track, k)
			if q.dot(first) < 0:
				q = -q
			sum += Vector4(q.x, q.y, q.z, q.w)
		sum = sum.normalized()
		var mean := Quaternion(sum.x, sum.y, sum.z, sum.w)
		for k in count:
			var q: Quaternion = jog.track_get_key_value(track, k)
			var delta := (mean.inverse() * q).normalized()
			if delta.w < 0:
				delta = -delta
			var angle := delta.get_angle()
			if angle < .0001:
				continue
			jog.track_set_key_value(track, k, (mean * Quaternion(delta.get_axis(), angle * factor)).normalized())
	var library := animator.get_animation_library("")
	if library != null:
		library.add_animation("jog", jog)

func play(clip: String, blend := .10, force := false) -> void:
	if animator == null or not animator.has_animation(clip):
		return
	if current != clip or force:
		if force and current == clip:
			animator.stop(true)
		current = clip
		animator.play(clip, blend)

func length(clip: String, fallback: float) -> float:
	if animator != null and animator.has_animation(clip):
		return animator.get_animation(clip).length
	return fallback

func tick(delta: float) -> void:
	if animator != null:
		animator.advance(delta * (rate if current in LOOPS else 1.0))
