import SwiftUI
import PlayaAPI

/// Horizontal scrollable day picker for event list navigation.
///
/// Days are Black Rock City days: labels and "is selected" use BRC time, so the picker
/// agrees with the event times and day buckets whatever zone the device is set to.
struct EventDayPickerView: View {
    let days: [Date]
    @Binding var selectedDay: Date
    @Environment(\.themeColors) var themeColors

    static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.timeZone = .burningMan
        return f
    }()

    static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        f.timeZone = .burningMan
        return f
    }()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let isSelected = Calendar.burningMan.isDate(day, inSameDayAs: selectedDay)
                        Button {
                            selectedDay = day
                        } label: {
                            VStack(spacing: 2) {
                                Text(Self.weekdayFormatter.string(from: day).uppercased())
                                    .font(.caption2)
                                    .fontWeight(isSelected ? .bold : .regular)
                                Text(Self.dayNumberFormatter.string(from: day))
                                    .font(.headline)
                                    .fontWeight(isSelected ? .bold : .regular)
                            }
                            .frame(width: 44, height: 52)
                            .foregroundColor(isSelected ? .white : themeColors.primaryColor)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? Color.accentColor : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(day)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                proxy.scrollTo(selectedDay, anchor: .center)
            }
            .onChange(of: selectedDay) { _, newDay in
                withAnimation {
                    proxy.scrollTo(newDay, anchor: .center)
                }
            }
        }
        .frame(height: 60)
    }
}
