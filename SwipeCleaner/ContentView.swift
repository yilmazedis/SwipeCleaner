import SwiftUI
import AVKit
import UniformTypeIdentifiers
import CryptoKit
import Vision

@Observable
final class ContentViewModel {
    @ObservationIgnored var loadingFolderTask: Task<Void, Error>?
    
    deinit {
        loadingFolderTask?.cancel()
        loadingFolderTask = nil
    }
}

struct ContentView: View {
    @State private var folderURL: URL?
    @State private var keepFolderURL: URL?
    @State private var mediaFiles: [URL] = []
    @State private var mediaFilesLoading = false
    @State private var currentIndex = 0
    @State private var errorMessage: String?
    @State private var actionFeedback: ActionFeedback? = nil
    @State private var keptCount = 0
    @State private var deletedCount = 0
    @FocusState private var viewerFocused: Bool
    
    @State private var duplicateGroups: [[URL]] = []
    @State private var showingDuplicates = false
    @State private var hideDuplicatesButton = true
    @State private var isFaceFiltering = false
    @State private var numberOfFaceFilteredFiles = 0
    @State private var numberOfFaceCheckedFiles = 0
    
    let viewModel = ContentViewModel()
    
    private let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"]
    private let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]

    enum ActionFeedback: Equatable {
        case kept, deleted
    }
    
    var body: some View {
        content
            .sheet(isPresented: $showingDuplicates) {
                DuplicateView(groups: duplicateGroups) { urlToDelete in
                    do {
                        try FileManager.default.trashItem(at: urlToDelete, resultingItemURL: nil)
                        deletedCount += 1
                        mediaFiles.removeAll { $0 == urlToDelete }
                        if currentIndex >= mediaFiles.count {
                            currentIndex = max(0, mediaFiles.count - 1)
                        }
                    } catch {
                        errorMessage = "Could not delete \(urlToDelete.lastPathComponent): \(error.localizedDescription)"
                    }
                }
            }
            .frame(minWidth: 700, minHeight: 500)
            .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { message in
                Text(message)
            }
    }
    
    var content: some View {
        VStack(spacing: 0) {

            // ── Top bar ──────────────────────────────────────────────────
            VStack {
                HStack(spacing: 12) {
                    // Source folder
                    Button {
                        viewModel.loadingFolderTask?.cancel()
                        viewModel.loadingFolderTask = Task {
                            mediaFilesLoading = true
                            defer {
                                mediaFilesLoading = false
                            }
                           
                            await selectFolder()
                        }
                    } label: {
                        Label(folderURL?.lastPathComponent ?? "Open Folder…", systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.bordered)

                    Divider().frame(height: 20)

                    // Keep destination
                    Button {
                        selectKeepFolder()
                    } label: {
                        Label(keepFolderURL?.lastPathComponent ?? "Set Keep Folder…",
                              systemImage: "folder.badge.checkmark")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(keepFolderURL == nil ? .orange : .primary)
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                    
                    // Stats
                    if folderURL != nil {
                        Button {
                            filterFaceForAllImage()
                        } label: {
                            if isFaceFiltering {
                                ProgressView()
                            } else {
                                Label("Filter Faces", systemImage: "face.dashed")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(isFaceFiltering)
                        
                        if !hideDuplicatesButton {
                            Button {
                                showingDuplicates.toggle()
                            } label: {
                                Label("Find Duplicates", systemImage: "square.stack.3d.up")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Button {
                            deleteSeenFiles()
                        } label: {
                            Label("Delete Seen", systemImage: "trash.slash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)

                        HStack(spacing: 16) {
                            Label("\(keptCount) kept", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.callout)
                            Label("\(deletedCount) deleted", systemImage: "trash.fill")
                                .foregroundColor(.red)
                                .font(.callout)
                        }
                    }

                    Spacer()

                    // File counter
                    if !mediaFiles.isEmpty {
                        Text("\(currentIndex + 1) / \(mediaFiles.count)")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .font(.callout)
                    }
                    
                    if mediaFilesLoading {
                        HStack {
                            Text("Loading Files")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                                .font(.callout)
                            
                            ProgressView()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
                
                if isFaceFiltering {
                    HStack {
                        Spacer()
                        Text("\(numberOfFaceFilteredFiles) Filtered")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .font(.callout)
                        
                        Text("\(numberOfFaceCheckedFiles) Checked")
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .font(.callout)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }

            // ── File name strip ──────────────────────────────────────────
            if let fileURL = currentFile {
                HStack {
                    Image(systemName: isImage(fileURL) ? "photo" : "film")
                        .foregroundColor(.secondary)
                    Text(fileURL.lastPathComponent)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color(NSColor.windowBackgroundColor))
            }

            // ── Media display ────────────────────────────────────────────
            ZStack {
                Color.black

                if let fileURL = currentFile {
                    if isImage(fileURL) {
                        ImageView(fileURL: fileURL)
                            .padding(20)
                            .id(fileURL)
                    } else if isVideo(fileURL) {
                        VideoPlayerView(fileURL: fileURL)
                            .padding(20)
                            .id(fileURL)
                    } else {
                        Text("Unsupported file type")
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(folderURL == nil ? "Open a folder to start cleaning" : "No media files found")
                            .foregroundColor(.secondary)
                    }
                }

                // ── Action feedback toast (bottom-right corner, non-blocking) ──
                if let feedback = actionFeedback {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Image(systemName: feedback == .kept ? "checkmark.circle.fill" : "trash.fill")
                                    .foregroundColor(feedback == .kept ? .green : .red)
                                Text(feedback == .kept ? "Kept" : "Deleted")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.65))
                            .cornerRadius(10)
                            .padding(16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.25), value: actionFeedback)
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusable()
            .focused($viewerFocused)
            .onAppear {
                viewerFocused = true
            }
            .onChange(of: currentIndex) { _, _ in
                viewerFocused = true
            }
            .onKeyPress(keys: ["d", "k", "x", .leftArrow, .rightArrow]) { press in
                handleKeyPress(press)
            }

            // ── Bottom hint bar ──────────────────────────────────────────
            HStack(spacing: 24) {
                Spacer()
                keyHint(key: "←", label: "Previous")
                keyHint(key: "→", label: "Next")

                Divider().frame(height: 16)

                keyHint(key: "K", label: "Keep", color: .green)
                keyHint(key: "D", label: "Delete", color: .red)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    // MARK: - Key hint view
    @ViewBuilder
    private func keyHint(key: String, label: String, color: Color = .secondary) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(NSColor.controlColor))
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            Text(label)
                .font(.caption)
                .foregroundColor(color == .secondary ? .secondary : color)
        }
    }

    // MARK: - Helpers
    private var currentFile: URL? {
        guard !mediaFiles.isEmpty, currentIndex >= 0, currentIndex < mediaFiles.count else { return nil }
        return mediaFiles[currentIndex]
    }

    private func isImage(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    private func isVideo(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Folder selection
    private func selectFolder() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // Request security-scoped access so file operations are permitted
        
        let response = await panel.begin()
        
        // Start accessing the security-scoped resource
        guard response == .OK, let url = panel.url else {
            return
        }
        
        _ = url.startAccessingSecurityScopedResource()
        folderURL = url
        keptCount = 0
        deletedCount = 0
        currentIndex = 0
        duplicateGroups = []
        hideDuplicatesButton = true

        self.mediaFiles = []
        
        let mediaFiles = await loadMedia(from: url)
        self.mediaFiles = mediaFiles
        findDuplicates(mediaFiles: mediaFiles)
    }

    private func selectKeepFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Set as Keep Folder"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                // Start accessing the security-scoped resource
                _ = url.startAccessingSecurityScopedResource()
                keepFolderURL = url
            }
        }
    }

    // MARK: - Load media
    private nonisolated func loadMedia(from folder: URL) async -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        var files: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.hasDirectoryPath { continue }
            let ext = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(ext) || videoExtensions.contains(ext) {
                files.append(fileURL)
            }
        }
        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Key handling
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow:
            guard !mediaFiles.isEmpty else { return .ignored }
            currentIndex = (currentIndex - 1 + mediaFiles.count) % mediaFiles.count
            return .handled

        case .rightArrow:
            guard !mediaFiles.isEmpty else { return .ignored }
            currentIndex = (currentIndex + 1) % mediaFiles.count
            return .handled

        case KeyEquivalent("k"):
            keepCurrentFile()
            return .handled

        case KeyEquivalent("d"):
            deleteCurrentFile()
            return .handled
            
        case KeyEquivalent("x"):
            deleteSeenFiles()
            return .handled

        default:
            return .ignored
        }
    }

    // MARK: - Keep
    private func keepCurrentFile() {
        guard let fileURL = currentFile else { return }

        // If no keep folder is set, ask the user to set one first
        if keepFolderURL == nil {
            selectKeepFolder()
            return
        }

        guard let destination = keepFolderURL else { return }

        let destURL = destination.appendingPathComponent(fileURL.lastPathComponent)

        do {
            // If a file with the same name already exists, add a suffix
            let finalDest = uniqueURL(for: destURL)
            try FileManager.default.moveItem(at: fileURL, to: finalDest)
            keptCount += 1
            showFeedback(.kept)
            advanceAfterAction()
        } catch {
            errorMessage = "Could not move file to Keep folder: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete
    private func deleteCurrentFile() {
        guard let fileURL = currentFile else { return }
        do {
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            deletedCount += 1
            showFeedback(.deleted)
            advanceAfterAction()
        } catch {
            errorMessage = "Failed to move file to Trash: \(error.localizedDescription)"
        }
    }
    
    private func deleteSeenFiles() {

        guard currentIndex > 0 else { return }

        let filesToDelete = Array(mediaFiles.prefix(currentIndex))

        for file in filesToDelete {
            do {
                try FileManager.default.trashItem(at: file, resultingItemURL: nil)
                deletedCount += 1
            } catch {
                errorMessage = "Failed deleting \(file.lastPathComponent)"
            }
        }

        mediaFiles.removeFirst(currentIndex)
        currentIndex = 0
    }

    // MARK: - After action helpers
    private func advanceAfterAction() {
        mediaFiles.remove(at: currentIndex)
        if mediaFiles.isEmpty {
            currentIndex = 0
        } else if currentIndex >= mediaFiles.count {
            currentIndex = mediaFiles.count - 1
        }
        // currentIndex stays the same — effectively advances to next file
    }

    private func showFeedback(_ feedback: ActionFeedback) {
        withAnimation(.spring(response: 0.2)) {
            actionFeedback = feedback
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                actionFeedback = nil
            }
        }
    }

    /// Returns a URL that doesn't conflict with existing files by appending a number suffix
    private func uniqueURL(for url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        let dir = url.deletingLastPathComponent()
        var counter = 1
        var candidate: URL
        repeat {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = dir.appendingPathComponent(name)
            counter += 1
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }

    private nonisolated func fileHash(for url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private nonisolated func findDuplicates(mediaFiles: [URL]) {
        var sizeMap: [UInt64: [URL]] = [:]

        for file in mediaFiles {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                sizeMap[UInt64(size), default: []].append(file)
            }
        }

        var hashMap: [String: [URL]] = [:]

        for group in sizeMap.values where group.count > 1 {
            for file in group {
                if let hash = fileHash(for: file) {
                    hashMap[hash, default: []].append(file)
                }
            }
        }
        
        let duplicates = hashMap.values.filter { $0.count > 1 }
        
        Task { @MainActor in
            duplicateGroups = duplicates
            hideDuplicatesButton = duplicates.isEmpty
        }
    }
    
    private func filterFaceForAllImage() {
        Task {
            numberOfFaceFilteredFiles = 0
            numberOfFaceCheckedFiles = 0
            var found: [URL] = []
            for url in mediaFiles {
                if await hasFace(in: url) {
                    found.append(url)
                    numberOfFaceFilteredFiles += 1
                }
                numberOfFaceCheckedFiles += 1
            }
            
            isFaceFiltering = true
            defer {
                isFaceFiltering = false
            }
            mediaFiles = found
        }
    }
    
    private nonisolated func hasFace(in url: URL) async -> Bool {
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return false }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return !(request.results ?? []).isEmpty
    }
}

struct DuplicateView: View {
    let groups: [[URL]]
    var onDelete: (URL) -> Void

    @State private var deletedURLs: Set<URL> = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Duplicate Files")
                    .font(.title2).bold()
                Spacer()
                
                Button(role: .destructive) {
                    deleteAll()
                } label: {
                    Label("Delete All", systemImage: "trash")
                        .font(.caption)
                        .frame(width: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Text("\(groups.count) group\(groups.count == 1 ? "" : "s")")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            List {
                ForEach(groups.indices, id: \.self) { index in
                    let visibleFiles = groups[index].filter { !deletedURLs.contains($0) }
                    if visibleFiles.count > 1 {
                        Section(header: Text("Group \(index + 1) — \(visibleFiles.count) copies")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(visibleFiles, id: \.self) { url in
                                        DuplicateThumbnailView(url: url) {
                                            deletedURLs.insert(url)
                                            onDelete(url)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
    
    func deleteAll() {
        for files in groups {
            for file in files {
                onDelete(file)
                deletedURLs.insert(file)
            }
        }
    }
}

struct DuplicateThumbnailView: View {
    let url: URL
    let onDelete: () -> Void

    private let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic"]
    private let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]

    @State private var thumbnail: NSImage? = nil
    @State private var fileSize: String = ""

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 160, height: 160)

                if let img = thumbnail {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    ProgressView()
                        .frame(width: 160, height: 160)
                }

                // Video badge
                if isVideo(url) {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                                .padding(4)
                                .background(.black.opacity(0.6))
                                .cornerRadius(4)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(6)
                    }
                    .frame(width: 160, height: 160)
                }
            }

            Text(url.lastPathComponent)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 160)

            Text(fileSize)
                .font(.caption2)
                .foregroundColor(.secondary)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.caption)
                    .frame(width: 140)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .onAppear {
            loadThumbnail()
            loadFileSize()
        }
    }

    private func isImage(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    private func isVideo(_ url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }

    private func loadThumbnail() {
        var img: NSImage?

        if isImage(url) {
            img = NSImage(contentsOf: url)
        } else if isVideo(url) {
            let asset = AVAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 320, height: 320)
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            if let cgImg = try? gen.copyCGImage(at: time, actualTime: nil) {
                img = NSImage(cgImage: cgImg, size: .zero)
            }
        }

        thumbnail = img
    }

    private func loadFileSize() {
        DispatchQueue.global(qos: .utility).async {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            DispatchQueue.main.async {
                fileSize = formatted
            }
        }
    }
}
