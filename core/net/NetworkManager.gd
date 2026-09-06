extends Node

## Partidas em rede: dois aparelhos, uma mesa.
##
## Duas formas de chegar ao mesmo lugar:
##
##   - **Na mesma rede Wi-Fi** (`Transport.LAN`): um aparelho abre a sala
##     (servidor ENet na porta `PORT`) e responde a quem procura na rede por UDP
##     (`DISCOVERY_PORT`); o outro encontra a sala na lista ou digita o endereco.
##     Nao precisa de servidor nenhum -- funciona no hotspot do proprio celular.
##   - **Pela internet** (`Transport.RELAY`): os dois entram como clientes num
##     relay WebSocket no servidor do contrato (`docs/server/api-contract.md`,
##     grupo Salas). O servidor ainda nao existe; ate existir, este caminho
##     termina em `State.ONLINE_UNAVAILABLE` depois de `RELAY_TIMEOUT`, e a tela
##     de sala diz que o online esta fora -- o resto do aplicativo segue inteiro,
##     como o contrato exige (secao 4).
##
## Os dois transportes falam o mesmo protocolo: RPCs deste autoload, que existe
## no mesmo caminho (`/root/NetworkManager`) nos dois aparelhos. O jogo nao
## sabe por onde a jogada viajou: `send_move()` de um lado vira `move_received`
## do outro, e `BaseGame` entrega ao `_on_net_move()` de cada jogo.
##
## Assentos: quem abre a sala e o jogador 1 (`local_seat == 1`), quem entra e o
## 2. E o jogo quem decide o que cada assento significa (X ou O, vermelho ou
## amarelo, pretas ou brancas).

signal state_changed(state: int)
signal room_found(info: Dictionary)
signal rooms_changed(rooms: Array)
signal match_started(game_id: String)
signal move_received(payload: Dictionary)
signal restart_received
signal peer_left
signal failed(reason_key: String)

enum State { OFFLINE, HOSTING, JOINING, CONNECTED, ONLINE_UNAVAILABLE }
enum Transport { LAN, RELAY }

const PORT := 47474
const DISCOVERY_PORT := 47475
const BEACON_ASK := "PLAYTABLE?"
const BEACON_TAG := "PLAYTABLE!"

## Versao do protocolo. Muda quando um RPC muda de assinatura; dois aparelhos
## com versoes diferentes nao entram na mesma sala.
const PROTOCOL := 1

## Endereco do relay do contrato. `wss://` e obrigatorio (secao 2 do contrato).
const RELAY_URL := "wss://playtable.ricasolucoes.com.br/api/v1/rooms/ws"
const RELAY_TIMEOUT := 8.0

## Quanto tempo uma sala vista na rede fica na lista sem responder de novo.
const ROOM_TTL := 4.0
const SCAN_INTERVAL := 1.0

var state: int = State.OFFLINE
var transport: int = Transport.LAN
var game_id: String = ""
var local_seat: int = 0
var opponent_name: String = ""
var room_code: String = ""

var _peer: MultiplayerPeer = null
var _udp: PacketPeerUDP = null
var _scan_timer: float = 0.0
var _relay_timer: float = 0.0
var _rooms: Dictionary = {}   # "ip" -> {"ip", "name", "game_id", "seen"}
var _partner_id: int = 0

## Jogadas enviadas quando nao ha peer -- so na suite, com `_test_activate()`.
var sent_moves: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	set_process(false)


# ----------------------------------------------------------------- consultas

## Verdadeiro durante uma partida em rede: e o que o jogo consulta no `_ready`.
func is_active() -> bool:
	return state == State.CONNECTED and game_id != ""


func is_host() -> bool:
	return local_seat == 1


func remote_seat() -> int:
	return 2 if local_seat == 1 else 1


## De quem e a vez, na convencao de assentos: `player` e 1 ou 2.
func is_my_turn(player: int) -> bool:
	return player == local_seat


func player_name() -> String:
	if PlayGamesManager != null and PlayGamesManager.is_logged_in():
		var nome: String = PlayGamesManager.player_name()
		if nome != "":
			return nome
	return tr("NET_PLAYER_DEFAULT")


## O endereco IPv4 privado deste aparelho na rede local, ou "" fora de uma.
func local_address() -> String:
	for addr in IP.get_local_addresses():
		var a: String = addr
		if a.begins_with("192.168.") or a.begins_with("10."):
			return a
		if a.begins_with("172."):
			var segundo := int(a.get_slice(".", 1))
			if segundo >= 16 and segundo <= 31:
				return a
	return ""


func rooms() -> Array:
	var lista: Array = []
	for info in _rooms.values():
		lista.append(info)
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return lista


# --------------------------------------------------------------------- sala

## Abre uma sala na rede local para `p_game_id` e passa a responder a quem
## procura. Quem entrar comeca a partida nos dois aparelhos.
func host(p_game_id: String) -> bool:
	leave()
	var enet := ENetMultiplayerPeer.new()
	var erro := enet.create_server(PORT, 1)
	if erro != OK:
		_falhar("NET_ERROR_HOST")
		return false
	_peer = enet
	multiplayer.multiplayer_peer = enet
	transport = Transport.LAN
	game_id = p_game_id
	local_seat = 1
	room_code = local_address()
	_abrir_farol()
	_set_state(State.HOSTING)
	return true


## Entra na sala de `address` (rede local).
func join(address: String) -> bool:
	leave()
	var enet := ENetMultiplayerPeer.new()
	var erro := enet.create_client(address.strip_edges(), PORT)
	if erro != OK:
		_falhar("NET_ERROR_JOIN")
		return false
	_peer = enet
	multiplayer.multiplayer_peer = enet
	transport = Transport.LAN
	local_seat = 2
	room_code = address.strip_edges()
	_set_state(State.JOINING)
	return true


## Procura salas na rede: manda o farol em broadcast a cada `SCAN_INTERVAL` e
## junta as respostas em `rooms()`.
func start_scan() -> void:
	_fechar_udp()
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_udp.bind(0)
	_rooms.clear()
	_scan_timer = 0.0
	set_process(true)


func stop_scan() -> void:
	if state == State.OFFLINE:
		_fechar_udp()
		set_process(false)


## Sala pela internet: `code` vazio cria uma sala nova no relay; com codigo,
## entra na sala de um amigo. Sem servidor, termina em ONLINE_UNAVAILABLE.
func connect_online(p_game_id: String, code: String = "") -> void:
	leave()
	var ws := WebSocketMultiplayerPeer.new()
	var url := RELAY_URL + ("/new?game=%s&v=%d" % [p_game_id, PROTOCOL] if code == "" else "/%s?v=%d" % [code.strip_edges().to_upper(), PROTOCOL])
	var erro := ws.create_client(url)
	if erro != OK:
		_set_state(State.ONLINE_UNAVAILABLE)
		return
	_peer = ws
	multiplayer.multiplayer_peer = ws
	transport = Transport.RELAY
	game_id = p_game_id
	local_seat = 1 if code == "" else 2
	room_code = code.strip_edges().to_upper()
	_relay_timer = RELAY_TIMEOUT
	set_process(true)
	_set_state(State.JOINING)


## Sai da sala, seja qual for o estado. O outro lado recebe `peer_left`.
func leave() -> void:
	_fechar_udp()
	if _peer != null:
		_peer.close()
		_peer = null
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_partner_id = 0
	_relay_timer = 0.0
	set_process(false)
	var estava := state
	state = State.OFFLINE
	game_id = ""
	local_seat = 0
	opponent_name = ""
	room_code = ""
	if estava != State.OFFLINE:
		state_changed.emit(state)


# ------------------------------------------------------------------ partida

## Manda a jogada ao outro aparelho. O formato e do jogo; aqui e so um
## dicionario de tipos simples (int, String, Array).
func send_move(payload: Dictionary) -> void:
	if not is_active():
		return
	if _partner_id == 0:
		sent_moves.append(payload.duplicate())
		return
	_rpc_move.rpc_id(_partner_id, payload)


## Pede ao outro lado que recomece a partida junto.
func send_restart() -> void:
	if is_active() and _partner_id != 0:
		_rpc_restart.rpc_id(_partner_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(nome: String, protocolo: int, p_game_id: String) -> void:
	var quem := multiplayer.get_remote_sender_id()
	if protocolo != PROTOCOL:
		_rpc_reject.rpc_id(quem, "NET_VERSION_MISMATCH")
		return
	opponent_name = nome
	_partner_id = quem
	if is_host():
		# O anfitriao manda o jogo; o convidado pode ter entrado sem saber qual.
		_rpc_start.rpc_id(quem, game_id, player_name())
		_comecar()
	elif p_game_id != "":
		game_id = p_game_id


@rpc("any_peer", "call_remote", "reliable")
func _rpc_start(p_game_id: String, nome_anfitriao: String) -> void:
	opponent_name = nome_anfitriao
	_partner_id = multiplayer.get_remote_sender_id()
	game_id = p_game_id
	_comecar()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_reject(reason_key: String) -> void:
	_falhar(reason_key)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_move(payload: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() != _partner_id:
		return
	move_received.emit(payload)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_restart() -> void:
	if multiplayer.get_remote_sender_id() == _partner_id:
		restart_received.emit()


func _comecar() -> void:
	_fechar_udp()
	set_process(false)
	_set_state(State.CONNECTED)
	match_started.emit(game_id)
	var def := GameCatalog.find_by_id(game_id)
	if def != null and SceneManager != null:
		SceneManager.goto_scene(def.scene_path)


# ------------------------------------------------------------ sinais do peer

func _on_peer_connected(id: int) -> void:
	if is_host():
		return  # o convidado se apresenta com _rpc_hello
	if transport == Transport.RELAY and id == 1:
		return  # o relay em si nao e o adversario
	_rpc_hello.rpc_id(id, player_name(), PROTOCOL, game_id)


func _on_connected_to_server() -> void:
	# Em LAN o servidor e o anfitriao; no relay ele e o intermediario, e o
	# convidado se apresenta a sala em vez de a um peer.
	_relay_timer = 0.0
	_rpc_hello.rpc_id(1, player_name(), PROTOCOL, game_id)


func _on_connection_failed() -> void:
	if transport == Transport.RELAY:
		_set_state(State.ONLINE_UNAVAILABLE)
		_desligar_peer()
	else:
		_falhar("NET_ERROR_JOIN")


func _on_peer_disconnected(id: int) -> void:
	if id == _partner_id or _partner_id == 0:
		_adversario_saiu()


func _on_server_disconnected() -> void:
	_adversario_saiu()


func _adversario_saiu() -> void:
	var estava_jogando := is_active()
	leave()
	if estava_jogando:
		peer_left.emit()


func _falhar(reason_key: String) -> void:
	leave()
	failed.emit(reason_key)


func _desligar_peer() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _set_state(novo: int) -> void:
	if state == novo:
		return
	state = novo
	state_changed.emit(state)


# ------------------------------------------------------------ farol na rede

func _abrir_farol() -> void:
	_fechar_udp()
	_udp = PacketPeerUDP.new()
	if _udp.bind(DISCOVERY_PORT, "*") != OK:
		_udp = null
		return
	set_process(true)


func _fechar_udp() -> void:
	if _udp != null:
		_udp.close()
		_udp = null


func _process(delta: float) -> void:
	if _relay_timer > 0.0:
		_relay_timer -= delta
		if _relay_timer <= 0.0 and state == State.JOINING and transport == Transport.RELAY:
			_desligar_peer()
			_set_state(State.ONLINE_UNAVAILABLE)
	if _udp == null:
		return
	if state == State.HOSTING:
		_responder_farol()
	elif state == State.OFFLINE:
		_varrer(delta)


func _responder_farol() -> void:
	while _udp.get_available_packet_count() > 0:
		var pacote := _udp.get_packet()
		if pacote.get_string_from_utf8() != BEACON_ASK:
			continue
		var ip := _udp.get_packet_ip()
		var porta := _udp.get_packet_port()
		_udp.set_dest_address(ip, porta)
		_udp.put_packet(build_beacon(player_name(), game_id).to_utf8_buffer())


func _varrer(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_INTERVAL
		_udp.set_dest_address("255.255.255.255", DISCOVERY_PORT)
		_udp.put_packet(BEACON_ASK.to_utf8_buffer())
	var mudou := false
	while _udp.get_available_packet_count() > 0:
		var pacote := _udp.get_packet()
		var info := parse_beacon(pacote.get_string_from_utf8())
		if info.is_empty():
			continue
		info["ip"] = _udp.get_packet_ip()
		info["seen"] = Time.get_ticks_msec() / 1000.0
		var nova := not _rooms.has(info["ip"])
		_rooms[info["ip"]] = info
		mudou = true
		if nova:
			room_found.emit(info)
	var agora := Time.get_ticks_msec() / 1000.0
	for ip in _rooms.keys():
		if agora - float(_rooms[ip]["seen"]) > ROOM_TTL:
			_rooms.erase(ip)
			mudou = true
	if mudou:
		rooms_changed.emit(rooms())


## O anuncio de uma sala, como texto: `PLAYTABLE!|<protocolo>|<jogo>|<nome>`.
static func build_beacon(nome: String, p_game_id: String) -> String:
	return "%s|%d|%s|%s" % [BEACON_TAG, PROTOCOL, p_game_id, nome.replace("|", " ")]


## O inverso de `build_beacon`; vazio quando o texto nao e um anuncio valido ou
## e de outra versao do protocolo.
static func parse_beacon(texto: String) -> Dictionary:
	var partes := texto.split("|")
	if partes.size() < 4 or partes[0] != BEACON_TAG:
		return {}
	if int(partes[1]) != PROTOCOL:
		return {}
	if partes[2] == "" or GameCatalog.find_by_id(partes[2]) == null:
		return {}
	return {"game_id": partes[2], "name": partes[3]}


# ---------------------------------------------------------------- para a suite

## Poe o gerente em partida sem peer nenhum: `send_move()` guarda em
## `sent_moves`, e a suite entrega jogadas remotas emitindo `move_received`.
func _test_activate(p_game_id: String, seat: int) -> void:
	leave()
	game_id = p_game_id
	local_seat = seat
	opponent_name = "Teste"
	sent_moves.clear()
	_set_state(State.CONNECTED)
