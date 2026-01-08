## Push Notifications - Backend (FCM)

### Visao geral
Fluxo:
1) App registra FCM token em `users/{userId}.fcmTokens[]`.
2) Job diario busca assinaturas com vencimento proximo.
3) Envia push via FCM.

---

## Parte 1 - APNs (Apple)

### 1. Criar chave APNs (.p8)
1) Acesse https://developer.apple.com/account
2) Certificates, Identifiers & Profiles
3) Keys -> "+" -> Apple Push Notifications service (APNs)
4) Gere a chave e baixe o arquivo `.p8`
5) Guarde:
   - **Key ID**
   - **Team ID**
   - Arquivo `.p8`

### 2. Gerar certificado APNs (alternativa ao .p8)
Use somente se preferir certificado em vez da chave.

1) Acesse https://developer.apple.com/account
2) Certificates, Identifiers & Profiles -> Certificates
3) Clique em "+"
4) Selecione **Apple Push Notification service SSL (Sandbox & Production)**
5) Selecione o App ID (com Push Notifications habilitado)
6) Gere o CSR:
   - macOS: **Keychain Access** -> Certificate Assistant -> Request a Certificate From a Certificate Authority
   - Use email, marque “Saved to disk”
7) Envie o CSR no portal da Apple e baixe o certificado `.cer`
8) No macOS, abra o `.cer` para instalar no Keychain
9) Exporte o certificado com a chave privada:
   - Keychain Access -> localize o certificado -> Export
   - Salve como `.p12`
10) No Firebase:
    - Project Settings -> Cloud Messaging
    - APNs Certificates -> Upload `.p12`

### 2. Configurar no Firebase
1) Firebase Console -> Project Settings -> Cloud Messaging
2) APNs Authentication Key -> Upload
3) Preencher:
   - Key ID
   - Team ID
   - Upload do `.p8`

---

## Parte 2 - Xcode

### 1. Habilitar capabilities
No target do app:
1) Signing & Capabilities
2) + Capability -> **Push Notifications**
3) + Capability -> **Background Modes**
   - Marcar: **Remote notifications**

### 2. Permissao no app
- O app precisa pedir permissao ao usuario.
- Ja implementamos isso no app (`NotificationManager.shared.configure()`).

### 3. Info.plist
- Para **push** nao e necessario adicionar chaves no Info.plist.
- Para **notificacoes locais**, o sistema nao exige chave de uso.
### 2. Entitlements
O Xcode adiciona automaticamente:
- `aps-environment`

---

## Parte 3 - Firebase Admin + Cloud Functions

### 1. Instalar Firebase CLI
```
npm i -g firebase-tools
firebase login
firebase init functions
```
Escolher:
- Functions (Node.js 18+)
- Firestore (opcional)

### 2. Dependencias
Dentro de `functions/`:
```
npm i firebase-admin firebase-functions
```

### 3. Função de envio (exemplo)
Crie `functions/src/notifications.ts`:
```
import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();

export const sendBillingReminders = functions.pubsub
  .schedule("every day 09:00")
  .timeZone("America/Sao_Paulo")
  .onRun(async () => {
    const db = admin.firestore();
    const today = new Date();
    const inTwoDays = new Date(today.getTime() + 2 * 24 * 60 * 60 * 1000);

    const users = await db.collection("users").get();
    for (const userDoc of users.docs) {
      const tokens = userDoc.data().fcmTokens || [];
      if (tokens.length === 0) continue;

      const subs = await db
        .collection("users")
        .doc(userDoc.id)
        .collection("subscriptions")
        .where("nextBillingDate", "<=", admin.firestore.Timestamp.fromDate(inTwoDays))
        .get();

      for (const sub of subs.docs) {
        const data = sub.data();
        const name = data.name || "Assinatura";
        const message = {
          notification: {
            title: "Cobrança em breve",
            body: `Sua assinatura de ${name} vence em breve.`
          },
          tokens
        };
        await admin.messaging().sendEachForMulticast(message);
      }
    }

    return null;
  });
```

### 4. Export no index
No `functions/src/index.ts`:
```
export { sendBillingReminders } from "./notifications";
```

### 5. Deploy
```
firebase deploy --only functions
```

---

## Parte 4 - Consideracoes
- Use `nextBillingDate` real (Timestamp).
- Evite enviar multiplos pushes para o mesmo usuario no mesmo dia.
- Opcional: gravar `lastNotificationAt` para controle.

---

## Verificacao rapida
1) Crie uma assinatura com `nextBillingDate` para hoje/amanha.
2) Execute a funcao manualmente:
```
firebase functions:shell
sendBillingReminders()
```

3) Verifique o push no device.
