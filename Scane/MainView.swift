//
//  ContentView.swift
//  Scane
//
//  Created by Matt Adam on 2021-11-29.
//

import SwiftUI

struct MainView: View {
    
    @ObservedObject
    var manager: ScanManager
    
    @State
    var previewImage: CGImage?
    
    @State var error: ErrorDefinition?
    @State var batchCount = 1
    @State var optionFilter = ""

    private var visibleOptions: [IScanOption] {
        let query = optionFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return manager.options.filter(\.isActive) }
        return manager.options.filter { option in
            option.isActive &&
            (option.name.localizedCaseInsensitiveContains(query) ||
             (option as? ScanOption<Bool>)?.title.localizedCaseInsensitiveContains(query) == true ||
             (option as? ScanOption<Int>)?.title.localizedCaseInsensitiveContains(query) == true ||
             (option as? ScanOption<Double>)?.title.localizedCaseInsensitiveContains(query) == true ||
             (option as? ScanOption<String>)?.title.localizedCaseInsensitiveContains(query) == true ||
             (option as? ScanButtonOption)?.title.localizedCaseInsensitiveContains(query) == true)
        }
    }
    
    func doInit() {
        Task {
            do {
                try await manager.initDevice()
            }
            catch {
                self.error = ErrorDefinition(error, "An error occurred initializing scanners")
            }
        }
    }

    func preview() {
        
        #if DEBUG
        if CGKeyCode.optionKeyPressed {
            previewImage = NSImage(named: "AppIcon")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            return;
        }
        #endif

        Task {
            do {
                let image = try await manager.scan(preview: true)
                previewImage = image
            }
            catch {
                self.error = ErrorDefinition(error, "An error occurred while preview scanning")
            }
        }
    }
    
    func scan() {
        
        #if DEBUG
        if CGKeyCode.optionKeyPressed {
            let cgImage = NSImage(named: "AppIcon")!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            let view = ScannedImageView(image: cgImage)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled, .closable], backing: .buffered, defer: false, content: view)
            window.title = "Scanned Image"
            window.makeKeyAndOrderFront(nil)
            window.center()
            return;
        }
        #endif

        Task {
            let image: CGImage
            do {
                image = try await manager.scan(preview: false)
            }
            catch {
                self.error = ErrorDefinition(error, "An error occurred while scanning")
                return
            }

            let view = ScannedImageView(image: image)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled, .closable], backing: .buffered, defer: false, content: view)
            window.title = "Scanned Image"
            window.makeKeyAndOrderFront(nil)
            window.center()
        }
    }

    func batchScan() {
        let count = max(1, batchCount)
        Task {
            for page in 1...count {
                do {
                    let image = try await manager.scan(preview: false)
                    let view = ScannedImageView(image: image)
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                                          styleMask: [.titled, .closable],
                                          backing: .buffered,
                                          defer: false,
                                          content: view)
                    window.title = "Scan \(page) of \(count)"
                    window.makeKeyAndOrderFront(nil)
                    window.center()
                }
                catch {
                    self.error = ErrorDefinition(error, "Batch scan failed on page \(page)")
                    break
                }
            }
        }
    }

    var body: some View {
        
        let isActive = manager.isScanning || manager.isLoading
        
        NavigationView {
            
            // Left column
            VStack(spacing: 0) {
                
                if let deviceInfo = manager.deviceInfo {
                    Text("\(deviceInfo.vendor) \(deviceInfo.model)")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                }
                
                HStack(spacing: 6) {
                    TextField("Filter options", text: $optionFilter)
                        .textFieldStyle(.roundedBorder)
                    if !optionFilter.isEmpty {
                        Button("Clear") { optionFilter = "" }
                            .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(ScanOptionSection.allCases) { section in
                            let sectionOptions = visibleOptions.filter { $0.section == section }
                            if !sectionOptions.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(section.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    ForEach(sectionOptions, id: \.name) { option in
                                        ScanOptionView(
                                            option: option,
                                            resetAction: { manager.reset(option: option) }
                                        )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        }
                        if visibleOptions.isEmpty {
                            Text("No active options match this filter.")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .disabled(isActive)

                Divider()

                HStack {
                    TextField("Profile", text: $manager.profileName)
                    Button("Save") { manager.saveProfile() }
                    Button("Load") { manager.loadProfile() }
                }
                .disabled(isActive)
                .padding(.top, 8)

                HStack {
                    Stepper("Pages: \(batchCount)", value: $batchCount, in: 1...100)
                    Button("Batch") { self.batchScan() }
                }
                .disabled(isActive)
                .padding(.top, 6)
                
                HStack {
                    if manager.canPreview {
                        Button(action: self.preview) {
                            Text("Preview")
                                .frame(width: 80)
                        }
                    }
                    
                    Button(action: self.scan) {
                        Text("Scan")
                            .frame(width: 80)
                    }
                }
                .disabled(isActive)
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
            .frame(minWidth: 360, idealWidth: 400, maxWidth: 460)

            // Right panel
            ZStack {
                if let previewImage = previewImage {
                    PreviewView(image: previewImage, manager: manager)
                        .disabled(isActive)
                        .overlay(Rectangle().fill(Color.black).opacity(isActive ? 0.5 : 0.0))
                }
                
                if manager.isLoading {
                    Spinner()
                }

                if manager.isScanning {
                    ScanProgressView(pct: manager.scanProgress)
                }
            }
        }
        .onAppear(perform: { doInit() })
        .alert(item: $error, content: { error in error.toAlert() })
        .alert("Scanner error", isPresented: Binding(
            get: { manager.lastError != nil },
            set: { if !$0 { manager.lastError = nil } }
        )) {
            Button("OK") { manager.lastError = nil }
        } message: {
            Text(manager.lastError ?? "")
        }
    }
}
