# Firestore Rules (owner-only)

Arquivo de regras: `Docs/firestore.rules`

## O que foi aplicado
- Apenas o **owner** pode editar/excluir grupos e membros.
- Membros apenas leem grupos em que estao listados.
- Convites abertos para leitura/criacao por usuarios autenticados.
- Subscriptions so podem ser lidas/escritas pelo proprio usuario.

## Como publicar
1. Firebase Console -> Firestore Database -> Rules.
2. Cole o conteudo de `Docs/firestore.rules`.
3. Publique.
