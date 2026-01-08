//
//  EditOverlayView.swift
//  Mousecape
//
//  Edit overlay view that covers the main interface
//  Slides in from the right with animation
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Windows Cursor UTType Extensions

extension UTType {
    /// Windows static cursor file (.cur)
    static var windowsCursor: UTType {
        UTType(filenameExtension: "cur") ?? .data
    }

    /// Windows animated cursor file (.ani)
    static var windowsAnimatedCursor: UTType {
        UTType(filenameExtension: "ani") ?? .data
    }
}

// MARK: - Edit Detail Content (right panel content only, used in HomeView)

struct EditDetailContent: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        Group {
            if appState.showCapeInfo {
                CapeInfoView(cape: cape)
            } else if let cursor = appState.editingSelectedCursor {
                CursorDetailView(cursor: cursor, cape: cape)
                    .id(cursor.id)  // Force view recreation when cursor changes
            } else {
                ContentUnavailableView(
                    localization.localized("Select a Cursor"),
                    systemImage: "cursorarrow.click",
                    description: Text(localization.localized("Choose a cursor from the list to edit"))
                )
            }
        }
        .onAppear {
            // Invalidate cache to ensure we get fresh cursor data
            cape.invalidateCursorCache()
            // Select first cursor when opening
            if appState.editingSelectedCursor == nil {
                appState.editingSelectedCursor = cape.cursors.first
            }
        }
        // Edit mode toolbar (navigationTitle is now in HomeView)
        .toolbar {
            // Flexible spacer pushes buttons to the right (macOS 26+ only)
            AdaptiveToolbarSpacer(.flexible)

            // Main action buttons group
            ToolbarItemGroup {
                Button(action: {
                    appState.showAddCursorSheet = true
                }) {
                    Image(systemName: "plus")
                }
                .help(localization.localized("Add Cursor"))

                Button(action: {
                    appState.showDeleteCursorConfirmation = true
                }) {
                    Image(systemName: "minus")
                }
                .help(localization.localized("Delete Cursor"))
                .disabled(appState.editingSelectedCursor == nil)

                Button(action: {
                    appState.showCapeInfo.toggle()
                    if appState.showCapeInfo {
                        appState.editingSelectedCursor = nil
                    }
                }) {
                    Image(systemName: appState.showCapeInfo ? "info.circle.fill" : "info.circle")
                }
                .help(localization.localized("Cape Info"))
            }

            AdaptiveToolbarSpacer(.fixed)

            // Done button (rightmost, standalone with green color)
            ToolbarItem {
                Button(action: {
                    appState.requestCloseEdit()
                }) {
                    Image(systemName: "checkmark")
                }
                .help(localization.localized("Done"))
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }
}

// MARK: - Edit Overlay View (legacy, full screen)

struct EditOverlayView: View {
    let cape: CursorLibrary
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            // Left sidebar: Cursor list (same style as HomeView/SettingsView)
            CursorListView(
                cape: cape,
                selection: $appState.editingSelectedCursor
            )
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            // Right side: Content area
            detailContent
                .scrollContentBackground(.hidden)
        }
        .onAppear {
            // Invalidate cache to ensure we get fresh cursor data
            cape.invalidateCursorCache()
            // Select first cursor when opening
            if appState.editingSelectedCursor == nil {
                appState.editingSelectedCursor = cape.cursors.first
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if appState.showCapeInfo {
            CapeInfoView(cape: cape)
        } else if let cursor = appState.editingSelectedCursor {
            CursorDetailView(cursor: cursor, cape: cape)
                .id(cursor.id)  // Force view recreation when cursor changes
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
    @Environment(LocalizationManager.self) private var localization

    /// Current filename from fileURL
    private var currentFilename: String {
        cape.fileURL?.lastPathComponent ?? "\(cape.identifier).cape"
    }

    /// Check if name is valid (not empty)
    private var isNameValid: Bool {
        !cape.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Check if author is valid (not empty)
    private var isAuthorValid: Bool {
        !cape.author.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Check if version is valid (> 0)
    private var isVersionValid: Bool {
        cape.version > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cape metadata form
                VStack(alignment: .leading, spacing: 16) {
                    Text(localization.localized("Cape Information"))
                        .font(.headline)

                    LabeledContent(localization.localized("Name")) {
                        TextField(localization.localized("Name"), text: Binding(
                            get: { cape.name },
                            set: { newValue in
                                // Filter to only allow valid filename characters
                                let filtered = AppState.filterNameOrAuthor(newValue)
                                let oldValue = cape.name
                                guard filtered != oldValue else { return }
                                cape.name = filtered
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.name = oldValue },
                                    redo: { [weak cape] in cape?.name = filtered }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isNameValid ? Color.clear : Color.red, lineWidth: 2)
                        )
                    }

                    LabeledContent(localization.localized("Author")) {
                        TextField(localization.localized("Author"), text: Binding(
                            get: { cape.author },
                            set: { newValue in
                                // Filter to only allow valid filename characters
                                let filtered = AppState.filterNameOrAuthor(newValue)
                                let oldValue = cape.author
                                guard filtered != oldValue else { return }
                                cape.author = filtered
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.author = oldValue },
                                    redo: { [weak cape] in cape?.author = filtered }
                                )
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isAuthorValid ? Color.clear : Color.red, lineWidth: 2)
                        )
                    }

                    LabeledContent(localization.localized("Version")) {
                        TextField(localization.localized("Version"), value: Binding(
                            get: { cape.version },
                            set: { newValue in
                                let oldValue = cape.version
                                // Ensure version is at least 0.1
                                let validValue = max(0.1, newValue)
                                guard validValue != oldValue else { return }
                                cape.version = validValue
                                appState.registerUndo(
                                    undo: { [weak cape] in cape?.version = oldValue },
                                    redo: { [weak cape] in cape?.version = validValue }
                                )
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isVersionValid ? Color.clear : Color.red, lineWidth: 2)
                        )
                    }

                    Divider()

                    LabeledContent(localization.localized("Cursors")) {
                        Text("\(cape.cursorCount)")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent(localization.localized("File")) {
                        // Show current filename (updates after save)
                        Text(currentFilename)
                            .foregroundStyle(.secondary)
                            .font(.system(.caption, design: .monospaced))
                            .id(appState.capeInfoRefreshTrigger)  // Force refresh when triggered
                    }
                }
                .padding()
                .adaptiveGlass(in: RoundedRectangle(cornerRadius: 12))

                // Cursor summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(localization.localized("Cursors")) (\(cape.cursorCount))")
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
                .adaptiveGlass(in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
}

// MARK: - Add Cursor Sheet

struct AddCursorSheet: View {
    let cape: CursorLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization
    @State private var selectedType: CursorType?

    // Filter out cursor types that already exist in the cape
    private var availableTypes: [CursorType] {
        let existingIdentifiers = Set(cape.cursors.map { $0.identifier })
        return CursorType.allCases.filter { !existingIdentifiers.contains($0.rawValue) }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(localization.localized("Add Cursor"))
                .font(.headline)

            cursorTypeList

            buttonBar
        }
        .padding()
        .frame(width: 350, height: 420)
        .onAppear {
            selectedType = availableTypes.first
        }
    }

    @ViewBuilder
    private var cursorTypeList: some View {
        if availableTypes.isEmpty {
            ContentUnavailableView(
                localization.localized("All Cursor Types Added"),
                systemImage: "checkmark.circle",
                description: Text(localization.localized("This cape already contains all standard cursor types."))
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(availableTypes) { type in
                        CursorTypeRow(
                            type: type,
                            isSelected: selectedType == type,
                            onSelect: { selectedType = type }
                        )
                    }
                }
                .padding(8)
            }
            .frame(height: 300)
            .adaptiveGlassClear(in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var buttonBar: some View {
        HStack {
            Button(localization.localized("Cancel")) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button(localization.localized("Add")) {
                addSelectedCursor()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedType == nil || availableTypes.isEmpty)
        }
    }

    private func addSelectedCursor() {
        guard let type = selectedType else { return }

        // Create and add cursor directly via AppState
        let newCursor = Cursor(identifier: type.rawValue)
        cape.addCursor(newCursor)
        appState.markAsChanged()
        appState.cursorListRefreshTrigger += 1
        appState.editingSelectedCursor = newCursor

        // Dismiss sheet
        dismiss()
    }
}

// MARK: - Cursor Type Row

private struct CursorTypeRow: View {
    let type: CursorType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: type.previewSymbol)
                .frame(width: 24)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            Text(type.displayName)
                .foregroundStyle(isSelected ? .primary : .secondary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.15))
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Cursor List View (for Edit)

struct CursorListView: View {
    let cape: CursorLibrary
    @Binding var selection: Cursor?
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        @Bindable var appState = appState

        List(cape.cursors, id: \.id, selection: $selection) { cursor in
            CursorListRow(cursor: cursor, currentIdentifier: cursor.identifier)
                .tag(cursor)
                .contextMenu {
                    Button(localization.localized("Duplicate")) {
                        duplicateCursor()
                    }
                    Divider()
                    Button(localization.localized("Delete"), role: .destructive) {
                        appState.showDeleteCursorConfirmation = true
                    }
                }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .id(appState.cursorListRefreshTrigger)  // Force list refresh when trigger changes
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
    @Environment(LocalizationManager.self) private var localization

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
                    Text("\(cursor.frameCount) \(localization.localized("frames"))")
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
    @Environment(LocalizationManager.self) private var localization
    @State private var hotspotX: Double = 0
    @State private var hotspotY: Double = 0
    @State private var frameCount: Int = 1
    @State private var fps: Double = 1  // Frames per second
    @State private var isLoadingValues = true  // Prevent onChange during load
    @State private var selectedType: CursorType = .arrow
    @State private var previewRefreshTrigger: Int = 0  // Force preview refresh
    @State private var availableTypes: [CursorType] = CursorType.allCases

    // MARK: - Validation

    /// Check if hotspot X is valid (>= 0)
    private var isHotspotXValid: Bool { hotspotX >= 0 }

    /// Check if hotspot Y is valid (>= 0)
    private var isHotspotYValid: Bool { hotspotY >= 0 }

    /// Check if frame count is valid (>= 1)
    private var isFrameCountValid: Bool { frameCount >= 1 }

    /// Check if FPS is valid (> 0)
    private var isFPSValid: Bool { fps > 0 }

    // Calculate available cursor types (current type + types not used by other cursors)
    private func calculateAvailableTypes() -> [CursorType] {
        let otherCursorIdentifiers = Set(cape.cursors
            .filter { $0.id != cursor.id }
            .map { $0.identifier })
        return CursorType.allCases.filter { type in
            !otherCursorIdentifiers.contains(type.rawValue)
        }
    }

    // Calculate frame duration from FPS
    private var frameDuration: Double {
        fps > 0 ? 1.0 / fps : 0
    }

    // Picker types - ensure selectedType is always included to avoid "invalid selection" warning
    private var pickerTypes: [CursorType] {
        if availableTypes.contains(selectedType) {
            return availableTypes
        } else {
            // Add current selection to the list if not present
            return [selectedType] + availableTypes
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Combined preview + drop zone
                CursorPreviewDropZone(
                    cursor: cursor,
                    refreshTrigger: previewRefreshTrigger
                )

                // Properties panel
                VStack(alignment: .leading, spacing: 16) {
                    // Type section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized("Type"))
                            .font(.headline)

                        Picker("", selection: $selectedType) {
                            ForEach(pickerTypes) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .leading)
                        .id(previewRefreshTrigger)  // Force picker refresh
                        .onChange(of: selectedType) { oldValue, newValue in
                            guard !isLoadingValues else { return }
                            guard newValue != oldValue else { return }
                            let oldIdentifier = cursor.identifier
                            let newIdentifier = newValue.rawValue
                            cursor.identifier = newIdentifier
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

                        Text(selectedType.rawValue)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Hotspot section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized("Hotspot"))
                            .font(.headline)

                        HStack(spacing: 16) {
                            HStack {
                                Text("X:")
                                TextField("X", value: $hotspotX, format: .number.precision(.fractionLength(1)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isHotspotXValid ? Color.clear : Color.red, lineWidth: 2)
                                    )
                                    .onChange(of: hotspotX) { oldValue, newValue in
                                        guard !isLoadingValues else { return }
                                        guard newValue != oldValue else { return }
                                        let capturedOld = oldValue
                                        let actualNew = max(0, newValue)
                                        cursor.hotSpot = NSPoint(x: CGFloat(actualNew), y: cursor.hotSpot.y)
                                        previewRefreshTrigger += 1
                                        appState.registerUndo(
                                            undo: { [weak cursor] in
                                                cursor?.hotSpot = NSPoint(x: CGFloat(capturedOld), y: cursor?.hotSpot.y ?? 0)
                                                self.hotspotX = capturedOld
                                                self.previewRefreshTrigger += 1
                                            },
                                            redo: { [weak cursor] in
                                                cursor?.hotSpot = NSPoint(x: CGFloat(actualNew), y: cursor?.hotSpot.y ?? 0)
                                                self.hotspotX = actualNew
                                                self.previewRefreshTrigger += 1
                                            }
                                        )
                                    }
                            }
                            HStack {
                                Text("Y:")
                                TextField("Y", value: $hotspotY, format: .number.precision(.fractionLength(1)))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(isHotspotYValid ? Color.clear : Color.red, lineWidth: 2)
                                    )
                                    .onChange(of: hotspotY) { oldValue, newValue in
                                        guard !isLoadingValues else { return }
                                        guard newValue != oldValue else { return }
                                        let capturedOld = oldValue
                                        let actualNew = max(0, newValue)
                                        cursor.hotSpot = NSPoint(x: cursor.hotSpot.x, y: CGFloat(actualNew))
                                        previewRefreshTrigger += 1
                                        appState.registerUndo(
                                            undo: { [weak cursor] in
                                                cursor?.hotSpot = NSPoint(x: cursor?.hotSpot.x ?? 0, y: CGFloat(capturedOld))
                                                self.hotspotY = capturedOld
                                                self.previewRefreshTrigger += 1
                                            },
                                            redo: { [weak cursor] in
                                                cursor?.hotSpot = NSPoint(x: cursor?.hotSpot.x ?? 0, y: CGFloat(actualNew))
                                                self.hotspotY = actualNew
                                                self.previewRefreshTrigger += 1
                                            }
                                        )
                                    }
                            }
                        }

                    }

                    Divider()

                    // Animation section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized("Animation"))
                            .font(.headline)

                        HStack {
                            Text(localization.localized("Frames:"))
                            TextField("Frames", value: $frameCount, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(isFrameCountValid ? Color.clear : Color.red, lineWidth: 2)
                                )
                                .onChange(of: frameCount) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    let actualNew = max(1, newValue)
                                    cursor.frameCount = actualNew
                                    previewRefreshTrigger += 1
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            cursor?.frameCount = capturedOld
                                            self.frameCount = capturedOld
                                            self.previewRefreshTrigger += 1
                                        },
                                        redo: { [weak cursor] in
                                            cursor?.frameCount = actualNew
                                            self.frameCount = actualNew
                                            self.previewRefreshTrigger += 1
                                        }
                                    )
                                }
                        }

                        HStack {
                            Text(localization.localized("Speed:"))
                            TextField("Speed", value: $fps, format: .number.precision(.fractionLength(1)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(isFPSValid ? Color.clear : Color.red, lineWidth: 2)
                                )
                                .onChange(of: fps) { oldValue, newValue in
                                    guard !isLoadingValues else { return }
                                    guard newValue != oldValue else { return }
                                    let capturedOld = oldValue
                                    let actualNew = max(0.1, newValue)
                                    let newDuration = 1.0 / actualNew
                                    cursor.frameDuration = CGFloat(newDuration)
                                    previewRefreshTrigger += 1
                                    appState.registerUndo(
                                        undo: { [weak cursor] in
                                            let oldDuration = capturedOld > 0 ? 1.0 / capturedOld : 0
                                            cursor?.frameDuration = CGFloat(oldDuration)
                                            self.fps = capturedOld
                                            self.previewRefreshTrigger += 1
                                        },
                                        redo: { [weak cursor] in
                                            cursor?.frameDuration = CGFloat(newDuration)
                                            self.fps = actualNew
                                            self.previewRefreshTrigger += 1
                                        }
                                    )
                                }
                            Text(localization.localized("frames/sec"))
                                .foregroundStyle(.secondary)
                        }

                        if cursor.isAnimated {
                            Text("Duration: \(String(format: "%.3f", frameDuration))s per frame, \(String(format: "%.2f", Double(frameCount) * frameDuration))s total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .adaptiveGlass(in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .onAppear {
            loadCursorValues()
        }
        .onChange(of: cursor.id) { _, _ in
            loadCursorValues()
        }
        .onChange(of: appState.cursorListRefreshTrigger) { _, _ in
            // Refresh preview and reload values when image is imported
            previewRefreshTrigger += 1
            loadCursorValues()
        }
    }

    private func loadCursorValues() {
        isLoadingValues = true
        hotspotX = Double(cursor.hotSpot.x)
        hotspotY = Double(cursor.hotSpot.y)
        frameCount = cursor.frameCount
        // Calculate FPS from frame duration
        let duration = Double(cursor.frameDuration)
        fps = duration > 0 ? 1.0 / duration : 1.0
        // Refresh available types
        availableTypes = calculateAvailableTypes()
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

// MARK: - Cursor Preview Drop Zone (Combined preview + image drop)

struct CursorPreviewDropZone: View {
    @Bindable var cursor: Cursor
    var refreshTrigger: Int = 0
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization
    @State private var isTargeted = false
    @State private var showFilePicker = false
    @State private var localRefreshTrigger = 0

    private let targetScale: CursorScale = .scale200  // Always use 2x HiDPI

    /// Supported image types for file picker
    private var supportedImageTypes: [UTType] {
        var types: [UTType] = [.png, .jpeg, .tiff, .gif]
        types.append(contentsOf: [.windowsCursor, .windowsAnimatedCursor])
        return types
    }

    /// Check if cursor has any valid image representation
    private var hasImage: Bool {
        cursor.hasAnyRepresentation
    }

    var body: some View {
        ZStack {
            if hasImage {
                // Show cursor preview with hotspot
                AnimatingCursorView(
                    cursor: cursor,
                    showHotspot: true,
                    refreshTrigger: refreshTrigger + localRefreshTrigger,
                    scale: 3
                )
            } else {
                // Empty state - prompt to add image
                VStack(spacing: 12) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)

                    Text(localization.localized("Drag image or click to select"))
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(localization.localized("Recommended: 64×64 px (HiDPI 2x)"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Drag overlay indicator
            if isTargeted {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
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
            allowedContentTypes: supportedImageTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .help(hasImage ? localization.localized("Click or drag to replace image") : localization.localized("Click or drag to add image"))
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

    /// Standard cursor size for 2x HiDPI (64x64 pixels = 32x32 points)
    private let standardCursorSize: Int = 64

    private func loadImage(from url: URL) -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security scoped resource: \(url)")
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Check if it's a Windows cursor file
        let ext = url.pathExtension.lowercased()
        if ext == "cur" || ext == "ani" {
            return loadWindowsCursor(from: url)
        }

        // Check if it's a GIF file - handle animation
        if ext == "gif" {
            return loadGIFImage(from: url)
        }

        guard let image = NSImage(contentsOf: url) else {
            print("Failed to load image from: \(url)")
            return false
        }

        // Get original image dimensions
        guard let originalBitmap = getOriginalBitmapRep(from: image) else {
            print("Failed to get bitmap rep from image")
            return false
        }

        let originalWidth = originalBitmap.pixelsWide
        let originalHeight = originalBitmap.pixelsHigh

        // Check if image is square
        let isSquare = originalWidth == originalHeight
        if !isSquare {
            // Show warning but continue with import
            appState.imageImportWarningMessage = "Image is not square (\(originalWidth)×\(originalHeight)). It will be scaled to fit and centered."
            appState.showImageImportWarning = true
        }

        // Scale image to standard size (64x64) with aspect fit and center
        guard let scaledBitmap = scaleImageToStandardSize(originalBitmap) else {
            print("Failed to scale image")
            return false
        }

        cursor.setRepresentation(scaledBitmap, for: targetScale)

        // Set cursor size to 32x32 points (since we use 2x scale)
        cursor.size = NSSize(width: 32, height: 32)

        appState.markAsChanged()

        // Trigger refresh - both local preview and cursor list
        localRefreshTrigger += 1
        appState.cursorListRefreshTrigger += 1

        print("Image imported successfully: \(originalWidth)x\(originalHeight) → \(standardCursorSize)x\(standardCursorSize)")
        return true
    }

    // MARK: - GIF Import

    /// Load an animated GIF file and extract all frames
    private func loadGIFImage(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else {
            print("Failed to read GIF data from: \(url)")
            return false
        }

        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("Failed to create image source from GIF")
            return false
        }

        let frameCount = CGImageSourceGetCount(imageSource)
        guard frameCount > 0 else {
            print("GIF has no frames")
            return false
        }

        // For single-frame GIFs, treat as static image
        if frameCount == 1 {
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                print("Failed to get first GIF frame")
                return false
            }
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            guard let scaledBitmap = scaleImageToStandardSize(bitmap) else {
                print("Failed to scale GIF image")
                return false
            }

            cursor.setRepresentation(scaledBitmap, for: targetScale)
            cursor.size = NSSize(width: 32, height: 32)
            cursor.frameCount = 1
            cursor.frameDuration = 0.0

            appState.markAsChanged()
            localRefreshTrigger += 1
            appState.cursorListRefreshTrigger += 1

            print("Static GIF imported successfully")
            return true
        }

        // Multi-frame GIF - extract all frames
        var frames: [NSBitmapImageRep] = []
        var totalDuration: Double = 0.0
        var frameWidth: Int = 0
        var frameHeight: Int = 0

        for i in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) else {
                continue
            }

            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            frames.append(bitmap)

            if i == 0 {
                frameWidth = bitmap.pixelsWide
                frameHeight = bitmap.pixelsHigh
            }

            // Get frame duration from GIF properties
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as? [String: Any],
               let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                // Try unclamped delay time first, then delay time
                if let delay = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, delay > 0 {
                    totalDuration += delay
                } else if let delay = gifProperties[kCGImagePropertyGIFDelayTime as String] as? Double, delay > 0 {
                    totalDuration += delay
                } else {
                    totalDuration += 0.1  // Default 100ms per frame
                }
            } else {
                totalDuration += 0.1
            }
        }

        guard !frames.isEmpty else {
            print("Failed to extract any frames from GIF")
            return false
        }

        // Calculate average frame duration
        let avgFrameDuration = totalDuration / Double(frames.count)

        // Create a sprite sheet (all frames stacked vertically)
        guard let spriteSheet = createSpriteSheet(from: frames, frameWidth: frameWidth, frameHeight: frameHeight) else {
            print("Failed to create sprite sheet from GIF frames")
            return false
        }

        // Scale the sprite sheet
        guard let scaledSpriteSheet = scaleGIFSpriteSheet(spriteSheet, frameCount: frames.count, originalFrameWidth: frameWidth, originalFrameHeight: frameHeight) else {
            print("Failed to scale GIF sprite sheet")
            return false
        }

        cursor.setRepresentation(scaledSpriteSheet, for: targetScale)
        cursor.size = NSSize(width: 32, height: 32)
        cursor.frameCount = frames.count
        cursor.frameDuration = CGFloat(avgFrameDuration)

        appState.markAsChanged()
        localRefreshTrigger += 1
        appState.cursorListRefreshTrigger += 1

        print("Animated GIF imported: \(frameWidth)x\(frameHeight), \(frames.count) frames, \(String(format: "%.3f", avgFrameDuration))s/frame")
        return true
    }

    /// Create a vertical sprite sheet from individual frames
    private func createSpriteSheet(from frames: [NSBitmapImageRep], frameWidth: Int, frameHeight: Int) -> NSBitmapImageRep? {
        let sheetHeight = frameHeight * frames.count

        guard let spriteSheet = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: frameWidth,
            pixelsHigh: sheetHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: frameWidth * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: spriteSheet) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context

        // Clear to transparent
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: frameWidth, height: sheetHeight).fill()

        // Draw each frame
        for (index, frame) in frames.enumerated() {
            let sourceImage = NSImage(size: NSSize(width: frame.pixelsWide, height: frame.pixelsHigh))
            sourceImage.addRepresentation(frame)

            let yOffset = CGFloat(index * frameHeight)
            let destRect = NSRect(x: 0, y: yOffset, width: CGFloat(frameWidth), height: CGFloat(frameHeight))
            sourceImage.draw(in: destRect, from: .zero, operation: .copy, fraction: 1.0)
        }

        NSGraphicsContext.restoreGraphicsState()
        return spriteSheet
    }

    /// Scale a GIF sprite sheet to standard cursor size
    private func scaleGIFSpriteSheet(_ original: NSBitmapImageRep, frameCount: Int, originalFrameWidth: Int, originalFrameHeight: Int) -> NSBitmapImageRep? {
        let targetSize = standardCursorSize

        guard let newBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetSize,
            pixelsHigh: targetSize * frameCount,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: targetSize * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }

        let originalWidth = CGFloat(originalFrameWidth)
        let originalHeight = CGFloat(originalFrameHeight)
        let targetSizeF = CGFloat(targetSize)

        let scale = min(targetSizeF / originalWidth, targetSizeF / originalHeight)
        let scaledWidth = originalWidth * scale
        let scaledHeight = originalHeight * scale

        let offsetX = (targetSizeF - scaledWidth) / 2
        let offsetY = (targetSizeF - scaledHeight) / 2

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: newBitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context

        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: targetSize, height: targetSize * frameCount).fill()

        let sourceImage = NSImage(size: NSSize(width: original.pixelsWide, height: original.pixelsHigh))
        sourceImage.addRepresentation(original)

        for frameIndex in 0..<frameCount {
            let srcY = CGFloat(frameIndex) * originalHeight
            let srcRect = NSRect(x: 0, y: srcY, width: originalWidth, height: originalHeight)

            let dstY = CGFloat(frameIndex) * targetSizeF + offsetY
            let dstRect = NSRect(x: offsetX, y: dstY, width: scaledWidth, height: scaledHeight)

            sourceImage.draw(in: dstRect, from: srcRect, operation: .copy, fraction: 1.0)
        }

        NSGraphicsContext.restoreGraphicsState()
        return newBitmap
    }

    /// Get original bitmap representation from image
    private func getOriginalBitmapRep(from image: NSImage) -> NSBitmapImageRep? {
        // First try to get existing bitmap rep
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep {
                return bitmapRep
            }
        }

        // Create new bitmap by drawing the image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return NSBitmapImageRep(cgImage: cgImage)
    }

    /// Scale image to standard 64x64 size with aspect fit and transparent padding
    private func scaleImageToStandardSize(_ original: NSBitmapImageRep) -> NSBitmapImageRep? {
        let targetSize = standardCursorSize

        // Create new bitmap with transparent background
        guard let newBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetSize,
            pixelsHigh: targetSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: targetSize * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }

        // Calculate aspect-fit scaling
        let originalWidth = CGFloat(original.pixelsWide)
        let originalHeight = CGFloat(original.pixelsHigh)
        let targetSizeF = CGFloat(targetSize)

        let scale = min(targetSizeF / originalWidth, targetSizeF / originalHeight)
        let scaledWidth = originalWidth * scale
        let scaledHeight = originalHeight * scale

        // Center the image
        let offsetX = (targetSizeF - scaledWidth) / 2
        let offsetY = (targetSizeF - scaledHeight) / 2

        // Draw into new bitmap
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: newBitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context

        // Clear to transparent
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: targetSize, height: targetSize).fill()

        // Draw scaled image centered
        let sourceImage = NSImage(size: NSSize(width: originalWidth, height: originalHeight))
        sourceImage.addRepresentation(original)

        let destRect = NSRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
        sourceImage.draw(in: destRect, from: .zero, operation: .copy, fraction: 1.0)

        NSGraphicsContext.restoreGraphicsState()

        return newBitmap
    }

    // MARK: - Windows Cursor Import

    /// Load a Windows cursor file (.cur or .ani)
    private func loadWindowsCursor(from url: URL) -> Bool {
        do {
            let result = try WindowsCursorConverter.shared.convert(fileURL: url)

            // Create bitmap from result
            guard let originalBitmap = result.createBitmapImageRep() else {
                print("Failed to create bitmap from Windows cursor")
                return false
            }

            // For animated cursors, set frame count and duration
            if result.frameCount > 1 {
                cursor.frameCount = result.frameCount
                cursor.frameDuration = result.frameDuration
            } else {
                cursor.frameCount = 1
                cursor.frameDuration = 0.0
            }

            // Calculate scale factor for hotspot adjustment
            let originalWidth = CGFloat(result.width)
            let originalHeight = CGFloat(result.height)
            let targetSizeF = CGFloat(standardCursorSize)

            // For animated cursors, the sprite sheet height is frameCount * height
            // We need to scale the entire sprite sheet
            let frameCount = result.frameCount
            let singleFrameHeight = originalHeight

            // Scale factor (same as PNG import logic)
            let scale = min(targetSizeF / originalWidth, targetSizeF / singleFrameHeight)
            let scaledWidth = originalWidth * scale
            let scaledHeight = singleFrameHeight * scale

            // Offset for centering
            let offsetX = (targetSizeF - scaledWidth) / 2
            let offsetY = (targetSizeF - scaledHeight) / 2

            // Scale hotspot proportionally and add offset
            let scaledHotspotX = CGFloat(result.hotspotX) * scale + offsetX
            let scaledHotspotY = CGFloat(result.hotspotY) * scale + offsetY

            // Set hotspot (scaled and centered)
            cursor.hotSpot = NSPoint(x: scaledHotspotX, y: scaledHotspotY)

            // Set size to 32x32 points (since we use 2x scale, same as PNG import)
            cursor.size = NSSize(width: 32, height: 32)

            // Scale the bitmap to standard size (64x64 per frame)
            if frameCount > 1 {
                // Animated cursor: scale each frame and stack vertically
                guard let scaledBitmap = scaleWindowsSpriteSheet(originalBitmap, frameCount: frameCount, originalFrameWidth: Int(originalWidth), originalFrameHeight: Int(singleFrameHeight)) else {
                    print("Failed to scale animated cursor sprite sheet")
                    return false
                }
                cursor.setRepresentation(scaledBitmap, for: targetScale)
            } else {
                // Static cursor: scale to 64x64
                guard let scaledBitmap = scaleImageToStandardSize(originalBitmap) else {
                    print("Failed to scale Windows cursor")
                    return false
                }
                cursor.setRepresentation(scaledBitmap, for: targetScale)
            }

            appState.markAsChanged()

            // Trigger refresh
            localRefreshTrigger += 1
            appState.cursorListRefreshTrigger += 1

            let frameInfo = result.frameCount > 1 ? " (\(result.frameCount) frames)" : ""
            print("Windows cursor imported: \(result.width)x\(result.height)\(frameInfo) → \(standardCursorSize)x\(standardCursorSize)")
            return true

        } catch {
            print("Failed to convert Windows cursor: \(error.localizedDescription)")
            appState.imageImportWarningMessage = "Failed to import Windows cursor: \(error.localizedDescription)"
            appState.showImageImportWarning = true
            return false
        }
    }

    /// Scale a Windows cursor sprite sheet (animated cursor with multiple frames stacked vertically)
    private func scaleWindowsSpriteSheet(_ original: NSBitmapImageRep, frameCount: Int, originalFrameWidth: Int, originalFrameHeight: Int) -> NSBitmapImageRep? {
        let targetSize = standardCursorSize

        // Create new bitmap for the scaled sprite sheet
        guard let newBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetSize,
            pixelsHigh: targetSize * frameCount,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: targetSize * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }

        // Calculate aspect-fit scaling
        let originalWidth = CGFloat(originalFrameWidth)
        let originalHeight = CGFloat(originalFrameHeight)
        let targetSizeF = CGFloat(targetSize)

        let scale = min(targetSizeF / originalWidth, targetSizeF / originalHeight)
        let scaledWidth = originalWidth * scale
        let scaledHeight = originalHeight * scale

        // Center offset
        let offsetX = (targetSizeF - scaledWidth) / 2
        let offsetY = (targetSizeF - scaledHeight) / 2

        // Draw into new bitmap
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: newBitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context

        // Clear to transparent
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: targetSize, height: targetSize * frameCount).fill()

        // Create source image from original bitmap
        let sourceImage = NSImage(size: NSSize(width: original.pixelsWide, height: original.pixelsHigh))
        sourceImage.addRepresentation(original)

        // Draw each frame
        for frameIndex in 0..<frameCount {
            // Source rect for this frame in the original sprite sheet
            let srcY = CGFloat(frameIndex) * originalHeight
            let srcRect = NSRect(x: 0, y: srcY, width: originalWidth, height: originalHeight)

            // Destination rect for this frame in the scaled sprite sheet
            let dstY = CGFloat(frameIndex) * targetSizeF + offsetY
            let dstRect = NSRect(x: offsetX, y: dstY, width: scaledWidth, height: scaledHeight)

            sourceImage.draw(in: dstRect, from: srcRect, operation: .copy, fraction: 1.0)
        }

        NSGraphicsContext.restoreGraphicsState()

        return newBitmap
    }
}

// MARK: - Helper Tool Settings Section

import ServiceManagement

struct HelperToolSettingsView: View {
    private static let helperBundleIdentifier = "com.sdmj76.mousecloakhelper"

    @State private var isHelperInstalled = false
    @State private var showInstallAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @Environment(LocalizationManager.self) private var localization

    var body: some View {
        Section(localization.localized("Helper Tool")) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.localized("Mousecape Helper"))
                        .font(.headline)
                    Text(isHelperInstalled ? localization.localized("Installed and running") : localization.localized("Not installed"))
                        .font(.caption)
                        .foregroundStyle(isHelperInstalled ? .green : .secondary)
                }

                Spacer()

                Button(isHelperInstalled ? localization.localized("Uninstall") : localization.localized("Install")) {
                    toggleHelper()
                }
            }

            Text(localization.localized("Once installed, the helper tool will automatically apply cursors at system startup without manually applying them."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            checkHelperStatus()
        }
        .alert(alertTitle, isPresented: $showInstallAlert) {
            Button(localization.localized("OK")) { }
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
                alertTitle = localization.localized("Success")
                alertMessage = localization.localized("The Mousecape helper was successfully installed.")
            } else {
                try service.unregister()
                isHelperInstalled = false
                alertTitle = localization.localized("Success")
                alertMessage = localization.localized("The Mousecape helper was successfully uninstalled.")
            }
        } catch {
            alertTitle = localization.localized("Error")
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
