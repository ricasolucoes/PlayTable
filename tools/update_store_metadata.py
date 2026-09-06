#!/usr/bin/env python3
import os
import sys
from pathlib import Path

FASTLANE_DIR = Path(__file__).resolve().parents[1] / "fastlane/metadata/android"

# ==============================================================================
# 1. CORE DESCRIPTIONS TEMPLATES
# ==============================================================================

PT_TITLE = "PlayTable: Jogos Clássicos"
PT_SHORT = "22 jogos clássicos de tabuleiro e cartas. 100% offline, grátis e sem anúncios."
PT_FULL = """O PlayTable é a coleção definitiva com 22 jogos clássicos de tabuleiro, cartas e raciocínio lógico em um único aplicativo — 100% gratuito, sem anúncios e totalmente offline!

Criado para quem valoriza boa jogabilidade, respeito à privacidade e resposta rápida, o PlayTable funciona diretamente no seu celular ou tablet. Sem conexão com a internet, sem cadastros, sem compras no app e sem coleta de dados. Ative o modo avião e jogue onde e quando quiser!

🎲 16 JOGOS DE TABULEIRO E RACIOCÍNIO:
• Damas: Tabuleiro 8x8 tradicional com coroação e capturas múltiplas.
• Batalha Naval: Grids 10x10 com radar de ataque e esquadra contra IA tática.
• Campo Minado: O clássico jogo de dedução lógica com primeiro clique seguro e bandeiras.
• Sudoku: Quebra-cabeças lógicos 9x9 com anotações numéricas e verificação.
• Dominó: 28 pedras (duplo 6) com compra estratégica e contagem clássica.
• Gamão (Backgammon): Movimentação em 24 pontos, barra de captura e dados virtuais.
• Reversi (Othello): Disputa de virada de peças com algoritmo Minimax avançado.
• Ludo: A tradicional corrida de 4 peões em cruz para toda a família.
• Quatro em Linha: Conecte quatro fichas antes do adversário (vertical, horizontal ou diagonal).
• Jogo da Velha (Tic-Tac-Toe): Partidas rápidas e dinâmicas contra IA imbatível ou amigos.
• Mancala (Kalah): O milenar jogo africano de semeadura e colheita de sementes.
• Senet: O lendário jogo de tabuleiro do Antigo Egito.
• Resta Um (Peg Solitaire): O consagrado puzzle de eliminação geométrica de pinos.
• Torre de Hanói: O fascinante desafio matemático de transferência sequencial de discos.
• Nim: O clássico jogo matemático de raciocínio lógico e remoção de pilhas.
• Caminho Numérico: Desafio numérico de conexão contínua estilo Hidato / Numbrix.

🃏 6 JOGOS DE CARTAS CLÁSSICOS:
• Paciência Klondike: O jogo de cartas solo mais famoso do mundo (Klondike Solitaire).
• Paciência Spider: Desafio profundo de ordenação de sequências em 10 colunas.
• Vinte e Um (Blackjack 21): Enfrente o dealer, calcule probabilidades e não estoure.
• Jogo da Memória: Teste e treine sua memória visual encontrando todos os pares.
• UnoLike: Descarte rápido por cor e número com cartas de inversão, bloqueio e compra.
• Vídeo Pôquer: Jacks or Better com troca estratégica de cartas e tabela clássica de pontos.

✨ PRINCIPAIS DESTAQUES:
• 100% Gratuito: Sem anúncios em vídeo, sem banners, sem paywalls e sem compras no app.
• 100% Offline-First: Jogue em viagens, no avião, metrô ou em qualquer lugar sem internet.
• Modos Flexíveis: Enfrente a inteligência artificial ou jogue com amigos em modo local no mesmo aparelho (pass-and-play).
• Estatísticas Detalhadas: Acompanhe vitórias, menor tempo e recordes pessoais salvos no dispositivo.
• Código Aberto & Transparente: Desenvolvido com Godot 4 sob a organização ricasolucoes no GitHub.

Baixe o PlayTable agora mesmo e tenha os melhores clássicos de mesa e cartas sempre à mão!"""

EN_TITLE = "PlayTable: Classic Board Games"
EN_SHORT = "22 classic board & card games in one app. 100% offline, free with zero ads."
EN_FULL = """PlayTable is the ultimate all-in-one collection of 22 timeless classic board games, card games, and logic puzzles — 100% free, completely ad-free, and fully offline!

Designed for pure gameplay, instant responsiveness, and complete user privacy, PlayTable runs locally on your smartphone or tablet. No Wi-Fi or mobile data required, no sign-ups, no tracking, and no in-app purchases. Turn on airplane mode and enjoy classic games anytime, anywhere!

🎲 16 CLASSIC BOARD & LOGIC GAMES:
• Checkers (Draughts): Classic 8x8 board with king promotion and mandatory captures.
• Battleship: 10x10 radar and fleet grids with intelligent Hunt & Target AI.
• Minesweeper: Legendary logic puzzle featuring safe first clicks and flag placement.
• Sudoku: Pure 9x9 logic grids with pencil notes and real-time conflict checking.
• Dominoes: Traditional double-six 28-tile game with classic draw and blocking rules.
• Backgammon: Classic 24-point board, bearing off, checker hits, and 3D dice rolling.
• Reversi (Othello): Strategic piece flipping powered by advanced Minimax algorithms.
• Ludo: Fun 4-token race track for quick matches and casual strategy.
• Connect Four (4 in a Row): Drop chips and connect 4 horizontally, vertically, or diagonally.
• Tic-Tac-Toe: Fast, crisp matches against adaptive AI or with a friend.
• Mancala (Kalah): The ancient African pit and pebble sowing strategy game.
• Senet: Explore the oldest known board game from Ancient Egypt.
• Peg Solitaire: The timeless cross-shaped board puzzle of jumping and clearing pegs.
• Tower of Hanoi: The classic mathematical disc-stacking puzzle.
• Nim: Deep mathematical strategy game of stone pile management.
• Number Path: Engaging sequential path puzzle (Hidato / Numbrix style).

🃏 6 TIMELESS CARD GAMES:
• Klondike Solitaire: The world's most beloved single-player card game.
• Spider Solitaire: High-challenge multi-column deck sequencing.
• Blackjack (21): Face the dealer, double down, and hit 21 without busting.
• Memory Match: Train and sharpen visual recall by matching hidden pairs.
• UnoLike: Fast-paced shedding game with color matching, Skips, Reverses, and Wilds.
• Video Poker: Classic Jacks or Better machine with strategic discard and payouts.

✨ TOP HIGHLIGHTS:
• 100% Free: No ads, no popups, no subscriptions, and no microtransactions.
• 100% Offline: Zero data usage — perfect for flights, commutes, and road trips.
• Multiple Modes: Play solo against smart AI or challenge friends locally on the same device.
• Local Stats & Privacy: All win streaks, personal bests, and records stay strictly on your device.
• Open Source: Proudly built with Godot 4 and maintained by the ricasolucoes GitHub community.

Download PlayTable today and carry a complete arcade of 22 classic games in your pocket!"""

ES_TITLE = "PlayTable: Juegos de Mesa"
ES_SHORT = "22 juegos clásicos de mesa y cartas. 100% offline, gratis y sin anuncios."
ES_FULL = """PlayTable es la colección definitiva con 22 juegos clásicos de mesa, cartas y acertijos lógicos en una sola aplicación: ¡100% gratis, sin anuncios y totalmente offline!

Diseñado para los amantes de los juegos tradicionales que buscan una experiencia fluida, sin interrupciones y con total respeto a la privacidad. Todo funciona localmente en tu dispositivo: sin conexión a internet, sin registros y sin compras integradas. ¡Activa el modo avión y juega donde y cuando quieras!

🎲 16 JUEGOS DE MESA Y LÓGICA:
• Damas: Tablero clásico 8x8 con damas voladoras y capturas múltiples obligatorias.
• Batalla Naval: Cuadrículas de radar y flota 10x10 con IA táctica Hunt & Target.
• Buscaminas: El legendario juego de deducción con primer toque seguro y banderas.
• Sudoku: Cuadrículas lógicas 9x9 con notas a lápiz y validación instantánea.
• Dominó: 28 fichas (doble seis) con modo clásico de robo y bloqueo.
• Backgammon: Tablero de 24 puntos, captura en barra y lanzamiento de dados.
• Reversi (Othello): Domina el tablero volteando las fichas rivales con IA Minimax.
• Ludo: La clásica carrera familiar de 4 peones hasta la meta.
• Cuatro en Línea: Conecta cuatro fichas seguidas en horizontal, vertical o diagonal.
• Tres en Línea (Ta-Te-Ti): Partidas rápidas y dinámicas para todas las edades.
• Mancala (Kalah): El milenario juego africano de siembra y recolección.
• Senet: El juego de mesa sagrado del Antiguo Egipto.
• Solitario de Clavijas (Senku): Salta y elimina clavijas hasta dejar una sola.
• Torre de Hanói: El clásico desafío matemático de traslado de discos.
• Nim: Clásico juego matemático de equilibrio y eliminación de pilas.
• Camino Numérico: Desafío de conexión secuencial continua estilo Hidato.

🃏 6 JUEGOS DE CARTAS CLÁSICOS:
• Solitario Klondike: El solitario de cartas más famoso y adictivo del mundo.
• Solitario Spider: Desafío de ordenamiento de naipes en 10 columnas.
• Blackjack (Veintiuno): Vence al crupier sumando 21 sin pasarte.
• Juego de Memoria: Encuentra y empareja todas las cartas ocultas.
• UnoLike: Juego de descarte por colores y números con cartas de acción y cambio de sentido.
• Video Poker: Jacks or Better con descarte estratégico y tabla oficial de pagos.

✨ CARACTERÍSTICAS DESTACADAS:
• 100% Gratis: Sin anuncios molestos, sin banners y sin microtransacciones.
• 100% Fuera de Línea (Offline): Juega en viajes, aviones o zonas sin cobertura.
• Modos Versátiles: Juega contra la IA o con amigos en el mismo dispositivo (modo local).
• Privacidad Absoluta: Tus récords, estadísticas y preferencias se quedan en tu dispositivo.
• Código Abierto: Desarrollado con Godot 4 bajo la organización ricasolucoes en GitHub.

¡Descarga PlayTable ahora y disfruta de 22 grandes clásicos en cualquier lugar!"""

# Localized variants for other languages
LOCALES_DATA = {
    # Portuguese variants
    "pt-BR": {"title": PT_TITLE, "short": PT_SHORT, "full": PT_FULL},
    "pt-PT": {"title": PT_TITLE, "short": "22 jogos clássicos de tabuleiro e cartas. 100% offline, grátis e sem anúncios.", "full": PT_FULL},
    
    # English variants
    "en-US": {"title": EN_TITLE, "short": EN_SHORT, "full": EN_FULL},
    "en-GB": {"title": EN_TITLE, "short": EN_SHORT, "full": EN_FULL},
    "en-CA": {"title": EN_TITLE, "short": EN_SHORT, "full": EN_FULL},
    "en-AU": {"title": EN_TITLE, "short": EN_SHORT, "full": EN_FULL},
    
    # Spanish variants
    "es-419": {"title": ES_TITLE, "short": ES_SHORT, "full": ES_FULL},
    "es-ES": {"title": ES_TITLE, "short": ES_SHORT, "full": ES_FULL},
    "es-US": {"title": ES_TITLE, "short": ES_SHORT, "full": ES_FULL},
    
    # French
    "fr-FR": {
        "title": "PlayTable: Jeux de Société",
        "short": "22 jeux classiques de société et cartes. 100% hors-ligne, gratuit, sans pub.",
        "full": """PlayTable est la collection ultime de 22 jeux de société, jeux de cartes et casse-têtes classiques réunis dans une seule application — 100% gratuit, sans publicité et entièrement hors-ligne !

🎲 16 JEUX DE SOCIÉTÉ ET DE RÉFLEXION :
• Dames (Checkers) : Plateau classique 8x8 avec promotion et prises obligatoires.
• Bataille Navale : Grilles 10x10 avec radar et flotte contre une IA tactique Hunt & Target.
• Démineur : Le jeu de logique légendaire avec premier clic sécurisé et drapeaux.
• Sudoku : Grilles 9x9 pures avec annotations au crayon et détection d'erreurs.
• Dominos : 28 dominos (double 6) avec pioche stratégique et règles traditionnelles.
• Backgammon : Plateau 24 flèches, capture et dés 3D virtuels.
• Reversi (Othello) : Retournement de pions tactique avec algorithme Minimax.
• Ludo (Petits Chevaux) : La course familiale classique de 4 pions.
• Puissance 4 : Alignez 4 jetons à l'horizontale, verticale ou diagonale.
• Morpion (Tic-Tac-Toe) : Parties rapides et amusantes contre l'IA ou à deux.
• Mancala (Kalah) : Le jeu de semis africain millénaire.
• Senet : Le mystérieux jeu de l'Égypte antique.
• Solitaire à Pions (Peg Solitaire) : Éliminez les billes pour n'en laisser qu'une seule.
• Tours de Hanoï : Le casse-tête mathématique emblématique.
• Nim : Jeu mathématique classique de retrait de bâtonnets.
• Chemin Numérique : Puzzle logique de parcours continu séquentiel (style Hidato).

🃏 6 JEUX DE CARTES CLASSIQUES :
• Solitaire Klondike : La patience de cartes la plus célèbre au monde.
• Solitaire Spider : Défi captivant d'ordonnancement de 10 colonnes.
• Blackjack (21) : Battez le croupier sans dépasser 21.
• Jeu de Mémoire : Retrouvez toutes les paires de cartes cachées.
• UnoLike : Débarrassez-vous de vos cartes par couleur et chiffre avec cartes action.
• Vidéo Poker : Jacks or Better avec tirage stratégique et tableau officiel des gains.

✨ POINTS FORTS :
• 100% Gratuit & Sans Pub : Aucune publicité, aucun achat intégré et aucune interruption.
• 100% Hors-ligne : Jouez n'importe où sans wifi ni données mobiles.
• Mode Deux Joueurs Local : Jouez à deux sur le même appareil (pass-and-play) ou contre l'IA.
• Open Source : Développé avec Godot 4 sous la communauté GitHub ricasolucoes.

Téléchargez PlayTable dès aujourd'hui et profitez de 22 chefs-d'œuvre du jeu classique !"""
    },
    "fr-CA": {
        "title": "PlayTable: Jeux de Société",
        "short": "22 jeux classiques de société et cartes. 100% hors-ligne, gratuit, sans pub.",
        "full": """PlayTable est la collection ultime de 22 jeux de société, jeux de cartes et casse-têtes classiques — 100% gratuit, sans pub et hors-ligne ! (Dames, Bataille Navale, Démineur, Sudoku, Dominos, Backgammon, Reversi, Ludo, Puissance 4, Solitaire Klondike, Solitaire Spider, Blackjack 21, Vidéo Poker et plus). Sans pub, sans internet, open source ricasolucoes."""
    },
    
    # German
    "de-DE": {
        "title": "PlayTable: Klassische Spiele",
        "short": "22 klassische Brett- & Kartenspiele in einer App. 100% offline & werbefrei.",
        "full": """PlayTable vereint 22 zeitlose Brett- und Kartenspiele sowie Logikrätsel in einer einzigen Premium-App — 100% kostenlos, komplett werbefrei und vollständig offline spielbar!

Enthält Dame, Schiffe versenken, Minesweeper, Sudoku, Domino, Backgammon, Reversi (Othello), Ludo (Mensch ärgere dich nicht), Vier Gewinnt, Tic-Tac-Toe, Mancala, Senet, Solitär (Peg Solitaire), Türme von Hanoi, Nim, Zahlenpfad sowie Klondike Solitaire, Spider Solitaire, Blackjack 21, Memory, UnoLike und Video Poker.

Keine Werbung, keine In-App-Käufe, kein Internet erforderlich. Mit Google Play Games Sidekick und lokalem Mehrspielermodus. Open Source auf GitHub unter ricasolucoes!"""
    },

    # Italian
    "it-IT": {
        "title": "PlayTable: Giochi da Tavolo",
        "short": "22 giochi classici da tavolo e carte. 100% offline, gratis e senza pubblicità.",
        "full": """PlayTable è la collezione definitiva di 22 grandi giochi classici da tavolo, carte e logica in un'unica applicazione — 100% gratuita, senza pubblicità e completamente offline!

Include Dama, Battaglia Navale, Campo Minato, Sudoku, Domino, Backgammon, Reversi (Othello), Ludo, Forza Quattro, Tris (Filetto), Mancala, Senet, Solitario della Pallina, Torre di Hanoi, Nim, Percorso Numerico, Solitario Klondike, Solitario Spider, Blackjack 21, Gioco della Memoria, UnoLike e Video Poker.

100% offline, zero pubblicità, supporto a Google Play Games Sidekick e multiplayer locale sullo stesso dispositivo. Open source su GitHub (ricasolucoes)."""
    },

    # Russian
    "ru-RU": {
        "title": "PlayTable: Настольные игры",
        "short": "22 классические настольные и карточные игры. 100% офлайн, без рекламы.",
        "full": """PlayTable — это коллекция из 22 классических настольных, карточных и логических игр в одном приложении. 100% бесплатно, без рекламы и без интернета!

Включает: Шашки, Морской бой, Сапёр, Судоку, Домино, Нарды (Бэкгаммон), Реверси (Отелло), Лудо, Четыре в ряд, Крестики-нолики, Манкала, Сенет, Солитер с колышками, Ханойская башня, Ним, Числовой путь, Пасьянс Косынка (Клондайк), Пасьянс Паук, Блэкджек 21, Игра на память, UnoLike и Видеопокер.

Полный офлайн, никаких встроенных покупок, поддержка Google Play Games Sidekick и игра вдвоем на одном экране. Открытый исходный код на GitHub (ricasolucoes)."""
    },

    # Japanese
    "ja-JP": {
        "title": "PlayTable: 定番ボードゲーム",
        "short": "22種類の定番ボード＆カードゲーム。完全オフライン・完全無料・広告なし。",
        "full": """PlayTable（プレイテーブル）は、22種類の定番ボードゲーム・トランプゲーム・ロジックパズルを1つに集約した究極のコレクションアプリです。完全無料・広告一切なし・100%オフライン対応！

【収録ゲーム一覧】
チェッカー、海戦ゲーム（バトルシップ）、マインスイーパー、数独（ナンプレ）、ドミノ、バックギャモン、リバーシ（オセロ）、ルドー、コネクトフォー（四目並べ）、三目並べ（マルバツ）、マンカラ、セネト、ペグ・ソリティア、ハノイの塔、ニム、ナンバーパス、ソリティア（クロンダイク）、スパイダーソリティア、ブラックジャック（21）、神経衰弱（メモリー）、UnoLike、ビデオポーカー。

広告なし、課金なし、通信制限なし。1台の端末で2人対戦も可能。Google Play Games Sidekick対応。GitHub（ricasolucoes）にてオープンソース公開中。"""
    },

    # Chinese Simplified
    "zh-CN": {
        "title": "PlayTable: 经典棋盘与纸牌",
        "short": "22款经典棋盘与纸牌游戏，完全离线单机，纯净无广告，永久免费。",
        "full": """PlayTable 是一款精选 22 款经典桌游、纸牌及益智解谜游戏的合集应用，100% 永久免费、完全离线、纯净无广告！

【收录 22 款经典游戏】
西洋跳棋、海战棋（战舰）、扫雷、数独、多米诺骨牌、双陆棋、黑白棋（黑白翻转棋）、飞行棋（Ludo）、四子棋、井字棋、播棋（Mancala）、塞尼特棋（古埃及棋）、孔明棋（独立钻石）、汉诺塔、尼姆游戏、数字寻路，以及克朗代克纸牌（经典接龙）、蜘蛛纸牌、二十一点（Blackjack）、记忆翻牌、UnoLike、视频扑克。

无任何广告插播、无内购、无需联网，支持单机双人同屏对战与 Google Play Games Sidekick。开源项目托管于 GitHub (ricasolucoes)。"""
    },

    # Chinese Traditional
    "zh-TW": {
        "title": "PlayTable: 經典棋盤與紙牌",
        "short": "22款經典棋盤與紙牌遊戲，完全離線單機，純淨無廣告，永久免費。",
        "full": """PlayTable 是一款精選 22 款經典桌遊、紙牌及益智解謎遊戲的合集應用，100% 永久免費、完全離線、純淨無廣告！

【收錄 22 款經典遊戲】
西洋跳棋、海戰棋、踩地雷、數獨、西洋骨牌、西洋雙陸棋、黑白棋、飛行棋、四子棋、圈圈叉叉、播棋、塞尼特棋、孔明棋、河內塔、尼姆遊戲、數字尋路，以及接龍紙牌（克朗代克）、蜘蛛紙牌、二十一點、記憶配對、UnoLike、視訊撲克。

無廣告插播、無內購陷阱、無須網路連線，支援單機雙人同螢幕對戰與 Google Play Games Sidekick。開源專案託管於 GitHub (ricasolucoes)。"""
    },

    # Korean
    "ko-KR": {
        "title": "PlayTable: 클래식 보드게임",
        "short": "22가지 클래식 보드게임과 카드게임. 100% 오프라인, 무료, 광고 없음.",
        "full": """PlayTable은 22가지 시대를 초월한 클래식 보드게임, 카드게임, 퍼즐 게임을 한곳에 모은 종합 게임 컬렉션입니다. 100% 무료, 광고 없음, 완벽 오프라인 지원!

체커, 해전 게임(배틀쉽), 지뢰찾기, 스도쿠, 도미노, 백개먼, 리버시(오델로), 루도, 사목 게임(커넥트4), 틱택토, 만칼라, 세네트, 페그 솔리테어, 하노이의 탑, 님, 숫자 경로 퍼즐, 클론다이크 솔리테어, 스파이더 솔리테어, 블랙잭 21, 기억력 카드 맞추기, UnoLike, 비디오 포커 수록.

광고 및 인앱 결제 없음, 비행기 탑승 중에도 플레이 가능. Google Play Games Sidekick 연동. GitHub (ricasolucoes) 오픈소스."""
    },

    # Hindi
    "hi-IN": {
        "title": "PlayTable: क्लासिक बोर्ड गेम्स",
        "short": "22 क्लासिक बोर्ड और कार्ड गेम्स। 100% ऑफलाइन, मुफ्त, बिना विज्ञापनों के।",
        "full": """PlayTable 22 क्लासिक बोर्ड गेम्स, कार्ड गेम्स और लॉजिक पहेलियों का सर्वश्रेष्ठ संग्रह है — 100% मुफ़्त, पूरी तरह से ऑफ़लाइन और बिना किसी विज्ञापन के!

शामिल खेल: चेकर्स, बैटलशिप, माइनस्वीपर, सुडोकू, डोमिनोज़, बैकगैमौन, रिवर्सी (ओथेलो), लूडो, कनेक्ट फोर, टिक-टैक-टो, मनकाला, सेनेट, पेग सॉलिटेयर, टॉवर ऑफ़ हनोई, निम, नंबर पाथ, क्लोंडाइक सॉलिटेयर, स्पाइडर सॉलिटेयर, ब्लैकजैक 21, मेमोरी मैच, UnoLike और वीडियो पोकर।

बिना इंटरनेट, बिना विज्ञापनों के खेलें। Google Play Games Sidekick सपोर्ट और ricasolucoes GitHub ओपन सोर्स।"""
    },

    # Indonesian
    "id": {
        "title": "PlayTable: Game Papan Klasik",
        "short": "22 game papan & kartu klasik dalam satu aplikasi. 100% offline, tanpa iklan.",
        "full": """PlayTable adalah koleksi lengkap 22 game papan, kartu, dan puzzle logika klasik terbaik — 100% gratis, tanpa iklan, dan sepenuhnya offline!

Termasuk Dam (Checkers), Kapal Perang (Battleship), Ranjau (Minesweeper), Sudoku, Domino, Backgammon, Reversi (Othello), Ludo, Sambung Empat (Connect 4), Tic-Tac-Toe, Mancala (Congklak), Senet, Peg Solitaire, Menara Hanoi, Nim, Jalur Angka, Solitaire Klondike, Solitaire Spider, Blackjack 21, Game Memori, UnoLike, dan Video Poker.

Tanpa iklan, tanpa kuota internet, dukungan Google Play Games Sidekick, dan open source di GitHub (ricasolucoes)."""
    },

    # Turkish
    "tr-TR": {
        "title": "PlayTable: Klasik Oyunlar",
        "short": "22 klasik masa ve kart oyunu bir arada. %100 çevrimdışı, ücretsiz, reklamsız.",
        "full": """PlayTable, 22 klasik masa, kart ve zeka oyununu tek bir uygulamada toplayan hepsi bir arada oyun koleksiyonudur — %100 ücretsiz, reklamsız ve tamamen çevrimdışı!

Dama, Amiral Battı, Mayın Tarlası, Sudoku, Domino, Tavla (Backgammon), Reversi (Othello), Kızma Birader (Ludo), Hedef 4 (Connect 4), Sos (Tic-Tac-Toe), Mangala, Senet, Solo Test, Hanoi Kuleleri, Nim, Sayı Yolu, Klasik Solitaire (Klondike), Spider Solitaire, Blackjack 21, Hafıza Kartı, UnoLike ve Video Poker içerir.

İnternetsiz oynanabilir, reklam içermez, Google Play Games Sidekick destekli ve GitHub'da (ricasolucoes) açık kaynak kodludur."""
    },

    # Arabic
    "ar": {
        "title": "PlayTable: ألعاب طاولة",
        "short": "٢٢ لعبة طاولة وبطاقات كلاسيكية. تعمل بدون إنترنت وبدون إعلانات مجاناً.",
        "full": """تطبيق PlayTable هو المجموعة الكاملة التي تضم ٢٢ لعبة كلاسيكية من ألعاب الطاولة، الورق والألغاز المنطقية — مجاناً ١٠٠٪، بدون إعلانات وتعمل كلياً بدون إنترنت!

تشمل الألعاب: الداما، المعركة البحرية، كاسحة الألغام، سودوكو، دومينو، طاولة الزهر، ريفيرسي (عطيل)، لودو، أربعة على التوالي، إكس أو (تيك تاك تو)، منقلة، سينيت، السوليتير الرخامي، أبراج هانوي، نيم، مسار الأرقام، سوليتير كلوندايك، سوليتير العنكبوت، بلاك جاك ٢١، لعبة الذاكرة، UnoLike، وفيديو بوكر.

بدون اتصال بالإنترنت، بدون إعلانات، يدعم Google Play Games Sidekick ومفتوح المصدر على GitHub (ricasolucoes)."""
    },

    # Dutch
    "nl-NL": {
        "title": "PlayTable: Klassieke Spellen",
        "short": "22 klassieke bord- en kaartspellen. 100% offline, gratis en zonder reclame.",
        "full": """PlayTable is de ultieme verzameling van 22 klassieke bord-, kaart- en denkspellen in één app — 100% gratis, zonder reclame en volledig offline speelbaar!

Bevat Dammen, Zeeslag, Mijnenveger, Sudoku, Domino, Backgammon, Reversi (Othello), Mens-erger-je-niet (Ludo), Vier op 'n Rij, Boter-kaas-en-eieren, Mancala, Senet, Peg Solitaire, Torens van Hanoi, Nim, Getallenpad, Patience (Klondike), Spider Solitaire, Blackjack 21, Geheugenspel, UnoLike en Video Poker.

Geen advertenties, geen internet nodig, Google Play Games Sidekick en open source op GitHub (ricasolucoes)."""
    },

    # Polish
    "pl-PL": {
        "title": "PlayTable: Gry Planszowe",
        "short": "22 klasyczne gry planszowe i karciane. 100% offline, bez reklam i opłat.",
        "full": """PlayTable to najlepsza kolekcja 22 klasycznych gier planszowych, karcianych i logicznych w jednej aplikacji — w 100% darmowa, bez reklam i w pełni offline!

Zawiera: Warcaby, Statki (Bitwa morska), Saper, Sudoku, Domino, Tryktrak (Backgammon), Reversi (Otello), Chińczyk (Ludo), Czwórki (Connect 4), Kółko i krzyżyk, Mankala, Senet, Samotnik (Peg Solitaire), Wieże Hanoi, Nim, Ścieżka liczb, Pasjans Klondike, Pasjans Pająk, Blackjack 21, Gra pamięciowa, UnoLike i Wideo Poker.

Graj bez internetu i reklam. Obsługa Google Play Games Sidekick oraz otwarty kod źródłowy na GitHubie (ricasolucoes)."""
    },

    # Swedish
    "sv-SE": {
        "title": "PlayTable: Klassiska Spel",
        "short": "22 klassiska bräd- och kortspel. 100% offline, helt gratis utan reklam.",
        "full": """PlayTable är den kompletta samlingen med 22 klassiska brädspel, kortspel och logikpussel — 100% gratis, reklamfritt och helt offline!

Innehåller Dam, Sänka skepp, Röj, Sudoku, Domino, Backgammon, Othello (Reversi), Fia med knuff (Ludo), Fyra i rad, Tre i rad, Kalaha (Mancala), Senet, Peg Solitaire, Tornen i Hanoi, Nim, Nummerväg, Harpan (Klondike Solitaire), Spindeln, Blackjack 21, Minnesspel, UnoLike och Video Poker.

Kräver inget internet och har inga köp i appen. Open source på GitHub (ricasolucoes)."""
    },

    # Thai
    "th": {
        "title": "PlayTable: บอร์ดเกมคลาสสิก",
        "short": "22 บอร์ดเกมและการ์ดเกมคลาสสิก เล่นออฟไลน์ 100% ฟรี ไม่มีโฆษณา",
        "full": """PlayTable รวม 22 บอร์ดเกม การ์ดเกม และเกมลับสมองคลาสสิกยอดนิยมไว้ในแอปเดียว — เล่นฟรี 100% ไม่มีโฆษณาคั่น และเล่นออฟไลน์ได้โดยไม่ต้องต่อเน็ต!

ประกอบด้วย: หมากฮอส, แบทเทิลชิป (เรือรบ), เกมกวาดทุ่นระเบิด (Minesweeper), ซูโดกุ, โดมิโน, แบ็คแกมมอน, โอเทลโล่ (Reversi), ลูโด, โฟร์อินอะโรว์ (Connect 4), โอเอกซ์ (Tic-Tac-Toe), มานคาลา, เซเน็ต, เป๊กโซลิแทร์, หอคอยแห่งฮานอย, นิม, ปริศนาตัวเลข, ไพ่โซลิแทร์ (Klondike), สไปเดอร์โซลิแทร์, แบล็คแจ็ค 21, เกมจับคู่ความจำ, UnoLike และวิดีโอโป๊กเกอร์

เล่นได้ทุกที่ ไม่ใช้เน็ต ไม่มีการซื้อในแอป โอเพ่นซอร์สบน GitHub (ricasolucoes)"""
    },

    # Vietnamese
    "vi": {
        "title": "PlayTable: Trò chơi cổ điển",
        "short": "22 trò chơi cờ và bài kinh điển. 100% ngoại tuyến, miễn phí, không quảng cáo.",
        "full": """PlayTable là bộ sưu tập đỉnh cao gồm 22 trò chơi cờ, bài và giải đố kinh điển trong một ứng dụng duy nhất — 100% miễn phí, hoàn toàn không có quảng cáo và chơi ngoại tuyến không cần mạng!

Bao gồm: Cờ đam, Bắn tàu (Battleship), Dò mìn (Minesweeper), Sudoku, Domino, Cờ tào cáo (Backgammon), Cờ lật (Reversi/Othello), Cờ cá ngựa (Ludo), Nối 4 (Connect 4), Cờ ca-rô (Tic-Tac-Toe), Ô ăn quan (Mancala), Senet, Peg Solitaire, Tháp Hà Nội, Nim, Đường dẫn số, Xếp bài Solitaire (Klondike), Spider Solitaire, Xì dách (Blackjack 21), Lật hình ghi nhớ, UnoLike và Video Poker.

Chơi mượt mà không tốn dung lượng mạng, mã nguồn mở trên GitHub (ricasolucoes)."""
    },
}

def validate_and_write(locale: str, title: str, short_desc: str, full_desc: str):
    loc_dir = FASTLANE_DIR / locale
    loc_dir.mkdir(parents=True, exist_ok=True)
    
    # Assertions for Google Play restrictions
    if len(title) > 30:
        raise ValueError(f"[{locale}] Title exceeds 30 chars ({len(title)}): '{title}'")
    if len(short_desc) > 80:
        raise ValueError(f"[{locale}] Short description exceeds 80 chars ({len(short_desc)}): '{short_desc}'")
    if len(full_desc) > 4000:
        raise ValueError(f"[{locale}] Full description exceeds 4000 chars ({len(full_desc)})")

    # Write files
    (loc_dir / "title.txt").write_text(title.strip() + "\n", encoding="utf-8")
    (loc_dir / "short_description.txt").write_text(short_desc.strip() + "\n", encoding="utf-8")
    (loc_dir / "full_description.txt").write_text(full_desc.strip() + "\n", encoding="utf-8")
    print(f"✓ [{locale:6s}] Title: {len(title):2d}/30 | Short: {len(short_desc):2d}/80 | Full: {len(full_desc):4d}/4000")

def main():
    print("Iniciando atualização de metadados da Play Store em 27 idiomas...\n")
    for loc, data in LOCALES_DATA.items():
        validate_and_write(loc, data["title"], data["short"], data["full"])
        
    print(f"\nSucesso total: todos os {len(LOCALES_DATA)} idiomas validados e gravados!")

if __name__ == "__main__":
    main()
