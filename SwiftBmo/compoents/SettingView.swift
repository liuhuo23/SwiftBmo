//
//  SettingView.swift
//  SwiftBmo
//
//  Created by liuhuo on 2025/12/12.
//

import SwiftUI
import CoreData


struct SettingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Subject.name, ascending: true)],
        animation: .default)
    private var subjects: FetchedResults<Subject>
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tasks.finished_at, ascending: false)],
        animation: .default)
    private var tasks: FetchedResults<Tasks>
    @State private var newSubjectName: String = ""
    @State private var showDeleteAlert = false
    @State private var subjectToDelete: Subject? = nil
    // Presets management
    @StateObject private var appInfo = AppInfo.shared
    @State private var newPresetText: String = ""
    @FocusState private var newPresetFocused: Bool
    @State private var presetAddError: String? = nil
    
    var body: some View {
        TabView {
            Tab("主题管理", systemImage: "tag") {
                VStack(alignment: .leading) {
                    List {
                        ForEach(subjects) { subject in
                            HStack {
                                Text(subject.name ?? "未知主题")
                                Spacer()
                                Button(action: {
                                    subjectToDelete = subject
                                    showDeleteAlert = true
                                }, label: {
                                    Label("删除", systemImage: "trash")
                                        .foregroundColor(.red)
                                })
                            }
                        }
                    }
                    
                    HStack {
                        TextField("新主题名称", text: $newSubjectName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("添加") {
                            addSubject()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                .padding()
                .alert("确认删除", isPresented: $showDeleteAlert, presenting: subjectToDelete) { subject in
                    Button("删除", role: .destructive) {
                        deleteSubject(subject)
                    }
                    Button("取消", role: .cancel) { }
                } message: { subject in
                    Text("确定要删除主题 \(subject.name ?? "未知主题") 吗？")
                }
            }
            
            Tab("其他设置", systemImage: "gear") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("常用秒数（预设）")
                        .font(.headline)

                    // Presets list
                    List {
                        ForEach(appInfo.presets, id: \.self) { p in
                            HStack {
                                Text("\(p) 秒")
                                Spacer()
                                Button(role: .destructive) {
                                    appInfo.removePreset(p)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .onDelete { idx in
                            appInfo.removePreset(at: idx)
                        }
                    }

                    HStack {
                        TextField("新增秒数", text: $newPresetText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 120)
                            .focused($newPresetFocused)
                            .onSubmit {
                                submitNewPreset()
                            }

                        Button("添加") {
                            submitNewPreset()
                        }
                        .buttonStyle(.borderedProminent)

                        if let err = presetAddError {
                            Text(err)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    Spacer()
                }
                .padding()
             }
             
             Tab("历史任务", systemImage: "clock") {
                 VStack {
                     Text("历史任务内容")
                         .font(.headline)
                     // 这里可以添加历史任务的列表或统计信息
                     Table(tasks){
                         TableColumn("主题") { task in
                             Text(task.subject?.name ?? "未知主题")
                         }
                         TableColumn("专注总时间") { task in
                             Text(task.formattedTotalTime)
                         }
                         TableColumn("完成时间") { task in
                             Text(task.finished_at?.formatted(date: .abbreviated, time: .shortened) ?? "未知时间")
                         }
                     }
                 }
                 .padding()
             }
         }
     }
     
     func addSubject() {
         let trimmedName = newSubjectName.trimmingCharacters(in: .whitespaces)
         guard !trimmedName.isEmpty else { return }
         
         let _ = Subject(name: trimmedName, context: viewContext)
         
         do {
             try viewContext.save()
             newSubjectName = ""
         } catch {
             print("Failed to save new subject: \(error)")
         }
     }
     
     private func deleteSubject(_ subject: Subject) {
         withAnimation {
             viewContext.delete(subject)
             
             do {
                 try viewContext.save()
             } catch {
                 print("Failed to delete subject: \(error)")
             }
         }
     }

    private func submitNewPreset() {
        presetAddError = nil
        let trimmed = newPresetText.trimmingCharacters(in: .whitespaces)
        guard let v = Int(trimmed), v > 0 else {
            presetAddError = "请输入正整数秒数"
            return
        }
        appInfo.addPreset(v)
        newPresetText = ""
        newPresetFocused = false
    }
 }
 
 
 #Preview {
     SettingView()
         .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
 }
