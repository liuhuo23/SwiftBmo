# 注意点 onChange 最新的使用方法
```swift
.onChange(of: subjects.count) { _, _ in
        if viewModel.selectSubject == nil, let first = subjects.first {
              viewModel.selectSubject = first
         }
}
```