import SwiftUI

// MARK: – Template Management

@MainActor
final class TemplateViewModel: ObservableObject {
    @Published var templates: [ResourceTemplate] = []
    @Published var isLoading = false
    @Published var error: Error?
    private let api = APIClient.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }
        templates = (try? await api.listTemplates()) ?? []
    }

    func create(_ template: ResourceTemplate) async throws {
        let created = try await api.createTemplate(template)
        templates.append(created)
    }

    func update(_ template: ResourceTemplate) async throws {
        let updated = try await api.updateTemplate(id: template.id, template)
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = updated
        }
    }

    func delete(id: Int) async throws {
        try await api.deleteTemplate(id: id)
        templates.removeAll { $0.id == id }
    }

    func apply(yaml: String) async throws -> ApplyResourceResponse {
        return try await api.applyResource(yaml: yaml)
    }
}

struct TemplateListView: View {
    @StateObject private var vm = TemplateViewModel()
    @State private var showCreate = false
    @State private var editingTemplate: ResourceTemplate?

    var body: some View {
        Group {
            if vm.templates.isEmpty && !vm.isLoading {
                ContentUnavailableView(
                    "No Templates",
                    systemImage: "doc.text.below.ecg",
                    description: Text("Create YAML templates for quick resource creation.")
                )
            } else {
                List {
                    ForEach(vm.templates) { template in
                        TemplateRow(template: template, vm: vm)
                            .onTapGesture { editingTemplate = template }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { try? await vm.delete(id: template.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreate) {
            TemplateFormView(vm: vm)
        }
        .sheet(item: $editingTemplate) { t in
            TemplateFormView(vm: vm, editing: t)
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .loadingOverlay(vm.isLoading && vm.templates.isEmpty)
    }
}

private struct TemplateRow: View {
    let template: ResourceTemplate
    @ObservedObject var vm: TemplateViewModel
    @State private var showApplyAlert = false
    @State private var applyResult: ApplyResourceResponse?
    @State private var applyError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name).font(.headline)
            if !template.description.isEmpty {
                Text(template.description).font(.caption).foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await applyTemplate() }
            } label: {
                Label("Apply", systemImage: "play.fill")
            }
            .tint(.green)
        }
        .alert("Applied", isPresented: .constant(applyResult != nil)) {
            Button("OK") { applyResult = nil }
        } message: {
            if let r = applyResult { Text("\(r.kind)/\(r.name) applied.") }
        }
        .alert("Error", isPresented: .constant(applyError != nil)) {
            Button("OK") { applyError = nil }
        } message: { Text(applyError ?? "") }
    }

    private func applyTemplate() async {
        do {
            applyResult = try await vm.apply(yaml: template.yaml)
        } catch {
            applyError = error.localizedDescription
        }
    }
}

struct TemplateFormView: View {
    @ObservedObject var vm: TemplateViewModel
    var editing: ResourceTemplate? = nil

    @State private var name = ""
    @State private var description = ""
    @State private var yaml = ""
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Info") {
                        TextField("Name", text: $name)
                        TextField("Description", text: $description)
                    }
                }
                .frame(height: 160)

                Text("YAML").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 4)

                YAMLEditorView(text: $yaml)

                if let err = error {
                    Text(err).foregroundStyle(.red).font(.caption).padding()
                }
            }
            .navigationTitle(editing != nil ? "Edit Template" : "New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(name.isEmpty || yaml.isEmpty || isSaving)
                        .bold()
                }
            }
        }
        .onAppear {
            if let t = editing {
                name        = t.name
                description = t.description
                yaml        = t.yaml
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let template = ResourceTemplate(ID: editing?.ID ?? 0, name: name, description: description, yaml: yaml)
        do {
            if editing != nil { try await vm.update(template) }
            else              { try await vm.create(template) }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
