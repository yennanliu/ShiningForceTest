class_name Rng
extends RefCounted
## The only source of randomness in a battle. Seeded, so battles replay exactly.

var start_seed: int
var _gen := RandomNumberGenerator.new()


func _init(p_seed: int) -> void:
	start_seed = p_seed
	_gen.seed = p_seed


## Uniform float in [lo, hi].
func between(lo: float, hi: float) -> float:
	return _gen.randf_range(lo, hi)


## True with probability p (0..1).
func chance(p: float) -> bool:
	return _gen.randf() < p


## Uniform int in [lo, hi].
func roll(lo: int, hi: int) -> int:
	return _gen.randi_range(lo, hi)


func pick(arr: Array) -> Variant:
	return arr[_gen.randi_range(0, arr.size() - 1)]
