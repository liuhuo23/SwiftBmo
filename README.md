# swift ui 定时器
```swift
import SwiftUI

struct TimerView: View {
    @State private var message = "等待定时器..."
    @State private var timer: Timer?

    var body: some View {
        VStack {
            Text(message)
                .font(.largeTitle)
                .padding()
            
            Button("开始定时器") {
                startTimer()
            }
            .padding()
            
            Button("停止定时器") {
                stopTimer()
            }
            .padding()
        }
        .onDisappear {
            stopTimer()
        }
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            message = "定时器触发！时间: \(Date())"
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
        message = "定时器已停止"
    }
}

#Preview {
    TimerView()
}
```
