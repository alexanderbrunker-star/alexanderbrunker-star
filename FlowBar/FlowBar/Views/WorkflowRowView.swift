import SwiftUI

struct WorkflowRowView: View {
    @EnvironmentObject var appState: AppState
    let workflow: Workflow

    @State private var isExpanded = false
    @State private var showDetail = false
    @State private var isHovered  = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button { isExpanded.toggle() } label: {
                HStack(spacing: 10) {
                    statusDot
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(workflow.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(workflow.enabled ? .primary : .secondary)
                                .lineLimit(1)

                            if !workflow.tags.isEmpty {
                                ForEach(workflow.tags.prefix(2), id: \.self) { tag in
                                    TagView(tag: tag)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            typeLabel
                            Spacer()
                            scheduleLabel
                        }
                    }

                    Spacer(minLength: 0)
                    chevron
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color(NSColor.controlBackgroundColor) : Color.clear)
            )
            .onHover { isHovered = $0 }

            // Expanded actions
            if isExpanded {
                expandedActions
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(statusBorderColor, lineWidth: 0.5)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        .sheet(isPresented: $showDetail) {
            WorkflowDetailView(workflow: workflow)
                .environmentObject(appState)
        }
    }

    // MARK: - Status Dot

    private var statusDot: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 28, height: 28)

            Image(systemName: workflow.lastStatus.icon)
                .font(.system(size: 14))
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: workflow.lastStatus == .running)
        }
    }

    // MARK: - Labels

    private var typeLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: workflow.type.icon)
                .font(.system(size: 9))
            Text(workflow.type.displayName)
                .font(.system(size: 10))
        }
        .foregroundStyle(.secondary)
    }

    private var scheduleLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
                .font(.system(size: 9))
            Text(workflow.schedule.nextRunDescription)
                .font(.system(size: 10))
        }
        .foregroundStyle(workflow.lastStatus == .failed ? .red.opacity(0.8) : .secondary)
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .rotationEffect(isExpanded ? .degrees(180) : .zero)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    // MARK: - Expanded Actions

    private var expandedActions: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !workflow.description.isEmpty {
                Text(workflow.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
            }

            // Last run info
            if let lastRun = workflow.lastRun {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                    Text("Last run: \(lastRun.relativeFormatted)")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
            }

            Divider().padding(.horizontal, 10)

            // Action buttons
            HStack(spacing: 6) {
                ActionButton(
                    label: "Run Now",
                    icon: "play.fill",
                    color: .green,
                    disabled: !workflow.enabled || appState.isPaused
                ) {
                    appState.runWorkflow(workflow)
                    isExpanded = false
                }

                ActionButton(
                    label: workflow.enabled ? "Disable" : "Enable",
                    icon: workflow.enabled ? "pause.fill" : "play.fill",
                    color: workflow.enabled ? .orange : .blue,
                    disabled: false
                ) {
                    appState.toggleEnabled(workflow)
                }

                ActionButton(
                    label: "Edit",
                    icon: "pencil",
                    color: .secondary,
                    disabled: false
                ) {
                    showDetail = true
                    isExpanded = false
                }

                ActionButton(
                    label: "Delete",
                    icon: "trash",
                    color: .red,
                    disabled: false
                ) {
                    appState.deleteWorkflow(workflow)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Colors

    private var statusColor: Color {
        switch workflow.lastStatus {
        case .idle:     return workflow.enabled ? .gray : .gray.opacity(0.5)
        case .running:  return .blue
        case .success:  return .green
        case .failed:   return .red
        case .skipped:  return .orange
        case .disabled: return .gray.opacity(0.5)
        }
    }

    private var statusBorderColor: Color {
        switch workflow.lastStatus {
        case .running: return .blue.opacity(0.4)
        case .failed:  return .red.opacity(0.3)
        default:       return .white.opacity(0.08)
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(disabled ? .tertiary : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((disabled ? Color.gray : color).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Tag View

struct TagView: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.blue.opacity(0.1))
            .clipShape(Capsule())
    }
}
