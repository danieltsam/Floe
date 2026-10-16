//
//  PointerRestTests.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import CoreGraphics
@testable import Floe
import Testing

struct PointerRestTests {
    @Test func aPointerThatNeverRestedMarksRows() {
        #expect(PointerRest().hasMoved(to: .zero))
    }

    @Test func aRestingPointerMarksNoRowUntilItMovesMoreThanTheSlack() {
        let rest = PointerRest()
        rest.rest(at: CGPoint(x: 100, y: 100))
        #expect(!rest.hasMoved(to: CGPoint(x: 100, y: 100)), "a row slid under the pointer")
        #expect(!rest.hasMoved(to: CGPoint(x: 101, y: 101)))
        #expect(rest.hasMoved(to: CGPoint(x: 103, y: 100)))
        #expect(rest.hasMoved(to: CGPoint(x: 100, y: 100)), "once moved, it stays moved until the next rest")

        rest.rest(at: CGPoint(x: 100, y: 100))
        #expect(!rest.hasMoved(to: CGPoint(x: 100, y: 100)))
    }
}
