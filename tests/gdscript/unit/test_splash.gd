extends GutTest

## A tela de abertura, que falha calada.
##
## O pacote nao passa pelo exportador do Godot (os scripts fazem `--export-pack`
## e chamam o gradle direto), entao ninguem escreve `res/drawable/splash_icon`
## no modelo de compilacao: quem faz isso e `tools/make_splash.py` mais
## `android/icons/install.sh`. Se um dos dois arquivos sumir -- e o
## `android/build/` e gerado, some sozinho quando o modelo e reinstalado --
## o Android 12 volta a abrir o jogo com o robo do Godot, e o build passa
## verde. O mesmo vale para o boot splash da engine: sem
## `application/boot_splash/image` ela desenha o proprio logo.
##
## Nada disto aparece em teste de jogo: e por isso que estes ficam aqui.

const ICONE := "res://android/icons/drawable/splash_icon.webp"
const MARCA := "res://android/icons/drawable/splash_branding_image.webp"
const FUNDO_ADAPTATIVO := "res://android/icons/mipmap-xxxhdpi-v4/icon_background.png"

## O Android mascara os 2/3 centrais do icone num circulo (192 dp de 288 dp).
const FRACAO_VISIVEL := 2.0 / 3.0
## Pixel que conta como arte, na mesma conta do gerador.
const LIMIAR_ARTE := 260.0 / 255.0


func _imagem(caminho: String) -> Image:
	assert_true(FileAccess.file_exists(caminho), "%s existe (rode tools/make_splash.py)" % caminho)
	if not FileAccess.file_exists(caminho):
		return null
	var img := Image.load_from_file(caminho)
	assert_not_null(img, "%s abre como imagem" % caminho)
	return img


# ------------------------------------------------------- boot splash da engine

func test_a_engine_tem_a_propria_abertura() -> void:
	var caminho: String = ProjectSettings.get_setting("application/boot_splash/image", "")
	assert_ne(caminho, "", "project.godot aponta um boot splash (senao a engine desenha o logo dela)")
	assert_true(FileAccess.file_exists(caminho), "%s existe" % caminho)


func test_os_dois_fundos_sao_a_mesma_cor() -> void:
	# O splash do sistema pinta @mipmap/icon_background e o da engine pinta
	# boot_splash/bg_color. Um vem depois do outro na mesma tela: cores
	# diferentes viram um piscar de fundo antes do menu.
	var fundo := _imagem(FUNDO_ADAPTATIVO)
	if fundo == null:
		return
	var do_sistema := fundo.get_pixel(fundo.get_width() / 2, fundo.get_height() / 2)
	var da_engine: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	assert_almost_eq(da_engine.r, do_sistema.r, 0.004, "vermelho igual ao do icon_background")
	assert_almost_eq(da_engine.g, do_sistema.g, 0.004, "verde igual ao do icon_background")
	assert_almost_eq(da_engine.b, do_sistema.b, 0.004, "azul igual ao do icon_background")


# ------------------------------------------------------ splash do Android 12+

func test_o_icone_e_a_marca_do_splash_existem() -> void:
	# install.sh copia estes dois para android/build/res/drawable; sem eles o
	# gradle empacota os que vem dentro do godot-lib.aar, que sao do Godot.
	assert_true(FileAccess.file_exists(ICONE), "%s existe (rode tools/make_splash.py)" % ICONE)
	assert_true(FileAccess.file_exists(MARCA), "%s existe (rode tools/make_splash.py)" % MARCA)


func test_a_marca_cabe_na_vista_de_200x80_dp() -> void:
	# A vista da imagem de marca tem tamanho fixo e a imagem e esticada nela:
	# fora do 2,5:1 o logo sai deformado no aparelho.
	var marca := _imagem(MARCA)
	if marca == null:
		return
	var proporcao := float(marca.get_width()) / float(marca.get_height())
	assert_almost_eq(proporcao, 2.5, 0.02, "a imagem de marca e 2,5:1 (200x80 dp)")


func test_a_arte_do_splash_cabe_no_circulo_do_sistema() -> void:
	# O erro que isto pega: herdar a escala do icone do launcher, que so
	# precisa caber numa zona segura QUADRADA. No circulo do splash aquela
	# escala corta a borda da mesa e as faiscas.
	#
	# A conta sai do centro do CANVAS, que e onde o circulo cai -- e nao do
	# centro da arte. Assim uma arte grande demais e uma arte fora do lugar
	# reprovam pelo mesmo assert, que e o que o olho ve: sobrou pedaco de fora.
	var icone := _imagem(ICONE)
	if icone == null:
		return
	var largura := icone.get_width()
	var altura := icone.get_height()
	var centro := Vector2(largura, altura) / 2.0
	var raio_da_arte := 0.0
	var pixels_de_arte := 0
	for y in altura:
		for x in largura:
			var p := icone.get_pixel(x, y)
			if p.a <= 0.78 or p.r + p.g + p.b <= LIMIAR_ARTE:
				continue
			pixels_de_arte += 1
			raio_da_arte = maxf(raio_da_arte, centro.distance_to(Vector2(x, y)))
	assert_gt(pixels_de_arte, 0, "o icone do splash tem arte, nao so fundo")
	if pixels_de_arte == 0:
		return
	var raio_do_circulo := largura * FRACAO_VISIVEL / 2.0
	assert_lt(raio_da_arte, raio_do_circulo,
		"a arte (raio %.0f px do centro do canvas) cabe no circulo que o Android mostra (raio %.0f px)"
		% [raio_da_arte, raio_do_circulo])
	# E ocupa o circulo: arte encolhida demais vira um selo perdido no meio da tela.
	assert_gt(raio_da_arte, raio_do_circulo * 0.7,
		"a arte preenche o circulo (raio %.0f px de %.0f px)" % [raio_da_arte, raio_do_circulo])
