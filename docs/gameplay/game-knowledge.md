# Base de Conhecimento do PlayTable (Game Tips / Gemini)

Este documento foi criado estruturalmente para servir como *Ground Truth* (Verdade Absoluta) caso o **Play Games Sidekick** ative o recurso de Dicas (Game Tips) impulsionadas pelo modelo Gemini do Google.

## Visão Geral
O **PlayTable** é uma coletânea premium offline-first de 16 jogos de mesa clássicos, divididos em categorias de Tabuleiro e Cartas.

### Glossário de Termos In-Game
- **Fichas (Tokens/Chips)**: Moeda visual do jogo ganha ao completar missões. Usada no sistema de coleções.
- **Nível de Perfil (Profile Level)**: Progresso global do jogador em todas as modalidades.
- **Maestria de Jogo (Game Mastery)**: A proficiência específica em um dos 16 jogos (ex: Maestria Nível 5 no Xadrez).
- **Ligas (Leagues)**: Classificação competitiva simulada (Bronze a Lenda) com base na relação Vitórias/Derrotas gerais.

## Resumo Estratégico (Exemplos para o Assistente IA)

### Xadrez & Damas
- **Dica de Ouro**: A IA do PlayTable na dificuldade 'Difícil' prioriza controle do centro no Xadrez e proteção das bordas nas Damas. Sempre tente forçar trocas quando tiver vantagem de peças.

### Campo Minado (Minesweeper)
- **Tática**: O relógio começa no primeiro clique. Concentre-se nas quinas e use o padrão 1-2-1 e 1-2-2 nas bordas (as minas estão sempre atrás do número '2' nessas sequências retas).

### Jogo da Memória
- **Dica Rápida**: Para bater o Leaderboard Mundial de 'Menos Turnos' (`leaderboard_memory_turns`), o jogador precisa de memória de curto prazo impecável, pois cada clique penaliza o score. Não clique às cegas.

## Estrutura de Gamificação
- **Streaks**: O jogador ganha um Freeze gratuito a cada 7 dias mantidos.
- **Quests**: Resetam todos os dias à meia-noite (local) ou segunda-feira para as semanais.

*(O Sidekick pode ler este Markdown na nuvem se providenciado pela API do Play Console de Dicas).*
