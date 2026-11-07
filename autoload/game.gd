extends Node
## Screen flow state machine. Holds the current Campaign. (Filled in at step 7.)

enum Screen { TITLE, CAMP, TOWN, BATTLE, RESULTS }

signal screen_changed(screen: Screen)
