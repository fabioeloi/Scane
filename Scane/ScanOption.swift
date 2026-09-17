//
//  ScanOption.swift
//  Scane
//
//  Created by Matt Adam on 2022-01-20.
//

import SwiftUI
import SaneKit


protocol ScanOptionValue: SANEActionValue, Equatable {
    static func createValue(with descriptor: SANEOptionDescriptor) -> Self
    static func getOptions(for descriptor: SANEOptionDescriptor) -> [Self]?
}

extension ScanOptionValue {
    static func createValue(with descriptor: SANEOptionDescriptor) -> Self {
        return Self()
    }
    static func getOptions(for descriptor: SANEOptionDescriptor) -> [Self]? { [] }
}

extension SANEActionValue {
    @SANEActor
    mutating func controlOption(handle: SANEHandle, index: Int, action: SANEAction) throws {
        try saneControlOption(handle: handle, n: index, action: action, value: &self)
    }
}

extension Bool: ScanOptionValue {}

extension Int: ScanOptionValue {
    static func getOptions(for descriptor: SANEOptionDescriptor) -> [Self]? {
        if case .intList(let list) = descriptor.constraint {
            return list
        }
        return nil
    }
}

extension Double: ScanOptionValue {
    static func getOptions(for descriptor: SANEOptionDescriptor) -> [Self]? {
        if case .fixedList(let list) = descriptor.constraint {
            return list
        }
        return nil
    }
}

extension String: ScanOptionValue {
    static func createValue(with descriptor: SANEOptionDescriptor) -> Self {
        return String(repeating: " ", count: descriptor.size + 1)
    }

    static func getOptions(for descriptor: SANEOptionDescriptor) -> [Self]? {
        if case .stringList(let list) = descriptor.constraint {
            return list
        }
        return nil
    }
}

// Normally this would be a protocol, but it must be a class in order to implement ObservableObject
@MainActor
class IScanOption: ObservableObject {
    let name: String
    let index: Int
    let section: ScanOptionSection
    var isActive: Bool { true }

    func update(handle: SANEHandle, updateDescriptor: Bool) async throws {}
    func reset(handle: SANEHandle) async throws {}
    var serializedValue: String? { nil }
    func apply(serializedValue: String, handle: SANEHandle) async throws {}

    var userSelectedValue: SANEActionValue { 0 }
    var minimumPossibleValue: SANEActionValue? { nil }

    fileprivate init(name: String, index: Int, section: ScanOptionSection) {
        self.name =  name
        self.index = index
        self.section = section
    }
}

enum ScanOptionSection: String, CaseIterable, Identifiable {
    case basic = "Basic"
    case geometry = "Geometry"
    case advanced = "Advanced"
    case calibration = "Calibration / Device"

    var id: String { rawValue }
}

@MainActor
class ScanOption<T: ScanOptionValue>: IScanOption {
    
    @Published var title: String
    @Published var options: [T]?

    var value: Binding<T> {
        Binding<T>(
            get: {
                self.value_
            },
            set: { newValue in
                self.objectWillChange.send()
                self.value_ = newValue
                
                Task {
                    await self.scanManager?.setValue(index: self.index, value: newValue)
                }
            }
        )
    }

    var type: SANEValueType { descriptor.type }
    override var isActive: Bool { descriptor.cap.isActive }

    fileprivate var descriptor: SANEOptionDescriptor
    private var value_: T
    private weak var scanManager: ScanManager?

    init(descriptor: SANEOptionDescriptor, index: Int, section: ScanOptionSection, scanManager: ScanManager, initialVale: T = T()) {
        self.descriptor = descriptor
        self.title = descriptor.title
        self.options = T.getOptions(for: descriptor)
        self.value_ = initialVale
        self.scanManager = scanManager
        super.init(name: descriptor.name, index: index, section: section)
    }
    
    override var userSelectedValue: SANEActionValue {
        return self.value_
    }
    
    override var minimumPossibleValue: SANEActionValue? {
        switch self.descriptor.constraint {
        case .intRange(range: let range):
            return range.min
        case .fixedRange(range: let range):
            return range.min
        case .intList(list: let list):
            return list.min()
        case .fixedList(list: let list):
            return list.min()
        case .stringList(list: let list):
            return list.min()
        default:
            return nil
        }
    }

    override func update(handle: SANEHandle, updateDescriptor: Bool) async throws {
        let descriptor = updateDescriptor ? self.descriptor : try await saneGetOptionDescriptor(handle: handle, n: index)
        var newValue = T()
        
        if descriptor.cap.isActive {
            newValue = T.createValue(with: descriptor)
            try await saneControlOption(handle: handle, n: index, action: .getValue, value: &newValue)
        }
        
        // active
        if descriptor.cap.isActive != self.descriptor.cap.isActive || newValue != self.value_ {
            self.objectWillChange.send()
            self.value_ = newValue
            self.descriptor = descriptor
        }
    }

    override func reset(handle: SANEHandle) async throws {
        var value = self.value_
        try saneControlOption(handle: handle, n: index, action: .setAuto, value: &value)
        try await update(handle: handle, updateDescriptor: false)
    }

    override var serializedValue: String? {
        String(describing: value_)
    }

    override func apply(serializedValue: String, handle: SANEHandle) async throws {
        let converted: T?
        switch T.self {
        case is Bool.Type:
            converted = (serializedValue as NSString).boolValue as? T
        case is Int.Type:
            converted = Int(serializedValue) as? T
        case is Double.Type:
            converted = Double(serializedValue) as? T
        case is String.Type:
            converted = serializedValue as? T
        default:
            converted = nil
        }
        guard let converted else { return }
        var value = converted
        try saneControlOption(handle: handle, n: index, action: .setValue, value: &value)
        try await update(handle: handle, updateDescriptor: false)
    }
}

@MainActor
final class ScanButtonOption: IScanOption {
    let title: String
    let desc: String
    private weak var scanManager: ScanManager?

    init(descriptor: SANEOptionDescriptor, index: Int, section: ScanOptionSection, scanManager: ScanManager) {
        self.title = descriptor.title
        self.desc = descriptor.desc
        self.scanManager = scanManager
        super.init(name: descriptor.name, index: index, section: section)
    }

    override var isActive: Bool { true }

    func activate() {
        Task {
            await scanManager?.activateButton(index: index)
        }
    }
}
