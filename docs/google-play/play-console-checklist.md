# Google Play Console — o que falta para o Play Games ligar

O código está pronto e vai no APK. O que falta são os **identificadores**, que
só a conta do Play Console gera, e a configuração do lado do Google. Enquanto
os ids estiverem vazios em `core/configs/play_games_ids.json`, o
`PlayGamesManager` não envia nada — de propósito, porque id inventado é
recusado em silêncio pelo servidor e daria a impressão de que a integração
funciona.

Conferir a qualquer momento:

```sh
android/pgs/install.sh --check        # lado Android: plugin, manifesto, permissão
python3 tools/gen_achievement_matrix.py   # quantas conquistas ainda sem id
```

E, de dentro do jogo, `PlayGamesManager.diagnostics()` responde em uma linha:
plugin presente, login, quantos ids mapeados, quantos envios na fila offline.

## Já feito no repositório

- [x] **Plugin Android** — `android/pgs/java/.../PlayTablePGS.java`, contra o PGS v2
- [x] **`APP_ID` no manifesto** — sem essa meta-data o SDK lança exceção na primeira chamada
- [x] **Permissão de internet** — o AAB de release saía sem permissão de rede nenhuma
- [x] **Dependência do SDK** — pela propriedade oficial `-Pplugins_remote_binaries`
- [x] **55 conquistas** definidas em `core/configs/achievements.json`
- [x] **9 placares e 5 eventos** definidos em `core/configs/play_games_ids.json`
- [x] **Saved Games** com merge no conflito
- [x] **Fila offline** persistida, para o que foi feito sem rede chegar depois

## Pendente no Console (manual)

- [ ] **Projeto do Play Games criado** e vinculado a `org.playtable.app`
- [ ] **ID do projeto** copiado para `app_id` em `core/configs/play_games_ids.json`
- [ ] **OAuth 2.0 Client IDs** de debug **e de release**, com o SHA-1 de cada keystore
      — sem o de release o app assinado nunca autentica, e o erro não é claro
- [ ] **55 conquistas criadas**, com os ids `CgkI...` colados no mapa
      (a matriz em `achievement-matrix.md` traz nome, descrição, tipo e XP de cada uma)
- [ ] **Conquistas publicadas** depois do teste
- [ ] **9 placares criados** — atenção à ordenação: quatro são *menor é melhor*
      (tempo do Campo Minado, jogadas da Memória e da Torre, peças do Resta Um).
      O jogo já manda o valor no formato certo; o placar precisa estar configurado assim
- [ ] **5 eventos criados** e publicados
- [ ] **Contas de teste** adicionadas na aba de testes do PGS — antes de publicar, só elas autenticam
- [ ] **Sidekick habilitado** nas Configurações Avançadas de Teste do App Bundle
- [ ] **Trilha interna** com o AAB, para validar login e conquista em aparelho real
- [ ] **Trilha fechada** com testadores externos
- [ ] **Play Points / Play Pass** avaliados (o app não tem anúncio nem compra, o que ajuda no Play Pass)
- [ ] **Level Up** — formulário final, depois de conquistas e placares publicados

## Ordem que funciona

1. Projeto do PGS + `app_id` → `install.sh` → build → o app já autentica.
2. Conquistas no Console → ids no mapa → as conquistas começam a chegar.
3. Placares e eventos → o resto do painel enche.

Não adianta inverter: sem `app_id` o SDK nem inicializa, e sem login nada é
enviado (fica na fila, e sobe quando o login resolver).
