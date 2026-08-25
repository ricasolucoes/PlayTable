extends CanvasLayer

## Componente UI visual de Fallback para Conquistas.
## 
## Caso o Google Play Games Sidekick/Overlay não esteja disponível 
## (ex: F-Droid, Desktop, Web ou falha no login), este script exibe 
## um popup nativo do próprio jogo para notificar o destravamento.

@onready var anim_player = $AnimationPlayer
@onready var title_label = $Panel/VBoxContainer/Title
@onready var desc_label = $Panel/VBoxContainer/Description
@onready var icon_rect = $Panel/Icon

func _ready() -> void:
	visible = false
	if GameEventBus:
		GameEventBus.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(ach_id: String) -> void:
	# Se o PGS estiver ativo, ele mostra o popup nativo do Android.
	# Aqui só mostramos o popup se o PGS falhou ou não existe.
	if PlayGamesManager and PlayGamesManager.is_available() and PlayGamesManager._is_logged_in:
		return
		
	# Fallback (Apenas visualização rápida de debug ou standalone)
	show_popup("Conquista Desbloqueada!", ach_id)

func show_popup(title: String, desc: String) -> void:
	title_label.text = title
	desc_label.text = desc
	visible = true
	# Aqui você teria uma animação "slide_in" e "slide_out" no AnimationPlayer
	if anim_player and anim_player.has_animation("show"):
		anim_player.play("show")
