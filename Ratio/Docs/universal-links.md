# Universal Links (Ratio)

Bundle ID: com.redpixel.Ratio
Dominio: https://uaipixel.com

## 1) apple-app-site-association (AASA)
Arquivo: `apple-app-site-association`
Sem extensao e com content-type `application/json`.

Use o conteudo do arquivo:
`Ratio/Docs/apple-app-site-association.json`

Observacoes importantes:
- O hash `#/apps/ratio` nao e enviado ao servidor. Para Universal Links, use caminhos reais como `/apps/ratio`.
- Mantenha `/invite` e `/invite/*` para convites.

Deploy:
- Publicar em `https://uaipixel.com/.well-known/apple-app-site-association`
- Opcional: tambem em `https://uaipixel.com/apple-app-site-association`

## 2) Associated Domains no Xcode
No target do app:
Signing & Capabilities -> Associated Domains
Adicionar:
`applinks:uaipixel.com`

## 3) Link de convite
Formato:
`https://uaipixel.com/invite?token=TOKEN_AQUI`

## 4) Tratamento no app (SwiftUI)
Adicionar handler para abrir o token:

```
.onOpenURL { url in
    // parse token do query param
}
```

Se quiser, eu implemento o handler e a tela de aceitar convite.
