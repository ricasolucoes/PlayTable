extends GutTest

## Portao de proveniencia da arte.
##
## O CLAUDE.md da pasta Jogos exige que todo asset gerado entre no repositorio
## com modelo, data e prompt num `.prompt.md` ao lado. Sem este teste a regra
## era boa intencao: 32 PNG entraram em `shared/assets/` sem uma linha de
## proveniencia, e so tres deles eram lidos por alguem.
##
## Vale para todo `.png` em `shared/assets/**`. Fatia de grade (`numeros_3.png`)
## herda a proveniencia da tira que a gerou (`numeros.prompt.md`).

const RAIZ := "res://shared/assets"

## Os tres sobreviventes do lote antigo, que o Memoria carrega e que ainda nao
## foram regenerados pelo pipeline (`tools/gen_art.py`). Cada um sai daqui no
## dia em que ganhar o proprio `.prompt.md`; o teste cobra a saida.
const LEGADO: Array = []


func _pngs(pasta: String, saida: Array) -> void:
	var d := DirAccess.open(pasta)
	if d == null:
		return
	d.list_dir_begin()
	var nome := d.get_next()
	while nome != "":
		var caminho := pasta.path_join(nome)
		if d.current_is_dir():
			if not nome.begins_with("."):
				_pngs(caminho, saida)
		elif nome.ends_with(".png"):
			saida.append(caminho)
		nome = d.get_next()
	d.list_dir_end()


## O `.prompt.md` que responde por um PNG: o irmao de mesmo nome, ou o da tira
## quando o nome termina em `_<n>`.
static func proveniencia_de(png: String) -> String:
	var base := png.get_basename()
	var direto := base + ".prompt.md"
	if FileAccess.file_exists(direto):
		return direto
	var re := RegEx.new()
	re.compile("^(.*)_\\d+$")
	var m := re.search(base)
	if m:
		var da_tira: String = m.get_string(1) + ".prompt.md"
		if FileAccess.file_exists(da_tira):
			return da_tira
	return ""


func _tem_linha(md: String, prefixo: String) -> bool:
	var texto := FileAccess.get_file_as_string(md)
	for linha in texto.split("\n"):
		if linha.begins_with(prefixo) and linha.length() > prefixo.length() + 1:
			return true
	return false


func test_todo_png_de_shared_assets_tem_proveniencia() -> void:
	var pngs: Array = []
	_pngs(RAIZ, pngs)
	assert_gt(pngs.size(), 0, "ha PNG em shared/assets")
	for png in pngs:
		if png in LEGADO:
			continue
		var md := proveniencia_de(png)
		assert_ne(md, "", "%s precisa de um .prompt.md ao lado (tools/gen_art.py grava)" % png)
		if md == "":
			continue
		assert_true(_tem_linha(md, "model:"), "%s declara o modelo" % md)
		assert_true(_tem_linha(md, "date:"), "%s declara a data" % md)


func test_a_lista_de_legado_so_guarda_o_que_ainda_nao_foi_regenerado() -> void:
	if LEGADO.is_empty():
		assert_true(true, "todos os assets foram regenerados e possuem proveniencia")
		return
	for png in LEGADO:
		assert_true(FileAccess.file_exists(png),
			"%s saiu do repositorio: tire-o de LEGADO" % png)
		assert_eq(proveniencia_de(png), "",
			"%s ja tem proveniencia: tire-o de LEGADO" % png)


func test_fatia_de_grade_herda_a_proveniencia_da_tira() -> void:
	# `numeros_3.png` sem `numeros_3.prompt.md` responde por `numeros.prompt.md`.
	var pasta := "user://prov_teste"
	DirAccess.make_dir_recursive_absolute(pasta)
	var md := FileAccess.open(pasta.path_join("numeros.prompt.md"), FileAccess.WRITE)
	md.store_string("---\nmodel: x\ndate: y\n---\n")
	md.close()
	assert_eq(proveniencia_de(pasta.path_join("numeros_3.png")), pasta.path_join("numeros.prompt.md"))
	assert_eq(proveniencia_de(pasta.path_join("mina.png")), "", "sem irmao nao ha proveniencia")
	DirAccess.remove_absolute(pasta.path_join("numeros.prompt.md"))
	DirAccess.remove_absolute(pasta)
