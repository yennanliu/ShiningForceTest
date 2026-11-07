class_name SpecialData
extends Resource
## A weapon special that may trigger on attack.

enum Effect { EXTRA_HIT, POISON, SLEEP, DRAIN }

@export var effect: Effect = Effect.EXTRA_HIT
@export_range(0.0, 1.0) var chance := 0.1
