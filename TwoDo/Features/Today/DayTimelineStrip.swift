import SwiftUI

struct DayTimelineStrip: View {
    let blocks: [TimelineBlock]
    var dayStartHour: Int = 7
    var dayEndHour: Int = 20
    var now: Date = .now
    var showCaption: Bool = true

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var currentNow: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 12)

                    ForEach(blocks) { block in
                        let startF = TimelineLayout.fraction(of: block.start, dayStartHour: dayStartHour, dayEndHour: dayEndHour)
                        let endF = TimelineLayout.fraction(of: block.end, dayStartHour: dayStartHour, dayEndHour: dayEndHour)
                        let x = startF * width
                        let w = max((endF - startF) * width, 8)

                        Capsule()
                            .fill(TwoDoColor.project(from: block.colorHex))
                            .frame(width: w, height: 12)
                            .offset(x: x)
                    }

                    let needleX = TimelineLayout.fraction(of: currentNow, dayStartHour: dayStartHour, dayEndHour: dayEndHour) * width
                    timelineNeedle
                        .offset(x: max(0, needleX - 5))
                }
            }
            .frame(height: TwoDoSpacing.timelineHeight)

            if showCaption, let caption = TimelineLayout.currentEventCaption(blocks: blocks, now: currentNow) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(TwoDoColor.accentBlue)
                        .frame(width: 7, height: 7)
                    Text(caption)
                        .font(TwoDoTypography.timelineCaption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear { currentNow = now }
        .onReceive(timer) { currentNow = $0 }
    }

    private var timelineNeedle: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(TwoDoColor.timelineNeedle)
                .frame(width: 9, height: 9)
                .shadow(color: TwoDoColor.timelineNeedle.opacity(0.5), radius: 2, y: 0)
            Rectangle()
                .fill(TwoDoColor.timelineNeedle)
                .frame(width: 2.5, height: 16)
        }
        .frame(width: 10, height: TwoDoSpacing.timelineHeight, alignment: .top)
    }
}
