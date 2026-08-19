class_name BoardCoord
extends RefCounted

const DIR_N = Vector2i(-1, 0)
const DIR_S = Vector2i(1, 0)
const DIR_W = Vector2i(0, -1)
const DIR_E = Vector2i(0, 1)

const DIR_NW = Vector2i(-1, -1)
const DIR_NE = Vector2i(-1, 1)
const DIR_SW = Vector2i(1, -1)
const DIR_SE = Vector2i(1, 1)

const CARDINALS = [DIR_N, DIR_S, DIR_W, DIR_E]
const DIAGONALS = [DIR_NW, DIR_NE, DIR_SW, DIR_SE]
const ALL_8_DIRECTIONS = [DIR_N, DIR_S, DIR_W, DIR_E, DIR_NW, DIR_NE, DIR_SW, DIR_SE]

const CONNECT_4_DIRECTIONS = [
	Vector2i(1, 0),  # Vertical
	Vector2i(0, 1),  # Horizontal
	Vector2i(1, 1),  # Diagonal Principal \
	Vector2i(1, -1)  # Diagonal Secundária /
]
