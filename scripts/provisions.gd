extends RefCounted
## Общие свойства улова и еды. Вес хранится в граммах, редкость сохраняется с рыбой.
const SPECIES := [
	{"id": "perch", "name": "Морской окунь", "rarity": "common", "speed": 0.18, "zone": 0.32, "min_weight": 220, "max_weight": 700, "turn_min": 0.8, "turn_max": 1.6, "gain": 0.17, "loss": 0.12},
	{"id": "mackerel", "name": "Скумбрия", "rarity": "rare", "speed": 0.27, "zone": 0.28, "min_weight": 500, "max_weight": 1600, "turn_min": 0.65, "turn_max": 1.1, "gain": 0.15, "loss": 0.13},
	{"id": "sturgeon", "name": "Северный осётр", "rarity": "legendary", "speed": 0.35, "zone": 0.24, "min_weight": 1200, "max_weight": 4000, "turn_min": 0.45, "turn_max": 0.9, "gain": 0.13, "loss": 0.14}
]
const RARITIES := {
	"common": {"name": "Обычная", "color": "9cbca6", "health": 3, "hunger": 12},
	"rare": {"name": "Редкая", "color": "82b9df", "health": 8, "hunger": 22},
	"legendary": {"name": "Легендарная", "color": "e8ba64", "health": 18, "hunger": 36}
}

static func definition(id: String) -> Dictionary:
	for species in SPECIES:
		if species.id == id:
			return species.duplicate()
	return {}

static func choose(rng: RandomNumberGenerator, first_cast: bool) -> Dictionary:
	if first_cast:
		return SPECIES[0].duplicate()
	var chance := rng.randf()
	return SPECIES[0 if chance < 0.70 else (1 if chance < 0.95 else 2)].duplicate()

static func fish_item(id: String, grams: int) -> Dictionary:
	var species := definition(id)
	if species.is_empty():
		return {}
	return {"kind": "fish", "species": id, "name": species.name, "rarity": species.rarity, "weight": clampi(grams, 1, 10000)}

static func ration() -> Dictionary:
	return {"kind": "ration", "name": "Паёк", "rarity": "common", "weight": 0}

static func bonuses(item: Dictionary) -> Dictionary:
	if item.get("kind", "") == "ration":
		return {"health": 5, "hunger": 35}
	var rarity: Dictionary = RARITIES.get(item.get("rarity", "common"), RARITIES.common)
	var grams := int(item.get("weight", 300))
	return {"health": roundi(float(rarity.health) + grams * 0.008), "hunger": roundi(float(rarity.hunger) + grams * 0.015)}

static func rarity_name(item: Dictionary) -> String:
	return str(RARITIES.get(item.get("rarity", "common"), RARITIES.common).name)

static func rarity_color(item: Dictionary) -> Color:
	return Color(str(RARITIES.get(item.get("rarity", "common"), RARITIES.common).color))

static func label(item: Dictionary) -> String:
	if item.get("kind", "") == "ration":
		return "Паёк"
	return "%s %d г · %s" % [str(item.name), int(item.weight), rarity_name(item).to_lower()]

static func restore(raw: Variant, count: int, cooked: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for value in raw:
			if not value is Dictionary:
				continue
			if cooked and value.get("kind", "") == "ration":
				result.append(ration())
			elif value.get("weight") is float or value.get("weight") is int:
				var item := fish_item(str(value.get("species", "")), int(value.weight))
				if not item.is_empty():
					result.append(item)
	else:
		# В старых сохранениях были только количества, без веса и редкости.
		for index in clampi(count, 0, 999):
			result.append(ration() if cooked else fish_item("perch", 300))
	return result
