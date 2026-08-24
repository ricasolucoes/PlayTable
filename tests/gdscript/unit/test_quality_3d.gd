extends GutTest

## Níveis de qualidade — exercita shared/3d/Quality3D.gd.
##
## MeshBuilder3D guarda malhas construídas com Quality3D.radial_segments() e
## TextureFactory3D guarda texturas, e nenhuma das chaves de cache inclui o
## tier. As três clear_cache() existiam para isso e ninguém as chamava: trocar a
## qualidade não mudava nada do que já tinha sido gerado.

var _tier_original: int


func before_each() -> void:
	_tier_original = Quality3D.tier()


func after_each() -> void:
	Quality3D.set_tier(_tier_original)


func test_radial_segments_cai_com_o_tier() -> void:
	Quality3D.set_tier(Quality3D.Tier.HIGH)
	var alto := Quality3D.radial_segments(40)
	Quality3D.set_tier(Quality3D.Tier.LOW)
	var baixo := Quality3D.radial_segments(40)
	assert_lt(baixo, alto, "qualidade baixa gera menos segmentos")


func test_trocar_o_tier_descarta_a_malha_gerada_com_o_anterior() -> void:
	Quality3D.set_tier(Quality3D.Tier.HIGH)
	var alta: Mesh = MeshBuilder3D.disc_token()
	var segmentos_altos := Quality3D.radial_segments(40)

	Quality3D.set_tier(Quality3D.Tier.LOW)
	var baixa: Mesh = MeshBuilder3D.disc_token()

	assert_lt(Quality3D.radial_segments(40), segmentos_altos, "o tier de fato mudou")
	assert_ne(alta.get_rid(), baixa.get_rid(),
		"a malha e reconstruida, nao servida do cache do tier anterior")


func test_tier_repetido_nao_descarta_o_cache() -> void:
	Quality3D.set_tier(Quality3D.Tier.HIGH)
	var primeira: Mesh = MeshBuilder3D.disc_token()
	Quality3D.set_tier(Quality3D.Tier.HIGH)
	var segunda: Mesh = MeshBuilder3D.disc_token()
	assert_eq(primeira.get_rid(), segunda.get_rid(),
		"sem mudanca de tier o cache continua valendo")
