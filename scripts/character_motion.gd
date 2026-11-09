extends RefCounted

const LOOPS := ["idle", "walk", "run", "watch", "fish_hold"]
var animator: AnimationPlayer
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
		for clip in LOOPS:
			if animator.has_animation(clip):
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

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
		animator.advance(delta)
