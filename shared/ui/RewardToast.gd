class_name RewardToast
extends CanvasLayer

## RewardToast: o aviso que mostra a gamificacao acontecendo.
##
## O PlayTable ja tinha o motor inteiro -- GamificationManager, XP, nivel,
## streak diaria, AchievementEngine -- ligado no GameEventBus. So que nada
## disso aparecia em lugar nenhum: o jogador ganhava a partida, o XP era
## creditado no perfil, e a tela nao dizia nada. Era gamificacao invisivel.
##
## Este no escuta o barramento e mostra o que aconteceu. BaseGame o pendura
## sozinho em toda partida, entao nenhum dos 19 jogos precisa saber que ele
## existe.

const HOLD := 1.7
const SLIDE := 0.28
const WIDTH := 420.0

## Nome legivel de cada conquista. O id cru ("ACH_FIRST_BLOOD") nao diz nada a
## quem esta jogando.
const ACHIEVEMENT_NAMES := {
	"ACH_FIRST_BLOOD": "ACH_FIRST_BLOOD_NAME",
	"ACH_VETERAN": "ACH_VETERAN_NAME",
	"ACH_MASTER": "ACH_MASTER_NAME",
	"ACH_LEVEL_10": "ACH_LEVEL_10_NAME",
	"ACH_ITEM_COLLECTOR": "ACH_ITEM_COLLECTOR_NAME",
	"ACH_COMEBACK": "ACH_COMEBACK_NAME",
}

var _queue: Array[Dictionary] = []
var _showing := false
var _card: PanelContainer
var _icon: Label
var _title: Label
var _detail: Label


func _ready() -> void:
	layer = 100
	_build()
	if GameEventBus:
		GameEventBus.xp_gained.connect(_on_xp_gained)
		GameEventBus.player_leveled_up.connect(_on_level_up)
		GameEventBus.achievement_unlocked.connect(_on_achievement)
		GameEventBus.daily_streak_updated.connect(_on_streak)


func _build() -> void:
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(WIDTH, 0)
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.offset_left = -WIDTH * 0.5
	_card.offset_right = WIDTH * 0.5
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.94)
	style.border_color = Color(0.98, 0.82, 0.34, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	_card.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)

	_icon = Label.new()
	_icon.add_theme_font_size_override("font_size", 34)
	_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 21)
	_title.add_theme_color_override("font_color", Color(0.99, 0.87, 0.42))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)

	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 15)
	_detail.add_theme_color_override("font_color", Color(0.84, 0.87, 0.94))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_detail)

	add_child(_card)


# ------------------------------------------------------------------- eventos

func _on_xp_gained(amount: int, _source: String) -> void:
	if amount <= 0:
		return
	# A curva de nivel mora no PlayerProfile: perguntar em vez de repetir a
	# formula aqui, senao o toast passa a mentir na primeira vez que a curva
	# mudar.
	var progresso := Vector2i(PlayerProfile.total_xp, 1000)
	if PlayerProfile.has_method("xp_progress"):
		progresso = PlayerProfile.xp_progress()
	_push("⭐", tr("TOAST_XP") % amount, tr("TOAST_LEVEL_PROGRESS") % [
		PlayerProfile.level, progresso.x, progresso.y])


func _on_level_up(new_level: int) -> void:
	_push("🎖️", tr("TOAST_LEVEL_UP") % new_level, tr("TOAST_LEVEL_UP_DESC"))


func _on_achievement(id: String) -> void:
	var key: String = ACHIEVEMENT_NAMES.get(id, "")
	var name_ := tr(key) if key != "" else id
	_push("🏆", tr("TOAST_ACHIEVEMENT"), name_)


func _on_streak(days: int) -> void:
	if days <= 1:
		return
	_push("🔥", tr("TOAST_STREAK") % days, tr("TOAST_STREAK_DESC"))


# --------------------------------------------------------------------- fila

## Os avisos entram numa fila em vez de se atropelarem: uma vitoria pode
## disparar XP, subida de nivel e conquista no mesmo quadro.
func _push(icon: String, title: String, detail: String) -> void:
	_queue.append({"icon": icon, "title": title, "detail": detail})
	if not _showing:
		_drain()


func _drain() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var item: Dictionary = _queue.pop_front()
	_icon.text = item["icon"]
	_title.text = item["title"]
	_detail.text = item["detail"]

	if AudioManager and AudioManager.has_method("play_click"):
		AudioManager.play_click()

	var rest := 24.0
	_card.offset_top = rest - 60.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_card, "modulate:a", 1.0, SLIDE).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_card, "offset_top", rest, SLIDE) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(HOLD)
	tw.chain().tween_property(_card, "modulate:a", 0.0, SLIDE).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(_drain)
