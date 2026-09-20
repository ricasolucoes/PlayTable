# Publicação iOS do PlayTable

O projeto da Apple está associado exclusivamente à equipe **Sierra Tecnologia
LTDA**, Team ID `28X7P94SF5`. O App ID é `org.playtable.app` e o registro
criado no App Store Connect é o app `PlayTable` (ID `6814064617`). Este
repositório continua em `github.com/ricasolucoes/PlayTable`; não há relação
com a organização Banlek.

## O que o workflow faz

`.github/workflows/release-appstore.yml` roda em um runner macOS, baixa a
versão do Godot registrada em `.godot-version`, instala o template iOS, roda a
suíte Python/GUT, exporta o projeto Xcode, importa temporariamente o
certificado e o provisioning profile, gera um IPA assinado e publica via
Fastlane.

- `ios-v1.0` publica no TestFlight.
- `workflow_dispatch` permite escolher `testflight` ou `appstore`.
- `appstore` usa o ambiente protegido `appstore-production`.
- A opção `submit_for_review` só deve ser ligada depois que metadados,
  classificação etária, privacidade, export compliance e status de comerciante
  estiverem preenchidos no App Store Connect.

## Secrets do GitHub

Configure os secrets no repositório `ricasolucoes/PlayTable` — nunca versiona
arquivos `.p12`, `.mobileprovision`, `.p8` ou senhas:

| Secret | Conteúdo |
| --- | --- |
| `IOS_CERTIFICATE_BASE64` | certificado Apple Distribution em `.p12`, codificado em Base64 |
| `IOS_CERTIFICATE_PASSWORD` | senha do `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | provisioning profile App Store para `org.playtable.app`, em Base64 |
| `APPSTORE_CONNECT_API_KEY_ID` | Key ID da chave da API do App Store Connect |
| `APPSTORE_CONNECT_ISSUER_ID` | Issuer ID da equipe Sierra Tecnologia LTDA |
| `APPSTORE_CONNECT_API_PRIVATE_KEY_BASE64` | arquivo `.p8` da mesma chave, em Base64 |

Exemplos locais para produzir Base64, sem copiar o arquivo para o Git:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
base64 -i PlayTable_Distribution.p12 | tr -d '\n'
base64 -i PlayTable_AppStore.mobileprovision | tr -d '\n'
```

O provisioning profile precisa ser de distribuição para a App Store, ter
`application-identifier` igual a `28X7P94SF5.org.playtable.app` e
`get-task-allow=false`. O workflow valida esses pontos antes de assinar.

## Pendências de App Store Connect

O registro e o App ID já existem, mas a primeira versão ainda precisa dos
dados exigidos pela Apple: descrição, palavras-chave, URL de suporte, URL da
política de privacidade, screenshots iPhone/iPad, classificação etária,
questionário de privacidade, export compliance e status de comerciante da UE.
O texto de privacidade do projeto está em `docs/privacy.html`; ele precisa
estar publicado em uma URL HTTPS acessível pela Apple antes do envio para
revisão.
