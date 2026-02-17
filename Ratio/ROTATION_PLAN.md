# Plano - Rodizio de Pagamento em Grupos

## Objetivo
Permitir que grupos usem rodizio de pagamento: a cada ciclo, apenas 1 membro paga o valor total. A ordem e editavel. O admin continua sempre como pago, pois usa o cartao dele.

## Regras definidas
- Ordem do rodizio: editavel (drag & drop).
- Entrada e saida de membros: mesmo fluxo atual do grupo.
- Avanco do rodizio:
  - automatico na proxima cobranca, ou
  - quando o pagador do ciclo for marcado como pago.
- Status dos demais membros no ciclo: `isento`.
- Atrasos seguem a mesma logica atual (apenas pagador do ciclo pode ficar pendente/atrasado).

## Plano de implementacao (passos pequenos)

1. **Modelo de dados**
   - Adicionar campos no grupo:
     - `paymentMode`: `split` | `rotation`
     - `rotationOrder`: [userId]
     - `rotationIndex`: Int
     - `rotationCycleStartDate`: Timestamp
     - `currentPayerId`: String (derivado ou persistido)
   - Adicionar status `exempt` no `GroupMemberStatus`.

2. **Criacao/edicao de grupo**
   - Novo campo "Modo de cobranca" (Divisao / Rodizio).
   - UI para ordenar membros (drag & drop) quando for rodizio.

3. **Logica de cobranca**
   - Se `rotation`:
     - definir o pagador atual
     - marcar demais como `exempt`
     - admin sempre `paid`
   - Se marcar pagador como pago antes da data, avancar o rodizio.

4. **Notificacoes**
   - Notificar apenas o pagador do ciclo.
   - Admin recebe alertas se pagador atrasar (mesma regra atual).

5. **UI do grupo**
   - Mostrar "Pagador do mes".
   - Exibir status `Isento` nos demais.
   - Ajustar historico para mostrar quem pagou em cada ciclo.

6. **Migracao**
   - Grupos antigos continuam em `split`.
   - Sem migracao obrigatoria.

7. **Analytics**
   - `rotation_enabled`
   - `rotation_payer_notified`
   - `rotation_advance`

8. **QA / testes**
   - Criar grupo com rodizio
   - Editar ordem
   - Membro entra/sai
   - Pagador atrasa
   - Pagador paga antes (avance antecipado)

---

Observacao: este plano depende do status `exempt` ser exibido corretamente em UI e mantido nos calculos de atraso.
