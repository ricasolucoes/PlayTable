class_name GameTimer
extends Node

## Helper component to manage game time and replace manual _process(delta) counting.

signal time_changed(seconds: int)
signal timeout()

@export var count_down: bool = false
@export var starting_time: float = 0.0

var elapsed_time: float = 0.0
var active: bool = false

func start() -> void:
	active = true

func stop() -> void:
	active = false

func reset() -> void:
	elapsed_time = starting_time
	time_changed.emit(int(elapsed_time))

func get_time() -> int:
	return int(elapsed_time)

func _process(delta: float) -> void:
	if not active:
		return
		
	var prev_sec := int(elapsed_time)
	if count_down:
		elapsed_time -= delta
		if elapsed_time <= 0:
			elapsed_time = 0
			active = false
			timeout.emit()
	else:
		elapsed_time += delta
		
	if int(elapsed_time) != prev_sec:
		time_changed.emit(int(elapsed_time))
