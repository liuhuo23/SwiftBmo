// UpdateManager.swift
// SwiftBmo

import Foundation
import Combine
import SwiftUI


struct UpdateView: View {
    @ObservedObject var manager: UpdateManager

    var body: some View {
        VStack(spacing: 16) {
            Text(sheetTitle)
                .font(.title2)
                .bold()
            switch manager.state {
            case .checking:
                // Show a more prominent checking UI with icon, linear progress and a cancel button
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        #if os(macOS)
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                        #else
                        Image("bmo")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                        #endif

                        VStack(alignment: .leading, spacing: 6) {
                            Text("正在检查更新...")
                                .font(.headline)
                            Text("请稍候，正在检测可用更新")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 6)
                        .padding(.horizontal)

                    HStack {
                        Spacer()
                        Button("取消") {
                            manager.cancelCheck()
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                }

            case .upToDate:
                Text("当前已是最新版本")
                    .foregroundColor(.secondary)
            case .error(let msg):
                Text("检查更新失败：\n\(msg)")
                    .foregroundColor(.red)
            case .available(let info):
                VStack(alignment: .leading, spacing: 8) {
                    Text("版本：v\(info.version)")
                        .font(.headline)
                    if let notes = info.releaseNotes {
                        ScrollView {
                            Text(notes)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 120)
                    }

                    if manager.isDownloading {
                        if let p = manager.downloadProgress {
                            ProgressView(value: p)
                        } else {
                            ProgressView("下载中...")
                        }
                    }

                    HStack {
                        if !manager.isDownloading {
                            Button("下载并安装") {
                                manager.downloadAndInstall(info)
                            }
                            .keyboardShortcut(.defaultAction)
                        }

                        Button("打开下载页") {
                            manager.openURL(info.url)
                        }
                        Spacer()
                        Button("关闭") {
                        }
                    }
                }
            default:
                Text("")
            }

            if let downloaded = manager.downloadedFileURL {
                HStack {
                    Text("已下载：\(downloaded.lastPathComponent)")
                    Spacer()
                    Button("在 Finder 中显示") {
#if os(macOS)
                        NSWorkspace.shared.activateFileViewerSelecting([downloaded])
#endif
                    }
                }
            }

            if let err = manager.downloadError {
                Text("下载失败：\(err)")
                    .foregroundColor(.red)
            }

        }
        .padding()
        .frame(minWidth: 400, minHeight: 200)
        .onAppear {
            UpdateManager.shared.checkForUpdate()
        }
    }

    private var sheetTitle: String {
        switch manager.state {
        case .checking: return "检查更新"
        case .upToDate: return "当前已是最新版本"
        case .error: return "检查更新"
        case .available: return "发现新版本"
        default: return "检查更新"
        }
    }
}


#Preview{
    UpdateView(manager: UpdateManager.shared)
}
