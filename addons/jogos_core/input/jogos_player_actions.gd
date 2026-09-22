class_name JogosPlayerActions
extends RefCounted

## Acoes de InputMap por jogador, criadas em runtime: `p1_up`, `p2_confirm`...
##
## Padrao do SuperTuxParty (`player1_up`, `player1_action1`): nenhum jogo le
## `Input.is_key_pressed()`; le acoes, e o teclado, o gamepad e os botoes de
## toque (`JogosTouchStick`/`JogosTouchButton`) alimentam as mesmas acoes.
## Nao havia equivalente nos jogos da casa (PlayTable: zero acoes; VOLTA:
## teclado fixo no roteador). Jogadores sao 1..N; o gamepad do jogador `n` e
## o `device n-1`. Bindings persistem no SaveManager, secao `Input`.

const ACTIONS: PackedStringArray = [
	"up", "down", "left", "right", "confirm", "cancel",
	"action1", "action2", "action3", "action4",
]

const MAX_PLAYERS: int = 4
const SAVE_SECTION: String = "Input"

const KEYBOARD_P1: Dictionary = {
	"up": [KEY_W, KEY_UP],
	"down": [KEY_S, KEY_DOWN],
	"left": [KEY_A, KEY_LEFT],
	"right": [KEY_D, KEY_RIGHT],
	"confirm": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"cancel": [KEY_ESCAPE, KEY_BACKSPACE],
	"action1": [KEY_E, KEY_J],
	"action2": [KEY_Q, KEY_K],
	"action3": [KEY_R, KEY_L],
	"action4": [KEY_F, KEY_I],
}

const GAMEPAD_BUTTONS: Dictionary = {
	"up": [JOY_BUTTON_DPAD_UP],
	"down": [JOY_BUTTON_DPAD_DOWN],
	"left": [JOY_BUTTON_DPAD_LEFT],
	"right": [JOY_BUTTON_DPAD_RIGHT],
	"confirm": [JOY_BUTTON_A],
	"cancel": [JOY_BUTTON_B],
	"action1": [JOY_BUTTON_X],
	"action2": [JOY_BUTTON_Y],
	"action3": [JOY_BUTTON_LEFT_SHOULDER],
	"action4": [JOY_BUTTON_RIGHT_SHOULDER],
}

## (eixo, sinal) do analogico esquerdo.
const GAMEPAD_AXES: Dictionary = {
	"up": [JOY_AXIS_LEFT_Y, -1.0],
	"down": [JOY_AXIS_LEFT_Y, 1.0],
	"left": [JOY_AXIS_LEFT_X, -1.0],
	"right": [JOY_AXIS_LEFT_X, 1.0],
}

var _players: int = 0


static func action_name(player: int, action: String) -> StringName:
	return StringName("p%d_%s" % [player, action])


static func is_valid_action(action: String) -> bool:
	return ACTIONS.has(action)


func player_count() -> int:
	return _players


## Garante as acoes de 1..count no InputMap, com bindings padrao so para as
## acoes que ainda nao tinham nenhum (bindings salvos ou do project.godot
## vencem os padroes).
func ensure_players(count: int) -> void:
	count = clampi(count, 1, MAX_PLAYERS)
	for p: int in range(1, count + 1):
		for action: String in ACTIONS:
			var name: StringName = action_name(p, action)
			if not InputMap.has_action(name):
				InputMap.add_action(name)
			if InputMap.action_get_events(name).is_empty():
				for ev: InputEvent in default_events(p, action):
					InputMap.action_add_event(name, ev)
	_players = maxi(_players, count)


static func default_events(player: int, action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if player == 1 and KEYBOARD_P1.has(action):
		for code: Variant in KEYBOARD_P1[action]:
			var k: InputEventKey = InputEventKey.new()
			k.physical_keycode = code as Key
			out.append(k)
	var device: int = player - 1
	if GAMEPAD_BUTTONS.has(action):
		for b: Variant in GAMEPAD_BUTTONS[action]:
			var jb: InputEventJoypadButton = InputEventJoypadButton.new()
			jb.device = device
			jb.button_index = b as JoyButton
			out.append(jb)
	if GAMEPAD_AXES.has(action):
		var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
		jm.device = device
		jm.axis = GAMEPAD_AXES[action][0] as JoyAxis
		jm.axis_value = float(GAMEPAD_AXES[action][1])
		out.append(jm)
	return out


func get_vector(player: int, deadzone: float = -1.0) -> Vector2:
	if not InputMap.has_action(action_name(player, "up")):
		return Vector2.ZERO
	return Input.get_vector(action_name(player, "left"), action_name(player, "right"),
		action_name(player, "up"), action_name(player, "down"), deadzone)


func is_pressed(player: int, action: String) -> bool:
	var name: StringName = action_name(player, action)
	return InputMap.has_action(name) and Input.is_action_pressed(name)


func just_pressed(player: int, action: String) -> bool:
	var name: StringName = action_name(player, action)
	return InputMap.has_action(name) and Input.is_action_just_pressed(name)


func just_released(player: int, action: String) -> bool:
	var name: StringName = action_name(player, action)
	return InputMap.has_action(name) and Input.is_action_just_released(name)


## Substitui os bindings de uma acao (remapeamento). Lista vazia = sem tecla.
func bind(player: int, action: String, events: Array[InputEvent]) -> void:
	var name: StringName = action_name(player, action)
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	InputMap.action_erase_events(name)
	for ev: InputEvent in events:
		InputMap.action_add_event(name, ev)


func events_of(player: int, action: String) -> Array[InputEvent]:
	var name: StringName = action_name(player, action)
	if not InputMap.has_action(name):
		return []
	return InputMap.action_get_events(name)


func reset_defaults(player: int) -> void:
	for action: String in ACTIONS:
		bind(player, action, default_events(player, action))


# ------------------------------------------------------------- persistencia

func save_bindings() -> bool:
	var save: Node = JogosLocator.autoload(&"SaveManager")
	if save == null or not save.has_method("set_setting"):
		return false
	for p: int in range(1, _players + 1):
		for action: String in ACTIONS:
			var serialized: Array = []
			for ev: InputEvent in events_of(p, action):
				var d: Dictionary = serialize_event(ev)
				if not d.is_empty():
					serialized.append(d)
			save.call("set_setting", String(action_name(p, action)), serialized, SAVE_SECTION)
	return true


func load_bindings() -> bool:
	var save: Node = JogosLocator.autoload(&"SaveManager")
	if save == null or not save.has_method("get_setting"):
		return false
	var any: bool = false
	for p: int in range(1, maxi(_players, 1) + 1):
		for action: String in ACTIONS:
			var raw: Variant = save.call("get_setting", String(action_name(p, action)), null, SAVE_SECTION)
			if raw is Array:
				var events: Array[InputEvent] = []
				for d: Variant in raw:
					if d is Dictionary:
						var ev: InputEvent = deserialize_event(d)
						if ev != null:
							events.append(ev)
				bind(p, action, events)
				any = true
	return any


static func serialize_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		return {"type": "key", "physical_keycode": int(k.physical_keycode), "keycode": int(k.keycode)}
	if ev is InputEventJoypadButton:
		var jb: InputEventJoypadButton = ev as InputEventJoypadButton
		return {"type": "joy_button", "device": jb.device, "button_index": int(jb.button_index)}
	if ev is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = ev as InputEventJoypadMotion
		return {"type": "joy_axis", "device": jm.device, "axis": int(jm.axis), "axis_value": jm.axis_value}
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev as InputEventMouseButton
		return {"type": "mouse_button", "button_index": int(mb.button_index)}
	return {}


static func deserialize_event(d: Dictionary) -> InputEvent:
	match str(d.get("type", "")):
		"key":
			var k: InputEventKey = InputEventKey.new()
			k.physical_keycode = int(d.get("physical_keycode", 0)) as Key
			k.keycode = int(d.get("keycode", 0)) as Key
			return k
		"joy_button":
			var jb: InputEventJoypadButton = InputEventJoypadButton.new()
			jb.device = int(d.get("device", 0))
			jb.button_index = int(d.get("button_index", 0)) as JoyButton
			return jb
		"joy_axis":
			var jm: InputEventJoypadMotion = InputEventJoypadMotion.new()
			jm.device = int(d.get("device", 0))
			jm.axis = int(d.get("axis", 0)) as JoyAxis
			jm.axis_value = float(d.get("axis_value", 1.0))
			return jm
		"mouse_button":
			var mb: InputEventMouseButton = InputEventMouseButton.new()
			mb.button_index = int(d.get("button_index", 1)) as MouseButton
			return mb
	return null
