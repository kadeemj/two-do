import SwiftUI
import UniformTypeIdentifiers

struct HourlyScheduleView: View {
    let day: Date
    let blocks: [TimelineBlock]
    var dayStartHour: Int = 6
    var dayEndHour: Int = 23
    var onDropTask: ((UUID, Date) -> Void)?
    var onMoveTask: ((UUID, Date) -> Void)?
    var onResizeTask: ((UUID, Int) -> Void)?
    var onTapTask: ((UUID) -> Void)?

    @State private var isDropTargeted = false

    // Expand the grid so blocks outside the default range never render past its edges.
    private var effectiveStartHour: Int {
        let earliest = blocks.map { Calendar.current.component(.hour, from: $0.start) }.min()
        return max(min(dayStartHour, earliest ?? dayStartHour), 0)
    }

    private var effectiveEndHour: Int {
        let calendar = Calendar.current
        let latest = blocks.map { block -> Int in
            let hour = calendar.component(.hour, from: block.end)
            let minute = calendar.component(.minute, from: block.end)
            return minute > 0 ? hour + 1 : hour
        }.max()
        return min(max(dayEndHour, latest ?? dayEndHour), 24)
    }

    private var hours: [Int] { Array(effectiveStartHour...effectiveEndHour) }
    private var gaps: [ScheduleGap] { ScheduleLayout.gaps(between: blocks) }

    var body: some View {
        GeometryReader { geo in
            let totalHours = CGFloat(max(effectiveEndHour - effectiveStartHour, 1))
            let hourHeight = max(geo.size.height / totalHours, TwoDoSpacing.scheduleHourHeight)
            let totalHeight = hourHeight * totalHours

            ZStack(alignment: .topLeading) {
                hourGrid(hourHeight: hourHeight, totalHeight: totalHeight)

                ForEach(gaps) { gap in
                    let y = yOffset(for: gap.start, hourHeight: hourHeight)
                    let mid = y + height(from: gap.start, to: gap.end, hourHeight: hourHeight) / 2 - 12
                    FreeTimeGap(minutes: gap.minutes)
                        .padding(.leading, 64)
                        .padding(.trailing, 16)
                        .offset(y: mid)
                }

                ForEach(blocks) { block in
                    if let taskID = block.taskID {
                        InteractiveScheduleBlock(
                            block: block,
                            taskID: taskID,
                            initialYOffset: yOffset(for: block.start, hourHeight: hourHeight),
                            hourHeight: hourHeight,
                            totalHeight: totalHeight,
                            maximumDurationMinutes: maximumDuration(for: block),
                            onMove: { newStart in
                                onMoveTask?(taskID, newStart)
                            },
                            onResize: { minutes in
                                onResizeTask?(taskID, minutes)
                            },
                            onTap: {
                                onTapTask?(taskID)
                            }
                        )
                        .padding(.leading, 64)
                        .padding(.trailing, 16)
                    } else {
                        ScheduleBlockView(block: block)
                            .frame(height: max(height(for: block, hourHeight: hourHeight), 36))
                            .padding(.leading, 64)
                            .padding(.trailing, 16)
                            .offset(y: yOffset(for: block.start, hourHeight: hourHeight))
                    }
                }
            }
            .frame(height: totalHeight, alignment: .top)
            .background {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TwoDoColor.accentBlue.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    TwoDoColor.accentBlue,
                                    style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                                )
                        }
                }
            }
            .contentShape(Rectangle())
            .onDrop(
                of: [UTType.plainText],
                delegate: TimelineTaskDropDelegate(
                    isTargeted: $isDropTargeted,
                    dateAtLocation: { location in
                        date(forYOffset: location.y, hourHeight: hourHeight)
                    },
                    onDropTask: { taskID, date in
                        onDropTask?(taskID, date)
                    }
                )
            )
            .clipped()
        }
        .frame(minHeight: CGFloat(max(effectiveEndHour - effectiveStartHour, 1)) * TwoDoSpacing.scheduleHourHeight)
        .accessibilityHint("Drop an unscheduled task onto a time to schedule it")
    }

    private func hourGrid(hourHeight: CGFloat, totalHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(hours.dropLast(), id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(hourLabel(hour))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 52, alignment: .trailing)
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 1)
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: hourHeight, alignment: .top)
            }
        }
        .frame(height: totalHeight, alignment: .top)
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? .now
        return DateFormatting.time.string(from: date)
    }

    private func yOffset(for date: Date, hourHeight: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let hoursFromStart = CGFloat(hour - effectiveStartHour) + CGFloat(minute) / 60
        return hoursFromStart * hourHeight
    }

    private func date(forYOffset yOffset: CGFloat, hourHeight: CGFloat) -> Date {
        let totalMinutes = (effectiveEndHour - effectiveStartHour) * 60
        let rawMinutes = Int((max(0, yOffset) / hourHeight * 60).rounded())
        let snappedMinutes = ScheduleGrid.snap(rawMinutes)
        let clampedMinutes = min(max(snappedMinutes, 0), max(totalMinutes - ScheduleGrid.incrementMinutes, 0))
        let startOfDay = Calendar.current.startOfDay(for: day)
        return Calendar.current.date(
            byAdding: .minute,
            value: effectiveStartHour * 60 + clampedMinutes,
            to: startOfDay
        ) ?? day
    }

    private func height(for block: TimelineBlock, hourHeight: CGFloat) -> CGFloat {
        height(from: block.start, to: block.end, hourHeight: hourHeight)
    }

    private func height(from start: Date, to end: Date, hourHeight: CGFloat) -> CGFloat {
        let hours = end.timeIntervalSince(start) / 3600
        return CGFloat(hours) * hourHeight
    }

    private func maximumDuration(for block: TimelineBlock) -> Int {
        let calendar = Calendar.current
        let endOfGrid = calendar.date(
            bySettingHour: effectiveEndHour,
            minute: 0,
            second: 0,
            of: block.start
        ) ?? block.end
        return max(
            ScheduleGrid.incrementMinutes,
            Int(endOfGrid.timeIntervalSince(block.start) / 60)
        )
    }
}

private enum ScheduleGrid {
    static let incrementMinutes = 15

    static func snap(_ minutes: Int) -> Int {
        Int((Double(minutes) / Double(incrementMinutes)).rounded()) * incrementMinutes
    }

    static func minuteDelta(for translation: CGFloat, hourHeight: CGFloat) -> Int {
        guard hourHeight > 0 else { return 0 }
        return snap(Int((translation / hourHeight * 60).rounded()))
    }
}

private struct TimelineTaskDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let dateAtLocation: (CGPoint) -> Date
    let onDropTask: (UUID, Date) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.plainText])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let date = dateAtLocation(info.location)
        guard let provider = info.itemProviders(for: [UTType.plainText]).first else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let value = object as? String,
                  let taskID = UUID(uuidString: value) else {
                return
            }
            Task { @MainActor in
                onDropTask(taskID, date)
            }
        }
        return true
    }
}

private struct InteractiveScheduleBlock: View {
    let block: TimelineBlock
    let taskID: UUID
    let initialYOffset: CGFloat
    let hourHeight: CGFloat
    let totalHeight: CGFloat
    let maximumDurationMinutes: Int
    let onMove: (Date) -> Void
    let onResize: (Int) -> Void
    let onTap: () -> Void

    @State private var moveTranslation: CGFloat = 0
    @State private var resizeTranslation: CGFloat = 0

    private var originalDurationMinutes: Int {
        max(block.durationMinutes, ScheduleGrid.incrementMinutes)
    }

    private var previewDurationMinutes: Int {
        let change = ScheduleGrid.minuteDelta(for: resizeTranslation, hourHeight: hourHeight)
        return min(
            max(originalDurationMinutes + change, ScheduleGrid.incrementMinutes),
            maximumDurationMinutes
        )
    }

    private var previewHeight: CGFloat {
        max(CGFloat(previewDurationMinutes) / 60 * hourHeight, 36)
    }

    private var previewYOffset: CGFloat {
        let proposed = initialYOffset + moveTranslation
        return min(max(proposed, 0), max(totalHeight - previewHeight, 0))
    }

    private var previewStart: Date {
        let delta = ScheduleGrid.minuteDelta(
            for: previewYOffset - initialYOffset,
            hourHeight: hourHeight
        )
        return block.start.addingTimeInterval(TimeInterval(delta * 60))
    }

    private var previewBlock: TimelineBlock {
        TimelineBlock(
            id: block.id,
            title: block.title,
            start: previewStart,
            end: previewStart.addingTimeInterval(TimeInterval(previewDurationMinutes * 60)),
            colorHex: block.colorHex,
            taskID: taskID
        )
    }

    private var isInteracting: Bool {
        moveTranslation != 0 || resizeTranslation != 0
    }

    var body: some View {
        ScheduleBlockView(block: previewBlock)
            .frame(height: previewHeight)
            .overlay(alignment: .topTrailing) {
                moveHandle
            }
            .overlay(alignment: .bottom) {
                resizeHandle
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture(perform: onTap)
            .offset(y: previewYOffset)
            .zIndex(isInteracting ? 20 : 2)
            .shadow(
                color: .black.opacity(isInteracting ? 0.16 : 0),
                radius: isInteracting ? 8 : 0,
                y: isInteracting ? 4 : 0
            )
            .animation(.snappy(duration: 0.18), value: isInteracting)
    }

    private var moveHandle: some View {
        Image(systemName: "arrow.up.and.down")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
            .background(.thinMaterial, in: Circle())
            .padding(4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        moveTranslation = value.translation.height
                    }
                    .onEnded { _ in
                        let newStart = previewStart
                        moveTranslation = 0
                        onMove(newStart)
                    }
            )
            .accessibilityLabel("Move \(block.title)")
            .accessibilityHint("Drag vertically; times snap to 15 minutes")
            .accessibilityAdjustableAction { direction in
                let minutes = direction == .increment
                    ? ScheduleGrid.incrementMinutes
                    : -ScheduleGrid.incrementMinutes
                onMove(block.start.addingTimeInterval(TimeInterval(minutes * 60)))
            }
    }

    private var resizeHandle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.55))
            .frame(width: 42, height: 5)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        resizeTranslation = value.translation.height
                    }
                    .onEnded { _ in
                        let minutes = previewDurationMinutes
                        resizeTranslation = 0
                        onResize(minutes)
                    }
            )
            .accessibilityLabel("Resize \(block.title)")
            .accessibilityValue(DateFormatting.durationLabel(previewDurationMinutes))
            .accessibilityAdjustableAction { direction in
                let change = direction == .increment
                    ? ScheduleGrid.incrementMinutes
                    : -ScheduleGrid.incrementMinutes
                let minutes = min(
                    max(originalDurationMinutes + change, ScheduleGrid.incrementMinutes),
                    maximumDurationMinutes
                )
                onResize(minutes)
            }
    }
}

struct ScheduleBlockView: View {
    let block: TimelineBlock
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(TwoDoColor.project(from: block.colorHex))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(TwoDoTypography.scheduleBlockTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    if block.isCalendarEvent {
                        Image(systemName: "calendar")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("\(DateFormatting.time.string(from: block.start)) – \(DateFormatting.time.string(from: block.end))")
                        .font(TwoDoTypography.metadata)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Spacer(minLength: 0)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(TwoDoColor.project(from: block.colorHex).opacity(colorScheme == .dark ? 0.28 : 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(TwoDoColor.project(from: block.colorHex).opacity(colorScheme == .dark ? 0.35 : 0.22), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct FreeTimeGap: View {
    let minutes: Int

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .medium))
                Text(DateFormatting.freeTimeLabel(minutes: minutes))
                    .font(TwoDoTypography.freeTime)
            }
            .foregroundStyle(TwoDoColor.freeTime)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            Spacer()
        }
    }
}
