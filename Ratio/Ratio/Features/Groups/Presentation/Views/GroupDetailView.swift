//
//  GroupDetailView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import SwiftUI

struct GroupDetailView: View {
    let group: SharedGroup
    let currentUserId: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var currentGroup: SharedGroup
    @StateObject private var paymentsViewModel = GroupPaymentsViewModel()
    private let groupsStore = GroupsStore()
    private let analytics = AnalyticsService.shared
    @State private var showPaymentSheet = false
    @State private var showPaymentError = false
    @State private var showLeaveConfirm = false
    @State private var selectedMemberForReceipts: GroupMember?
    @State private var showLeaveError = false
    @State private var leaveErrorMessage: String = "Não foi possível sair do grupo."
    @State private var isLeavingGroup = false
    @State private var ownerPixKey: String?
    @State private var usdRate: ExchangeRate?
    @State private var eurRate: ExchangeRate?
    @State private var exchangeRateListener: ListenerRegistration?
    @State private var eurRateListener: ListenerRegistration?
    @State private var preferredCurrencyCode = PreferencesStore.shared.primaryCurrencyCode()

    init(group: SharedGroup, currentUserId: String?) {
        self.group = group
        self.currentUserId = currentUserId
        _currentGroup = State(initialValue: group)
    }

    var body: some View {
        List {
            Section("Grupo") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentGroup.name)
                        .font(.title2.bold())
                    if let subscriptionName = currentGroup.subscriptionName {
                        Text(subscriptionName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Total")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedCurrency(currentGroup.totalAmount))
                        .font(.headline)
                }
                if let estimated = estimatedAmount(for: currentGroup.totalAmount) {
                    HStack {
                        Text("Estimado em \(preferredCurrencyCode)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedCurrency(estimated, currencyCode: preferredCurrencyCode))
                            .font(.subheadline.weight(.semibold))
                    }
                }

                HStack {
                    Text("Periodicidade")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currentGroup.billingPeriod)
                        .foregroundStyle(.secondary)
                }

                if let billingDay = currentGroup.chargeDay ?? currentGroup.billingDay {
                    HStack {
                        Text("Dia de cobrança do grupo")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(billingDay)")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Categoria")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currentGroup.category.label)
                        .foregroundStyle(.secondary)
                }
            }

            if let currentMember = currentMember {
                Section("Seu pagamento") {
                    HStack {
                        Text("Status")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currentMember.status.label)
                            .foregroundStyle(statusColor(for: currentMember.status))
                    }
                    if let estimated = estimatedAmount(for: currentMember.amount) {
                        HStack {
                            Text("Estimado em \(preferredCurrencyCode)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formattedCurrency(estimated, currencyCode: preferredCurrencyCode))
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    if hasReceipts(currentMember) {
                        Button("Ver comprovantes") {
                            selectedMemberForReceipts = currentMember
                        }
                    }

                    if currentMember.status == .pending || currentMember.status == .overdue {
                        if let paymentKey = (currentGroup.pixKey?.isEmpty == false) ? currentGroup.pixKey : ownerPixKey, !paymentKey.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Chave Pix para pagamento")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text(paymentKey)
                                        .font(.subheadline)
                                        .monospaced()
                                    Spacer()
                                    CopyButton(textToCopy: paymentKey)
                                }
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }

                        Button("Marcar como pago") {
                            showPaymentSheet = true
                        }
                    } else if currentMember.status == .submitted {
                        Text("Aguardando confirmação do organizador.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let notes = currentGroup.notes, !notes.isEmpty {
                Section("Observações") {
                    Text(notes)
                }
            }

            if let ownerPhone = currentGroup.ownerPhoneNumber,
               !ownerPhone.isEmpty {
                Section("Contato do organizador") {
                    HStack {
                        Text(ownerPhone)
                            .font(.body)
                        Spacer()
                        CopyButton(textToCopy: ownerPhone)
                    }

                    let cleanedPhone = sanitizedPhoneNumber(ownerPhone)
                    if !cleanedPhone.isEmpty {
                        HStack {
                            Button {
                                if let url = URL(string: "tel://\(cleanedPhone)") {
                                    openURL(url)
                                }
                            } label: {
                                Label("Ligar", systemImage: "phone.fill")
                            }

                            Spacer()

                            Button {
                                if let url = URL(string: "https://wa.me/\(cleanedPhone)") {
                                    openURL(url)
                                }
                            } label: {
                                Label("WhatsApp", systemImage: "message.fill")
                            }
                        }
                    }
                }
            }
            
            if (currentGroup.serviceLogin?.isEmpty == false) || (currentGroup.servicePassword?.isEmpty == false) {
                Section("Credenciais de Acesso") {
                    if let login = currentGroup.serviceLogin, !login.isEmpty {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Login")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(login)
                                    .font(.body)
                            }
                            Spacer()
                            CopyButton(textToCopy: login)
                        }
                    }
                    
                    if let password = currentGroup.servicePassword, !password.isEmpty {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Senha")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                SecureField("Senha", text: .constant(password))
                                    .disabled(true)
                            }
                            Spacer()
                            CopyButton(textToCopy: password)
                        }
                    }
                }
            }

            Section("Membros") {
                ForEach(orderedMembers) { member in
                    HStack(spacing: 12) {
                        MemberAvatarView(name: member.name, photoURL: member.photoURL)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(memberDisplayName(for: member))
                                    .font(.subheadline.weight(.semibold))
                                if let roleLabel = memberRoleLabel(for: member) {
                                    Text(roleLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(member.status.label)
                                .font(.footnote)
                                .foregroundStyle(statusColor(for: member.status))
                        }
                        Spacer()

                        if hasReceipts(member) {
                            Button {
                                selectedMemberForReceipts = member
                            } label: {
                                Image(systemName: "doc.text.magnifyingglass")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        if canApprove(member: member) {
                            Button("Aprovar") {
                                Task {
                                    await paymentsViewModel.approvePayment(groupId: currentGroup.id, memberId: member.id)
                                    if paymentsViewModel.errorMessage == nil {
                                        updateMemberStatus(member.id, status: .paid)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                        } else if isOwner, member.status != .paid, member.userId != currentUserId {
                            Button {
                                Task {
                                    let usersStore = UsersStore()
                                    var phoneNumber: String?
                                    if let userId = member.userId {
                                        if let profile = try? await usersStore.fetchUserProfile(userId: userId) {
                                            phoneNumber = profile.phoneNumber
                                        }
                                    }
                                    
                                    if let url = WhatsAppMessageBuilder.buildPaymentRequest(
                                        memberName: member.name,
                                        groupName: currentGroup.name,
                                        amount: member.amount,
                                        currencyCode: currentGroup.currencyCode,
                                        pixKey: (currentGroup.pixKey?.isEmpty == false) ? currentGroup.pixKey : paymentsViewModel.userPixKey,
                                        phoneNumber: phoneNumber
                                    ) {
                                        await MainActor.run {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "bell.fill")
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color.orange))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedCurrency(member.amount))
                            .font(.subheadline.weight(.semibold))
                        if let estimated = estimatedAmount(for: member.amount) {
                            Text("≈ \(formattedCurrency(estimated, currencyCode: preferredCurrencyCode))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !isOwner, currentUserId != nil {
                Section("Ações") {
                    Button(role: .destructive) {
                        showLeaveConfirm = true
                    } label: {
                        Text("Sair do grupo")
                    }
                }
            }
        }
        .navigationTitle("Detalhes do grupo")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") {
                    dismiss()
                }
            }
        }
        .sheet(item: $selectedMemberForReceipts) { member in
            ReceiptHistorySheetView(memberName: member.name, receipts: receipts(for: member))
        }
        .task {
            preferredCurrencyCode = PreferencesStore.shared.primaryCurrencyCode()
            if let currentUserId {
                await paymentsViewModel.fetchUserPixKey(userId: currentUserId)
            }
            if let ownerId = currentGroup.ownerId, ownerId != currentUserId {
                if let profile = try? await UsersStore().fetchUserProfile(userId: ownerId) {
                    ownerPixKey = profile.pixKey
                }
            }
            exchangeRateListener = ExchangeRateStore().listenUsdRate { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let rate):
                        usdRate = rate
                    case .failure:
                        usdRate = nil
                    }
                }
            }
            eurRateListener = ExchangeRateStore().listenEurRate { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let rate):
                        eurRate = rate
                    case .failure:
                        eurRate = nil
                    }
                }
            }
        }
        .onDisappear {
            exchangeRateListener?.remove()
            exchangeRateListener = nil
            eurRateListener?.remove()
            eurRateListener = nil
        }
        .sheet(isPresented: $showPaymentSheet) {
            if let currentMember = currentMember {
                NavigationStack {
                    PaymentSubmissionView(
                        groupId: currentGroup.id,
                        memberId: currentMember.userId ?? currentMember.id,
                        amount: currentMember.amount,
                        currencyCode: currentGroup.currencyCode,
                        onSubmitted: {
                            updateMemberStatus(currentMember.id, status: .submitted)
                        }
                    )
                }
            }
        }
        .alert("Erro", isPresented: $showPaymentError) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text(paymentsViewModel.errorMessage ?? "Não foi possível atualizar o pagamento.")
        }
        .alert("Erro", isPresented: $showLeaveError) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text(leaveErrorMessage)
        }
        .alert("Sair do grupo?", isPresented: $showLeaveConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Sair", role: .destructive) {
                guard let currentUserId else { return }
                isLeavingGroup = true
                Task {
                    do {
                        try await groupsStore.leaveGroup(groupId: currentGroup.id, userId: currentUserId)
                        await MainActor.run {
                            isLeavingGroup = false
                            analytics.track(.group_leave, parameters: [
                                "group_id": currentGroup.id,
                                "role": isOwner ? "owner" : "member"
                            ])
                            dismiss()
                        }
                    } catch {
                        await MainActor.run {
                            isLeavingGroup = false
                            leaveErrorMessage = (error as NSError).localizedDescription
                            showLeaveError = true
                        }
                    }
                }
            }
        } message: {
            Text("O organizador do grupo será notificado sobre sua saída.")
        }
        .overlay {
            if isLeavingGroup {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Saindo do grupo...")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .onChange(of: group) { _, newValue in
            currentGroup = newValue
        }
        .onChange(of: paymentsViewModel.errorMessage) { _, newValue in
            showPaymentError = newValue != nil
        }
        .onAppear {
            analytics.screenView(.screen_group_detail)
            analytics.track(.group_view, parameters: ["group_id": currentGroup.id])
        }
    }

    private func memberDisplayName(for member: GroupMember) -> String {
        let trimmed = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    private func memberRoleLabel(for member: GroupMember) -> String? {
        let isOwner = member.userId == currentGroup.ownerId
        let isCurrentUser = currentUserId == member.userId

        switch (isOwner, isCurrentUser) {
        case (true, true):
            return "Você • Organizador"
        case (true, false):
            return "Organizador"
        case (false, true):
            return "Você"
        default:
            return nil
        }
    }

    private func formattedCurrency(_ value: Double, currencyCode: String? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode ?? currentGroup.currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private func receipts(for member: GroupMember) -> [ReceiptHistoryItem] {
        if !member.receiptHistory.isEmpty {
            return member.receiptHistory.sorted { $0.submittedAt > $1.submittedAt }
        }
        if let url = member.receiptURL {
            return [ReceiptHistoryItem(id: UUID().uuidString, url: url, submittedAt: member.submittedAt ?? Date())]
        }
        return []
    }

    private func hasReceipts(_ member: GroupMember) -> Bool {
        !member.receiptHistory.isEmpty || member.receiptURL != nil
    }

    private func estimatedAmount(for amount: Double) -> Double? {
        convert(amount: amount, from: currentGroup.currencyCode, to: preferredCurrencyCode)
    }

    private func convert(amount: Double, from: String, to: String) -> Double? {
        if from == to {
            return nil
        }
        let usdRate = usdRate
        let eurRate = eurRate

        func toBRL(_ amount: Double, currency: String) -> Double? {
            switch currency {
            case "USD":
                guard let rate = usdRate, rate.rate > 0 else { return nil }
                let base = amount * rate.rate
                let margin = base * max(rate.marginPct, 0)
                return base + margin
            case "EUR":
                guard let rate = eurRate, rate.rate > 0 else { return nil }
                let base = amount * rate.rate
                let margin = base * max(rate.marginPct, 0)
                return base + margin
            case "BRL":
                return amount
            default:
                return nil
            }
        }

        func fromBRL(_ amount: Double, currency: String) -> Double? {
            switch currency {
            case "USD":
                guard let rate = usdRate, rate.rate > 0 else { return nil }
                return amount / rate.rate
            case "EUR":
                guard let rate = eurRate, rate.rate > 0 else { return nil }
                return amount / rate.rate
            case "BRL":
                return amount
            default:
                return nil
            }
        }

        if from == "BRL" {
            return fromBRL(amount, currency: to)
        }
        if to == "BRL" {
            return toBRL(amount, currency: from)
        }
        guard let brlAmount = toBRL(amount, currency: from) else { return nil }
        return fromBRL(brlAmount, currency: to)
    }

    private func statusColor(for status: GroupMemberStatus) -> Color {
        switch status {
        case .paid:
            return .green
        case .pending:
            return .orange
        case .submitted:
            return .blue
        case .overdue:
            return .red
        }
    }

    private var orderedMembers: [GroupMember] {
        guard let ownerId = currentGroup.ownerId else { return currentGroup.members }
        return currentGroup.members.sorted { lhs, rhs in
            let lhsIsOwner = lhs.userId == ownerId
            let rhsIsOwner = rhs.userId == ownerId
            if lhsIsOwner != rhsIsOwner {
                return lhsIsOwner
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var currentMember: GroupMember? {
        guard let currentUserId else { return nil }
        return currentGroup.members.first { $0.userId == currentUserId }
    }

    private func canApprove(member: GroupMember) -> Bool {
        guard let ownerId = currentGroup.ownerId, ownerId == currentUserId else { return false }
        return member.status == .submitted
    }

    private var isOwner: Bool {
        guard let ownerId = currentGroup.ownerId, let currentUserId else { return false }
        return ownerId == currentUserId
    }

    private func sanitizedPhoneNumber(_ value: String) -> String {
        value.filter { $0.isNumber }
    }

    private func updateMemberStatus(_ memberId: String, status: GroupMemberStatus) {
        currentGroup = SharedGroup(
            id: currentGroup.id,
            name: currentGroup.name,
            category: currentGroup.category,
            totalAmount: currentGroup.totalAmount,
            currencyCode: currentGroup.currencyCode,
            billingPeriod: currentGroup.billingPeriod,
            billingDay: currentGroup.billingDay,
            notes: currentGroup.notes,
            ownerId: currentGroup.ownerId,
            ownerPhoneNumber: currentGroup.ownerPhoneNumber,
            subscriptionId: currentGroup.subscriptionId,
            subscriptionName: currentGroup.subscriptionName,
            subscriptionCategory: currentGroup.subscriptionCategory,
            subscriptionPeriod: currentGroup.subscriptionPeriod,
            subscriptionNextBillingDate: currentGroup.subscriptionNextBillingDate,
            chargeDay: currentGroup.chargeDay,
            chargeNextBillingDate: currentGroup.chargeNextBillingDate,
            serviceLogin: currentGroup.serviceLogin,
            servicePassword: currentGroup.servicePassword,
            pixKey: currentGroup.pixKey,
            members: currentGroup.members.map { member in
                guard member.id == memberId else { return member }
                return GroupMember(
                    id: member.id,
                    name: member.name,
                    amount: member.amount,
                    status: status,
                    userId: member.userId,
                    photoURL: member.photoURL,
                    receiptURL: member.receiptURL,
                    receiptHistory: member.receiptHistory,
                    submittedAt: status == .submitted ? Date() : member.submittedAt,
                    approvedAt: status == .paid ? Date() : member.approvedAt
                )
            }
        )
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(
            group: SharedGroup(
                id: "preview",
                name: "Netflix",
                category: .streaming,
                totalAmount: 59.9,
                currencyCode: "BRL",
                billingPeriod: "Mensal",
                billingDay: 5,
                notes: "Teste",
                ownerId: "1",
                ownerPhoneNumber: "31999999999",
                subscriptionId: "sub",
                subscriptionName: "Netflix",
                subscriptionCategory: "streaming",
                subscriptionPeriod: "monthly",
                subscriptionNextBillingDate: Date(),
                chargeDay: 9,
                chargeNextBillingDate: Date(),
                serviceLogin: nil,
                servicePassword: nil,
                pixKey: nil,
                members: [
                    GroupMember(id: "1", name: "Leo", amount: 20, status: .paid, userId: "1", photoURL: nil, receiptURL: nil, receiptHistory: [], submittedAt: nil, approvedAt: nil),
                    GroupMember(id: "2", name: "Pessoa", amount: 20, status: .pending, userId: nil, photoURL: nil, receiptURL: nil, receiptHistory: [], submittedAt: nil, approvedAt: nil)
                ]
            ),
            currentUserId: "1"
        )
    }
}
