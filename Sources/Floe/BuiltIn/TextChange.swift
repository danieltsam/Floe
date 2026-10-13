//
//  TextChange.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import CryptoKit
import Foundation

/// `base64 hello`: a text in another form. The word alone works on what is on the clipboard.
nonisolated enum TextChange: String, CaseIterable, Sendable {
    case base64, unbase64, urlencode, urldecode, uppercase, lowercase, titlecase, sha256

    /// Longer than this is left alone: the row shows one line of it.
    static let longest = 100_000

    var kind: String {
        switch self {
        case .base64: "Base64"
        case .unbase64: String(localized: "From Base64", bundle: .floe, comment: "The kind of a result, shown beside its title. Base64 is a way of writing data as text.")
        case .urlencode: String(localized: "URL Encoded", bundle: .floe, comment: "The kind of a result, shown beside its title.")
        case .urldecode: String(localized: "URL Decoded", bundle: .floe, comment: "The kind of a result, shown beside its title.")
        case .uppercase: String(localized: "Uppercase", bundle: .floe, comment: "The kind of a result, shown beside its title.")
        case .lowercase: String(localized: "Lowercase", bundle: .floe, comment: "The kind of a result, shown beside its title.")
        case .titlecase: String(localized: "Title Case", bundle: .floe, comment: "The kind of a result, shown beside its title.")
        case .sha256: "SHA-256"
        }
    }

    /// Nil when the text cannot be read that way, such as text that is not Base64.
    func applied(to text: String) -> String? {
        switch self {
        case .base64: Data(text.utf8).base64EncodedString()
        case .unbase64: Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { String(data: $0, encoding: .utf8) }
        case .urlencode: text.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~")))
        case .urldecode: text.removingPercentEncoding
        case .uppercase: text.uppercased()
        case .lowercase: text.lowercased()
        case .titlecase: text.capitalized
        case .sha256: SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
        }
    }

    func row(for text: String) -> AnswerRow? {
        guard !text.isEmpty, text.count <= Self.longest, let changed = applied(to: text), !changed.isEmpty else { return nil }
        return AnswerRow(id: rawValue, text: changed, kind: kind, symbol: "textformat.alt")
    }
}
