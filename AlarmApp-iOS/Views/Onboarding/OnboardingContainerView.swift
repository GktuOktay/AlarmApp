import SwiftUI
import AlarmAppCore

/// First-launch onboarding: 3-page paged flow introducing alarm groups,
/// bulk-dismiss, and Calendar bypass-days.
struct OnboardingContainerView: View {
    var onFinished: () -> Void

    @State private var page = 0
    private let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    onFinished()
                } label: {
                    Text("onboarding.skip")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            TabView(selection: $page) {
                OnboardingPageView(
                    systemImage: "bell.and.waves.left.and.right",
                    titleKey: "onboarding.page1.title",
                    bodyKey: "onboarding.page1.body"
                )
                .tag(0)

                OnboardingPageView(
                    systemImage: "checkmark.circle.badge.xmark",
                    titleKey: "onboarding.page2.title",
                    bodyKey: "onboarding.page2.body"
                )
                .tag(1)

                OnboardingPageView(
                    systemImage: "calendar.badge.minus",
                    titleKey: "onboarding.page3.title",
                    bodyKey: "onboarding.page3.body"
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < lastPage {
                    withAnimation { page += 1 }
                } else {
                    onFinished()
                }
            } label: {
                Text(page < lastPage ? "onboarding.next" : "onboarding.get_started")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.pill(tint: .accentColor))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
    }
}

#Preview {
    OnboardingContainerView(onFinished: {})
}
