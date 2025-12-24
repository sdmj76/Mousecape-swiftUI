//
//  EditOverlayView.swift
//  Mousecape
//
//  Edit overlay view that covers the main interface
//  Slides in from the right with animation
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Edit Detail View (for right panel only, with cursor list)

struct EditDetailView: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState
    @State private var showAddCursorSheet = false

    var body: some View {
        @Bindable var appState = appState

        HSplitView {
            // Left: Cursor list
            CursorListView(
                cape: cape,
                selection: $appState.editingSelectedCursor,
                onAddCursor: { showAddCursorSheet = true }
            )
            .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            // Right: Detail content
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minWidth: 300)
        }
        .onAppear {
            // Select first cursor when opening
            if appState.editingSelectedCursor == nil {
                appState.editingSelectedCursor = cape.cursors.first
            }
        }
        .sheet(isPresented: $showAddCursorSheet) {
            AddCursorSheet(cape: cape) { newCursor in
                appState.editingSelectedCursor = newCursor
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if appState.showCapeInfo {
            CapeInfoView(cape: cape)
        } else if let cursor = appState.editingSelectedCursor {
            CursorDetailView(cursor: cursor, cape: cape)
        } else {
            ContentUnavailableView(
                "Select a Cursor",
                systemImage: "cursorarrow.click",
                description: Text("Choose a cursor from the list to edit")
            )
        }
    }
}

// MARK: - Edit Overlay View (legacy, full screen)

struct EditOverlayView: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState
    @State private var showAddCursorSheet = false

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            // Left sidebar: Cursor list (same style as HomeView/SettingsView)
            CursorListView(
                cape: cape,
                selection: $appState.editingSelectedCursor,
                onAddCursor: { showAddCursorSheet = true }
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            // Right side: Content area
            detailContent
        }
        .onAppear {
            // Select first cursor when opening
            if appState.editingSelectedCursor == nil {
                appState.editingSelectedCursor = cape.cursors.first
            }
        }
        .sheet(isPresented: $showAddCursorSheet) {
            AddCursorSheet(cape: cape) { newCursor in
                appState.editingSelectedCursor = newCursor
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if appState.showCapeInfo {
            CapeInfoView(cape: cape)
        } else if let cursor = appState.editingSelectedCursor {
            CursorDetailView(cursor: cursor, cape: cape)
        } else {
            ContentUnavailableView(
                "Select a Cursor",
                systemImage: "cursorarrow.click",
                description: Text("Choose a cursor from the list to edit")
            )
        }
    }
}

// MARK: - Cape Info View (Metadata Editor)

struct CapeInfoView: View {
    @Bindable var cape: CursorLibrary
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cape metadata form
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cape Information")
                        .font(.headline)

                    LabeledContent("Name") {
                        TextField("Cape Name", text: Binding(
                            get: { cape.name },
                            set: { newValue in
                                let oldValue = cape.name
                                guard newValue != oldValue else { return }
                                cape.name = newValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.name = oldValue },
                                    redo: { [weak cape] in cape?.name = newValue }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    }

                    LabeledContent("Author") {
                        TextField("Author", text: Binding(
                            get: { cape.author },
                            set: { newValue in
                                let oldValue = cape.author
                                guard newValue != oldValue else { return }
                                cape.author = newValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.author = oldValue },
                                    redo: { [weak cape] in cape?.author = newValue }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    }

                    LabeledContent("Version") {
                        TextField("Version", value: Binding(
                            get: { cape.version },
                            set: { newValue in
                                let oldValue = cape.version
                                guard newValue != oldValue else { return }
                                cape.version = newValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.version = oldValue },
                                    redo: { [weak cape] in cape?.version = newValue }
                                )
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    }

                    LabeledContent("Identifier") {
                        TextField("Identifier", text: Binding(
                            get: { cape.identifier },
                            set: { newValue in
                                let oldValue = cape.identifier
                                guard newValue != oldValue else { return }
                                cape.identifier = newValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.identifier = oldValue },
                                    redo: { [weak cape] in cape?.identifier = newValue }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .font(.system(.body, design: .monospaced))
                    }

                    Divider()

                    LabeledContent("Cursors") {
                        Text("\(cape.cursorCount)")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("HiDPI") {
                        Toggle("", isOn: Binding(
                            get: { cape.isHiDPI },
                            set: { newValue in
                                let oldValue = cape.isHiDPI
                                guard newValue != oldValue else { return }
                                cape.isHiDPI = newValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.isHiDPI = oldValue },
                                    redo: { [weak cape] in cape?.isHiDPI = newValue }
                                )
                            }
                        ))
                        .labelsHidden()
                    }

                    if let url = cape.fileURL {
                        LabeledContent("File") {
                            Text(url.lastPathComponent)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

                // Cursor summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cursors (\(cape.cursorCount))")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                        ForEach(cape.cursors) { cursor in
                            VStack(spacing: 4) {
                                if let image = cursor.previewImage(size: 48) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                } else {
                                    Image(systemName: cursor.cursorType?.previewSymbol ?? "cursorarrow")
                                        .font(.title)
                                        .frame(width: 48, height: 48)
                                }
                                Text(cursor.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}

// MARK: - Add Cursor Sheet

struct AddCursorSheet: View {
    let cape: CursorLibrary
    let onAdd: (Cursor) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var selectedType: CursorType = .arrow

    // Filter out cursor types that already exist in the cape
    private var availableTypes: [CursorType] {
        let existingIdentifiers = Set(cape.cursors.map { $0.identifier })
        return CursorType.allCases.filter { !existingIdentifiers.contains($0.rawValue) }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Cursor")
                .font(.headline)

            if availableTypes.isEmpty {
                ContentUnavailableView(
                    "All Cursor Types Added",
                    systemImage: "checkmark.circle",
                    description: Text("This cape already contains all standard cursor types.")
                )
            } else {
                List(availableTypes, selection: $selectedType) { type in
                    HStack {
                        Image(systemName: type.previewSymbol)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
                .frame(height: 300)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    let newCursor = Cursor(identifier: selectedType.rawValue)
                    cape.addCursor(newCursor)
                    appState.markAsChanged()
                    onAdd(newCursor)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(availableTypes.isEmpty)
            }
        }
        .padding()
        .frame(width: 350, height: 420)
        .onAppear {
            if let first = availableTypes.first {
                selectedType = first
            }
        }
    }
}

// MARK: - Cursor List View (for Edit)

struct CursorListView: View {
    let cape: CursorLibrary
    @Binding var selection: Cursor?
    let onAddCursor: () -> Void
    @Environment(AppState.self) private var appState
    @State private var showDeleteConfirmation = false

    var body: some View {
        List(cape.cursors, id: \.id, selection: $selection) { cursor in
            CursorListRow(cursor: cursor, currentIdentifier: cursor.identifier)
                .tag(cursor)
                .contextMenu {
                    Button("Duplicate") {
                        duplicateCursor()
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
        }
        .listStyle(.sidebar)
        .id(appState.cursorListRefreshTrigger)  // Force list refresh when trigger changes
        .safeAreaInset(edge: .bottom) {
            // Bottom: Add/Remove/Duplicate buttons
            HStack(spacing: 8) {
                Button(action: onAddCursor) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add Cursor")

                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selection == nil)
                .help("Remove Cursor")

                Button(action: duplicateCursor) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .disabled(selection == nil)
                .help("Duplicate Cursor")

                Spacer()
            }
            .padding(8)
            .background(.ultraThinMaterial)
        }
        .confirmationDialog(
            "Delete Cursor?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                removeCursor()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let cursor = selection {
                Text("Are you sure you want to delete '\(cursor.displayName)'?")
            }
        }
    }

    private func removeCursor() {
        guard let cursor = selection else { return }
        cape.removeCursor(cursor)
        selection = cape.cursors.first
        appState.markAsChanged()
    }

    private func duplicateCursor() {
        guard let cursor = selection else { return }
        // Create a copy with a modified identifier
        let newCursor = Cursor(identifier: cursor.identifier + ".copy")
        newCursor.frameDuration = cursor.frameDuration
        newCursor.frameCount = cursor.frameCount
        newCursor.size = cursor.size
        newCursor.hotSpot = cursor.hotSpot

        // Copy representations
        for scale in CursorScale.allCases {
            if let rep = cursor.representation(for: scale) {
                newCursor.setRepresentation(rep, for: scale)
            }
        }

        cape.addCursor(newCursor)
        selection = newCursor
        appState.markAsChanged()
    }
}

// MARK: - Cursor List Row

struct CursorListRow: View {
    let cursor: Cursor
    /// Pass the identifier to force refresh when type changes
    var currentIdentifier: String?

    private var displayName: String {
        let identifier = currentIdentifier ?? cursor.identifier
        if let type = CursorType(rawValue: identifier) {
            return type.displayName
        }
        // Fallback: extract name from identifier
        let name = identifier.components(separatedBy: ".").last ?? "Cursor"
        var result = ""
        for char in name {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.isEmpty ? "Cursor" : result
    }

    var body: some View {
        HStack {
            // Preview thumbnail
            if let image = cursor.previewImage(size: 32) {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                let identifier = currentIdentifier ?? cursor.identifier
                Image(systemName: CursorType(rawValue: identifier)?.previewSymbol ?? "cursorarrow")
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.headline)
                if cursor.isAnimated {
                    Text("\(cursor.frameCount) frames")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cursor Detail View

struct CursorDetailView: View {
    @Bindable var cursor: Cursor
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState
    @State private var showHotspot = false
    @State private var hotspotX: Double = 0
    @State private var hotspotY: Double = 0
    @State private var frameCount: Int = 1
    @State private var frameDuration: Double = 0
    @State private var isLoadingValues = true  // Prevent onChange during load
    @State private var selectedType: CursorType = .arrow
    // Store previous values for undo
    @State private var prevHotspotX: Double = 0
    @State private var prevHotspotY: Double = 0
    @State private var prevFrameCount: Int = 1
    @State private var prevFrameDuration: Double = 0

    // Get available cursor types (current type + types not used by other cursors)
    private var availableTypes: [CursorType] {
        let otherCursorIdentifiers = Set(cape.cursors
            .filter { $0.id != cursor.id }
            .map { $0.identifier })
        return CursorType.allCases.filter { type in
            !otherCursorIdentifiers.contains(type.rawValue)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Large preview area
                AnimatingCursorView(cursor: cursor, showHotspot: showHotspot)
                    .frame(height: 200)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))

                // Properties panel
                VStack(alignment: .leading, spacing: 12) {
                    Text("Properties")
                        .font(.headline)

                    LabeledContent("Type") {
                        Picker("", selection: $selectedType) {
                            ForEach(availableTypes) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        .onChange(of: selectedType) { oldValue, newValue in
                            guard !isLoadingValues else { return }
                            guard newValue != oldValue else { return }
                            let oldIdentifier = cursor.identifier
                            let newIdentifier = newValue.rawValue
                            cursor.identifier = newIdentifier
                            // Trigger cursor list refresh
                            appState.cursorListRefreshTrigger += 1
                            appState.registerUndo(
                                undo: { [weak cursor] in
                                    cursor?.identifier = oldIdentifier
                                    if let type = CursorType(rawValue: oldIdentifier) {
                                        self.selectedType = type
                                    }
                                    self.appState.cursorListRefreshTrigger += 1
                                },
                                redo: { [weak cursor] in
                                    cursor?.identifier = newIdentifier
                                    self.selectedType = newValue
                                    self.appState.cursorListRefreshTrigger += 1
                                }
                            )
                        }
                    }

                    LabeledContent("Identifier") {
                        Text(selectedType.rawValue)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    LabeledContent("Hotspot") {
                        HStack {
                            Text("X:")
                            TextField("X", value: $hotspotX, format: .number.precision(.fractionLength(1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onChange(of: hotspotX) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    cursor.hotSpot = NSPoint(x: CGFloat(newValue), y: cursor.hotSpot.y)
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            cursor?.hotSpot = NSPoint(x: CGFloat(capturedOld), y: cursor?.hotSpot.y ?? 0)
                                            self.hotspotX = capturedOld
                                        },
                                        redo: { [weak cursor] in
                                            cursor?.hotSpot = NSPoint(x: CGFloat(newValue), y: cursor?.hotSpot.y ?? 0)
                                            self.hotspotX = newValue
                                        }
                                    )
                                }
                            Text("Y:")
                            TextField("Y", value: $hotspotY, format: .number.precision(.fractionLength(1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onChange(of: hotspotY) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    cursor.hotSpot = NSPoint(x: cursor.hotSpot.x, y: CGFloat(newValue))
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            cursor?.hotSpot = NSPoint(x: cursor?.hotSpot.x ?? 0, y: CGFloat(capturedOld))
                                            self.hotspotY = capturedOld
                                        },
                                        redo: { [weak cursor] in
                                            cursor?.hotSpot = NSPoint(x: cursor?.hotSpot.x ?? 0, y: CGFloat(newValue))
                                            self.hotspotY = newValue
                                        }
                                    )
                                }
                            Toggle("Show", isOn: $showHotspot)
                        }
                    }

                    Divider()

                    LabeledContent("Animation") {
                        HStack {
                            Text("Frames:")
                            TextField("Frames", value: $frameCount, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .onChange(of: frameCount) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    let actualNew = max(1, newValue)
                                    cursor.frameCount = actualNew
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            cursor?.frameCount = capturedOld
                                            self.frameCount = capturedOld
                                        },
                                        redo: { [weak cursor] in
                                            cursor?.frameCount = actualNew
                                            self.frameCount = actualNew
                                        }
                                    )
                                }
                            Text("Duration:")
                            TextField("Duration", value: $frameDuration, format: .number.precision(.fractionLength(2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                                .onChange(of: frameDuration) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    let actualNew = max(0, newValue)
                                    cursor.frameDuration = CGFloat(actualNew)
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            cursor?.frameDuration = CGFloat(capturedOld)
                                            self.frameDuration = capturedOld
                                        },
                                        redo: { [weak cursor] in
                                            cursor?.frameDuration = CGFloat(actualNew)
                                            self.frameDuration = actualNew
                                        }
                                    )
                                }
                            Text("sec")
                        }
                    }

                    if cursor.isAnimated {
                        Text("Total animation: \(String(format: "%.2f", Double(frameCount) * frameDuration))s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))

                // Resolutions panel
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Resolutions")
                            .font(.headline)
                        Spacer()
                        Text("Drag images to add")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        ForEach(CursorScale.allCases) { scale in
                            ResolutionDropZone(scale: scale, cursor: cursor)
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .onAppear {
            loadCursorValues()
        }
        .onChange(of: cursor.id) { _, _ in
            loadCursorValues()
        }
    }

    private func loadCursorValues() {
        isLoadingValues = true
        hotspotX = Double(cursor.hotSpot.x)
        hotspotY = Double(cursor.hotSpot.y)
        frameCount = cursor.frameCount
        frameDuration = Double(cursor.frameDuration)
        // Load cursor type
        if let type = CursorType(rawValue: cursor.identifier) {
            selectedType = type
        } else if let firstAvailable = availableTypes.first {
            selectedType = firstAvailable
        }
        // Delay resetting the flag to ensure onChange doesn't fire during load
        DispatchQueue.main.async {
            isLoadingValues = false
        }
    }
}

// MARK: - Resolution Drop Zone

struct ResolutionDropZone: View {
    let scale: CursorScale
    @Bindable var cursor: Cursor
    @Environment(AppState.self) private var appState
    @State private var isTargeted = false
    @State private var showFilePicker = false

    var body: some View {
        VStack {
            Text(scale.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Show representation or placeholder
            ZStack {
                if cursor.hasRepresentation(for: scale) {
                    if let image = cursor.previewImage(size: 64) {
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: 64, height: 64)
                    }

                    // Remove button overlay
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: removeRepresentation) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .red)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(2)
                } else {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 64, height: 64)
                }
            }
            .frame(width: 64, height: 64)
        }
        .padding(8)
        .glassEffect(
            isTargeted ? .regular.tint(.accentColor) : .clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .onTapGesture {
            showFilePicker = true
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleURLDrop(urls)
        } isTargeted: { isTargeted in
            self.isTargeted = isTargeted
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.png, .jpeg, .tiff, .gif],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .help("Click to select image or drag & drop")
    }

    private func handleURLDrop(_ urls: [URL]) -> Bool {
        guard let url = urls.first else { return false }
        return loadImage(from: url)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                _ = loadImage(from: url)
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }

    private func loadImage(from url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let image = NSImage(contentsOf: url) else { return false }

        if let rep = image.representations.first {
            cursor.setRepresentation(rep, for: scale)
            appState.markAsChanged()
            return true
        }
        return false
    }

    private func removeRepresentation() {
        cursor.removeRepresentation(for: scale)
        appState.markAsChanged()
    }
}

// MARK: - Helper Tool Settings Section

import ServiceManagement

struct HelperToolSettingsView: View {
    private static let helperBundleIdentifier = "com.alexzielenski.mousecloakhelper"

    @State private var isHelperInstalled = false
    @State private var showInstallAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Helper Tool"

    var body: some View {
        Section("Helper Tool") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mousecape Helper")
                        .font(.headline)
                    Text(isHelperInstalled ? "Installed and running" : "Not installed")
                        .font(.caption)
                        .foregroundStyle(isHelperInstalled ? .green : .secondary)
                }

                Spacer()

                Button(isHelperInstalled ? "Uninstall" : "Install") {
                    toggleHelper()
                }
            }

            Text("The helper tool ensures cursors persist after logout/login and system updates.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            checkHelperStatus()
        }
        .alert(alertTitle, isPresented: $showInstallAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    private func checkHelperStatus() {
        let service = SMAppService.loginItem(identifier: Self.helperBundleIdentifier)
        isHelperInstalled = (service.status == .enabled)
    }

    private func toggleHelper() {
        let service = SMAppService.loginItem(identifier: Self.helperBundleIdentifier)
        let shouldInstall = !isHelperInstalled

        do {
            if shouldInstall {
                try service.register()
                isHelperInstalled = true
                alertTitle = "Success"
                alertMessage = "The Mousecape helper was successfully installed."
            } else {
                try service.unregister()
                isHelperInstalled = false
                alertTitle = "Success"
                alertMessage = "The Mousecape helper was successfully uninstalled."
            }
        } catch {
            alertTitle = "Error"
            alertMessage = error.localizedDescription
        }
        showInstallAlert = true
    }
}

// MARK: - Preview

#Preview {
    EditOverlayView(cape: CursorLibrary(name: "Test Cape", author: "Test"))
        .environment(AppState.shared)
        .environment(LocalizationManager.shared)
}
