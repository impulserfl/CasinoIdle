class_name FX
extends RefCounted

## Small juice helpers: floating win text, pulses, flashes, shakes.
## All of these are no-ops if the host node has left the tree, so they are safe
## to fire from inside a coroutine that may outlive its scene.


## Spawns a label at `at` (local to `host`) that drifts up and fades out.
static func float_text(host: Control, text: String, color: Color, at: Vector2,
		size: int = 28) -> void:
	if host == null or not host.is_inside_tree():
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 100
	# Fixed size avoids waiting a frame for the label to measure itself.
	l.size = Vector2(360, 44)
	l.position = at - Vector2(180, 22)
	host.add_child(l)

	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 80.0, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(l.queue_free)


## Quick scale-up-and-back.
static func pulse(node: Control, amount: float = 1.12, duration: float = 0.22) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * amount, duration * 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, duration * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## Tints a node toward `color` then back to white.
static func flash(node: CanvasItem, color: Color, duration: float = 0.45) -> void:
	if node == null or not node.is_inside_tree():
		return
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color.WHITE, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Positional shake around the node's current position.
static func shake(node: Control, strength: float = 8.0, duration: float = 0.3) -> void:
	if node == null or not node.is_inside_tree():
		return
	var origin := node.position
	var tw := node.create_tween()
	var steps := 6
	for i in range(steps):
		var falloff := strength * (1.0 - float(i) / float(steps))
		var offset := Vector2(randf_range(-falloff, falloff), randf_range(-falloff, falloff))
		tw.tween_property(node, "position", origin + offset, duration / float(steps))
	tw.tween_property(node, "position", origin, duration / float(steps))


## Counts a label from one value to another (chips formatting applied).
static func count_to(host: Node, target_label: Label, from_value: float,
		to_value: float, duration: float = 0.4) -> void:
	if host == null or not host.is_inside_tree() or target_label == null:
		return
	var tw := host.create_tween()
	var setter := Callable(FX, "_apply_chip_text").bind(target_label)
	tw.tween_method(setter, from_value, to_value, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _apply_chip_text(value: float, target_label: Label) -> void:
	if is_instance_valid(target_label):
		target_label.text = Fmt.chips(value)
