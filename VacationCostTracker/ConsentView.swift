import SwiftUI

struct ConsentView: View {
    let onConsent: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 90, height: 90)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 10) {
                    Text("Before You Begin")
                        .font(.title2.bold())

                    Text("VacationCostTracker connects to your bank via Plaid to automatically import transactions and track your travel spending.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    consentPoint(
                        icon: "lock.shield.fill",
                        color: .green,
                        title: "Your data stays private",
                        detail: "Transaction data is used only to display your expenses. It is never sold or shared with third parties."
                    )
                    consentPoint(
                        icon: "iphone",
                        color: .blue,
                        title: "On-device display only",
                        detail: "Your financial data is shown only to you within this app."
                    )
                    consentPoint(
                        icon: "hand.raised.fill",
                        color: .orange,
                        title: "You are in control",
                        detail: "You can disconnect your bank at any time from the app settings."
                    )
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onConsent) {
                    Text("I Understand, Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Text("By continuing, you consent to the collection and processing of your financial data as described above. View our [Privacy Policy](https://pruta1.github.io/VacationExpenseTracker/).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func consentPoint(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
