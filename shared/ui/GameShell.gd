class_name GameShell
extends Control

## Unified UI shell to be used by all games, replacing decentralized UI nodes.

signal restart_requested()

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var level_label: Label = $VBoxContainer/LevelLabel
@onready var btn_restart: Button = $VBoxContainer/BtnRestart
@onready var timer: GameTimer = $GameTimer

func _ready() -> void:
	btn_restart.pressed.connect(func(): restart_requested.emit())
	btn_restart.hide()

func set_status(text: String) -> void:
	status_label.text = text

func set_level(text: String) -> void:
	level_label.text = text

func show_restart() -> void:
	btn_restart.show()

func hide_restart() -> void:
	btn_restart.hide()
