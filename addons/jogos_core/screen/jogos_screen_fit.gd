class_name JogosScreenFit
extends RefCounted

## Regra da casa "o jogo ocupa a tela", em funcoes puras.
##
## Fonte: PlayTable `shared/BaseGame.gd` (fit_table, measure_hud_bands,
## _scan_hud, _schedule_refit) e `shared/3d/CameraRig3D.gd` (_apply_framing);
## VOLTA `src/presentation/camera/game_camera.gd` (frame_to/_apply_zoom) e
## `safe_area.gd`. Tirado: o acoplamento a TabletopEnvironment3D, Tokens3D,
## Arena/Claim do VOLTA. Tudo que e conta fica aqui, sem no e sem camera, para
## a suite provar a matematica em headless.
##
## As regras que o codigo carrega:
## - a area util sai da HUD REAL medida em runtime (Controls ancorados ao topo
##   ou ao rodape), nunca de um numero escrito a mao;
## - o recorte seguro do display entra so quando cabe na janela;
## - o conteudo enche a area util com folga <= 4%;
## - em 3D a conta e feita na borda de PERTO, que projeta mais larga e mais
##   alta que o plano do foco; se a largura manda, a camera inclina mais ate o
##   teto do tema.

## Folga entre a HUD e a borda do conteudo, em pixels do viewport logico.
const HUD_GAP: float = 10.0

## Folga padrao ao redor do conteudo (4%).
const DEFAULT_SLACK: float = 0.04

## Menor fracao da altura que a faixa util pode ter: HUD que come mais que
## isso e defeito da cena, nao motivo para esmagar o tabuleiro.
const MIN_USABLE_FRACTION: float = 0.35

const META_REFIT_PENDING: StringName = &"jogos_refit_pending"
const META_IGNORE_FIT: StringName = &"jogos_ignore_fit"


# ------------------------------------------------------------------ HUD

## Quanto a HUD come em cima e embaixo: (topo, rodape) em pixels do viewport.
## Conta so blocos de primeiro nivel ancorados ao topo (`anchor_bottom == 0`)
## ou ao rodape (`anchor_top == 1`); o que esta dentro de um Container e
## posicionado pelo container e as ancoras dele mentem. Ignora nos cujo nome
## comeca por "Touch" (camadas de toque de tela cheia), CanvasLayers e nos com
## meta `jogos_ignore_fit`.
static func hud_bands(root: Node, viewport_height: float) -> Vector2:
	if root == null or viewport_height <= 0.0:
		return Vector2(HUD_GAP, HUD_GAP)
	return _scan_hud(root, viewport_height) + Vector2(HUD_GAP, HUD_GAP)


static func _scan_hud(node: Node, height: float) -> Vector2:
	var bands: Vector2 = Vector2.ZERO
	for child: Node in node.get_children():
		if child is CanvasLayer or child.get_meta(META_IGNORE_FIT, false):
			continue
		if child is Control:
			var ctrl: Control = child as Control
			if not ctrl.visible or ctrl.name.begins_with("Touch"):
				continue
			if not (node is Container):
				var r: Rect2 = ctrl.get_global_rect()
				if r.size.x > 0.0 and r.size.y > 0.0:
					if ctrl.anchor_top <= 0.001 and ctrl.anchor_bottom <= 0.001:
						bands.x = maxf(bands.x, r.end.y)
						continue
					elif ctrl.anchor_top >= 0.999 and ctrl.anchor_bottom >= 0.999:
						bands.y = maxf(bands.y, height - r.position.y)
						continue
		var inner: Vector2 = _scan_hud(child, height)
		bands.x = maxf(bands.x, inner.x)
		bands.y = maxf(bands.y, inner.y)
	return bands


## Retangulo que sobra do viewport depois das faixas de HUD.
static func measure_hud_bands(root: Node, viewport_rect: Rect2) -> Rect2:
	var bands: Vector2 = hud_bands(root, viewport_rect.size.y)
	return shrink_by_bands(viewport_rect, bands.x, bands.y)


static func shrink_by_bands(rect: Rect2, top: float, bottom: float) -> Rect2:
	var min_h: float = rect.size.y * MIN_USABLE_FRACTION
	var h: float = maxf(rect.size.y - top - bottom, min_h)
	var y: float = rect.position.y + clampf(top, 0.0, rect.size.y - h)
	return Rect2(rect.position.x, y, rect.size.x, h)


static func shrink_by_insets(rect: Rect2, insets: Vector4) -> Rect2:
	var out: Rect2 = Rect2(
		rect.position.x + insets.x,
		rect.position.y + insets.y,
		rect.size.x - insets.x - insets.z,
		rect.size.y - insets.y - insets.w
	)
	if out.size.x < rect.size.x * MIN_USABLE_FRACTION or out.size.y < rect.size.y * MIN_USABLE_FRACTION:
		return rect
	return out


## Recorte seguro do display como retangulo util do viewport.
static func safe_area_insets(viewport: Viewport) -> Rect2:
	if viewport == null:
		return Rect2()
	var vp: Rect2 = viewport.get_visible_rect()
	return shrink_by_insets(vp, JogosSafeArea.insets(viewport))


## A area util de verdade: viewport menos HUD medida menos recorte seguro.
static func usable_rect(root: Node, viewport: Viewport) -> Rect2:
	if viewport == null:
		return Rect2()
	var vp: Rect2 = viewport.get_visible_rect()
	var safe: Rect2 = shrink_by_insets(vp, JogosSafeArea.insets(viewport))
	return measure_hud_bands(root, safe)


# ------------------------------------------------------------------ 2D

## Zoom e deslocamento para um conteudo (mundo) encher `usable` (viewport).
## Devolve {"zoom": float, "offset": Vector2, "width_bound": bool}. O
## `offset` e o da Camera2D (posicao no centro do conteudo) que leva o centro
## do conteudo ao centro da faixa util, e nao ao centro geometrico da tela.
static func fit_2d(content: Rect2, usable: Rect2, viewport_size: Vector2,
		slack: float = DEFAULT_SLACK) -> Dictionary:
	if content.size.x <= 0.0 or content.size.y <= 0.0 or usable.size.x <= 0.0 or usable.size.y <= 0.0:
		return {"zoom": 1.0, "offset": Vector2.ZERO, "width_bound": true}
	var margin: float = 1.0 + maxf(slack, 0.0)
	var zx: float = usable.size.x / (content.size.x * margin)
	var zy: float = usable.size.y / (content.size.y * margin)
	var zoom: float = minf(zx, zy)
	var offset: Vector2 = (viewport_size * 0.5 - usable.get_center()) / zoom
	return {"zoom": zoom, "offset": offset, "width_bound": zx <= zy}


static func fit_camera_2d(camera: Camera2D, content: Rect2, usable: Rect2,
		slack: float = DEFAULT_SLACK, zoom_multiplier: float = 1.0) -> Dictionary:
	if camera == null:
		return {}
	var vp_size: Vector2 = camera.get_viewport_rect().size
	var fit: Dictionary = fit_2d(content, usable, vp_size, slack)
	var z: float = float(fit["zoom"]) * maxf(zoom_multiplier, 0.0001)
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.zoom = Vector2(z, z)
	camera.position = content.get_center()
	camera.offset = (vp_size * 0.5 - usable.get_center()) / z
	return fit


# ------------------------------------------------------------------ 3D

## Distancia e inclinacao para um conteudo de `content_size_xz` unidades
## (largura X, profundidade Z) caber em `usable`, dentro de um viewport de
## `viewport_size`, com `fov_deg` vertical. Devolve
## {"distance", "tilt_deg", "shift_up", "shift_right", "usable_fraction"}.
## `tilt_deg` e piso: se a largura manda, sobe ate `max_auto_tilt`.
static func fit_3d(content_size_xz: Vector2, usable: Rect2, viewport_size: Vector2,
		fov_deg: float, tilt_deg: float, max_auto_tilt: float,
		margin: float = 1.0 + DEFAULT_SLACK) -> Dictionary:
	var vp: Vector2 = viewport_size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return {"distance": 1.0, "tilt_deg": tilt_deg, "shift_up": 0.0, "shift_right": 0.0, "usable_fraction": 1.0}
	var aspect: float = vp.x / vp.y
	var safe_top: float = maxf(usable.position.y, 0.0)
	var safe_bottom: float = maxf(vp.y - usable.end.y, 0.0)
	var safe_h: float = maxf(vp.y - safe_top - safe_bottom, vp.y * MIN_USABLE_FRACTION)
	var safe_fraction: float = safe_h / vp.y
	var w_fraction: float = clampf(usable.size.x / vp.x, MIN_USABLE_FRACTION, 1.0)

	var half_v: float = tan(deg_to_rad(fov_deg) * 0.5)
	var half_h_full: float = half_v * aspect
	var half_h: float = half_h_full * w_fraction

	var base_tilt: float = clampf(tilt_deg, 20.0, 89.0)
	var tilt_cap: float = clampf(maxf(max_auto_tilt, base_tilt), 20.0, 89.0)
	var need_w: float = content_size_xz.x * 0.5 * margin
	var depth_half: float = content_size_xz.y * 0.5 * margin

	# Borda de perto: `depth_half * cos(tilt)` mais proxima que o foco, por
	# isso projeta mais larga. Dimensionar pelo plano do foco vazava embaixo.
	var dist_for_width: float = _dist_for_width(need_w, half_h, depth_half, base_tilt)
	var tilt: float = base_tilt
	if depth_half > 0.0001:
		# sin_needed >= 1: nem deitando de todo a profundidade encosta na
		# faixa util (tabuleiro quadrado em retrato). Inclinar mais sempre
		# ajuda, entao o caso sem solucao vai ate o teto.
		var sin_needed: float = (dist_for_width * half_v * safe_fraction) / depth_half
		var balanced: float = rad_to_deg(asin(clampf(sin_needed, 0.0, 1.0)))
		tilt = clampf(maxf(base_tilt, balanced), base_tilt, tilt_cap)
		dist_for_width = _dist_for_width(need_w, half_h, depth_half, tilt)

	var tilt_rad: float = deg_to_rad(tilt)
	var dist_for_depth: float = depth_half * sin(tilt_rad) / maxf(half_v * safe_fraction, 0.0001) \
		+ depth_half * cos(tilt_rad)
	var dist: float = maxf(maxf(dist_for_width, dist_for_depth), 1.0)

	# Recentra na faixa util: HUD alta em cima empurra o conteudo para baixo.
	var world_h: float = 2.0 * dist * half_v
	var world_w: float = 2.0 * dist * half_h_full
	var shift_up: float = ((safe_top - safe_bottom) * 0.5 / vp.y) * world_h
	var shift_right: float = ((usable.get_center().x - vp.x * 0.5) / vp.x) * world_w
	return {
		"distance": dist,
		"tilt_deg": tilt,
		"shift_up": shift_up,
		"shift_right": shift_right,
		"usable_fraction": safe_fraction,
	}


static func _dist_for_width(need_w: float, half_h: float, depth_half: float, tilt_deg: float) -> float:
	return need_w / maxf(half_h, 0.0001) + depth_half * cos(deg_to_rad(tilt_deg))


## Posicao e alvo da camera a partir de um `fit_3d`, olhando `focus` de cima
## no eixo +Z. Devolve {"position": Vector3, "target": Vector3}.
static func camera_pose(focus: Vector3, fit: Dictionary) -> Dictionary:
	var dist: float = float(fit.get("distance", 1.0))
	var tilt_rad: float = deg_to_rad(float(fit.get("tilt_deg", 52.0)))
	var position: Vector3 = focus + Vector3(0.0, dist * sin(tilt_rad), dist * cos(tilt_rad))
	var target: Vector3 = focus
	var forward: Vector3 = (target - position).normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	var up: Vector3 = right.cross(forward).normalized()
	var shift: Vector3 = up * float(fit.get("shift_up", 0.0)) + right * float(fit.get("shift_right", 0.0))
	return {"position": position + shift, "target": target + shift}


## Enquadra `bounds` (AABB do conteudo em mundo, plano XZ) na faixa `usable`.
## `opts`: tilt_deg (52), max_auto_tilt (70), fov_deg (camera.fov), margin (1.04).
static func fit_camera_3d(camera: Camera3D, bounds: AABB, usable: Rect2, opts: Dictionary = {}) -> Dictionary:
	if camera == null:
		return {}
	var vp_size: Vector2 = camera.get_viewport().get_visible_rect().size if camera.is_inside_tree() else Vector2(720, 1280)
	var fov: float = float(opts.get("fov_deg", camera.fov))
	var fit: Dictionary = fit_3d(
		Vector2(bounds.size.x, bounds.size.z), usable, vp_size, fov,
		float(opts.get("tilt_deg", 52.0)), float(opts.get("max_auto_tilt", 70.0)),
		float(opts.get("margin", 1.0 + DEFAULT_SLACK)))
	var focus: Vector3 = bounds.get_center()
	focus.y = bounds.position.y + bounds.size.y
	var pose: Dictionary = camera_pose(focus, fit)
	camera.fov = fov
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.position = pose["position"]
	if camera.position.distance_squared_to(pose["target"]) > 0.0001:
		camera.look_at(pose["target"], Vector3.UP)
	return fit


# ------------------------------------------------------------------ refit

## Chama `fn` depois de dois quadros, uma vez so por no, sem `await`.
## No `_ready` os Control ainda nao tem retangulo (o container de baixo mede
## a tela inteira e a HUD sairia com 1260 px). Corrotina que acorda depois de
## o no ter sido liberado imprime "Resumed function after await, but class
## instance is gone"; a chamada adiada num objeto liberado e descartada em
## silencio.
static func schedule_refit(node: Node, fn: Callable) -> void:
	if node == null or not node.is_inside_tree():
		return
	if bool(node.get_meta(META_REFIT_PENDING, false)):
		return
	node.set_meta(META_REFIT_PENDING, true)
	Callable(JogosScreenFit, &"_refit_step").call_deferred(node, fn, 2)


static func _refit_step(node: Node, fn: Callable, remaining: int) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		if is_instance_valid(node):
			node.set_meta(META_REFIT_PENDING, false)
		return
	if remaining > 0:
		Callable(JogosScreenFit, &"_refit_step").call_deferred(node, fn, remaining - 1)
		return
	node.set_meta(META_REFIT_PENDING, false)
	if fn.is_valid():
		fn.call()


## Liga `fn` ao `size_changed` do viewport do no (uma vez) e agenda o refit.
static func watch_resize(node: Node, fn: Callable) -> void:
	if node == null or not node.is_inside_tree():
		return
	var vp: Viewport = node.get_viewport()
	if vp != null and not vp.size_changed.is_connected(fn):
		vp.size_changed.connect(fn)
	schedule_refit(node, fn)
