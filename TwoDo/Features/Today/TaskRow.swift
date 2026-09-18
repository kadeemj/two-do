import SwiftUI
import SwiftData

struct TaskRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TodoTask
    var isOverdue: Bool = false
    var showDragHandle: Bool = true
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProjectColorStripe(hex: task.project?.colorHex)
                .frame(height: 40)
                .padding(.top, 2)

            Button {
                toggleComplete()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(task.isCompleted ? TwoDoColor.accentBlue : Color.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Button {
                    onTap?()
                } label: {
                    Text(task.title)
                        .font(TwoDoTypography.taskTitle)
                        .foregroundStyle(titleColor)
                        .strikethrough(task.isCompleted, color: .secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                metadataRow

                if let subs = task.subtasks?.filter({ !$0.isCompleted }), !subs.isEmpty {
                    ForEach(subs.sorted(by: { $0.sortIndex < $1.sortIndex }), id: \.id) { sub in
                        SubtaskRow(task: sub)
                    }
                }
            }

            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(TwoDoColor.project(from: task.project?.colorHex ?? "AAAAAA").opacity(0.55))
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, TwoDoSpacing.rowHorizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private var titleColor: Color {
        if task.isCompleted { return .secondary }
        return isOverdue ? TwoDoColor.overdue : Color.primary
    }

    @ViewBuilder
    private var metadataRow: some View {
        HStack(spacing: 10) {
            if task.isFlagged {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            if task.recurrence != nil {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .medium))
                    .accessibilityLabel(task.recurrence?.displayName ?? "Recurring")
            }
            if task.hasLocation {
                Image(systemName: "mappin")
                    .font(.system(size: 12, weight: .medium))
            }
            if task.hasPhone {
                Image(systemName: "phone")
                    .font(.system(size: 12, weight: .medium))
            }
            if let tag = task.tags?.sorted(by: {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }).first {
                Label(tag.name, systemImage: "tag")
                    .font(TwoDoTypography.metadata)
                    .lineLimit(1)
            }
            if let minutes = task.durationMinutes {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .medium))
                    Text(DateFormatting.durationLabel(minutes))
                        .font(TwoDoTypography.metadata)
                }
            }
            if let due = task.dueAt {
                Text(DateFormatting.relativeDue(due))
                    .font(TwoDoTypography.metadata)
                    .foregroundStyle(TwoDoColor.accentBlue)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(TwoDoColor.metadata)
    }

    private func toggleComplete() {
        withAnimation(.snappy) {
            _ = try? TaskCompletion.toggle(task, in: modelContext)
        }
    }
}

struct SubtaskRow: View {
    @Bindable var task: TodoTask

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
            Image(systemName: "briefcase.fill")
                .font(.system(size: 11))
                .foregroundStyle(TwoDoColor.project(from: task.project?.colorHex ?? "598FE8"))
            Text(task.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.leading, 2)
        .padding(.top, 3)
    }
}

/// Swipe-left-to-delete for rows hosted in a ScrollView (where List's native
/// swipeActions are unavailable). Reveals a delete button at the trailing
/// edge; a long full swipe deletes immediately.
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offsetX: CGFloat = 0
    @State private var isOpen = false

    private let revealWidth: CGFloat = 84
    private let fullSwipeDistance: CGFloat = 220

    init(onDelete: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.onDelete = onDelete
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if offsetX < 0 {
                Rectangle()
                    .fill(TwoDoColor.overdue)
                    .frame(width: -offsetX)
                    .overlay(alignment: .trailing) {
                        Button(action: performDelete) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: min(revealWidth, -offsetX))
                                .frame(maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete task")
                    }
            }

            content()
                .background(Color(.systemBackground))
                .overlay {
                    if isOpen {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { setOpen(false) }
                    }
                }
                .offset(x: offsetX)
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    guard isOpen || abs(value.translation.width) > abs(value.translation.height) else { return }
                    let base: CGFloat = isOpen ? -revealWidth : 0
                    offsetX = min(0, base + value.translation.width)
                }
                .onEnded { value in
                    if -offsetX > fullSwipeDistance {
                        performDelete()
                    } else {
                        setOpen(-offsetX > revealWidth * 0.6 || value.predictedEndTranslation.width < -revealWidth)
                    }
                }
        )
        .clipped()
    }

    private func setOpen(_ open: Bool) {
        withAnimation(.snappy) {
            isOpen = open
            offsetX = open ? -revealWidth : 0
        }
    }

    private func performDelete() {
        isOpen = false
        onDelete()
    }
}

struct ProjectColorStripe: View {
    let hex: String?

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(TwoDoColor.project(from: hex ?? "3380F5"))
            .frame(width: TwoDoSpacing.colorStripeWidth)
    }
}

struct TaskSectionHeader: View {
    let title: String
    let count: Int
    var isOverdue: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(TwoDoTypography.sectionHeader)
                .foregroundStyle(isOverdue ? TwoDoColor.overdue : Color.primary)
                .tracking(0.8)
            Spacer()
            Text("\(count)")
                .font(TwoDoTypography.sectionHeader)
                .foregroundStyle(isOverdue ? TwoDoColor.overdue.opacity(0.85) : Color.secondary)
        }
        .padding(.horizontal, TwoDoSpacing.rowHorizontal)
        .padding(.top, TwoDoSpacing.sectionHeaderTop)
        .padding(.bottom, 6)
    }
}
