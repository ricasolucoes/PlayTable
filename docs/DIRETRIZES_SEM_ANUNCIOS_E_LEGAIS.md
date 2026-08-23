# 🛡️ Diretrizes Open Source, Modelo Sem Anúncios e Aspectos Legais

Este documento estabelece as diretrizes éticas, técnicas e jurídicas do ecossistema **Jogos de Mesa Offline** para garantir total liberdade aos usuários, ausência de custos operacionais e conformidade legal.

---

## 🚫 Modelo 100% Gratuito & Zero Anúncios

Para manter o projeto verdadeiramente limpo, ético e sustentável sem custos para o jogador:

1. **Licenciamento Aberto:**
   - Todo o código fonte deste repositório está sob a licença **MIT** (ou GPL compatível), permitindo inspeção, fork e modificação livre.
2. **Zero SDKs de Publicidade:**
   - Nenhum SDK de anúncios (Google AdMob, Unity Ads, AppLovin, etc.) é incluído ou permitido no código.
3. **Zero Telemetria e Zero Contas:**
   - Não utilizamos Firebase Analytics, Facebook SDK, Crashlytics ou rastreadores de terceiros.
   - Não existe tela de login, cadastro ou sincronização em nuvem obrigatória.
4. **Sem Microtransações (Zero IAP):**
   - Não há moedas virtuais, compras dentro do app (*In-App Purchases*), passes de batalha ou bloqueios por paywall.
5. **Armazenamento 100% Local:**
   - Todo o progresso, configurações e estatísticas de vitória/derrota são gravados em arquivos locais do dispositivo (`user://settings.save` ou `SharedPreferences`).

---

## 🎨 Criação e Uso de Recursos Visuais (Assets)

Para manter a licença limpa e evitar riscos de direitos autorais:

- **Artes Autorais ou Vetoriais por Código:** Cartas, tabuleiros e peças devem ser gerados preferencialmente de forma procedural (GDScript / Flutter CustomPainter) ou utilizando vetores SVG abertos.
- **Fontes e Sons Livres:** Uso exclusivo de fontes abertas (como Google Fonts sob licença OFL) e efeitos sonoros sob domínio público (CC0).
- **Sem Ripping:** Nunca extrair ou utilizar imagens, sons ou fontes de outros aplicativos comerciais existentes.

---

## ⚖️ Cuidados Legais com Jogos Tradicionais e Culturais

Ao implementar jogos de cartas e tabuleiro populares no Brasil e no mundo (Truco, Buraco, Canastra, Sueca, Dominó, Banco Imobiliário):

### 1. Regras vs Propriedade Intelectual
- **Regras Tradicionais são de Domínio Público:** As mecânicas de jogos tradicionais (como a contagem de tentos do Truco, a formação de canastras ou o valor das peças de dominó) não são patenteáveis e pertencem ao patrimônio cultural.
- **Identidade e Nomes Comerciais:**
  - Evite copiar marcas registradas de empresas comerciais.
  - Para jogos baseados no conceito de negociação de propriedades (estilo *Monopoly* ou *Banco Imobiliário*), utilize um nome genérico autoral (ex: *Negócios Imobiliários*, *Comércio de Cidades*) e cartas/tabuleiros com nomes de cidades e propriedades fictícias ou genéricas.
  - Não utilize logotipos, mascotes ou slogans associados a marcas de baralhos ou fabricantes de brinquedos.

### 2. Jogos Sem Apostas Reais
- Jogos como Truco e 21 (Blackjack) são implementados estritamente como jogos de estratégia contra IA local, sem apostas em dinheiro real, sem compra de fichas e sem simulação de cassino predatório.

---

## 📲 Estratégias de Distribuição Multiplataforma

### 🤖 Android
- **F-Droid:** Inclusão no catálogo do F-Droid (focado exclusivamente em software livre e de código aberto, sem bibliotecas proprietárias).
- **GitHub Releases:** Publicação de APKs e AABs assinados diretamente nas tags de versão do GitHub via scripts de automação ([`build_apk.sh`](../build_apk.sh)).
- **Google Play Store:** Opcional como aplicativo gratuito sem anúncios.

### 🍎 iOS / macOS
- **Compilação Local:** O Godot exporta o projeto Xcode nativo, que pode ser compilado e executado em qualquer Mac host.
- **App Store:** Caso deseje publicar na App Store da Apple, lembre-se de que é necessária uma conta ativa do *Apple Developer Program*, mesmo para aplicativos 100% gratuitos e de código aberto.
- **TestFlight / AltStore / Sideloading:** Distribuição alternativa viável sem taxas adicionais.
