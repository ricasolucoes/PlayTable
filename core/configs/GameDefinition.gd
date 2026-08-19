## GameDefinition: Resource that defines a game entry for dynamic menu generation.
##
## Use this to register games without hardcoding paths in menu scripts.
## Each GameDefinition holds the display metadata and scene path for a game.
class_name GameDefinition
extends Resource

## The display title of the game (translatable key or direct text)
@export var title: String = ""

## The emoji or icon character displayed alongside the title
@export var icon: String = "🎲"

## Path to the game's main scene file (res://games/...)
@export var scene_path: String = ""

## Category for menu grouping
@export var category: StringName = &"board"

## Brief description (translatable key)
@export var description: String = ""

## Whether this game is fully implemented (false = shows GenericGame placeholder)
@export var is_implemented: bool = true

## Create a GameDefinition with the given parameters
static func create(p_title: String, p_icon: String, p_scene_path: String, p_category: StringName, p_description: String = "", p_implemented: bool = true) -> GameDefinition:
	var def := GameDefinition.new()
	def.title = p_title
	def.icon = p_icon
	def.scene_path = p_scene_path
	def.category = p_category
	def.description = p_description
	def.is_implemented = p_implemented
	return def
