//
//  CircularProgressView.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/7.
//

import SwiftUI

struct CircularProgressView<Content: View>: View {
    private let progress: Double // expected 0...1
    private let lineWidth: CGFloat
    private let backgroundColor: Color
    private let foregroundColor: Color
    private let foregroundGradient: AngularGradient?
    private let content: Content
    private let animationDuration: Double

    // Primary initializer with custom content
    init(progress: Double,
         lineWidth: CGFloat = 10,
         backgroundColor: Color = Color.gray.opacity(0.2),
         foregroundColor: Color = .blue,
         foregroundGradient: AngularGradient? = nil,
         animationDuration: Double = 0.4,
         @ViewBuilder content: () -> Content) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.foregroundGradient = foregroundGradient
        self.content = content()
        self.animationDuration = animationDuration
    }

    // Convenience initializer without custom content (EmptyView)
    init(progress: Double,
         lineWidth: CGFloat = 10,
         backgroundColor: Color = Color.gray.opacity(0.2),
         foregroundColor: Color = .blue,
         foregroundGradient: AngularGradient? = nil,
         animationDuration: Double = 0.4) where Content == EmptyView {
        self.progress = progress
        self.lineWidth = lineWidth
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.foregroundGradient = foregroundGradient
        self.content = EmptyView()
        self.animationDuration = animationDuration
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let clamped = progress.isFinite ? min(max(progress, 0.0), 1.0) : 0.0

            ZStack {
                // Background ring
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    .foregroundColor(backgroundColor)

                // Foreground progress
                // Use gradient when provided, otherwise use a solid color.
                Group {
                    if let gradient = foregroundGradient {
                        Circle()
                            .trim(from: 0.0, to: CGFloat(clamped))
                            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(gradient)
                    } else {
                        Circle()
                            .trim(from: 0.0, to: CGFloat(clamped))
                            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(foregroundColor)
                    }
                }
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: animationDuration), value: clamped)

                // Content overlay (centered)
                content
                    .allowsHitTesting(false)
            }
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Progress"))
            .accessibilityValue(Text("\(Int(clamped * 100)) percent"))
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 24) {
        CircularProgressView(progress: 0.7) {
            Text("70%")
                .font(.title)
                .bold()
        }
        .frame(width: 120, height: 120)

        CircularProgressView(progress: 0.35, lineWidth: 14, foregroundGradient: AngularGradient(gradient: Gradient(colors: [.purple, .pink, .orange]), center: .center)) {
            VStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.linearGradient(Gradient(colors: [.orange, .red]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .font(.title)
                Text("35%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 100, height: 100)

        CircularProgressView(progress: 0.9, lineWidth: 8, backgroundColor: Color.black.opacity(0.05), foregroundColor: .green)
            .frame(width: 80, height: 80)
    }
    .padding()
}
