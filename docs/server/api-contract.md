# Contrato da API do servidor PlayTable

**Criado em:** 2026-08-31
**Estado:** o servidor não existe; existe o domínio
**Escopo:** regras de base. Cada grupo de endpoint é detalhado pela fase que o consome.

## 1. O que este documento é — e o que não é

- É o conjunto de regras que qualquer endpoint futuro herda, escrito **antes** do servidor existir, para que o cliente Godot possa ser codificado contra ele.
- **Não** é a especificação da API. Não há corpo de requisição nem de resposta aqui, de propósito.
- O servidor `playtable.ricasolucoes.com.br` é mantido **fora deste repositório**. Este arquivo é o único vínculo entre os dois lados.
- A terceira camada é opcional. O app tem de continuar completo sem ela, e é isso que as regras abaixo protegem.

## 2. Endereço, versão e ambiente

- Base: `https://playtable.ricasolucoes.com.br/api/v1`
- Versão no caminho. Mudança que quebra compatibilidade nasce em `/api/v2`; `/api/v1` continua servindo os aparelhos antigos até saírem de circulação. O cliente fixa em build a versão contra a qual foi escrito e nunca "descobre" a versão em tempo de execução.
- Só HTTPS. Chamada em texto claro é erro de configuração, não modo degradado.
- Ambiente: um só endereço de produção. Não há staging previsto; enquanto o servidor não existir, todo cliente roda no caminho de "servidor ausente" descrito na seção 4, que é justamente o modo que precisa ser testado mais.

## 3. Autenticação e identidade

- Não existe conta própria do PlayTable, e não vai existir: seria uma quarta camada de identidade em cima de três.
- Jogador **logado no Play Games**: a identidade é o PGS Player. O cliente pede ao plugin um server auth code, troca por um token de curta duração em `POST /api/v1/auth/pgs`, e manda `Authorization: Bearer <token>` nas chamadas seguintes. O servidor valida o code contra o Google — o cliente nunca é fonte de verdade sobre quem é o jogador.
- Jogador **convidado**: identidade é um id anônimo de instalação, gerado e guardado em `user://`. Não atravessa aparelho, não é recuperável e o contrato não promete que seja. Quem quiser progresso entre aparelhos entra no Play Games — é essa a troca, e ela precisa estar escrita.
- Token expirado é resposta `401` e renovação silenciosa. `401` nunca vira tela de login: cai no caminho da seção 4.

## 4. Servidor ausente é estado normal

- Toda chamada tem timeout curto — 10 a 30 segundos em `HTTPRequest.timeout`, conforme o tamanho do que se espera. `0.0` (sem timeout) é proibido fora de download grande.
- Timeout, erro de conexão, DNS que não resolve e `5xx` são **o mesmo estado**: "sem servidor agora". Isso não é erro para o jogador, não gera diálogo, não gera log vermelho. Vira item de fila local e tenta de novo depois.
- **Não escreva detector de conectividade nem ping ativo.** A informação de "tem servidor?" sai da própria chamada que falhou. Um detector separado seria um sistema paralelo, contra a decisão travada da fase 1, e mentiria de qualquer jeito (rede presente não é servidor presente).
- A fila é a mesma forma que o `core/services/PlayGamesManager.gd:220-277` já usa para o Play Games: persistida em `user://`, com colapso de repetição por tipo de operação, drenada quando a próxima chamada real der certo. O que muda é só o transporte — `HTTPRequest` no lugar de `Engine.get_singleton()`.
- Multiplayer é a exceção honesta: partida em tempo real não vai para fila. Sem servidor, a tela de sala diz que o online está fora e o resto do app segue inteiro. O que não pode acontecer é a ausência do servidor afetar qualquer coisa fora das telas de online.

## 5. Formato de resposta e erro

- Corpo sempre JSON, `Content-Type: application/json; charset=utf-8`.
- Erro traz `{"erro": {"codigo": "<slug estável>", "mensagem": "<texto humano>"}}`. O `codigo` é o que o cliente compara; a `mensagem` é para log, nunca para exibir crua ao jogador.
- O status HTTP carrega a classe: `400` pedido malformado, `401` sem token ou token expirado, `403` autenticado mas sem direito, `404` recurso inexistente, `409` conflito de estado, `429` excesso de chamadas, `5xx` problema do servidor (tratado como ausência, seção 4).

## 6. Idempotência

- Toda chamada que muda estado aceita o cabeçalho `Idempotency-Key` com um UUID gerado pelo cliente e reusado nas retentativas.
- Repetir a mesma chave devolve o mesmo resultado sem aplicar o efeito duas vezes. Sem isso, a fila da seção 4 duplicaria XP em toda reconexão instável — e a fila é obrigatória, então a idempotência também é.

## 7. Grupos de endpoint

| Grupo | Prefixo | Para quê | Fase dona | Estado |
|---|---|---|---|---|
| Autenticação | `/api/v1/auth/*` | trocar o server auth code do PGS por um bearer de curta duração | Fase 3 | a definir |
| Recall | `/api/v1/recall/*` | lado servidor da Recall API (service account, persona por PGS Player) | Fase 3 | a definir |
| Gamificação | `/api/v1/gamification/*` | espelhar perfil, XP, conquistas e missões do `PlayerProfile` | Fase 8 | a definir |
| Salas | `/api/v1/rooms/*` | criar, listar, entrar e sair de sala; convite entre amigos | Fase 7.1 | a definir |
| Partidas | `/api/v1/matches/*` | estado, turno, reconexão e abandono | Fase 7.1 | a definir |
| Integridade | `/api/v1/integrity/*` | verificar o token do Play Integrity, que só pode ser verificado no servidor | Fase 10 | a definir |

Cada fase dona escreve a sua seção neste mesmo arquivo, sem mover as regras de 1 a 6.

## 8. Regras que todo endpoint futuro herda

- Timeout curto e fila — nunca esperar indefinidamente, nunca perder a mutação.
- Idempotência em toda mutação — repetir a mesma chave nunca aplica o efeito duas vezes.
- Identidade vinda do PGS ou de um id anônimo de instalação — nunca de uma conta própria do PlayTable.
- Nunca bloquear jogabilidade — a ausência do servidor não pode impedir uma partida offline.
- Nunca inventar um sistema paralelo ao que já existe no cliente — a fila reaproveita a forma de `PlayGamesManager.gd:220-277`.

## 9. Fora deste repositório

O servidor em si — implementação, deploy, banco de dados, service account da Recall API — fica fora deste repositório. Este repositório versiona o contrato e o cliente que o consome, nada mais.
