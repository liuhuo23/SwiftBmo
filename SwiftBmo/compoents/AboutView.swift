//
//  AboutView.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/8.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack {
            HStack{
                #if os(macOS)
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(16)
                #else
                Image("bmo")
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(16)
                #endif
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("SwiftBmo")
                        .font(.largeTitle)
                        .bold()
                    
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text("版本 \(version)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    
                    Text("一个简单的计时器应用")
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal)
                    
                    Link("GitHub", destination: URL(string: "https://github.com/liuhuo23/SwiftBmo")!)
                        .font(.body)
                        .foregroundColor(.blue)
                    
                    Text("© 2025 liuhuo. All rights reserved.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            Spacer()

            HStack {
                Spacer()
                Button("关闭") {
                    dismissWindow()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
    }
}


#Preview {
    AboutView()
}
