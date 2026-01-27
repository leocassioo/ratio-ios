//
//  EditGroupView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import SwiftUI
import UIKit

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: GroupsViewModel
    let group: SharedGroup
    let ownerId: String

    @State private var groupName: String
    @State private var selectedSubscriptionId: String?
    @State private var totalAmountValue: Double
    @State private var totalAmountText: String
    @State private var currencyCode: String
    @State private var billingDay: Int
    @State private var manualPeriod: SubscriptionPeriod
    @State private var groupCategory: GroupCategory
    @State private var notes: String
    @State private var serviceLogin: String
    @State private var servicePassword: String
    @State private var pixKey: String
    @State private var ownerPhoneNumber: String
    @State private var splitEqually: Bool = true
    @State private var ownerParticipates: Bool
    @State private var members: [GroupMemberDraft]
    @State private var memberValues: [String: Double] = [:]
    @State private var newMemberName = ""
    @State private var showDeleteAlert = false
    @State private var didCopyMessage = false
    @State private var didCopyToken = false
    @State private var showSubscriptionInUseAlert = false
    @State private var subscriptionInUseName = ""
    @State private var clearedSubscription = false
    @StateObject private var creationViewModel: GroupCreationViewModel
    @StateObject private var inviteViewModel: GroupInviteViewModel
    private let isOwner: Bool

    init(viewModel: GroupsViewModel, group: SharedGroup, ownerId: String) {
        self.viewModel = viewModel
        self.group = group
        self.ownerId = ownerId
        self.isOwner = group.ownerId == ownerId
        let ownerAmount = group.members.first(where: { $0.userId == ownerId })?.amount
        _groupName = State(initialValue: group.name)
        _selectedSubscriptionId = State(initialValue: group.subscriptionId)
        _totalAmountValue = State(initialValue: group.totalAmount)
        _totalAmountText = State(initialValue: AmountInputFormatter.format(group.totalAmount))
        _currencyCode = State(initialValue: group.currencyCode)
        _billingDay = State(initialValue: group.billingDay ?? 1)
        let initialPeriod = EditGroupView.periodFromLabel(group.subscriptionPeriod ?? group.billingPeriod)
        _manualPeriod = State(initialValue: initialPeriod)
        _groupCategory = State(initialValue: group.category)
        _notes = State(initialValue: group.notes ?? "")
        _serviceLogin = State(initialValue: group.serviceLogin ?? "")
        _servicePassword = State(initialValue: group.servicePassword ?? "")
        _pixKey = State(initialValue: group.pixKey ?? "")
        _ownerPhoneNumber = State(initialValue: group.ownerPhoneNumber ?? "")
        _ownerParticipates = State(initialValue: (ownerAmount ?? 1) > 0)
        _members = State(initialValue: group.members.map {
            GroupMemberDraft(
                id: $0.id,
                name: $0.name,
                amountText: $0.amount.formatted(.number.precision(.fractionLength(2))),
                status: $0.status,
                userId: $0.userId,
                photoURL: $0.photoURL,
                receiptURL: $0.receiptURL
            )
        })
        _creationViewModel = StateObject(wrappedValue: GroupCreationViewModel(ownerId: ownerId))
        _inviteViewModel = StateObject(wrappedValue: GroupInviteViewModel(
            groupId: group.id,
            groupName: group.name,
            ownerId: ownerId
        ))
    }

    var body: some View {
        Form {
            groupSection
            credentialsSection
            paymentDataSection
            contactSection
            notesSection
            membersSection
            if perPersonAmount > 0 {
                summarySection
            }
            inviteSection
            deleteSection
        }
        .navigationTitle("Editar grupo")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    Task {
                        if let subscription = selectedSubscriptionForSave {
                            if isSubscriptionInUse(subscriptionId: subscription.id) {
                                subscriptionInUseName = subscription.name
                                showSubscriptionInUseAlert = true
                                return
                            }
                            let normalizedMembers = normalizedMemberList()
                            await viewModel.updateGroup(
                                groupId: group.id,
                                name: groupName,
                                subscription: subscription,
                                billingDay: billingDay,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                                serviceLogin: serviceLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : serviceLogin,
                                servicePassword: servicePassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : servicePassword,
                                pixKey: pixKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : pixKey,
                                ownerPhoneNumber: ownerPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ownerPhoneNumber,
                                members: normalizedMembers,
                                ownerId: ownerId
                            )
                        } else {
                            let normalizedMembers = normalizedMemberList()
                            await viewModel.updateGroupManual(
                                groupId: group.id,
                                name: groupName,
                                category: groupCategory,
                                totalAmount: totalAmountValue,
                                currencyCode: currencyCode,
                                period: manualPeriod,
                                billingDay: billingDay,
                                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                                serviceLogin: serviceLogin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : serviceLogin,
                                servicePassword: servicePassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : servicePassword,
                                pixKey: pixKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : pixKey,
                                ownerPhoneNumber: ownerPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ownerPhoneNumber,
                                members: normalizedMembers,
                                ownerId: ownerId
                            )
                        }
                        dismiss()
                    }
                }
                .disabled(!canSubmit || !isOwner)
            }
        }
        .alert("Excluir grupo?", isPresented: $showDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Excluir", role: .destructive) {
                Task {
                    await viewModel.deleteGroup(groupId: group.id)
                    dismiss()
                }
            }
        } message: {
            Text("Essa ação é permanente e remove o grupo para todos os membros.")
        }
        .alert("Assinatura já vinculada", isPresented: $showSubscriptionInUseAlert) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text("A assinatura \"\(subscriptionInUseName)\" já está vinculada a outro grupo. Edite o grupo existente ou escolha outra assinatura.")
        }
        .onAppear {
            creationViewModel.startListening()
            updateSelectedSubscription()
        }
        .onDisappear {
            creationViewModel.stopListening()
        }
        .onChange(of: selectedSubscriptionId) { _, _ in
            updateSelectedSubscription()
            if selectedSubscriptionId == nil {
                clearedSubscription = true
            } else {
                clearedSubscription = false
            }
        }
        .onChange(of: manualPeriod) { _, _ in
            if splitEqually {
                applyEqualSplit()
            }
        }
        .onChange(of: splitEqually) { _, newValue in
            if newValue {
                applyEqualSplit()
            }
        }
        .onChange(of: ownerParticipates) { _, _ in
            if splitEqually {
                applyEqualSplit()
            }
        }
        .onChange(of: totalAmountValue) { _, _ in
            if splitEqually {
                applyEqualSplit()
            }
        }
        .onChange(of: members.count) { _, _ in
            if splitEqually {
                applyEqualSplit()
            }
        }
    }

    private var groupSection: some View {
        Section("Grupo") {
            TextField("Nome do grupo", text: $groupName)

            Picker("Assinatura (opcional)", selection: $selectedSubscriptionId) {
                Text("Selecione uma assinatura").tag(Optional<String>.none)
                ForEach(creationViewModel.subscriptions) { subscription in
                    Text(subscription.name).tag(Optional(subscription.id))
                }
            }

            if let subscription = selectedSubscription {
                HStack {
                    Text("Total")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedCurrency(subscription.amount, currencyCode: subscription.currencyCode))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Periodicidade")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(subscription.period.label)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Tipo")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(subscription.category.label)
                        .foregroundStyle(.secondary)
                }
            } else {
                TextField("Valor total", text: $totalAmountText)
                    .keyboardType(.decimalPad)
                    .onChange(of: totalAmountText) { _, newValue in
                        let sanitized = AmountInputFormatter.sanitize(newValue)
                        if sanitized != newValue {
                            totalAmountText = sanitized
                        }
                        totalAmountValue = AmountInputFormatter.parse(sanitized) ?? 0
                    }

                Picker("Moeda", selection: $currencyCode) {
                    ForEach(PrimaryCurrencyOption.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }

                Picker("Periodicidade", selection: $manualPeriod) {
                    ForEach(SubscriptionPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }

                Picker("Categoria", selection: $groupCategory) {
                    ForEach(GroupCategory.allCases) { category in
                        Text(category.label).tag(category)
                    }
                }
            }

            Stepper(value: $billingDay, in: 1...31) {
                Text("Dia de cobrança do grupo: \(billingDay)")
            }

            Toggle("Dividir igualmente", isOn: $splitEqually)
            Toggle("Eu participo do rateio", isOn: $ownerParticipates)
        }
    }

    private var credentialsSection: some View {
        Section("Credenciais de Acesso (Opcional)") {
            TextField("Login do serviço", text: $serviceLogin)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Senha do serviço", text: $servicePassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .textCase(nil)
    }

    private var paymentDataSection: some View {
        Section("Dados de Pagamento (Opcional)") {
            TextField("Chave Pix do grupo", text: $pixKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Text("Se preenchido, esta chave será usada em vez da chave do seu perfil.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

    }

    private var contactSection: some View {
        Section("Contato do organizador (Opcional)") {
            TextField("Telefone para contato", text: $ownerPhoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .disabled(!isOwner)
            Text("Esse número ficará visível para os membros do grupo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var notesSection: some View {
        Section("Observações") {
            TextField("Detalhes do grupo", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
        }
    }

    private var membersSection: some View {
        Section("Membros") {
            HStack {
                TextField("Nome do membro", text: $newMemberName)
                    .submitLabel(.done)
                    .onSubmit(addMember)
                Button {
                    addMember()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach($members) { $member in
            MemberRowView(
                member: $member,
                currencySymbol: currencySymbol,
                splitEqually: splitEqually,
                memberValues: $memberValues,
                parseAmount: parseAmount,
                formatAmount: formatAmount,
                sanitizeAmount: AmountInputFormatter.sanitize
            )
        }
            .onDelete(perform: deleteMember)
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                Text("Por pessoa")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedCurrency(perPersonAmount, currencyCode: currencyCode))
                    .font(.headline)
            }
        } header: {
            Text("Resumo")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Text("Excluir grupo")
            }
            .disabled(!isOwner)
        }
    }

    private var inviteSection: some View {
        Section {
            if inviteViewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("Gerando link...")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Gerar link de convite") {
                    Task {
                        await inviteViewModel.createInvite()
                    }
                }
                .disabled(!isOwner)
            }

            if let url = inviteViewModel.inviteURL {
                let message = inviteMessage(for: url)
                let token = inviteToken(from: url)
                ShareLink(item: message) {
                    Label("Compartilhar convite", systemImage: "square.and.arrow.up")
                }
                .disabled(!isOwner)

                Button {
                    UIPasteboard.general.string = message
                    setCopiedState(type: .message)
                } label: {
                    Label(
                        didCopyMessage ? "Copiado" : "Copiar mensagem",
                        systemImage: didCopyMessage ? "checkmark" : "doc.on.doc"
                    )
                }
                .disabled(!isOwner)

                Button {
                    UIPasteboard.general.string = token
                    setCopiedState(type: .token)
                } label: {
                    Label(
                        didCopyToken ? "Código copiado" : "Copiar código do convite",
                        systemImage: didCopyToken ? "checkmark" : "number"
                    )
                }
                .disabled(!isOwner || token.isEmpty)
            }

            if let message = inviteViewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Convite")
        } footer: {
            Text("O link expira em 24 horas e pode ser usado sem limite de pessoas.")
        }
    }

    private var canSubmit: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        totalAmountValue > 0 &&
        !members.isEmpty
    }

    private func normalizedMemberList() -> [GroupMemberDraft] {
        members
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { member in
                var copy = member
                if splitEqually, let value = memberValues[member.id] {
                    copy.amountText = formatAmount(value)
                }
                if !ownerParticipates, copy.userId == ownerId {
                    copy.amountText = formatAmount(0)
                }
                return copy
            }
    }

    private func deleteMember(at offsets: IndexSet) {
        members.remove(atOffsets: offsets)
    }

    private func applyEqualSplit() {
        guard !members.isEmpty else { return }
        let count = participantCount
        if count == 0 {
            members = members.map { member in
                var copy = member
                copy.amountText = formatAmount(0)
                memberValues[copy.id] = 0
                return copy
            }
            return
        }
        let value = totalAmountValue / Double(count)
        members = members.map { member in
            var copy = member
            if !ownerParticipates, copy.userId == ownerId {
                copy.amountText = formatAmount(0)
                memberValues[copy.id] = 0
            } else {
                copy.amountText = formatAmount(value)
                memberValues[copy.id] = value
            }
            return copy
        }
    }

    private func updateSelectedSubscription() {
        guard let subscription = selectedSubscriptionForSave else { return }

        totalAmountValue = subscription.amount
        totalAmountText = formatAmount(subscription.amount)
        currencyCode = subscription.currencyCode
        if groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            groupName = subscription.name
        }
        if billingDay <= 0 {
            billingDay = Calendar.current.component(.day, from: subscription.nextBillingDate)
        }
        manualPeriod = subscription.period
        groupCategory = GroupCategory(rawValue: subscription.category.rawValue) ?? groupCategory
        if splitEqually {
            applyEqualSplit()
        }
    }

    private func parseAmount(_ text: String) -> Double? {
        AmountInputFormatter.parse(text)
    }

    private func formatAmount(_ value: Double) -> String {
        AmountInputFormatter.format(value)
    }

    private func addMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        members.append(GroupMemberDraft(id: UUID().uuidString, name: trimmed, amountText: "", status: .pending, userId: nil, photoURL: nil, receiptURL: nil))
        newMemberName = ""
        if splitEqually {
            applyEqualSplit()
        }
    }

    private func inviteMessage(for url: URL) -> String {
        """
        Você foi convidado(a) para o grupo "\(group.name)" no Ratio.

        Baixe o app:
        https://uaipixel.com/apps/ratio

        Abra o convite:
        \(url.absoluteString)
        """
    }

    private func inviteToken(from url: URL) -> String {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "token" })?
            .value ?? ""
    }

    private enum CopiedType {
        case message
        case token
    }

    private func setCopiedState(type: CopiedType) {
        switch type {
        case .message:
            didCopyMessage = true
        case .token:
            didCopyToken = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            switch type {
            case .message:
                didCopyMessage = false
            case .token:
                didCopyToken = false
            }
        }
    }

    private var perPersonAmount: Double {
        let count = participantCount
        guard count > 0 else { return 0 }
        return totalAmountValue / Double(count)
    }

    private var participantCount: Int {
        members.filter { member in
            if ownerParticipates {
                return true
            }
            return member.userId != ownerId
        }.count
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.currencySymbol
    }

    private var selectedSubscription: SubscriptionItem? {
        guard let selectedSubscriptionId else { return nil }
        return creationViewModel.subscriptions.first { $0.id == selectedSubscriptionId }
    }

    private var selectedSubscriptionForSave: SubscriptionItem? {
        if let selectedSubscription {
            return selectedSubscription
        }

        if clearedSubscription {
            return nil
        }

        guard let subscriptionId = group.subscriptionId else { return nil }
        let period = SubscriptionPeriod(rawValue: group.subscriptionPeriod ?? "") ?? .monthly
        let category = SubscriptionCategory(rawValue: group.subscriptionCategory ?? "") ?? .other
        return SubscriptionItem(
            id: subscriptionId,
            name: group.subscriptionName ?? group.name,
            amount: group.totalAmount,
            currencyCode: group.currencyCode,
            category: category,
            period: period,
            nextBillingDate: group.subscriptionNextBillingDate ?? Date(),
            notes: group.notes ?? ""
        )
    }

    private func isSubscriptionInUse(subscriptionId: String) -> Bool {
        viewModel.groups.contains { $0.subscriptionId == subscriptionId && $0.id != group.id }
    }

    private static func periodFromLabel(_ label: String) -> SubscriptionPeriod {
        let lower = label.lowercased()
        if lower.contains("semana") {
            return .weekly
        }
        if lower.contains("trimestre") {
            return .quarterly
        }
        if lower.contains("anual") || lower.contains("ano") {
            return .yearly
        }
        if lower.contains("única") || lower.contains("unica") {
            return .oneTime
        }
        return .monthly
    }
}

#Preview {
    NavigationStack {
        EditGroupView(
            viewModel: GroupsViewModel(),
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
                    GroupMember(id: "1", name: "Leo", amount: 20, status: .paid, userId: "1", photoURL: nil, receiptURL: nil, submittedAt: nil, approvedAt: nil),
                    GroupMember(id: "2", name: "Pessoa", amount: 20, status: .pending, userId: nil, photoURL: nil, receiptURL: nil, submittedAt: nil, approvedAt: nil)
                ]
            ),
            ownerId: "preview"
        )
    }
}
