import SwiftUI

struct HourlyScheduleView: View {
    let blocks: [TimelineBlock]
    var dayStartHour: Int = 8
    var dayEndHour: Int = 19

    private var hours: [Int] { Array(dayStartHour...dayEndHour) }
    private var gaps: [ScheduleGap] { ScheduleLayout.gaps(between: blocks) }

    var body: some View {
        GeometryReader { geo in
            let totalHours = CGFloat(max(dayEndHour - dayStartHour, 1))
            let hourHeight = max(geo.size.height / totalHours, TwoDoSpacing.scheduleHourHeight)
            let totalHeight = hourHeight * totalHours

            ZStack(alignment: .topLeading) {
                // Hour labels + grid lines
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

                // Event blocks
                ForEach(blocks) { block in
                    let y = yOffset(for: block.start, hourHeight: hourHeight)
                    let h = max(height(for: block, hourHeight: hourHeight), 36)
                    ScheduleBlockView(block: block)
                        .frame(height: h)
                        .padding(.leading, 64)
                        .padding(.trailing, 16)
                        .offset(y: y)
                }

                // Free time gaps
                ForEach(gaps) { gap in
                    let y = yOffset(for: gap.start, hourHeight: hourHeight)
                    let mid = y + height(from: gap.start, to: gap.end, hourHeight: hourHeight) / 2 - 12
                    FreeTimeGap(minutes: gap.minutes)
                        .padding(.leading, 64)
                        .padding(.trailing, 16)
                        .offset(y: mid)
                }
            }
            .frame(height: totalHeight, alignment: .top)
        }
        .frame(minHeight: CGFloat(max(dayEndHour - dayStartHour, 1)) * TwoDoSpacing.scheduleHourHeight)
    }

    private func hourLabel(_ hour: Int) -> String {
        var comps = DateComponents()
        comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? .now
        return DateFormatting.time.string(from: date)
    }

    private func yOffset(for date: Date, hourHeight: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let hoursFromStart = CGFloat(hour - dayStartHour) + CGFloat(minute) / 60
        return hoursFromStart * hourHeight
    }

    private func height(for block: TimelineBlock, hourHeight: CGFloat) -> CGFloat {
        height(from: block.start, to: block.end, hourHeight: hourHeight)
    }

    private func height(from start: Date, to end: Date, hourHeight: CGFloat) -> CGFloat {
        let hours = end.timeIntervalSince(start) / 3600
        return CGFloat(hours) * hourHeight
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
