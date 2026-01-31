# Ratio - Mapa de Coleta (GA4 / Firebase)

Este documento define eventos, parâmetros e propriedades de usuário para rastrear o uso do app no GA4 via Firebase.

## 1) Aquisição / Primeira sessão
- `first_open` (automático)
- `app_open` (automático)
- `onboarding_view` (params: `step_index`)
- `onboarding_complete`
- `push_permission_view`
- `push_permission_result` (params: `status` = granted/denied)
- `deeplink_open` (params: `source`, `route`)
- `tab_select` (params: `tab` = home/subscriptions/groups/advisor/settings)

## 2) Autenticação
- `auth_login_start` (params: `method` = email/apple/google)
- `auth_login_success` (params: `method`)
- `auth_login_error` (params: `method`, `reason`)
- `auth_signup_start` (params: `method` = email/apple/google)
- `auth_signup_success` (params: `method`)
- `auth_signup_error` (params: `method`, `reason`)
- `auth_password_reset_start`
- `auth_password_reset_success`
- `auth_password_reset_error` (params: `reason`)
- `auth_logout`

## 3) Assinaturas (Core)
- `subscription_create` (params: `subscription_id`, `category`, `period`, `currency`, `source` = manual)
- `subscription_edit` (params: `subscription_id`, `category`, `period`, `currency`)
- `subscription_delete` (params: `subscription_id`)
- `subscription_view` (params: `subscription_id`)

## 4) Grupos (Compartilhamento)
- `group_create` (params: `group_id`, `category`, `period`, `currency`, `source` = from_subscription/manual)
- `group_edit` (params: `group_id`)
- `group_view` (params: `group_id`)
- `group_delete` (params: `group_id`)
- `group_leave` (params: `group_id`, `role`)

## 5) Convites
- `invite_create` (params: `group_id`, `max_uses`, `expires_in_hours`)
- `invite_share` (params: `group_id`, `channel` = link/system_share)
- `invite_open` (params: `token`)
- `invite_accept_success` (params: `group_id`)
- `invite_accept_error` (params: `reason`)
- `invite_redeem_manual` (params: `token_valid`)

## 6) Pagamentos / Comprovantes
- `payment_submit` (params: `group_id`, `member_id`, `has_receipt`)
- `payment_submit_success` (params: `group_id`, `member_id`, `has_receipt`)
- `payment_submit_error` (params: `reason`)
- `payment_approve` (params: `group_id`, `member_id`)
- `payment_reject` (params: `group_id`, `member_id`)
- `payment_sheet_open` (params: `group_id`)
- `receipt_view` (params: `group_id`, `member_id`)
- `receipt_history_open` (params: `group_id`, `member_id`)
- `receipt_share` (params: `group_id`, `member_id`)
- `receipt_save_photos` (params: `group_id`, `member_id`, `result`)
- `share_extension_open`
- `share_extension_submit` (params: `group_id`, `result`)
- `share_extension_error` (params: `reason`)
- `share_extension_cancel`

## 7) Notificações / Push
- `notification_received` (params: `type` = billing/overdue/payment_submitted/payment_status)
- `notification_open` (params: `type`, `route`)
- `notification_history_open`
- `notification_mark_read`

## 8) Home / Dashboard
- `home_open`
- `home_total_monthly_tap`
- `home_insight_tap` (params: `insight_type`)
- `home_upcoming_payment_tap` (params: `item_type` = subscription/group)
- `home_chart_category_tap` (params: `category`)
- `home_chart_monthly_tap` (params: `month_index`)
- `home_empty_state_view`

## 9) Advisor (IA)
- `advisor_open`
- `advisor_cta_tap`
- `advisor_generate` (params: `model`, `reasoning_effort`)
- `advisor_generate_success` (params: `tokens`)
- `advisor_generate_error` (params: `reason`)
- `advisor_refresh`
- `pro_feature_blocked` (params: `feature` = advisor/charts/etc)

## 10) Histórico
- `history_open`
- `history_month_view` (params: `month`)
- `history_item_view` (params: `source` = subscription/group)

## 11) Configurações
- `settings_open`
- `settings_profile_open`
- `settings_profile_edit`
- `settings_change_email_open`
- `settings_change_email_success`
- `settings_currency_change` (params: `currency`)
- `settings_delete_account_start`
- `settings_delete_account_success`
- `settings_delete_account_error` (params: `reason`)
- `settings_whats_new_open`
- `settings_help_open` (params: `source` = tutorial/faq)

## 12) Monetização / Pro
- `paywall_open` (params: `source`)
- `paywall_cta_tap` (params: `plan`)
- `subscription_start` (params: `plan`, `price`)
- `subscription_success`
- `restore_tap`
- `restore_success`

## 13) Propriedades de Usuário (User Properties)
**Observação:** não coletar dados pessoais (PII). Sem e-mail, nome, Apple ID ou identificadores do iCloud.

**Perfil do app**
- `app_language` (pt-BR, en, es, etc.)
- `theme` (light/dark/system)
- `is_pro` (true/false)
- `primary_currency` (BRL/USD/EUR)

**Uso**
- `subscriptions_count` (0, 1, 2, 3+)
- `groups_count` (0, 1, 2, 3+)
- `uses_advisor` (true/false)
- `uses_share_extension` (true/false)

**Plataforma**
- `platform` (ios / mac_catalyst)
- `locale_region` (BR, US, etc.)

## Convenções
- Nome em `snake_case`.
- Parâmetros curtos e consistentes.
- Não enviar dados pessoais.

## 14) Screen Views (todas telas e sheets)
**Onboarding / Permissões**
- `screen_onboarding`
- `screen_onboarding_ai`
- `screen_onboarding_tutorial`
- `screen_push_permission`

**Autenticação**
- `screen_login`
- `screen_signup`
- `screen_password_reset`

**Home**
- `screen_home`
- `screen_home_empty`
- `screen_home_insight_detail` (sheet)

**Assinaturas**
- `screen_subscriptions`
- `screen_subscriptions_empty`
- `screen_create_subscription` (sheet)
- `screen_edit_subscription` (sheet)

**Grupos**
- `screen_groups`
- `screen_groups_empty`
- `screen_create_group` (sheet)
- `screen_edit_group` (sheet)
- `screen_group_detail` (sheet)
- `screen_payment_submit` (sheet)
- `screen_receipt_history` (sheet)
- `screen_receipt_preview`
- `screen_invite_accept`
- `screen_invite_redeem`

**Notificações**
- `screen_notifications_history`

**Advisor**
- `screen_advisor`

**Configurações / Conta**
- `screen_settings`
- `screen_profile`
- `screen_change_email`
- `screen_delete_account`
- `screen_billing_history`

**Monetização / Pro**
- `screen_paywall` (upgrade prompt)
- `screen_subscription_benefits`
- `screen_subscription_success`

**WhatsNew**
- `screen_whats_new`

**Share Extension**
- `screen_share_extension`

## 15) Caminhos principais (journeys)
- `onboarding → push_permission → login → home`
- `home → create_subscription → subscription_success`
- `home → groups → group_detail → payment_submit → receipt_history → receipt_preview`
- `groups → create_group → invite_create → invite_share`
- `settings → profile → change_email`
- `settings → delete_account`
- `notifications_history → notification_open → group_detail`
