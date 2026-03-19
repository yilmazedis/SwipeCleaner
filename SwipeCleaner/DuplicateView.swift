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
}

struct DuplicateView: View {
    let groups: [[URL]]
    var onDelete: (URL) -> Void

    @State var viewModel = DuplicateViewModel()

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
                    let visibleFiles = groups[index].filter { !viewModel.deletedURLs.contains($0) }
                    if visibleFiles.count > 1 {
                        Section(header: Text("Group \(index + 1) — \(visibleFiles.count) copies")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(visibleFiles, id: \.self) { url in
                                        DuplicateThumbnailView(url: url) {
                                            viewModel.deletedURLs.insert(url)
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
                if !viewModel.deletedURLs.contains(file) {
                    onDelete(file)
                    viewModel.deletedURLs.insert(file)
                }
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
