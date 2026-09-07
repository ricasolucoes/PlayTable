extends Control

## A sala de espera das partidas em rede.
##
## Duas portas para a mesma mesa: a rede Wi-Fi em que os dois aparelhos ja
## estao (sem servidor, sem cadastro) e, quando o servidor do contrato existir,
## a internet. A tela diz o que esta acontecendo em cada uma -- sala aberta e
## em que endereco, salas encontradas na rede, servidor fora -- e sai sozinha
## para o jogo quando a partida comeca (`NetworkManager.match_started`).
##
## Montada em codigo, como o MainMenu: quase tudo aqui muda com o estado do
## NetworkManager.

const MAIN_MENU := "res://core/telas/MainMenu.tscn"
const MARGEM := 24
const TOPO := 36

var _jogo_escolhido: String = ""
var _corpo: VBoxContainer = null
var _status: Label = null
var _lan_status: Label = null
var _online_status: Label = null
var _lista_salas: VBoxContainer = null
var _btn_host: Button = null
var _btn_cancelar: Button = null
var _endereco: LineEdit = null
var _codigo: LineEdit = null
var _chips: Dictionary = {}   # game_id -> Button


func _ready() -> void:
	var jogos := GameCatalog.get_net_games()
	if not jogos.is_empty():
		_jogo_escolhido = GameCatalog.game_id_of(jogos[0])
	_montar()
	if NetworkManager != null:
		NetworkManager.state_changed.connect(_on_state_changed)
		NetworkManager.rooms_changed.connect(_on_rooms_changed)
		NetworkManager.failed.connect(_on_failed)
		if NetworkManager.state == NetworkManager.State.OFFLINE:
			NetworkManager.start_scan()
	_refrescar()


func _exit_tree() -> void:
	if NetworkManager == null:
		return
	if NetworkManager.state_changed.is_connected(_on_state_changed):
		NetworkManager.state_changed.disconnect(_on_state_changed)
	if NetworkManager.rooms_changed.is_connected(_on_rooms_changed):
		NetworkManager.rooms_changed.disconnect(_on_rooms_changed)
	if NetworkManager.failed.is_connected(_on_failed):
		NetworkManager.failed.disconnect(_on_failed)
	NetworkManager.stop_scan()


# ------------------------------------------------------------------ montagem

func _montar() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(preload("res://shared/ui/TabletopBackground.tscn").instantiate())

	var coluna := VBoxContainer.new()
	coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
	coluna.add_theme_constant_override("separation", 0)
	add_child(coluna)

	var barra := MarginContainer.new()
	barra.add_theme_constant_override("margin_left", MARGEM)
	barra.add_theme_constant_override("margin_right", MARGEM)
	barra.add_theme_constant_override("margin_top", TOPO)
	barra.add_theme_constant_override("margin_bottom", 12)
	coluna.add_child(barra)

	var linha := UIKit.hbox(16)
	barra.add_child(linha)
	var voltar := UIKit.botao(tr("BTN_BACK"))
	voltar.name = "BtnBack"
	voltar.custom_minimum_size = Vector2(150, UIKit.TOQUE_MIN)
	voltar.pressed.connect(_on_voltar)
	linha.add_child(voltar)
	var titulo := UIKit.rotulo(tr("NET_TITLE"), UIKit.FONTE_TITULO, UIKit.OURO)
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(UIKit.expandir(titulo))

	var rolagem := UIKit.rolagem()
	coluna.add_child(rolagem)

	var margem := MarginContainer.new()
	margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margem.add_theme_constant_override("margin_left", MARGEM)
	margem.add_theme_constant_override("margin_right", MARGEM)
	margem.add_theme_constant_override("margin_top", 8)
	margem.add_theme_constant_override("margin_bottom", 24)
	rolagem.add_child(margem)

	_corpo = UIKit.vbox(20)
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margem.add_child(_corpo)

	_corpo.add_child(_secao_jogos())
	_corpo.add_child(_secao_lan())
	_corpo.add_child(_secao_online())

	_status = UIKit.paragrafo("", UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO)
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corpo.add_child(_status)


func _secao_jogos() -> Control:
	var cartao := UIKit.cartao()
	var col := UIKit.vbox(10)
	cartao.add_child(col)
	col.add_child(UIKit.rotulo(tr("NET_PICK_GAME"), UIKit.FONTE_SECAO, UIKit.OURO))

	var grade := HFlowContainer.new()
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	col.add_child(grade)
	for def in GameCatalog.get_net_games():
		var id := GameCatalog.game_id_of(def)
		var chip := UIKit.botao("%s %s" % [def.icon, def.display_name()], UIKit.FONTE_CORPO)
		chip.name = "Jogo_" + id
		chip.toggle_mode = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(_on_jogo.bind(id))
		grade.add_child(chip)
		_chips[id] = chip
	return cartao


func _secao_lan() -> Control:
	var cartao := UIKit.cartao()
	var col := UIKit.vbox(12)
	cartao.add_child(col)
	col.add_child(UIKit.rotulo(tr("NET_LAN_TITLE"), UIKit.FONTE_SECAO, UIKit.OURO))
	col.add_child(UIKit.paragrafo(tr("NET_LAN_HINT")))

	var fila := UIKit.hbox(12)
	col.add_child(fila)
	_btn_host = UIKit.botao(tr("NET_HOST"), UIKit.FONTE_CORPO)
	_btn_host.name = "BtnHost"
	_btn_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_host.pressed.connect(_on_host)
	fila.add_child(_btn_host)
	_btn_cancelar = UIKit.botao(tr("NET_CANCEL"), UIKit.FONTE_CORPO)
	_btn_cancelar.name = "BtnCancelar"
	_btn_cancelar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_cancelar.pressed.connect(_on_cancelar)
	fila.add_child(_btn_cancelar)

	_lan_status = UIKit.paragrafo("", UIKit.FONTE_CORPO, UIKit.TEXTO)
	_lan_status.name = "LanStatus"
	col.add_child(_lan_status)

	col.add_child(UIKit.paragrafo(tr("NET_SCAN_HINT")))
	_lista_salas = UIKit.vbox(8)
	_lista_salas.name = "Salas"
	col.add_child(_lista_salas)

	var entrada := UIKit.hbox(12)
	col.add_child(entrada)
	_endereco = LineEdit.new()
	_endereco.name = "Endereco"
	_endereco.placeholder_text = tr("NET_ADDRESS_HINT")
	_endereco.custom_minimum_size = Vector2(0, UIKit.TOQUE_MIN)
	_endereco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_endereco.add_theme_font_size_override("font_size", UIKit.FONTE_CORPO)
	_endereco.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	entrada.add_child(_endereco)
	var entrar := UIKit.botao(tr("NET_JOIN"), UIKit.FONTE_CORPO)
	entrar.name = "BtnJoin"
	entrar.custom_minimum_size = Vector2(150, UIKit.TOQUE_MIN)
	entrar.pressed.connect(_on_join)
	entrada.add_child(entrar)
	return cartao


func _secao_online() -> Control:
	var cartao := UIKit.cartao(false)
	var col := UIKit.vbox(12)
	cartao.add_child(col)
	col.add_child(UIKit.rotulo(tr("NET_ONLINE_TITLE"), UIKit.FONTE_SECAO, UIKit.OURO))
	col.add_child(UIKit.paragrafo(tr("NET_ONLINE_HINT")))

	var criar := UIKit.botao(tr("NET_ONLINE_HOST"), UIKit.FONTE_CORPO)
	criar.name = "BtnOnlineHost"
	criar.pressed.connect(_on_online_host)
	col.add_child(criar)

	var entrada := UIKit.hbox(12)
	col.add_child(entrada)
	_codigo = LineEdit.new()
	_codigo.name = "Codigo"
	_codigo.placeholder_text = tr("NET_ONLINE_CODE_HINT")
	_codigo.custom_minimum_size = Vector2(0, UIKit.TOQUE_MIN)
	_codigo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codigo.max_length = 8
	_codigo.add_theme_font_size_override("font_size", UIKit.FONTE_CORPO)
	entrada.add_child(_codigo)
	var entrar := UIKit.botao(tr("NET_JOIN"), UIKit.FONTE_CORPO)
	entrar.name = "BtnOnlineJoin"
	entrar.custom_minimum_size = Vector2(150, UIKit.TOQUE_MIN)
	entrar.pressed.connect(_on_online_join)
	entrada.add_child(entrar)

	_online_status = UIKit.paragrafo("", UIKit.FONTE_CORPO, UIKit.TEXTO)
	_online_status.name = "OnlineStatus"
	col.add_child(_online_status)
	return cartao


# ------------------------------------------------------------------- estado

func _refrescar() -> void:
	for id in _chips:
		(_chips[id] as Button).button_pressed = id == _jogo_escolhido
	if NetworkManager == null:
		return
	var estado: int = NetworkManager.state
	var parado := estado == NetworkManager.State.OFFLINE or estado == NetworkManager.State.ONLINE_UNAVAILABLE
	_btn_host.visible = parado
	_btn_cancelar.visible = not parado
	match estado:
		NetworkManager.State.HOSTING:
			var ip: String = NetworkManager.local_address()
			_lan_status.text = tr("NET_WAITING") % ip if ip != "" else tr("NET_WAITING_NO_IP")
			_online_status.text = ""
		NetworkManager.State.JOINING:
			if NetworkManager.transport == NetworkManager.Transport.RELAY:
				_online_status.text = tr("NET_CONNECTING") % tr("NET_ONLINE_TITLE")
				_lan_status.text = ""
			else:
				_lan_status.text = tr("NET_CONNECTING") % NetworkManager.room_code
				_online_status.text = ""
		NetworkManager.State.CONNECTED:
			_lan_status.text = tr("NET_CONNECTED")
		NetworkManager.State.ONLINE_UNAVAILABLE:
			_online_status.text = tr("NET_ONLINE_UNAVAILABLE")
			_lan_status.text = ""
		_:
			_lan_status.text = ""
			_online_status.text = ""
	_on_rooms_changed(NetworkManager.rooms())


func _on_rooms_changed(salas: Array) -> void:
	if _lista_salas == null:
		return
	for filho in _lista_salas.get_children():
		_lista_salas.remove_child(filho)
		filho.queue_free()
	if salas.is_empty():
		_lista_salas.add_child(UIKit.paragrafo(tr("NET_NONE_FOUND")))
		return
	for info in salas:
		var def := GameCatalog.find_by_id(str(info["game_id"]))
		var nome_jogo := def.display_name() if def != null else str(info["game_id"])
		var b := UIKit.botao(tr("NET_ROOM_ROW") % [str(info["name"]), nome_jogo], UIKit.FONTE_CORPO)
		b.pressed.connect(_on_sala.bind(str(info["ip"])))
		_lista_salas.add_child(b)


func _on_state_changed(_estado: int) -> void:
	_refrescar()


func _on_failed(reason_key: String) -> void:
	_status.text = tr(reason_key)
	_refrescar()
	if NetworkManager != null and NetworkManager.state == NetworkManager.State.OFFLINE:
		NetworkManager.start_scan()


# -------------------------------------------------------------------- acoes

func _click() -> void:
	if AudioManager:
		AudioManager.play_click()


func _on_jogo(id: String) -> void:
	_click()
	_jogo_escolhido = id
	_refrescar()


func _on_host() -> void:
	_click()
	_status.text = ""
	if _jogo_escolhido == "":
		return
	NetworkManager.host(_jogo_escolhido)
	_refrescar()


func _on_cancelar() -> void:
	_click()
	NetworkManager.leave()
	NetworkManager.start_scan()
	_refrescar()


func _on_sala(ip: String) -> void:
	_click()
	_endereco.text = ip
	_on_join()


func _on_join() -> void:
	_click()
	_status.text = ""
	var ip := _endereco.text.strip_edges()
	if ip == "":
		return
	NetworkManager.join(ip)
	_refrescar()


func _on_online_host() -> void:
	_click()
	_status.text = ""
	if _jogo_escolhido == "":
		return
	NetworkManager.connect_online(_jogo_escolhido)
	_refrescar()


func _on_online_join() -> void:
	_click()
	_status.text = ""
	var code := _codigo.text.strip_edges()
	if code == "":
		return
	NetworkManager.connect_online(_jogo_escolhido, code)
	_refrescar()


func _on_voltar() -> void:
	_click()
	if NetworkManager != null and NetworkManager.state != NetworkManager.State.CONNECTED:
		NetworkManager.leave()
	SceneManager.goto_scene(MAIN_MENU)
