extends GutTest

const Metrics = preload("res://shared/ui/MobileHudMetrics.gd")


func _topbar() -> GameTopBar:
	var holder := Control.new()
	holder.size = Vector2(828.0, 1792.0)
	add_child_autofree(holder)
	var top := GameTopBar.new()
	holder.add_child(top)
	return top


func test_content_begins_after_chrome_and_ends_before_bottom_safe_area() -> void:
	var m: MobileHudMetrics = Metrics.calculate(
		Vector2(828.0, 1792.0), Vector4(0.0, 96.0, 0.0, 34.0), 88.0, 132.0)
	assert_eq(m.chrome_rect.position.y, 96.0)
	assert_gte(m.content_rect.position.y, m.chrome_rect.end.y)
	assert_lte(m.content_rect.end.y, 1792.0 - 34.0 - 132.0)
	assert_true(m.bottom_rect.position.y >= m.content_rect.end.y)


func test_metrics_recompute_after_viewport_change() -> void:
	var m: MobileHudMetrics = Metrics.calculate(
		Vector2(720.0, 1280.0), Vector4(0.0, 0.0, 0.0, 0.0), 88.0, 88.0)
	var resized: MobileHudMetrics = m.resized(
		Vector2(720.0, 1600.0), Vector4(0.0, 44.0, 0.0, 22.0))
	assert_eq(resized.chrome_rect.position.y, 44.0)
	assert_gt(resized.content_rect.size.y, m.content_rect.size.y)


func test_chrome_collapses_low_priority_badges() -> void:
	var top := _topbar()
	top.game_title = "Jogo de Cores e Cartas"
	top.set_context_badges([
		{"id": "turn", "icon": "↻", "priority": 100, "tooltip": "Turno"},
		{"id": "moves", "icon": "✦", "priority": 20, "tooltip": "Jogadas"},
		{"id": "network", "icon": "⌁", "priority": 10, "tooltip": "Conexao"},
	])
	await wait_process_frames(2)
	assert_true(top.has_badge("turn"))
	assert_lte(top.visible_badge_count(), 2)
	assert_true(top.get_node("Linha/BtnBack").get_global_rect().end.x <= 828.0)


func test_chrome_exposes_content_top_after_safe_area() -> void:
	var top := _topbar()
	await wait_process_frames(2)
	assert_gte(top.content_top_px, top.BANDA)
