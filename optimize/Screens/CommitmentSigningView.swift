//
//  CommitmentSigningView.swift
//  optimize
//
//  Commitment signing screen with checkboxes and signature canvas
//

import SwiftUI

struct CommitmentSigningView: View {
    @State private var commitments: [CommitmentItem] = [
        CommitmentItem(text: AppStrings.Commitment.item1, isChecked: true),
        CommitmentItem(text: AppStrings.Commitment.item2, isChecked: true),
        CommitmentItem(text: AppStrings.Commitment.item3, isChecked: true),
        CommitmentItem(text: AppStrings.Commitment.item4, isChecked: true),
        CommitmentItem(text: AppStrings.Commitment.item5, isChecked: true)
    ]
    @State private var signature: [CGPoint] = []
    @State private var animateItems = false

    let onComplete: () -> Void

    var hasSignature: Bool {
        signature.count > 10 // Minimum points for a valid signature
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: Spacing.sm) {
                Text(AppStrings.Commitment.title)
                    .font(.system(size: 32, weight: .light, design: .serif))
                    .foregroundStyle(.white)

                Text(AppStrings.Commitment.subtitle)
                    .font(.appBody)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.bottom, Spacing.xl)

            // Commitment items
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(Array(commitments.enumerated()), id: \.element.id) { index, item in
                    CommitmentRow(item: item) {
                        Haptics.selection()
                        commitments[index].isChecked.toggle()
                    }
                    .opacity(animateItems ? 1 : 0)
                    .offset(x: animateItems ? 0 : -20)
                    .animation(
                        AppAnimation.spring.delay(Double(index) * 0.1),
                        value: animateItems
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Signature canvas
            VStack(spacing: Spacing.sm) {
                SignatureCanvasWithControls(
                    signature: $signature,
                    strokeColor: .white,
                    backgroundColor: Color.white.opacity(0.15)
                )
                .frame(height: 180)
                .padding(.horizontal, Spacing.lg)
            }

            Spacer()

            // Continue button
            VStack(spacing: Spacing.lg) {
                Button(action: {
                    Haptics.success()
                    onComplete()
                }) {
                    Text(AppStrings.Onboarding.continue)
                        .font(.appBodyMedium)
                        .foregroundStyle(Color.appAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.full, style: .continuous))
                }
                .buttonStyle(.pressable)
                .opacity(hasSignature ? 1 : 0.6)
                .disabled(!hasSignature)
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.bottom, Spacing.xl)
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
                animateItems = true
            }
        }
    }
}

// MARK: - Commitment Item Model
struct CommitmentItem: Identifiable {
    let id = UUID()
    var text: String
    var isChecked: Bool
}

// MARK: - Commitment Row
struct CommitmentRow: View {
    let item: CommitmentItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.md) {
                // Checkbox
                ZStack {
                    Circle()
                        .fill(item.isChecked ? Color.white : Color.clear)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        )

                    if item.isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.appAccent)
                    }
                }

                // Text
                Text(item.text)
                    .font(.appBody)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CommitmentSigningView {
        print("Commitment complete")
    }
}
