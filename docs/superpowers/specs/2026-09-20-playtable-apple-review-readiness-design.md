# PlayTable — prontidão para a revisão da Apple

## Contexto

O retorno da Apple é principalmente uma solicitação de informação, mas ele
também expõe riscos de submissão: não há notas detalhadas, as capturas de loja
foram copiadas entre idiomas e o build precisa declarar o uso da rede local.
O código do cliente já possui dois transportes multiplayer: LAN e relay pela
internet.

Durante o diagnóstico, o endpoint público de salas
`https://games.ricasolucoes.com.br/api/v1/rooms?game=jogo_da_velha` respondeu
HTTP 200 com JSON válido. Portanto, o relay permanece no produto e deve ser
descrito como serviço externo opcional; não será removido nem escondido.

## Decisões

1. **Notas do App Review** — a fonte única será
   `fastlane/metadata/review_information/notes.txt`, em inglês, com as seis
   respostas pedidas pela Apple e as respostas preventivas sobre conta, UGC,
   compras e modelo de negócio. O Fastfile lerá esse arquivo, eliminando a
   divergência entre o texto versionado e o texto enviado.
2. **Serviços e privacidade** — a documentação distinguirá o núcleo local, a
   rede local entre aparelhos e o RicaGames (HTTP para salas e WebSocket para
   partidas online). O PGS continua exclusivo do Android; a build iOS não
   exige conta nem credenciais.
3. **Rede local no iOS** — o preset declarará
   `NSLocalNetworkUsageDescription`. O script de exportação validará a chave no
   Info.plist gerado antes de produzir o projeto Xcode.
4. **Screenshots** — cada idioma terá três fontes PNG reais de 720×1280,
   capturadas a partir do próprio Godot (`MainMenu`, Damas e Batalha Naval).
   O script de preparação usará a fonte do locale correspondente e falhará se
   uma fonte for idêntica à portuguesa. O redimensionamento para iPhone/iPad
   preserva o conteúdo da captura e não desenha uma tela fictícia.
5. **QA físico** — o repositório terá um roteiro reproduzível para instalar a
   mesma build em iPhone/iPad físicos, iniciar a gravação desde o ícone e
   percorrer o fluxo principal, incluindo multiplayer quando houver dois
   aparelhos. O workflow não permitirá submissão automática sem uma referência
   de gravação física fornecida pelo responsável da conta.

## Fora do escopo do repositório

O repositório não pode criar a gravação em um iPhone que não está conectado,
nem anexar mídia ou responder manualmente no App Store Connect. Esses dois
 passos continuam sendo gates humanos documentados no checklist.

## Verificação

- testes Python de configuração do release;
- suíte GUT completa;
- exportação iOS e inspeção do `Info.plist`;
- script de screenshots com dimensões, fontes por locale e hashes;
- verificação manual em dispositivos físicos e anexo da gravação antes de
  `submit_for_review=true`.
