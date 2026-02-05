//
//  ContactsAnalyzer.swift
//  optimize
//
//  Analyzes the user's contacts to find cleanup opportunities.
//  Uses Contacts framework to detect:
//  - Duplicate contacts (same name or phone number)
//  - Nameless contacts (only number or email, no name)
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

    // MARK: - Public API

    func analyze() async {
        state = .analyzing
        progress = 0

        // Check permission
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

            progress = 0.3

            // Find duplicates (same full name)
            let duplicates = findDuplicates(allContacts)
            progress = 0.6

            // Find nameless contacts
            let nameless = findNameless(allContacts)
            progress = 0.8

            // Find contacts with no phone or email
            let noInfo = findNoInfo(allContacts)
            progress = 1.0

            let result = ContactAnalysisResult(
                duplicates: duplicates,
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

    // MARK: - Analysis Logic

    private func findDuplicates(_ contacts: [CNContact]) -> [ContactCleanupItem] {
        var nameGroups: [String: [CNContact]] = [:]

        for contact in contacts {
            let fullName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let normalized = fullName.lowercased().trimmingCharacters(in: .whitespaces)
            nameGroups[normalized, default: []].append(contact)
        }

        var duplicates: [ContactCleanupItem] = []
        for (_, group) in nameGroups where group.count >= 2 {
            // Keep the first, mark rest as duplicates
            let displayName = CNContactFormatter.string(from: group[0], style: .fullName) ?? "Bilinmeyen"
            for contact in group.dropFirst() {
                duplicates.append(ContactCleanupItem(
                    id: contact.identifier,
                    contact: contact,
                    reason: .duplicate(matchName: displayName)
                ))
            }
        }

        return duplicates
    }

    private func findNameless(_ contacts: [CNContact]) -> [ContactCleanupItem] {
        contacts.compactMap { contact in
            let givenName = contact.givenName.trimmingCharacters(in: .whitespaces)
            let familyName = contact.familyName.trimmingCharacters(in: .whitespaces)

            guard givenName.isEmpty && familyName.isEmpty else { return nil }

            // Must have at least a phone or email to be "nameless" (not "no info")
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

            // No name AND no contact info = empty/useless contact
            guard givenName.isEmpty && familyName.isEmpty && !hasPhone && !hasEmail else { return nil }

            return ContactCleanupItem(
                id: contact.identifier,
                contact: contact,
                reason: .noPhoneOrEmail
            )
        }
    }
}
