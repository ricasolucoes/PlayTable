# PlayTable — regras do projeto

As instruções compartilhadas de `../CLAUDE.md` e `~/.claude/CLAUDE.md` valem integralmente para este projeto.

## Uso restrito de APIs / Modelos GPT (OpenAI)

- As APIs do GPT (OpenAI) devem ser usadas **exclusivamente** para:
  1. **Geração de imagens** (chamadas diretas via scripts como `tools/gen_art.py` ou endpoints dedicados, sem abrir subagentes analíticos ou loops de chat).
  2. **Tradução de idiomas e localização**.
- É **terminantemente proibido** usar APIs ou chamadas do GPT para raciocínio, análise de código, planejamento de tarefas, testes ou orquestração geral. Toda análise e raciocínio são de responsabilidade do próprio ambiente de trabalho/modelo primário.
