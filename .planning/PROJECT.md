# PROJECT: Jogos de Mesa Offline

## Overview
Um aplicativo consolidado que reúne diversos minijogos clássicos de tabuleiro e cartas em uma única aplicação, oferecendo uma experiência limpa, focada em usabilidade, performance, privacidade e software livre.

## Core Tenets
- **100% Gratuito & Open Source:** Código sob licença MIT. Sem restrições de uso ou telemetria proprietária.
- **Offline First:** Toda jogabilidade acontece localmente. Sem necessidade de conexão com a internet.
- **Sem Anúncios (Zero Ads):** Nenhuma propaganda, pop-up ou SDK de tracking/ad networks.
- **Três Camadas, Duas Opcionais:** A base é local e completa — toda jogabilidade, progresso, XP, conquistas e missões funcionam no aparelho, sem rede e sem login. Por cima dela, o **Google Play Games Services v2** é uma camada opcional (conquistas, placares e Cloud Save), que só existe se o jogador entrar. Por cima dessa, um **servidor próprio opcional** (`playtable.ricasolucoes.com.br`, mantido fora deste repositório) para sincronizar gamificação e jogar com amigos.
- **Camada Opcional Nunca Vira Requisito:** Jogador deslogado ou servidor inacessível é estado normal, não erro. Nenhuma tela pode bloquear, e nenhuma feature de jogabilidade pode exigir rede ou conta.
- **Sem Compras:** Não há microtransações ou IAP (In-App Purchases).
- **Diretrizes Legais de Jogos Tradicionais:** Respeito ao domínio público das regras, com nomes, artes e logotipos 100% autorais (evitando conflito com marcas registradas como Monopoly/Banco Imobiliário ou baralhos comerciais).

## Architecture
- **core/**: Sistemas vitais do app — 20 autoloads registrados em `project.godot`, incluindo o barramento `core/services/GameEventBus.gd`, o perfil do jogador (`core/services/PlayerProfile.gd`, onde de fato mora o progresso) e a persistência (`core/save/`). O `core/save/SaveManager.gd` guarda só configuração (volume e tema); progresso, XP e conquistas ficam no `PlayerProfile`.
- **shared/**: Componentes e UI reutilizáveis (layouts de tabuleiro, peças 2D, estilos base).
- **games/**: Módulos independentes contendo as regras e lógicas específicas de cada jogo.
- **docs/**: Documentação detalhada de catálogo de jogos, especificações, roadmap e legalidade.

## Engine
- **Godot 4.7.2-stable** — versão pinada em `.godot-version`; `scripts/godot_bin.sh` resolve o binário correto sozinho. GDScript puro no cliente; Java só na ponte Android do Play Games (`android/pgs/java/org/playtable/pgs/PlayTablePGS.java`).
- **Plataforma:** Android (preset único em `export_presets.cfg`), package `org.playtable.app`. Não há preset de iOS nem de desktop no repositório.
