//
//  DuplicateView.swift
//  SwipeCleaner
//
//  Created by Yılmaz Edis on 20.03.2026.
//

import SwiftUI
import AVKit

@MainActor
@Observable
final class DuplicateViewModel {
    @ObservationIgnored var deletedURLs: Set<URL> = []

    // Precomputed so the List body never iterates all groups
    func visibleGroups(from groups: [[URL]]) -> [(index: Int, files: [URL])] {
        groups.enumerated().compactMap { (i, group) in
            let visible = group.filter { !deletedURLs.contains($0) }
            return visible.count > 1 ? (index: i, files: visible) : nil
        }
    }
}

struct DuplicateView: View {
    let groups: [[URL]]
    var onDelete: (URL) -> Void

    @State var viewModel = DuplicateViewModel()

    // Derive once per render; @Observable invalidates this when deletedURLs changes
    private var visibleGroups: [(index: Int, files: [URL])] {
        viewModel.visibleGroups(from: groups)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Duplicate Files")
                    .font(.title2).bold()
                Spacer()
                Text("\(visibleGroups.count) group\(visibleGroups.count == 1 ? "" : "s")")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // LazyVStack: only renders rows near the viewport
            ScrollView(.vertical) {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(visibleGroups, id: \.index) { group in
                        Section {
                            // LazyHStack: only renders thumbnails near the horizontal viewport
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(group.files, id: \.self) { url in
                                        DuplicateThumbnailView(url: url) {
                                            viewModel.deletedURLs.insert(url)
                                            onDelete(url)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                            }
                        } header: {
                            HStack {
                                Text("Group \(group.index + 1) — \(group.files.count) copies")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
                        }
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
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
