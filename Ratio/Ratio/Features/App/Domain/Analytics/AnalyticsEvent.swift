//
//  AnalyticsEvent.swift
//  Ratio
//
//  Centralized analytics definitions.
//

import Foundation

struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]?

    init(name: String, parameters: [String: Any]? = nil) {
        self.name = name
        self.parameters = parameters
    }
}

enum AnalyticsEventName: String {
    // Acquisition / First session
    case onboarding_view
    case onboarding_complete
    case push_permission_view
    case push_permission_result
    case deeplink_open
    case tab_select

    // Auth
    case auth_login_start
    case auth_login_success
    case auth_login_error
    case auth_signup_start
    case auth_signup_success
    case auth_signup_error
    case auth_password_reset_start
    case auth_password_reset_success
    case auth_password_reset_error
    case auth_logout

    // Subscriptions
    case subscription_create
    case subscription_edit
    case subscription_delete
    case subscription_view

    // Groups
    case group_create
    case group_edit
    case group_view
    case group_delete
    case group_leave

    // Invites
    case invite_create
    case invite_share
    case invite_open
    case invite_accept_success
    case invite_accept_error
    case invite_redeem_manual

    // Payments / Receipts
    case payment_submit
    case payment_submit_success
    case payment_submit_error
    case payment_approve
    case payment_reject
    case payment_sheet_open
    case receipt_view
    case receipt_history_open
    case receipt_share
    case receipt_save_photos
    case share_extension_open
    case share_extension_submit
    case share_extension_error
    case share_extension_cancel

    // Notifications
    case notification_received
    case notification_open
    case notification_history_open
    case notification_mark_read

    // Home / Dashboard
    case home_open
    case home_total_monthly_tap
    case home_insight_tap
    case home_upcoming_payment_tap
    case home_chart_category_tap
    case home_chart_monthly_tap
    case home_empty_state_view

    // Advisor
    case advisor_open
    case advisor_cta_tap
    case advisor_generate
    case advisor_generate_success
    case advisor_generate_error
    case advisor_refresh
    case pro_feature_blocked

    // History
    case history_open
    case history_month_view
    case history_item_view

    // Settings / Account
    case settings_open
    case settings_profile_open
    case settings_profile_edit
    case settings_change_email_open
    case settings_change_email_success
    case settings_currency_change
    case settings_delete_account_start
    case settings_delete_account_success
    case settings_delete_account_error
    case settings_whats_new_open
    case settings_help_open

    // Monetization / Pro
    case paywall_open
    case paywall_cta_tap
    case subscription_start
    case subscription_success
    case restore_tap
    case restore_success

    // WhatsNew
    case whatsnew_view
    case whatsnew_continue
    case whatsnew_update_tap
}

enum AnalyticsUserProperty: String {
    case app_language
    case theme
    case is_pro
    case primary_currency
    case subscriptions_count
    case groups_count
    case uses_advisor
    case uses_share_extension
    case platform
    case locale_region
}

enum AnalyticsScreenName: String {
    // Onboarding / Permissions
    case screen_onboarding
    case screen_onboarding_ai
    case screen_onboarding_tutorial
    case screen_push_permission

    // Auth
    case screen_login
    case screen_signup
    case screen_password_reset

    // Home
    case screen_home
    case screen_home_empty
    case screen_home_insight_detail

    // Subscriptions
    case screen_subscriptions
    case screen_subscriptions_empty
    case screen_create_subscription
    case screen_edit_subscription

    // Groups
    case screen_groups
    case screen_groups_empty
    case screen_create_group
    case screen_edit_group
    case screen_group_detail
    case screen_payment_submit
    case screen_receipt_history
    case screen_receipt_preview
    case screen_invite_accept
    case screen_invite_redeem

    // Notifications
    case screen_notifications_history

    // Advisor
    case screen_advisor

    // Settings / Account
    case screen_settings
    case screen_profile
    case screen_change_email
    case screen_delete_account
    case screen_billing_history

    // Monetization / Pro
    case screen_paywall
    case screen_subscription_benefits
    case screen_subscription_success

    // WhatsNew
    case screen_whats_new

    // Share Extension
    case screen_share_extension
}
