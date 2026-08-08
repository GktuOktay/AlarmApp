import SwiftUI

/// Single reusable onboarding page: icon + localized title + localized body.
struct OnboardingPageView: View {
    let systemImage: String
    let titleKey: LocalizedStringKey
    let bodyKey: LocalizedStringKey

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 72, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(height: 96)

            Text(titleKey)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(bodyKey)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingPageView(
        systemImage: "bell.and.waves.left.and.right",
        titleKey: "onboarding.page1.title",
        bodyKey: "onboarding.page1.body"
    )
}
