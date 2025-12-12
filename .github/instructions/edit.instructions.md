---
applyTo: '**'
---
Provide project context and coding guidelines that AI should follow when generating code, or answering questions.

# onChange的正确写法
```swift
.onChange(of: subjects.count) { _, _ in
        if viewModel.selectSubject == nil, let first = subjects.first {
            viewModel.selectSubject = first
        }
    }
```
注意， _,_ in 其中的第一个下划线代表旧值，第二个下划线代表新值。如果不需要使用它们，可以使用下划线来忽略它们。
