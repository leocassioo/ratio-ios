# Ratio - Plano de Produto e Desenvolvimento

## Visao Geral
Ratio e um app iOS nativo para gestao de assinaturas recorrentes e divisao de custos
com grupos (familia, republica, amigos). O diferencial e o foco em recorrencia,
pagamentos e cobrancas entre participantes.

Referencias:
- Splitwise (divisao de contas)
- Rocket Money / Truebill (gastos recorrentes)
- Kotas / Spliiit (assinaturas compartilhadas)

## Objetivos
- Centralizar assinaturas e vencimentos.
- Automatizar o rateio e o acompanhamento de pagamentos.
- Entregar experiencia nativa, simples e clara no iOS.

## MVP (Fase 1)
### Autenticacao
- Login com Apple.
- Login com email/senha.
- Onboarding simples (nome, foto opcional, moeda padrao).

### Home / Dashboard
- Lista de assinaturas ativas.
- Total mensal estimado.
- Proximos vencimentos (timeline).
- Atalhos: adicionar assinatura, criar grupo.

### Assinaturas (CRUD)
- Nome, valor, data de cobranca, categoria, logo/icone.
- Periodicidade: semanal, mensal, trimestral, anual.
- Suporte a moedas (BRL, USD) - opcional no MVP.

### Grupos e Compartilhamento (core)
- Criar grupo.
- Convidar por email ou link.
- Vincular assinatura ao grupo.
- Definir pagador principal.
- Divisao igualitaria ou personalizada.

### Cobranca e Status
- Cada membro cadastra forma de recebimento (Pix/link).
- Participante marca como pago e anexa comprovante (foto).
- Pagador valida comprovante e encerra cobranca.

### Notificacoes
- Lembrete de vencimento para o titular.
- Lembrete de pagar ao amigo para participantes.

## Fase 2 (V1.0 e Diferenciais)
- Analytics: gastos por categoria e por grupo.
- Acompanhamento de inflacao dos valores (historico de reajustes).
- Templates de assinatura (Netflix, Spotify etc).
- Widgets (proximos vencimentos).
- Modo economico: sugestoes de cortes.

## Fase 3 (Avancado)
- Integracao bancaria (Open Finance).
- Marketplace de assinaturas compartilhadas.
- Regras automaticas de cobranca (ex.: cobrar 3 dias antes).

## UX e Design System
- 100% SwiftUI.
- HIG Apple, acessibilidade e Dynamic Type.
- Suporte a Light/Dark.
- i18n preparado desde o inicio (com String Catalogs).
- Layout responsivo para iPhone e iPad.

## Arquitetura Tecnica
- Swift 5+, SwiftUI.
- MVVM por feature.
- Firebase: Auth, Firestore, Storage, Messaging.
- Firestore para dados em tempo real.

## Estrutura de Projeto (padrao ThinkList)
- Features/App/Domain
- Features/App/Presentation/Views
- Features/Home/Presentation/Views
- Features/Groups/Presentation/Views
- Features/Settings/Presentation/Views

## Modelo de Dados (sugestao inicial)
### User
- id, nome, email, fotoURL
- moedaPadrao, idioma, tema
- formasDePagamento (pixKey, paymentLink)

### Subscription
- id, nome, valor, moeda, categoria, logoURL
- periodicidade, diaCobranca, status
- ownerId (quem paga)
- groupId (opcional)

### Group
- id, nome, membros[]
- ownerId

### Split
- subscriptionId
- participantes[] { userId, porcentagem, valor }
- statusCobranca[] { userId, status, comprovanteURL }

## Plano de Trabalho (alto nivel)
### Etapa 0 - Fundacao
- Ajustar estrutura do projeto (feito).
- Criar tab bar e ajustes (feito).
- Definir temas e idioma base (feito).

### Etapa 1 - Autenticacao e Base
- Tela de login (Apple + Email).
- Estrutura de usuario no Firestore.
- Onboarding simples.

### Etapa 2 - Assinaturas
- CRUD de assinaturas.
- Lista e detalhes.
- Periodicidade e proximo vencimento.

### Etapa 3 - Grupos e Rateio
- Criar/entrar em grupos.
- Vincular assinatura ao grupo.
- Rateio igualitario/personalizado.

### Etapa 4 - Cobranca
- Registro de pagamento.
- Upload de comprovante.
- Validacao pelo pagador.

### Etapa 5 - Notificacoes
- Push para vencimento e cobranca.

## Backlog de Ideias
- Categorias customizaveis.
- Busca e filtros.
- Historico de pagamentos.
- Exportacao CSV.
- Integração com calendario.
- Status de inadimplencia por membro.
