## Push Notifications (cobranca)

### Passos no Firebase
1. Ativar APNs no Firebase Console (Project Settings -> Cloud Messaging).
2. Enviar a chave APNs (.p8) ou certificado.

### Passos no Xcode
1. Signing & Capabilities -> Push Notifications.
2. Background Modes -> Remote notifications.

### Como o app registra o token
- Ao abrir, pede permissao e registra o FCM token em `users/{userId}.fcmTokens[]`.

### Backend (exemplo de logica)
Agendar um job diario (Cloud Functions/cron):
- Buscar assinaturas com `nextBillingDate` <= hoje + N dias.
- Para cada usuario, ler `fcmTokens`.
- Enviar push via FCM.

Payload sugerido:
```
{
  "title": "Cobranca em breve",
  "body": "Sua assinatura de Netflix vence em 2 dias."
}
```
