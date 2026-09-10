extends Node

## Autoload `InputRouter`: acoes por jogador + direcao continua por driver.
##
## Fonte: VOLTA `src/input/input_router.gd` (driver + buffer, coleta em
## `_unhandled_input` para nao competir com a UI) + `JogosPlayerActions`
## (padrao SuperTuxParty). Tirado: as teclas fixas WASD do roteador -- agora
## o teclado alimenta as acoes `p1_*`, e o driver so cuida do toque.
##
## Dois caminhos que convivem:
## - acoes discretas (`is_pressed(1, "confirm")`, `get_vector(1)`), para
##   jogos de botao/tabuleiro e para ler o gamepad;
## - `poll_direction(delta)`, para runners que querem a direcao continua do
##   swipe/joystick com buffer (nenhum toque descartado).

var actions: JogosPlayerActions = JogosPlayerActions.new()
var driver: JogosInputDriver = JogosSwipeDriver.new()
var buffer: JogosInputBuffer = JogosInputBuffer.new()

## Desliga o driver de toque (jogos que so usam acoes e nao querem o roteador
## engolindo o toque).
var direction_enabled: bool = false

var _last_pushed_direction: Vector2 = Vector2.ZERO


func _init() -> void:
	_last_pushed_direction = driver.poll(0.0)


func _ready() -> void:
	set_process_unhandled_input(true)


# ------------------------------------------------------------------ acoes

func ensure_players(count: int) -> void:
	actions.ensure_players(count)


func player_count() -> int:
	return actions.player_count()


func get_vector(player: int, deadzone: float = -1.0) -> Vector2:
	return actions.get_vector(player, deadzone)


func is_pressed(player: int, action: String) -> bool:
	return actions.is_pressed(player, action)


func just_pressed(player: int, action: String) -> bool:
	return actions.just_pressed(player, action)


func just_released(player: int, action: String) -> bool:
	return actions.just_released(player, action)


func bind(player: int, action: String, events: Array[InputEvent]) -> void:
	actions.bind(player, action, events)


func save_bindings() -> bool:
	return actions.save_bindings()


func load_bindings() -> bool:
	return actions.load_bindings()


# ---------------------------------------------------------------- direcao

func set_driver(new_driver: JogosInputDriver) -> void:
	driver = new_driver if new_driver != null else JogosSwipeDriver.new()
	buffer = JogosInputBuffer.new()
	_last_pushed_direction = driver.poll(0.0)
	direction_enabled = true


func poll_direction(delta: float) -> Vector2:
	buffer.tick(delta)
	if buffer.has_commands():
		return buffer.pop_command()
	return driver.poll(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not direction_enabled:
		return
	feed(event)


## Entrada do driver, publica para testes e para quem coleta em `gui_input`.
func feed(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		driver.process_event(event)
		_last_pushed_direction = driver.poll(0.0)
		_mark_handled()
		return
	driver.process_event(event)
	var direction: Vector2 = driver.poll(0.0)
	# So enfileira o que muda a direcao de fato; sem isto o primeiro poll
	# consumiria um comando fantasma antes do comando real do arraste.
	if direction.dot(_last_pushed_direction) <= buffer.similarity_threshold:
		buffer.push_command(direction)
		_last_pushed_direction = direction
	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		_mark_handled()


func _mark_handled() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.set_input_as_handled()
