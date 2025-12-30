//
//  KeyValueRow.swift
//  optimize
//
//  Simple key-value row for displaying file attributes
//

import SwiftUI

struct KeyValueRow: View {
    let key: String
    let value: String
    var valueColor: Color = .primary
    var icon: String? = nil

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }

            Text(key)
                .font(.appBody)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.appBodyMedium)
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Section of Key Value Rows
struct KeyValueSection: View {
    let rows: [(key: String, value: String, icon: String?)]

    init(_ rows: [(String, String, String?)]) {
        self.rows = rows.map { (key: $0.0, value: $0.1, icon: $0.2) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                KeyValueRow(
                    key: row.key,
                    value: row.value,
                    icon: row.icon
                )

                if index < rows.count - 1 {
                    Divider()
                        .padding(.leading, row.icon != nil ? 28 : 0)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        GlassCard {
            VStack(spacing: 0) {
                KeyValueRow(key: "Sayfa", value: "84", icon: "doc.text")
                Divider()
                KeyValueRow(key: "Tür", value: "PDF", icon: "doc.fill")
                Divider()
                KeyValueRow(key: "Görsel sayısı", value: "42", icon: "photo")
            }
        }

        GlassCard {
            KeyValueSection([
                ("Sayfa", "84", "doc.text"),
                ("Görsel yoğunluğu", "Yüksek", "photo.stack"),
                ("DPI", "300", "viewfinder")
            ])
        }
    }
    .padding()
}
