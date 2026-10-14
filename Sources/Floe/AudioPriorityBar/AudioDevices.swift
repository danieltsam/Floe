//
//  AudioDevices.swift
//  Project: Audio Priority Bar
//
//  Copyright (Audio Priority Bar) © 2024 tobi, © 2026 Camille Guillory
//  Audio Priority Bar by Camille Guillory, https://github.com/camguillory/Audio-Priority-Bar
//  Licensed under the MIT License
//
//  Floe changes © 2026 René Jiménez, under the GNU AGPLv3.
//
//  Adapted for Floe from Audio Priority Bar's CoreAudioProperties.swift and Models.swift, and cut down:
//  Floe lists the devices and makes one the default, so the volume, the mute, the headphone and speaker
//  categories and the remembered devices are left out.

import AudioToolbox
import CoreAudio
import Foundation

nonisolated enum AudioRole: String, CaseIterable, Sendable {
    case input
    case output
}

/// One side of a sound device: a device that plays and records is two of these.
nonisolated struct AudioDevice: Identifiable, Equatable, Hashable, Sendable {
    let platformID: UInt32
    let uid: String
    let name: String
    let role: AudioRole
    /// Software routing device (Krisp, Zoom, a Multi-Output Device) rather than a physical endpoint.
    var isVirtual = false
    /// A monitor or TV reached over a video cable, from its transport type.
    var isDisplayOutput = false
    /// CoreAudio's kAudioDeviceTransportType* value. Zero when unknown.
    var transportType: UInt32 = 0

    var id: String {
        "\(role.rawValue):\(uid)"
    }

    var isBluetooth: Bool {
        transportType == kAudioDeviceTransportTypeBluetooth || transportType == kAudioDeviceTransportTypeBluetoothLE
    }
}

nonisolated enum AudioDevices {
    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static func devices() -> [AudioDevice] {
        deviceIDs().flatMap { id in
            AudioRole.allCases.compactMap { role in makeDevice(id: id, role: role) }
        }
    }

    static func deviceIDs() -> [AudioObjectID] {
        var address = property(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    static func defaultDevice(_ role: AudioRole) -> AudioObjectID? {
        var id = AudioObjectID(0)
        guard read(system, selector: selector(for: role), into: &id) == noErr, id != kAudioObjectUnknown else { return nil }
        return id
    }

    static func setDefault(_ id: AudioObjectID, role: AudioRole) -> Bool {
        var id = id
        return write(system, selector: selector(for: role), value: &id) == noErr
    }

    private static func selector(for role: AudioRole) -> AudioObjectPropertySelector {
        role == .input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    }

    private static func makeDevice(id: AudioObjectID, role: AudioRole) -> AudioDevice? {
        let scope = role == .input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
        guard !streams(id, scope: scope).isEmpty,
              let name = stringProperty(id, selector: kAudioDevicePropertyDeviceNameCFString),
              let uid = stringProperty(id, selector: kAudioDevicePropertyDeviceUID)
        else { return nil }
        let transport = transport(id)
        return AudioDevice(
            platformID: id,
            uid: uid,
            name: name,
            role: role,
            isVirtual: isVirtualTransport(transport),
            isDisplayOutput: role == .output && isDisplayTransport(transport),
            transportType: transport
        )
    }

    private static func transport(_ id: AudioObjectID) -> UInt32 {
        var transport = UInt32(0)
        guard read(id, selector: kAudioDevicePropertyTransportType, into: &transport) == noErr else { return kAudioDeviceTransportTypeUnknown }
        return transport
    }

    /// CoreAudio reports software devices as virtual or aggregate transports, which separates Krisp and
    /// Multi-Output from real hardware without matching on names.
    private static func isVirtualTransport(_ transport: UInt32) -> Bool {
        transport == kAudioDeviceTransportTypeVirtual || transport == kAudioDeviceTransportTypeAggregate
    }

    /// Sound reaching a monitor or TV over the video cable. The transport says so outright, which a product name cannot.
    static func isDisplayTransport(_ transport: UInt32) -> Bool {
        transport == kAudioDeviceTransportTypeHDMI || transport == kAudioDeviceTransportTypeDisplayPort
    }

    private static func streams(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> [AudioObjectID] {
        var address = property(kAudioDevicePropertyStreams, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var streams = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &streams) == noErr else { return [] }
        return streams
    }

    private static func stringProperty(_ id: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var value: Unmanaged<CFString>?
        var address = property(selector)
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    private static func read<T: BitwiseCopyable>(
        _ id: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        into value: inout T
    ) -> OSStatus {
        var address = property(selector, scope: scope)
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
    }

    private static func write<T: BitwiseCopyable>(_ id: AudioObjectID, selector: AudioObjectPropertySelector, value: inout T) -> OSStatus {
        var address = property(selector)
        return AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<T>.size), &value)
    }

    private static func property(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}
