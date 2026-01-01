//
//  RatingRequestView.swift
//  optimize
//
//  Rating request screen with testimonials and App Store review trigger
//

import SwiftUI
import StoreKit

struct RatingRequestView: View {
    @State private var animateStars = false
    @State private var animateContent = false
    @State private var selectedReviewIndex = 0

    let onComplete: () -> Void

    private let testimonials: [Testimonial] = [
        Testimonial(
            name: "Mehmet K.",
            username: "@mehmetk",
            rating: 5,
            text: AppStrings.Rating.testimonial1,
            avatarColor: .blue
        ),
        Testimonial(
            name: "Ayşe D.",
            username: "@aysed_92",
            rating: 5,
            text: AppStrings.Rating.testimonial2,
            avatarColor: .purple
        ),
        Testimonial(
            name: "Ali Y.",
            username: "@aliy",
            rating: 5,
            text: AppStrings.Rating.testimonial3,
            avatarColor: .green
        ),
        Testimonial(
            name: "Zeynep S.",
            username: "@zeyneps",
            rating: 5,
            text: AppStrings.Rating.testimonial4,
            avatarColor: .orange
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Stars with laurel
            HStack(spacing: Spacing.md) {
                // Left laurel
                Image(systemName: "laurel.leading")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.8))
                    .scaleEffect(animateStars ? 1 : 0.5)
                    .opacity(animateStars ? 1 : 0)

                // Stars
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                            .scaleEffect(animateStars ? 1 : 0)
                            .opacity(animateStars ? 1 : 0)
                            .animation(
                                AppAnimation.bouncy.delay(Double(index) * 0.1),
                                value: animateStars
                            )
                    }
                }

                // Right laurel
                Image(systemName: "laurel.trailing")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.8))
                    .scaleEffect(animateStars ? 1 : 0.5)
                    .opacity(animateStars ? 1 : 0)
            }
            .animation(AppAnimation.spring.delay(0.3), value: animateStars)

            // Title
            Text(AppStrings.Rating.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, Spacing.md)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)

            // Description
            Text(AppStrings.Rating.description)
                .font(.appBody)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.sm)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)

            // User avatars
            HStack(spacing: -12) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [testimonials[index].avatarColor, testimonials[index].avatarColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(testimonials[index].name.prefix(1)))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.appAccent, lineWidth: 3)
                        )
                }

                Text(AppStrings.Rating.userCount)
                    .font(.appBodyMedium)
                    .foregroundStyle(.white)
                    .padding(.leading, Spacing.md)
            }
            .padding(.top, Spacing.lg)
            .opacity(animateContent ? 1 : 0)

            Spacer()

            // Testimonials
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(Array(testimonials.enumerated()), id: \.element.id) { index, testimonial in
                        TestimonialCard(testimonial: testimonial)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 30)
                            .animation(
                                AppAnimation.spring.delay(0.4 + Double(index) * 0.1),
                                value: animateContent
                            )
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .frame(height: 160)

            Spacer()

            // Next button
            Button(action: {
                Haptics.success()
                requestReview()
                onComplete()
            }) {
                Text(AppStrings.Rating.next)
                    .font(.appBodyMedium)
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.full, style: .continuous))
            }
            .buttonStyle(.pressable)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
            .opacity(animateContent ? 1 : 0)
        }
        .background(
            LinearGradient(
                colors: [Color.appAccent, Color.appAccent.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animateStars = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(AppAnimation.spring) {
                    animateContent = true
                }
            }
        }
    }

    private func requestReview() {
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

// MARK: - Testimonial Model
struct Testimonial: Identifiable {
    let id = UUID()
    let name: String
    let username: String
    let rating: Int
    let text: String
    let avatarColor: Color
}

// MARK: - Testimonial Card
struct TestimonialCard: View {
    let testimonial: Testimonial

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack(spacing: Spacing.sm) {
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [testimonial.avatarColor, testimonial.avatarColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(testimonial.name.prefix(1)))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(testimonial.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(testimonial.username)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // Stars
                HStack(spacing: 2) {
                    ForEach(0..<testimonial.rating, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.goldAccent)
                    }
                }
            }

            // Review text
            Text(testimonial.text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(Spacing.md)
        .frame(width: 260)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    RatingRequestView {
        print("Rating complete")
    }
}
