import SwiftUI

struct ClientInvoiceListView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var invoices: [InvoiceRow] = []
    @State private var isLoading = true
    @State private var selectedInvoice: InvoiceRow?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if invoices.isEmpty {
                    emptyState
                } else {
                    ForEach(invoices) { invoice in
                        invoiceCard(invoice)
                            .onTapGesture { selectedInvoice = invoice }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("My Invoices")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadInvoices() }
        .refreshable { await loadInvoices() }
        .sheet(item: $selectedInvoice) { invoice in
            ClientInvoiceDetailSheet(invoice: invoice)
        }
    }

    private func invoiceCard(_ invoice: InvoiceRow) -> some View {
        BentoCard(cornerRadius: 14) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AVIATheme.teal)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(invoice.invoice_number ?? "Invoice")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        if let desc = invoice.description {
                            Text(desc)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(invoice.formattedAmount)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        StatusBadge(title: invoice.displayStatus, color: statusColor(for: invoice.statusEnum))
                    }
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(16)

                if invoice.statusEnum == .sent || invoice.statusEnum == .overdue {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundStyle(invoice.statusEnum == .overdue ? AVIATheme.destructive : AVIATheme.warning)
                        Text("Due: \(invoice.formattedDueDate)")
                            .font(.neueCaption2)
                            .foregroundStyle(invoice.statusEnum == .overdue ? AVIATheme.destructive : AVIATheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(invoice.statusEnum == .overdue ? AVIATheme.destructive.opacity(0.05) : AVIATheme.cardBackgroundAlt)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Invoices")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)
            Text("You don't have any invoices yet.")
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func loadInvoices() async {
        isLoading = true
        defer { isLoading = false }
        invoices = await SupabaseService.shared.fetchInvoicesForClient(clientId: viewModel.currentUser.id)
    }

    private func statusColor(for status: InvoiceStatus) -> Color {
        switch status {
        case .draft: AVIATheme.textTertiary
        case .sent: AVIATheme.warning
        case .paid: AVIATheme.success
        case .overdue: AVIATheme.destructive
        case .cancelled: AVIATheme.textTertiary
        }
    }
}

// MARK: - Client Invoice Detail Sheet

struct ClientInvoiceDetailSheet: View {
    let invoice: InvoiceRow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Status header
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: invoice.statusEnum.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(headerColor)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(invoice.invoice_number ?? "Invoice")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Status: \(invoice.displayStatus)")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                            StatusBadge(title: invoice.displayStatus, color: headerColor)
                        }
                        .padding(16)
                    }

                    // Amount & Details
                    BentoCard(cornerRadius: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.teal)
                                Text("Invoice Details")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.teal)
                            }

                            detailRow("Amount", invoice.formattedAmount)

                            if let desc = invoice.description, !desc.isEmpty {
                                detailRow("Description", desc)
                            }

                            if invoice.due_date != nil {
                                detailRow("Due Date", invoice.formattedDueDate)
                            }

                            if let packagePrice = invoice.package_price {
                                detailRow("Package Price", String(format: "$%.2f", packagePrice))
                            }

                            if let paidAt = invoice.paid_at {
                                detailRow("Paid", formatDate(paidAt))
                            }

                            if let invoiceNum = invoice.invoice_number {
                                detailRow("Invoice #", invoiceNum)
                            }
                        }
                        .padding(16)
                    }

                    // Notes
                    if let notes = invoice.notes, !notes.isEmpty {
                        BentoCard(cornerRadius: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "note.text")
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.teal)
                                    Text("Notes")
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(AVIATheme.teal)
                                }
                                Text(notes)
                                    .font(.neueSubheadline)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            .padding(16)
                        }
                    }

                    // Payment info
                    if invoice.statusEnum == .sent || invoice.statusEnum == .overdue {
                        BentoCard(cornerRadius: 14) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.warning)
                                    Text("Payment")
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(AVIATheme.warning)
                                }
                                Text("Please contact your AVIA Homes representative to arrange payment. Your admin will mark this invoice as paid once received.")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            .padding(16)
                        }
                    }

                    if invoice.statusEnum == .paid {
                        BentoCard(cornerRadius: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(AVIATheme.success)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Invoice Paid")
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                    if let paidAt = invoice.paid_at {
                                        Text(formatDate(paidAt))
                                            .font(.neueCaption)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(16)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Invoice Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
        }
    }

    private var headerColor: Color {
        switch invoice.statusEnum {
        case .draft: AVIATheme.textTertiary
        case .sent: AVIATheme.warning
        case .paid: AVIATheme.success
        case .overdue: AVIATheme.destructive
        case .cancelled: AVIATheme.textTertiary
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
    }

    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else { return isoString }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

extension InvoiceRow: @retroactive Hashable {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: InvoiceRow, rhs: InvoiceRow) -> Bool {
        lhs.id == rhs.id
    }
}
