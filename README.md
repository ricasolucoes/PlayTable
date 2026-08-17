# Jogos de Mesa Offline

Bem-vindo ao repositório do **Jogos de Mesa Offline**.

## 📖 Sobre o Projeto
Este é um aplicativo consolidado que reúne diversos minijogos clássicos de tabuleiro e cartas em uma única aplicação. O objetivo principal deste projeto é oferecer uma experiência de entretenimento limpa, com foco em usabilidade e performance.

### 🛡️ Nossos Princípios Fundamentais
Para mantermos a visão do projeto, as seguintes diretrizes são **obrigatórias**:

1. **100% Gratuito & Open Source:** Todo o código está sob licença MIT. Não há restrições de uso comercial, e a distribuição independente (F-Droid, GitHub Releases, etc.) deve ser mantida.
2. **Offline First:** Os jogos não requerem e não devem depender de servidores online para funcionar. Toda a jogabilidade acontece no próprio dispositivo.
3. **Sem Anúncios (Zero Ads):** Não utilizamos e nunca implementaremos SDKs de anúncios, propagandas em tela, banners ou intersticiais.
4. **Sem Sistema de Contas/Login:** Não há obrigatoriedade de login, servidores no Firebase ou contas para jogar. O armazenamento de perfis, estatísticas e saves é **100% local**.
5. **Sem Compras Obrigatórias:** Todo o conteúdo do jogo está disponível nativamente sem in-app purchases (IAP).

---

## 🏗️ Arquitetura do Repositório

Optamos por uma arquitetura em que vários jogos compartilham um único aplicativo para simplificar a manutenção e reduzir o retrabalho. O código não está completamente misturado, e as regras de negócio de cada jogo ficam isoladas.

```text
/
├── core/                  # Sistemas comuns vitais do aplicativo
│   ├── telas/             # Menu inicial e seleção de categorias/jogos
│   ├── navegacao/         # Lógica de transição de telas/cenas
│   ├── configs/           # Temas, volume de sons, etc.
│   ├── save/              # Armazenamento e persistência local (JSON/SQLite/etc.)
│   └── estatisticas/      # Módulo genérico para registrar vitórias e derrotas
├── shared/                # Componentes visuais e lógica reaproveitável
│   ├── tabuleiro/         # Componentes base de renderização de grades e grids
│   ├── pecas/             # Componentes de peões, discos e modelos 2D comuns
│   └── ui/                # Botões padrão, painéis de status de partida
└── games/                 # Módulo de cada jogo isolado (Regras, IAs, Lógicas únicas)
    ├── quatro_em_linha/    # Jogo 1
    ├── reversi/           # Jogo 2
    └── batalha_naval/     # Jogo 3
```

> **Regra de Ouro da Arquitetura:**
> Componentes visuais (como o estilo dos menus ou o desenho de um tabuleiro genérico) podem ser compartilhados (`shared`), mas as **regras do jogo** (como as condições de captura do Reversi) **não devem** ser transformadas em uma superclasse genérica compartilhada. As regras de cada jogo são independentes.

---

## 🚀 Roteiro de Lançamento (Roadmap)

### Fase 1: O Início (Jogos de Tabuleiro)
A primeira versão foca na construção da base de UI/UX comum e lança os seguintes três jogos:
- **Quatro em Linha:** Serve para testar sistema de turnos simples, grid vertical e física leve.
- **Reversi:** Estabelece um oponente IA e lógica baseada na captura e contagem de peças.
- **Batalha Naval:** Apresenta conceitos de "ocultação de tabuleiro", coordenação espacial e grids duplos.

### Fase 2: Expansão Contínua
Após a validação da base, expandiremos a coleção:
- Adição de novos tabuleiros: *Damas*, *Mancala*, *Jogo da Velha*.
- Criação do grupo de jogos de cartas: *Solitário*, *Memória*, *21*.
- Implementação de desafios diários offline e estatísticas globais (locais) do usuário.

### Fase 3: Possíveis Spin-Offs
Se houver uma adoção muito massiva de um único jogo da plataforma (ex: o Solitário tornar-se muito popular), separaremos aquele módulo em um aplicativo próprio, partilhando o mesmo código base deste repositório para evitar fragmentação excessiva.

---

## 🛠️ Stack de Desenvolvimento
O projeto está estruturado de modo a ser "agnóstico" nas pastas bases neste momento, podendo ser perfeitamente encaixado em uma arquitetura Flutter ou Godot.

Para rodar este repositório, consulte os documentos em cada pasta principal ao escolher o motor definitivo para a compilação mobile (iOS/Android).

---

Feito com 💙 para jogadores e desenvolvedores.
