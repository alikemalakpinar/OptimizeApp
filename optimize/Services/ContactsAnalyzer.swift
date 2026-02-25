//
//  ContactsAnalyzer.swift
//  optimize
//
//  Analyzes the user's contacts to find cleanup opportunities.
//  Uses Contacts framework to detect:
//  - Duplicate contacts (fuzzy name matching via Levenshtein distance)
//  - Duplicate phone numbers (normalized: stripped spaces/dashes/country codes)
//  - Nameless contacts (only number or email, no name)
//  - Empty contacts (no useful information at all)
//
//  INTELLIGENCE:
//  - Levenshtein distance for fuzzy name matching (catches typos)
//  - Phone normalization: strips +90, +1, spaces, dashes, parentheses
//  - Cross-field duplicate detection (same phone across different names)
//
//  PRIVACY: Only reads contact metadata - never modifies without user action.
//

import Contacts
import Foundation

// MARK: - Contact Cleanup Models

struct ContactCleanupItem: Identifiable {
    let id: String
    let contact: CNContact
    let reason: ContactIssue

    var displayName: String {
        let name = CNContactFormatter.string(from: contact, style: .fullName)
        return name ?? contact.phoneNumbers.first?.value.stringValue ?? contact.emailAddresses.first?.value as String? ?? "İsimsiz Kişi"
    }

    var detail: String {
        switch reason {
        case .duplicate(let matchName):
            return "\"\(matchName)\" ile tekrar"
        case .phoneDuplicate(let matchName):
            return "\"\(matchName)\" ile aynı numara"
        case .nameless:
            if let phone = contact.phoneNumbers.first?.value.stringValue {
                return phone
            } else if let email = contact.emailAddresses.first?.value as String? {
                return email
            }
            return "Bilgi yok"
        case .noPhoneOrEmail:
            return "Telefon veya e-posta yok"
        }
    }
}

enum ContactIssue {
    case duplicate(matchName: String)
    case phoneDuplicate(matchName: String)
    case nameless
    case noPhoneOrEmail
}

struct ContactAnalysisResult {
    let duplicates: [ContactCleanupItem]
    let namelessContacts: [ContactCleanupItem]
    let noInfoContacts: [ContactCleanupItem]
    let totalCount: Int

    var totalIssueCount: Int {
        duplicates.count + namelessContacts.count + noInfoContacts.count
    }

    static let empty = ContactAnalysisResult(
        duplicates: [],
        namelessContacts: [],
        noInfoContacts: [],
        totalCount: 0
    )
}

// MARK: - Contacts Analyzer

@MainActor
final class ContactsAnalyzer: ObservableObject {

    @Published var state: AnalysisState = .idle
    @Published var progress: Double = 0

    enum AnalysisState: Equatable {
        case idle
        case analyzing
        case completed(ContactAnalysisResult)
        case permissionDenied
        case error(String)

        static func == (lhs: AnalysisState, rhs: AnalysisState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.analyzing, .analyzing), (.permissionDenied, .permissionDenied):
                return true
            case (.completed(let a), .completed(let b)):
                return a.totalIssueCount == b.totalIssueCount
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    private let store = CNContactStore()

    /// Levenshtein distance threshold for fuzzy name matching.
    /// Names with distance <= this are considered duplicates.
    private let fuzzyThreshold = 2

    // MARK: - Public API

    func analyze() async {
        state = .analyzing
        progress = 0

        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined {
            do {
                let granted = try await store.requestAccess(for: .contacts)
                guard granted else {
                    state = .permissionDenied
                    return
                }
            } catch {
                state = .permissionDenied
                return
            }
        } else if status != .authorized {
            state = .permissionDenied
            return
        }

        do {
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName)
            ]

            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var allContacts: [CNContact] = []

            try store.enumerateContacts(with: request) { contact, _ in
                allContacts.append(contact)
            }

            progress = 0.2

            // Find duplicates (fuzzy name matching + phone number matching)
            let nameDuplicates = findFuzzyNameDuplicates(allContacts)
            progress = 0.5

            let phoneDuplicates = findPhoneDuplicates(allContacts)
            progress = 0.7

            // Merge name and phone duplicates, avoiding double-counting
            let existingDuplicateIDs = Set(nameDuplicates.map(\.id))
            let uniquePhoneDuplicates = phoneDuplicates.filter { !existingDuplicateIDs.contains($0.id) }
            let allDuplicates = nameDuplicates + uniquePhoneDuplicates

            // Find nameless contacts
            let nameless = findNameless(allContacts)
            progress = 0.85

            // Find contacts with no phone or email
            let noInfo = findNoInfo(allContacts)
            progress = 1.0

            let result = ContactAnalysisResult(
                duplicates: allDuplicates,
                namelessContacts: nameless,
                noInfoContacts: noInfo,
                totalCount: allContacts.count
            )

            state = .completed(result)
        } catch {
            state = .error("Rehber analizi başarısız: \(error.localizedDescription)")
        }
    }

    /// Delete a contact
    func deleteContact(_ contact: CNContact) -> Bool {
        let saveRequest = CNSaveRequest()
        guard let mutableContact = contact.mutableCopy() as? CNMutableContact else { return false }
        saveRequest.delete(mutableContact)
        do {
            try store.execute(saveRequest)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Fuzzy Name Duplicate Detection

    /// Find duplicates using Levenshtein distance for fuzzy name matching.
    /// Catches typos like "Ali Veli" vs "Ali Velı" or "Ahmet Yılmaz" vs "Ahmet Yilmaz".
    private func findFuzzyNameDuplicates(_ contacts: [CNContact]) -> [ContactCleanupItem] {
        // Build array of (contact, normalizedName)
        var namedContacts: [(contact: CNContact, name: String)] = []

        for contact in contacts {
            let fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            let trimmed = fullName.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let normalized = trimmed.lowercased()
                .folding(options: .diacriticInsensitive, locale: Locale(identifier: "tr"))
            namedContacts.append((contact, normalized))
        }

        var duplicates: [ContactCleanupItem] = []
        var visited = Set<String>()

        for i in 0..<namedContacts.count {
            guard !visited.contains(namedContacts[i].contact.identifier) else { continue }

            var group: [CNContact] = [namedContacts[i].contact]

            for j in (i+1)..<namedContacts.count {
                guard !visited.contains(namedContacts[j].contact.identifier) else { continue }

                let distance = levenshteinDistance(namedContacts[i].name, namedContacts[j].name)

                // Exact match or within fuzzy threshold
                if distance <= fuzzyThreshold {
                    group.append(namedContacts[j].contact)
                    visited.insert(namedContacts[j].contact.identifier)
                }
            }

            if group.count >= 2 {
                visited.insert(namedContacts[i].contact.identifier)
                let displayName = CNContactFormatter.string(from: group[0], style: .fullName) ?? "Bilinmeyen"
                for contact in group.dropFirst() {
                    duplicates.append(ContactCleanupItem(
                        id: contact.identifier,
                        contact: contact,
                        reason: .duplicate(matchName: displayName)
                    ))
                }
            }
        }

        return duplicates
    }

    // MARK: - Phone Number Duplicate Detection

    /// Find contacts with the same normalized phone number.
    /// Normalization strips spaces, dashes, parentheses, and common country code prefixes.
    private func findPhoneDuplicates(_ contacts: [CNContact]) -> [ContactCleanupItem] {
        var phoneGroups: [String: [CNContact]] = [:]

        for contact in contacts {
            for phoneNumber in contact.phoneNumbers {
                let normalized = normalizePhoneNumber(phoneNumber.value.stringValue)
                guard normalized.count >= 7 else { continue } // Skip too-short numbers
                phoneGroups[normalized, default: []].append(contact)
            }
        }

        var duplicates: [ContactCleanupItem] = []
        var seen = Set<String>()

        for (_, group) in phoneGroups where group.count >= 2 {
            // Deduplicate: same contact can appear for multiple numbers
            let unique = group.filter { seen.insert($0.identifier).inserted || !seen.contains($0.identifier) }
            guard unique.count >= 2 else { continue }

            let displayName = CNContactFormatter.string(from: unique[0], style: .fullName)
                ?? unique[0].phoneNumbers.first?.value.stringValue ?? "Bilinmeyen"

            for contact in unique.dropFirst() {
                guard !seen.contains("dup_\(contact.identifier)") else { continue }
                seen.insert("dup_\(contact.identifier)")
                duplicates.append(ContactCleanupItem(
                    id: contact.identifier,
                    contact: contact,
                    reason: .phoneDuplicate(matchName: displayName)
                ))
            }
        }

        return duplicates
    }

    // MARK: - Phone Number Normalization

    /// Normalize a phone number by stripping formatting and common country code prefixes.
    /// "+90 (532) 123-45 67" → "5321234567"
    private func normalizePhoneNumber(_ raw: String) -> String {
        // Strip all non-digit characters
        var digits = raw.filter(\.isNumber)

        // Strip common country code prefixes
        let countryPrefixes = ["90", "1", "44", "49", "33", "39", "34", "81", "86", "91", "7"]
        for prefix in countryPrefixes {
            if digits.hasPrefix(prefix) && digits.count > prefix.count + 9 {
                digits = String(digits.dropFirst(prefix.count))
                break
            }
        }

        // Also handle leading 0 for domestic numbers
        if digits.hasPrefix("0") && digits.count > 10 {
            digits = String(digits.dropFirst())
        }

        return digits
    }

    // MARK: - Levenshtein Distance

    /// Compute the Levenshtein (edit) distance between two strings.
    /// Used for fuzzy name matching to catch typos and minor variations.
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count

        // Quick checks
        if m == 0 { return n }
        if n == 0 { return m }
        if s1 == s2 { return 0 }

        // Use single-row optimization for O(n) space
        var previousRow = Array(0...n)
        var currentRow = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            currentRow[0] = i

            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                currentRow[j] = min(
                    currentRow[j - 1] + 1,       // insertion
                    previousRow[j] + 1,           // deletion
                    previousRow[j - 1] + cost     // substitution
                )
            }

            previousRow = currentRow
        }

        return previousRow[n]
    }

    // MARK: - Nameless & No-Info Detection

    private func findNameless(_ contacts: [CNContact]) -> [ContactCleanupItem] {
        contacts.compactMap { contact in
            let givenName = contact.givenName.trimmingCharacters(in: .whitespaces)
            let familyName = contact.familyName.trimmingCharacters(in: .whitespaces)

            guard givenName.isEmpty && familyName.isEmpty else { return nil }

            let hasPhone = !contact.phoneNumbers.isEmpty
            let hasEmail = !contact.emailAddresses.isEmpty
            guard hasPhone || hasEmail else { return nil }

            return ContactCleanupItem(
                id: contact.identifier,
                contact: contact,
                reason: .nameless
            )
        }
    }

    private func findNoInfo(_ contacts: [CNContact]) -> [ContactCleanupItem] {
        contacts.compactMap { contact in
            let givenName = contact.givenName.trimmingCharacters(in: .whitespaces)
            let familyName = contact.familyName.trimmingCharacters(in: .whitespaces)
            let hasPhone = !contact.phoneNumbers.isEmpty
            let hasEmail = !contact.emailAddresses.isEmpty

            guard givenName.isEmpty && familyName.isEmpty && !hasPhone && !hasEmail else { return nil }

            return ContactCleanupItem(
                id: contact.identifier,
                contact: contact,
                reason: .noPhoneOrEmail
            )
        }
    }
}
