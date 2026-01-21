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

    @State private var groupName = ""
    @State private var selectedSubscriptionId: String?
    @State private var totalAmountValue: Double = 0
    @State private var currencyCode = "BRL"
    @State private var billingPeriodLabel = ""
    @State private var billingDay = 1
    @State private var notes = ""
    @State private var serviceLogin = ""
    @State private var servicePassword = ""
    @State private var ownerPhoneNumber = ""
    @State private var ownerPhotoURL: String?

    @State private var pixKey = ""
    @State private var splitEqually = true
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
        .onChange(of: selectedSubscriptionId) { _, _ in
            updateSelectedSubscription()
        }
        .sheet(isPresented: $showInviteSheet, onDismiss: {
            dismiss()
        }) {
            inviteSheet
        }
    }

    private var groupSection: some View {
        Section {
            if creationViewModel.subscriptions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Para criar um grupo, cadastre uma assinatura primeiro.", systemImage: "info.circle")
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

            TextField("Nome do grupo", text: $groupName)

            Picker("Assinatura", selection: $selectedSubscriptionId) {
                Text(creationViewModel.subscriptions.isEmpty ? "Nenhuma assinatura disponível" : "Selecione uma assinatura")
                    .tag(Optional<String>.none)
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

                Stepper(value: $billingDay, in: 1...31) {
                    Text("Dia de cobrança do grupo: \(billingDay)")
                }
            }

            Toggle("Dividir igualmente", isOn: $splitEqually)
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
        !members.isEmpty &&
        selectedSubscription != nil
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
                return copy
            }
    }

    private func deleteMember(at offsets: IndexSet) {
        members.remove(atOffsets: offsets)
    }

    private func applyEqualSplit() {
        guard !members.isEmpty else { return }
        let value = totalAmountValue / Double(members.count)
        members = members.map { member in
            var copy = member
            copy.amountText = formatAmount(value)
            return copy
        }
        members.forEach { memberValues[$0.id] = value }
    }

    private func updateSelectedSubscription() {
        guard let subscription = selectedSubscription else {
            totalAmountValue = 0
            currencyCode = "BRL"
            billingPeriodLabel = ""
            billingDay = 1
            return
        }

        totalAmountValue = subscription.amount
        currencyCode = subscription.currencyCode
        billingPeriodLabel = subscription.period.label
        billingDay = Calendar.current.component(.day, from: subscription.nextBillingDate)
        if groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            groupName = subscription.name
        }
        updateSplitAmounts()
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
        guard !members.isEmpty else { return 0 }
        return totalAmountValue / Double(members.count)
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
                    Text("Compartilhe o link com os membros do grupo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    ShareLink(item: message) {
                        Label("Compartilhar convite", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        UIPasteboard.general.string = message
                        setCopiedState(type: .message)
                    } label: {
                        Label(
                            didCopyMessage ? "Copiado" : "Copiar mensagem",
                            systemImage: didCopyMessage ? "checkmark" : "doc.on.doc"
                        )
                    }

                    Button {
                        UIPasteboard.general.string = token
                        setCopiedState(type: .token)
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
                try? await subscriptionsStore.createSubscription(userId: ownerId, data: data)
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
