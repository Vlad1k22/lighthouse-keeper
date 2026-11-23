extends RefCounted
## Убирает мерцание (z-fighting) плоских объектов, лежащих вплотную на одной высоте:
## доски причала на основании гавани, слои почвы и сегменты тропинок.
## Меньший объект приподнимается на несколько миллиметров — на глаз незаметно.
const FLAT := 0.45
const SAME := 0.006
const LIFT := 0.009
const CELL := 6.0

static func apply(world: Node) -> int:
	var items := []
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if box.size.y > FLAT or box.size.x * box.size.z < .02:
			continue
		items.append({"node":mesh, "box":box, "top":box.end.y, "area":box.size.x * box.size.z})
	items.sort_custom(func(a, b): return a.area > b.area)
	var grid := {}
	var lifted := 0
	for item in items:
		var box: AABB = item.box
		var keys := _cells(box)
		var raise := 0.0
		for key in keys:
			for other in grid.get(key, []):
				var other_box: AABB = other.box
				if absf(float(other.top) - float(item.top) - raise) < SAME and other_box.intersects(box):
					var overlap := other_box.intersection(box)
					if overlap.size.x * overlap.size.z > .01:
						raise = float(other.top) - float(item.top) + LIFT
		if raise > 0:
			item.node.global_position.y += raise
			item.top = float(item.top) + raise
			lifted += 1
		for key in keys:
			if not grid.has(key):
				grid[key] = []
			grid[key].append(item)
	return lifted

static func _cells(box: AABB) -> Array:
	var keys := []
	for x in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
		for z in range(floori(box.position.z / CELL), floori(box.end.z / CELL) + 1):
			keys.append(Vector2i(x, z))
	return keys
