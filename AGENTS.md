# PlayTable — instruções para agentes

As instruções compartilhadas de `../AGENTS.md`, `../CLAUDE.md` e `~/.codex/AGENTS.md` valem integralmente para este projeto.

## Uso restrito de APIs / Modelos GPT (OpenAI)

- As APIs do GPT (OpenAI) devem ser usadas **exclusivamente** para:
  1. **Geração de imagens** (chamadas/scripts diretos como DALL-E / Image Generation, sem instanciar subagentes ou loops analíticos de chat).
  2. **Tradução de idiomas e localização**.
- É **terminantemente proibido** usar APIs ou chamadas do GPT para raciocínio, análise de código, planejamento de tarefas, testes ou orquestração geral. Toda análise e raciocínio são de responsabilidade do próprio ambiente de trabalho/modelo primário.
