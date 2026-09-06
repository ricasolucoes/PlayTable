extends GutTest

## Som e musica: os efeitos sintetizados do AudioManager e o loop gerado do
## MusicSynth. Nao ha arquivo de audio no repositorio; e isto que a suite cobra.


func test_todo_efeito_que_a_api_promete_existe() -> void:
	for nome in ["click", "chip_drop", "piece_place", "card_flip", "card_match", "win", "lose",
			"level_up", "draw", "explosion", "splash", "capture", "dice", "shuffle", "error", "flag"]:
		assert_true(AudioManager.has_sound(nome), "efeito '%s' sintetizado" % nome)


func test_os_efeitos_sintetizados_sao_de_16_bits() -> void:
	# "dice" nao tem arquivo: e sempre sintetizado.
	var wav: AudioStreamWAV = AudioManager._cached_sounds["dice"]
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS, "16 bits: o piso de ruido de 8 bits era audivel")
	assert_true(wav.data.size() > 8000, "os dados batem mais de um decimo de segundo")


func test_efeito_em_arquivo_so_entra_quando_o_arquivo_existe() -> void:
	for nome in AudioManager.EFEITOS_ARQUIVO:
		var caminho: String = AudioManager.EFEITOS_ARQUIVO[nome]
		assert_eq(AudioManager.is_file_backed(nome), ResourceLoader.exists(caminho),
			"'%s' vem do arquivo exatamente quando %s existe" % [nome, caminho])
	assert_false(AudioManager.is_file_backed("dice"), "sem arquivo, a sintese continua")


func test_a_faixa_em_arquivo_quando_existe_repete() -> void:
	var faixa: AudioStream = AudioManager._carregar_faixa()
	if not ResourceLoader.exists(AudioManager.MUSICA_ARQUIVO):
		assert_null(faixa, "sem music.mp3 a musica e sintetizada")
		return
	assert_not_null(faixa, "music.mp3 carrega")
	if faixa is AudioStreamMP3:
		assert_true((faixa as AudioStreamMP3).loop, "e repete")


func test_som_e_musica_sao_chaves_separadas_e_gravadas() -> void:
	var som_antes: bool = AudioManager.sound_enabled
	var musica_antes: bool = AudioManager.music_enabled
	AudioManager.sound_enabled = false
	AudioManager.music_enabled = true
	assert_false(bool(SaveManager.get_setting(AudioManager.CHAVE_SOM, true)), "som desligado gravado")
	assert_true(bool(SaveManager.get_setting(AudioManager.CHAVE_MUSICA, false)), "musica ligada gravada")
	AudioManager.sound_enabled = som_antes
	AudioManager.music_enabled = musica_antes


func test_cada_clima_tem_partitura_e_a_lista_bate() -> void:
	for mood in MusicSynth.MOODS:
		assert_true(MusicSynth.is_mood(mood), "clima %s tem partitura" % mood)
	assert_false(MusicSynth.is_mood("heavy_metal"), "clima desconhecido e recusado")


func test_o_loop_renderizado_tem_o_tamanho_do_compasso_e_cabe_em_menos_um_a_um() -> void:
	# Dois compassos bastam para a conta e para a suite nao gastar segundos.
	var amostras := MusicSynth.render("tabuleiro", 2, 8000)
	assert_eq(amostras.size(), MusicSynth.loop_samples("tabuleiro", 2, 8000), "tamanho do loop = compassos x andamento")
	var pico := 0.0
	var energia := 0.0
	for v in amostras:
		pico = maxf(pico, absf(v))
		energia += v * v
	assert_true(pico <= 1.0, "nunca estoura (%.3f)" % pico)
	assert_true(pico > 0.05, "nao e silencio (%.3f)" % pico)
	assert_true(energia / float(amostras.size()) > 0.0005, "tem musica o tempo todo, nao um estalo")


func test_o_loop_emenda_sem_salto() -> void:
	var amostras := MusicSynth.render("cartas", 2, 8000)
	# A cauda do fim ja foi somada ao comeco; a diferenca entre a ultima e a
	# primeira amostra e a de duas amostras vizinhas, nao um degrau.
	var salto := absf(amostras[amostras.size() - 1] - amostras[0])
	assert_true(salto < 0.08, "a emenda do loop nao estala (salto %.3f)" % salto)


func test_o_stream_repete_do_comeco_ao_fim() -> void:
	var amostras := MusicSynth.render("menu", 1, 8000)
	var wav := MusicSynth.to_stream(amostras, 8000)
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "loop ligado")
	assert_eq(wav.loop_end, amostras.size(), "ate a ultima amostra")
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS, "16 bits")
	assert_eq(wav.mix_rate, 8000, "na taxa em que foi renderizado")


func test_o_clima_sai_do_catalogo() -> void:
	assert_eq(AudioManager.mood_for_game("blackjack"), "cartas", "mesa de carteado")
	assert_eq(AudioManager.mood_for_game("sudoku"), "quebra_cabeca", "jogo solitario")
	assert_eq(AudioManager.mood_for_game("campo_minado"), "quebra_cabeca", "campo minado e solitario")
	assert_eq(AudioManager.mood_for_game("damas"), "tabuleiro", "duelo de tabuleiro")
	assert_eq(AudioManager.mood_for_game("jogo_da_velha"), "tabuleiro", "duelo com dupla local")
	assert_eq(AudioManager.mood_for_scene(autofree(Control.new())), "menu", "fora dos jogos e menu")


func test_em_headless_pedir_musica_nao_abre_thread() -> void:
	AudioManager.play_music("menu")
	assert_null(AudioManager._thread, "sem saida de audio nao ha o que renderizar")
	assert_false(AudioManager.is_music_playing(), "e nada toca")
