class_name StateShader3D
extends RefCounted

## O material dos marcadores de estado -- o anel do `Board3D` e o halo dos jogos
## que nao tem tabuleiro em grade.
##
## Existe porque `StandardMaterial3D` nao sabe emitir na cor da instancia:
## `vertex_color_use_as_albedo` alimenta o albedo e mais nada, entao a emissao
## fica presa no valor escrito no material. Era assim que todo marcador do
## Board3D saia BRANCO, qualquer que fosse o estado -- e com o glow do ambiente
## por cima, o branco ainda vazava para as casas vizinhas.
##
## Num MultiMesh com `use_colors = true`, `COLOR` chega ao fragmento com a cor
## daquela instancia. Sao seis linhas de shader, e e a unica forma de o anel
## verde de jogada legal e o anel vermelho de casa minada acenderem cada um na
## sua cor sem virarem dois materiais diferentes.

const CODIGO := """
shader_type spatial;
render_mode cull_back, shadows_disabled;

uniform float energy = 1.15;

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * energy;
	ROUGHNESS = 0.45;
}
"""

static var _shader: Shader = null
static var _marker: ShaderMaterial = null


## O shader, compilado uma vez para o processo inteiro.
static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO
	return _shader


## Material do marcador de estado. Compartilhado de proposito: e o mesmo anel no
## Board3D e no CellHalo3D, e um material so significa um compile so.
static func marker() -> ShaderMaterial:
	if _marker == null:
		_marker = ShaderMaterial.new()
		_marker.shader = shader()
		_marker.set_shader_parameter("energy", 1.15)
	return _marker


## Um material proprio, para quem precisa de outra intensidade sem mexer no
## material compartilhado.
static func with_energy(energy: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader()
	mat.set_shader_parameter("energy", energy)
	return mat
