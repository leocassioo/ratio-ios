//
//  CreateGroupView.swift
//  Ratio
//
//  Created by Codex on 21/12/25.
//

import FirebaseFirestore
import SwiftUI
import FirebaseCore

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @ObservedObject var viewModel: GroupsViewModel
    let ownerId: String
    let ownerName: String
    private let subscriptionsStore = SubscriptionsStore()
    private let analytics = AnalyticsService.shared

    @State private var groupName = ""
    @State private var selectedSubscriptionId: String?
    @State private var totalAmountValue: Double = 0
    @State private var totalAmountText = ""
    @State private var currencyCode = "BRL"
    @State private var billingPeriodLabel = ""
    @State private var billingDay = 1
    @State private var manualPeriod: SubscriptionPeriod = .monthly
    @State private var groupCategory: GroupCategory = .other
    @State private var notes = ""
    @State private var serviceLogin = ""
    @State private var servicePassword = ""
    @State private var ownerPhoneNumber = ""
    @State private var ownerPhotoURL: String?

    @State private var pixKey = ""
    @State private var splitEqually = true
    @State private var ownerParticipates = true
    @State private var members: [GroupMemberDraft] = []
    @State private var memberValues: [String: Double] = [:]
    @State private var newMemberName = ""
    @StateObject private var creationViewModel: GroupCreationViewModel
    @State private var showInviteSheet = false
    @State private var inviteURL: URL?
    @State private var inviteError: String?
    @State private var isGeneratingInvite = false
    @State private var isSaving = false
    @State private var didCopyMessage = false
    @State private var didCopyToken = false
    @State private var showSubscriptionInUseAlert = false
    @State private var subscriptionInUseName = ""
    @State private var didEditBillingDay = false
    @State private var isSettingBillingDay = false
    @State private var createdGroupId: String?

    init(viewModel: GroupsViewModel, ownerId: String, ownerName: String) {
        self.viewModel = viewModel
        self.ownerId = ownerId
        self.ownerName = ownerName
        _creationViewModel = StateObject(wrappedValue: GroupCreationViewModel(ownerId: ownerId))
    }

    var body: some View {
        ZStack {
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
            }
            .disabled(isSaving)

            if isSaving {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Salvando grupo...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Novo grupo")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
                .disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") {
                    Task {
                        guard !isSaving else { return }
                        isSaving = true
                        defer { isSaving = false }
                        if let subscription = selectedSubscription {
                            if isSubscriptionInUse(subscriptionId: subscription.id) {
                                subscriptionInUseName = subscription.name
                                showSubscriptionInUseAlert = true
                                return
                            }
                            let normalizedMembers = normalizedMemberList()
                            if let groupId = await viewModel.createGroup(
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
                            ) {
                                createdGroupId = groupId
                                await generateInvite(groupId: groupId, groupName: groupName)
                                showInviteSheet = true
                            }
                        } else {
                            let normalizedMembers = normalizedMemberList()
                            if let groupId = await viewModel.createGroupManual(
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
                            ) {
                                createdGroupId = groupId
                                await generateInvite(groupId: groupId, groupName: groupName)
                                showInviteSheet = true
                            }
                        }
                    }
                }
                .disabled(!canSubmit || isSaving)
            }
        }
        .onAppear {
            analytics.screenView(.screen_create_group)
            if members.isEmpty {
                members = [
                    GroupMemberDraft(
                        id: UUID().uuidString,
                        name: ownerName.isEmpty ? "Você" : ownerName,
                        amountText: "",
                        status: .paid,
                        userId: ownerId,
                        photoURL: ownerPhotoURL,
                        receiptURL: nil
                    )
                ]
            }
            updateSelectedSubscription()
            if selectedSubscription == nil {
                setBillingDayToToday()
            }
            if totalAmountText.isEmpty, totalAmountValue > 0 {
                totalAmountText = formatAmount(totalAmountValue)
            }
            creationViewModel.startListening()
            Task {
                if let profile = try? await UsersStore().fetchUserProfile(userId: ownerId) {
                    if let key = profile.pixKey {
                        pixKey = key
                    }
                    if let phone = profile.phoneNumber, ownerPhoneNumber.isEmpty {
                        ownerPhoneNumber = phone
                    }
                    if let photo = profile.photoURL, ownerPhotoURL == nil {
                        ownerPhotoURL = photo
                        if let index = members.firstIndex(where: { $0.userId == ownerId }) {
                            members[index].photoURL = photo
                        }
                    }
                }
            }
        }
        .onDisappear {
            creationViewModel.stopListening()
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
        .onChange(of: billingDay) { _, _ in
            if !isSettingBillingDay {
                didEditBillingDay = true
            }
        }
        .onChange(of: members.count) { _, _ in
            if splitEqually {
                applyEqualSplit()
            }
        }
        .onChange(of: selectedSubscriptionId) { _, _ in
            updateSelectedSubscription()
            if selectedSubscriptionId == nil, !didEditBillingDay {
                setBillingDayToToday()
            }
        }
        .onChange(of: manualPeriod) { _, newValue in
            billingPeriodLabel = newValue.label
            if splitEqually {
                applyEqualSplit()
            }
        }
        .sheet(isPresented: $showInviteSheet, onDismiss: {
            dismiss()
        }) {
            inviteSheet
        }
        .alert("Assinatura já vinculada", isPresented: $showSubscriptionInUseAlert) {
            Button("Ok", role: .cancel) {}
        } message: {
            Text("A assinatura \"\(subscriptionInUseName)\" já está vinculada a um grupo. Edite o grupo existente ou escolha outra assinatura.")
        }
    }

    private var groupSection: some View {
        Section {
            if creationViewModel.subscriptions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Você pode criar um grupo manual ou vincular uma assinatura.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        openCreateSubscription()
                    } label: {
                        Label("Cadastrar assinatura", systemImage: "creditcard")
                    }
                }
                .padding(.vertical, 4)
            }

            Picker("Assinatura (opcional)", selection: $selectedSubscriptionId) {
                Text(creationViewModel.subscriptions.isEmpty ? "Nenhuma assinatura disponível" : "Selecione uma assinatura")
                    .tag(Optional<String>.none)
                ForEach(creationViewModel.subscriptions) { subscription in
                    Text(subscription.name).tag(Optional(subscription.id))
                }
            }

            TextField("Nome do grupo", text: $groupName)

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
        } header: {
            Text("Grupo")
        } footer: {
            NavigationLink {
                RedeemInviteView()
            } label: {
                Text("Já tem um convite? Resgatar código")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
            Text("Se deixado em branco, será usada a chave Pix do seu perfil ao cobrar.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var contactSection: some View {
        Section("Contato do organizador (Opcional)") {
            TextField("Telefone para contato", text: $ownerPhoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
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
                if copy.userId == nil && copy.name == ownerName {
                    copy.userId = ownerId
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
        guard let subscription = selectedSubscription else {
            if billingPeriodLabel.isEmpty {
                billingPeriodLabel = manualPeriod.label
            }
            return
        }

        totalAmountValue = subscription.amount
        totalAmountText = formatAmount(subscription.amount)
        currencyCode = subscription.currencyCode
        billingPeriodLabel = subscription.period.label
        manualPeriod = subscription.period
        groupCategory = GroupCategory(rawValue: subscription.category.rawValue) ?? .other
        billingDay = Calendar.current.component(.day, from: subscription.nextBillingDate)
        if groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            groupName = subscription.name
        }
        updateSplitAmounts()
    }

    private func setBillingDayToToday() {
        let today = Calendar.current.component(.day, from: Date())
        isSettingBillingDay = true
        billingDay = today
        isSettingBillingDay = false
    }

    private func updateSplitAmounts() {
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

    private func isSubscriptionInUse(subscriptionId: String) -> Bool {
        viewModel.groups.contains { $0.subscriptionId == subscriptionId }
    }

    private var inviteSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Convite do grupo")
                    .font(.headline)

                if isGeneratingInvite {
                    ProgressView("Gerando link...")
                } else if let inviteURL {
                    let message = inviteMessage(for: inviteURL)
                    let token = inviteToken(from: inviteURL)
                    let groupId = createdGroupId ?? ""
                    Text("Compartilhe o link com os membros do grupo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    ShareLink(item: message) {
                        Label("Compartilhar convite", systemImage: "square.and.arrow.up")
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        analytics.track(.invite_share, parameters: ["group_id": groupId, "channel": "system_share"])
                    })

                    Button {
                        UIPasteboard.general.string = message
                        setCopiedState(type: .message)
                        analytics.track(.invite_share, parameters: ["group_id": groupId, "channel": "link"])
                    } label: {
                        Label(
                            didCopyMessage ? "Copiado" : "Copiar mensagem",
                            systemImage: didCopyMessage ? "checkmark" : "doc.on.doc"
                        )
                    }

                    Button {
                        UIPasteboard.general.string = token
                        setCopiedState(type: .token)
                        analytics.track(.invite_share, parameters: ["group_id": groupId, "channel": "link"])
                    } label: {
                        Label(
                            didCopyToken ? "Código copiado" : "Copiar código do convite",
                            systemImage: didCopyToken ? "checkmark" : "number"
                        )
                    }
                    .disabled(token.isEmpty)
                } else if let inviteError {
                    Text(inviteError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Convite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        showInviteSheet = false
                    }
                }
            }
        }
    }

    private func generateInvite(groupId: String, groupName: String) async {
        isGeneratingInvite = true
        inviteError = nil
        inviteURL = nil

        do {
            let expiresAt = Date().addingTimeInterval(60 * 60 * 24)
            let token = try await InvitesStore().createInvite(
                groupId: groupId,
                groupName: groupName,
                createdBy: ownerId,
                expiresAt: expiresAt,
                maxUses: 0
            )
            inviteURL = URL(string: "https://uaipixel.com/invite?token=\(token)")
            analytics.track(.invite_create, parameters: [
                "group_id": groupId,
                "max_uses": 0,
                "expires_in_hours": 24
            ])
        } catch {
            inviteError = "Não foi possível gerar o link."
        }

        isGeneratingInvite = false
    }

    private func inviteMessage(for url: URL) -> String {
        """
        Você foi convidado(a) para o grupo "\(groupName)" no Ratio.

        Baixe o app (em breve):
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

    private func openCreateSubscription() {
        dismiss()
        router.route(to: .subscriptions)
        router.present(.createSubscription(ownerId: ownerId) { newSubscription in
            Task {
                let data: [String: Any] = [
                    "name": newSubscription.name,
                    "amount": newSubscription.amount,
                    "currencyCode": newSubscription.currencyCode,
                    "category": newSubscription.category.rawValue,
                    "period": newSubscription.period.rawValue,
                    "nextBillingDate": Timestamp(date: newSubscription.nextBillingDate),
                    "notes": newSubscription.notes.isEmpty ? nil : newSubscription.notes,
                    "ownerId": ownerId,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                try? await subscriptionsStore.createSubscription(
                    userId: ownerId,
                    id: newSubscription.id,
                    data: data
                )
            }
        })
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
}


#Preview {
    NavigationStack {
        CreateGroupView(
            viewModel: GroupsViewModel(),
            ownerId: "preview",
            ownerName: "Leonardo"
        )
    }
}
