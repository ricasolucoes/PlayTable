# Estratégia de Rollout e Publicação

A Gamificação Avançada insere um grande delta de alterações comportamentais no PlayTable. 
Não devemos lançar isso diretamente em 100% da base de produção.

## 1. Trilha de Testes Fechados (Closed Beta)
- Fazer upload do AAB gerado por `./build_aab.sh` no canal **Closed Testing**.
- Liberar para testers autorizados via lista de e-mail.
- **Objetivo**: Garantir que o CloudSaveSync está fazendo parse adequado de saves antigos para a nova versão.

## 2. Staged Rollout (Produção Gradual)
- Após 7 dias de monitoramento de ANRs/Crashes no Play Console.
- Promover para Produção em lotes:
  - **10%**: Monitorar taxas de reclamações e falhas na autenticação.
  - **50%**: Validar se a distribuição das missões (Quests) e Maestria está balanceada.
  - **100%**: Live completo.

## 3. Fallback Plan (Rollback)
- Se a integração do Plugin do Play Games apresentar crashes sistêmicos em Androids de marcas específicas:
- Utilizaremos o arquivo `liveops_config.json` via patch secundário (ou servidor, quando aplicável) setando `"google_play_sidekick": false` para desligar as chamadas JNI.
- Como o `PlayerProfile.gd` e a `AchievementEngine.gd` funcionam perfeitamente offline, os jogadores não perderão progresso e as UI locais assumirão o feedback.
