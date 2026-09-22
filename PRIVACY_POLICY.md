# Política de Privacidade — PlayTable

**Última atualização:** 24 de agosto de 2026  
**Desenvolvedor / Organização:** [Rica Soluções](https://github.com/ricasolucoes)  
**Repositório:** [https://github.com/ricasolucoes/PlayTable](https://github.com/ricasolucoes/PlayTable)

---

## 1. Visão Geral e Princípios Fundamentais

O **PlayTable** é um aplicativo de jogos de tabuleiro e cartas tradicional, gratuito, de código aberto (*open source*, sob licença MIT) e desenvolvido com a filosofia **Offline First** e **Privacidade por Padrão** (*Privacy by Design*).

Nossos compromissos fundamentais:
* **Zero Anúncios:** Não exibimos nenhum tipo de publicidade (banners, vídeos recompensados ou intersticiais).
* **Zero Rastreamento / ID de Publicidade:** O aplicativo **não coleta e não utiliza o ID de Publicidade do Google (Advertising ID / AD_ID)** nem qualquer outro identificador para fins de rastreamento ou marketing.
* **Sem Cadastro Obrigatório:** Não solicitamos nome, e-mail, telefone ou documentos pessoais.
* **Armazenamento 100% Local:** O histórico de partidas, pontuações, temas e configurações de áudio são armazenados exclusivamente na memória local do seu próprio dispositivo.

---

## 2. Dados Coletados e Finalidade

### 2.1 Dados Pessoais
O PlayTable **NÃO** coleta, armazena, transmite ou compartilha nenhum dado de identificação pessoal com os desenvolvedores ou terceiros.

### 2.2 Dados de Jogo e Preferências (Armazenamento Local)
As seguintes informações são salvas unicamente de forma local no seu aparelho (`user://config.save`):
* Preferências de volume e efeitos sonoros;
* Seleção de idioma da interface;
* Estatísticas locais de vitórias, derrotas e recordes nos 22 jogos.

Esses dados nunca saem do seu aparelho, a menos que você utilize ferramentas externas de backup do próprio sistema operacional Android.

---

## 3. Serviços Opcionais de Terceiros

### 3.1 Google Play Games (somente Android)

Os builds Android podem integrar opcionalmente o **Google Play Games Services
(PGS v2)**, fornecido pela Google LLC:
* **Finalidade:** permitir conquistas, placares e sincronização opcional do progresso.
* **Tratamento de dados:** dados vinculados à conta Play Games são tratados pela
  infraestrutura da Google conforme a [Política de Privacidade da Google](https://policies.google.com/privacy).
* **Uso offline:** o PlayTable funciona sem conexão e sem login. O build iOS
  submetido à Apple não usa PGS e não exige Game Center ou outra conta.

### 3.2 Multiplayer opcional do PlayTable

O modo local usa a rede Wi-Fi entre dois aparelhos e não envia dados a um
serviço externo. Os três jogos de rede também podem usar opcionalmente o
RicaGames (`https://games.ricasolucoes.com.br/api/v1`) para criar/entrar em uma
sala temporária e o WebSocket retornado para retransmitir jogadas. O serviço
recebe apenas o código da sala e os dados técnicos necessários à partida; não há
conta PlayTable, publicidade, perfil social ou conteúdo publicado pelo jogador.
O modo solo e o multiplayer local continuam funcionando quando esse serviço
está indisponível.

---

## 4. Privacidade de Crianças (COPPA e Política para Famílias da Google Play)

O PlayTable é adequado para todas as faixas etárias, incluindo crianças e famílias:
* Não coletamos dados de crianças;
* Não há compras no app (*In-App Purchases*);
* Não há anúncios direcionados ou comportamentais;
* Não há bate-papo aberto, fóruns ou interação social direta que exponha menores de idade.

---

## 5. Permissões Solicitadas

O PlayTable requer apenas as permissões estritamente necessárias para a execução do motor gráfico (Godot Engine) no Android. Não solicitamos permissões invasivas como:
* ❌ Localização (GPS);
* ❌ Câmera ou Microfone;
* ❌ Contatos, Agenda ou SMS;
* ❌ ID de Publicidade (`AD_ID` explicitamente desativado).

---

## 6. Alterações nesta Política de Privacidade

Podemos atualizar esta Política de Privacidade periodicamente para refletir melhorias no aplicativo ou novos requisitos legais/plataformas. A versão mais recente estará sempre disponível publicamente neste repositório.

---

## 7. Contato e Dúvidas

Em caso de dúvidas, sugestões ou solicitações relacionadas a esta Política de Privacidade ou ao aplicativo PlayTable, entre em contato através dos nossos canais oficiais:

* **GitHub:** [https://github.com/ricasolucoes/PlayTable/issues](https://github.com/ricasolucoes/PlayTable/issues)
* **Organização:** [https://github.com/ricasolucoes](https://github.com/ricasolucoes)

---

# Privacy Policy — PlayTable (English Version)

**Last updated:** August 24, 2026  
**Developer / Organization:** [Rica Soluções](https://github.com/ricasolucoes)  
**Repository:** [https://github.com/ricasolucoes/PlayTable](https://github.com/ricasolucoes/PlayTable)

### 1. Core Principles
PlayTable is a free, open-source (MIT licensed), offline-first board and card games collection designed with strict Privacy by Design principles.
* **No Ads:** Zero third-party advertisements.
* **No Advertising ID:** We do not collect, request, or use Google's Advertising ID (`AD_ID`).
* **No Personal Data Collection:** We do not require accounts, logins, emails, or personal identification.
* **Local Storage Only:** Game settings, audio volumes, and gameplay records are stored strictly on your local device.

### 2. Third-Party Services
Android builds may optionally integrate with **Google Play Games Services (PGS v2)** for achievements, leaderboards, and cloud progress, governed by [Google's Privacy Policy](https://policies.google.com/privacy). The iOS build does not require Game Center or any account. The optional PlayTable multiplayer relay uses the RicaGames service at `https://games.ricasolucoes.com.br/api/v1` only for temporary room setup and live match relay. The game remains fully functional offline without signing in.

### 3. Children's Privacy (COPPA)
PlayTable does not knowingly collect any personal data from children under 13 (or applicable age in your jurisdiction). It is family-safe, ad-free, and contains no in-app purchases.

### 4. Contact
For any questions regarding this policy, please open an issue at [https://github.com/ricasolucoes/PlayTable/issues](https://github.com/ricasolucoes/PlayTable/issues).
