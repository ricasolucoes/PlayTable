# PROJECT: Jogos de Mesa Offline

## Overview
Um aplicativo consolidado que reúne diversos minijogos clássicos de tabuleiro e cartas em uma única aplicação, oferecendo uma experiência limpa, focada em usabilidade, performance, privacidade e software livre.

## Core Tenets
- **100% Gratuito & Open Source:** Código sob licença MIT. Sem restrições de uso ou telemetria proprietária.
- **Offline First:** Toda jogabilidade acontece localmente. Sem necessidade de conexão com a internet.
- **Sem Anúncios (Zero Ads):** Nenhuma propaganda, pop-up ou SDK de tracking/ad networks.
- **Sem Sistema de Contas/Login:** Dados salvos localmente, sem contas, sem servidores, sem dependências proprietárias.
- **Sem Compras:** Não há microtransações ou IAP (In-App Purchases).
- **Diretrizes Legais de Jogos Tradicionais:** Respeito ao domínio público das regras, com nomes, artes e logotipos 100% autorais (evitando conflito com marcas registradas como Monopoly/Banco Imobiliário ou baralhos comerciais).

## Architecture
- **core/**: Sistemas vitais do app (navegação, configs, estatísticas locais, save data).
- **shared/**: Componentes e UI reutilizáveis (layouts de tabuleiro, peças 2D, estilos base).
- **games/**: Módulos independentes contendo as regras e lógicas específicas de cada jogo.
- **docs/**: Documentação detalhada de catálogo de jogos, especificações, roadmap e legalidade.

## Engines Suportadas
- **Godot 4.3 (Implementação Atual):** Ideal para Quatro em Linha, Batalha Naval, Damas, Reversi, Ludo, etc.
- **Flutter:** Opção ideal para Solitário, Dominó, Sudoku e jogos focados em interface 2D/widgets.
