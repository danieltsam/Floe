//
//  SessionFormFieldTests.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

@testable import Floe
import Foundation
import Testing

@MainActor
struct SessionFormFieldTests {
    private let session = ExtensionSession(command: Fixture.command("planets"), arguments: [:])

    private func apply(_ json: [String: Any]) throws {
        var kept = KeptRender()
        let message = try #require(DecodedHostMessage.decode(JSONSerialization.data(withJSONObject: json), kept: &kept))
        session.apply(message)
    }

    @Test func aFieldsResetTakesAwayWhatWasTypedAndLeavesTheOtherFields() throws {
        session.formValues = ["subject": "typed", "body": "kept"]
        try apply(["type": "resetField", "id": "subject"])
        #expect(session.formValues["subject"] == nil)
        #expect(session.formValues["body"] as? String == "kept")
        try apply(["type": "resetField"])
        try apply(["type": "focusField", "id": "body"])
        #expect(session.formValues.count == 1, "a reset that names no field, and a focus, change nothing")
    }
}
