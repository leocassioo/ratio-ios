# Firestore Rules (owner-only)

Arquivo de regras: `Docs/firestore.rules`

## O que foi aplicado
- Owner pode editar/excluir grupos e membros.
- Owner e membros leem grupos em que estao listados (via `resource.data`).
- Membro pode aceitar convite: cria seu doc em `members` e adiciona seu `userId` em `memberIds`.
- Membros podem atualizar **apenas o status/recibo** do proprio pagamento.
- Convites abertos para leitura/criacao por usuarios autenticados.
- Subscriptions so podem ser lidas/escritas pelo proprio usuario.

## Como publicar
1. Firebase Console -> Firestore Database -> Rules.
2. Cole o conteudo de `Docs/firestore.rules`.
3. Publique.
