extends RefCounted
## Blender-authored radio outpost; existing stations and campaign state stay authoritative.
const MODEL := "res://assets/models/radio_station/radio_station_v01.glb"
const LEGACY_PREFIXES := ["RadioHut","RadioRoof","RadioConsole","RadioDial","RadioKnob","AntennaMast","AntennaCross","GuyWire"]

static func install(coast: Node3D) -> bool:
	if coast.has_node("RadioOutpost"):
		return true
	if not ResourceLoader.exists(MODEL):
		return false
	var packed: PackedScene = load(MODEL)
	if packed == null:
		return false
	for child in coast.get_children():
		if not child is MeshInstance3D:
			continue
		for prefix in LEGACY_PREFIXES:
			if str(child.name).begins_with(prefix):
				child.hide()
	var outpost := Node3D.new()
	outpost.name = "RadioOutpost"
	outpost.position = Vector3(-12,1,-39.5)
	coast.add_child(outpost)
	var owner_root: Node = coast if coast.owner == null else coast.owner
	outpost.owner = owner_root
	var visual: Node3D = packed.instantiate()
	visual.name = "BlenderVisual"
	outpost.add_child(visual)
	visual.owner = owner_root
	# Simple extra shapes follow the visible tower foot and protruding battery shelf.
	# The original wall/console/mast bodies remain present; cables are intentionally non-blocking.
	var body := StaticBody3D.new()
	body.name = "OutpostCollision"
	outpost.add_child(body)
	body.owner = owner_root
	var base := BoxShape3D.new()
	base.size = Vector3(1.12,.18,1.10)
	add_shape(body,base,Vector3(-4,.09,-.5),"MastPlinth",owner_root)
	var mast := CylinderShape3D.new()
	mast.radius = .42
	mast.height = 1.7
	add_shape(body,mast,Vector3(-4,1.0,-.5),"MastFoot",owner_root)
	var shelf := BoxShape3D.new()
	shelf.size = Vector3(1.95,1.30,.26)
	add_shape(body,shelf,Vector3(0,.65,3.27),"TransmitterFront",owner_root)
	var light := OmniLight3D.new()
	light.name = "SignalIndicatorLight"
	light.position = Vector3(.14,1.105,3.33)
	light.omni_range = 1.4
	light.shadow_enabled = false
	outpost.add_child(light)
	light.owner = owner_root
	sync(coast,false)
	return true

static func add_shape(body: StaticBody3D, shape: Shape3D, at: Vector3, title: String, owner_root: Node) -> void:
	var collision := CollisionShape3D.new()
	collision.name = title
	collision.shape = shape
	collision.position = at
	body.add_child(collision)
	collision.owner = owner_root

static func sync(coast: Node3D, repaired: bool) -> void:
	var outpost := coast.get_node_or_null("RadioOutpost")
	if outpost == null:
		return
	var visual := outpost.get_node("BlenderVisual")
	for pair in [["RS_PanelFault",not repaired],["RS_PanelOnline",repaired],["RS_BatteryInstalled",repaired]]:
		var node: Node3D = visual.find_child(pair[0],true,false)
		if node != null:
			node.visible = pair[1]
	var light: OmniLight3D = outpost.get_node("SignalIndicatorLight")
	light.light_color = Color("8bc997") if repaired else Color("bc7443")
	light.light_energy = .35 if repaired else .05
