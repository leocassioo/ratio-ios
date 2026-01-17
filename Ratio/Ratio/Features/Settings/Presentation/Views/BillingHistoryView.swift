//
//  BillingHistoryView.swift
//  Ratio
//
//  Created by Codex on 16/02/26.
//

import SwiftUI
import FirebaseAuth

struct BillingHistoryView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = BillingHistoryViewModel()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
            } else if let message = viewModel.errorMessage, viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Sem histórico ainda")
                        .font(.headline)
                    Text("Assim que houver cobranças, elas aparecerão aqui.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        summaryCards
                        ForEach(groupedItems, id: \.monthStart) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)

                                ForEach(section.items) { item in
                                    historyCard(item)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Histórico")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let userId = authViewModel.user?.uid {
                viewModel.startListening(userId: userId)
                viewModel.loadAnnualEstimate(userId: userId)
            }
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }

    private func historyCard(_ item: BillingHistoryItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(item.type.label) • \(formattedDate(item.occurredAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedCurrency(item.amount, currencyCode: item.currencyCode))
                .font(.subheadline.weight(.semibold))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(borderOpacity), lineWidth: 1)
        )
    }

    private var groupedItems: [(monthStart: Date, title: String, items: [BillingHistoryItem])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: viewModel.items) { item in
            calendar.date(from: calendar.dateComponents([.year, .month], from: item.occurredAt)) ?? item.occurredAt
        }

        return grouped
            .map { (monthStart: $0.key, items: $0.value) }
            .sorted { $0.monthStart > $1.monthStart }
            .map { entry in
                (
                    monthStart: entry.monthStart,
                    title: formatter.string(from: entry.monthStart).capitalized,
                    items: entry.items
                )
            }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(title: "Assinaturas", value: subscriptionSummaryText())
            summaryCard(title: "Estimativa anual", value: formattedAnnualEstimate())
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator).opacity(borderOpacity), lineWidth: 1)
        )
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }

    private var borderOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.2
    }

    private func subscriptionSummaryText() -> String {
        guard let primaryCurrency = viewModel.items.first?.currencyCode else {
            return "R$ 0,00/mês"
        }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let monthlyTotal = viewModel.items
            .filter { $0.currencyCode == primaryCurrency && $0.occurredAt >= cutoff }
            .reduce(0) { $0 + $1.amount }
        return "\(formattedCurrency(monthlyTotal, currencyCode: primaryCurrency))/mês"
    }

    private func formattedAnnualEstimate() -> String {
        formattedCurrency(viewModel.annualEstimateAmount, currencyCode: viewModel.annualEstimateCurrency)
    }

    private func formattedCurrency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0,00"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        BillingHistoryView()
            .environmentObject(AuthViewModel())
    }
}
