class_name Inventory
extends RefCounted
## Party gold and shared storage.

var gold := 0
var storage: Array[ItemData] = []


func buy(item: ItemData) -> bool:
	if gold < item.price:
		return false
	gold -= item.price
	storage.append(item)
	return true


func sell(index: int) -> bool:
	if index < 0 or index >= storage.size():
		return false
	gold += storage[index].price / 2
	storage.remove_at(index)
	return true


func to_dict() -> Dictionary:
	return {"gold": gold, "storage": storage.map(func(i: ItemData) -> String: return String(i.id))}


static func from_dict(d: Dictionary) -> Inventory:
	var inv := Inventory.new()
	inv.gold = d.get("gold", 0)
	for id in d.get("storage", []):
		var it := Content.item(StringName(id))
		if it != null:
			inv.storage.append(it)
	return inv
