# PROJECT: Jogos de Mesa Offline

## Overview
Um aplicativo consolidado que reúne diversos minijogos clássicos de tabuleiro e cartas em uma única aplicação, oferecendo uma experiência limpa, focada em usabilidade e performance.

## Core Tenets
- **100% Gratuito & Open Source:** Código sob licença MIT. Sem restrições de uso.
- **Offline First:** Toda jogabilidade acontece localmente. Sem necessidade de conexão com a internet.
- **Sem Anúncios (Zero Ads):** Nenhuma propaganda, pop-up ou SDK de tracking.
- **Sem Sistema de Contas/Login:** Dados salvos localmente, sem contas, sem servidores, sem dependências proprietárias.
- **Sem Compras:** Não há IAP (In-App Purchases).

## Architecture
- **core/**: Sistemas vitais do app (navegação, configs, estatísticas locais, save data).
- **shared/**: Componentes e UI reutilizáveis (layouts de tabuleiro, peças 2D, estilos base).
- **games/**: Módulos independentes contendo as regras e lógicas específicas de cada jogo.

## Engine
Agnóstica por enquanto (Pronta para adotar Godot ou Flutter).
