//
//  CalendarView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI
import HorizonCalendar

let calendar = Calendar.current

struct CalendarView: View {
    var startDate = calendar.date(byAdding: .year, value: -2, to: Date())!
    var endDate = calendar.date(byAdding: .year, value: 2, to: Date())!
    
    @StateObject var proxy: CalendarViewProxy = .init()
    @State var selectedDate: Date?
    @State var displayedMonth: DateComponents = calendar.dateComponents([.year, .month], from: Date())
    
    var currentMonthLabel: String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = Locale(identifier: "cs_CZ")
        df.setLocalizedDateFormatFromTemplate("MMMMy")
        let date = calendar.date(from: displayedMonth)!
        return df.string(from: date)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Kalendář směn_")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                
                HStack {
                    Text(currentMonthLabel.capitalized(with: Locale.current))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.semibold)
                    Spacer()
                    HStack {
                        PrevMonthButton {
                            let baseComponents = displayedMonth
                            if let baseDate = calendar.date(from: baseComponents) {
                                let target = calendar.date(byAdding: .month, value: -1, to: baseDate)!
                                scrollToMonthAndUpdateState(dateContainingMonth: target)
                            }
                        }
                        NextMonthButton {
                            let baseComponents = displayedMonth
                            if let baseDate = calendar.date(from: baseComponents) {
                                let target = calendar.date(byAdding: .month, value: 1, to: baseDate)!
                                scrollToMonthAndUpdateState(dateContainingMonth: target)
                            }
                        }
                    }
                }
                
                CalendarViewRepresentable(
                    calendar: calendar,
                    visibleDateRange: startDate...endDate,
                    monthsLayout: .horizontal(options: HorizontalMonthsLayoutOptions()),
                    dataDependency: selectedDate,
                    proxy: proxy
                )
                .dayOfWeekHeaders { month, index in
                    Text(dayOfWeekName(index: index).uppercased())
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.gray)
                }
                .days { day in
                    let date = calendar.date(from: day.components)!
                    let isToday = calendar.isDateInToday(date)
                    let backgroundOpacity: Double = getBackgroundOpacity(date: date)

                    Button {
                        selectedDate = date
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .padding(2)
                                .opacity(backgroundOpacity)
                            VStack(spacing: 5) {
                                Text("\(day.day)")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(isToday ? Color.white : Color.primary)
                                
                                // TODO: dots on days containing one-off tasks
                                Circle()
                                    .frame(maxWidth: 5, maxHeight: 5)
                                    .opacity(1)
                            }
                        }
                    }
                }
                .monthHeaders { content in
                    // empty view
                }
                .onDeceleratingEnd { visibleDayRange in
                    displayedMonth = visibleDayRange.lowerBound.components // this updates the header at the same time
                }
                .onAppear {
                    selectedDate = Date()
                    scrollToMonthAndUpdateState(dateContainingMonth: selectedDate!, animated: false)
                }
                
                
                RoundedRectangle(cornerRadius: 2)
                    .foregroundStyle(.tint)
                    .frame(maxHeight: 2)
            }
            .padding(.horizontal, 12)
            .padding(.top, 24)
        }
    }
    
    func scrollToMonthAndUpdateState(dateContainingMonth: Date, animated: Bool = true) {
        proxy.scrollToMonth(containing: dateContainingMonth, scrollPosition: .centered, animated: animated)
        displayedMonth = calendar.dateComponents([.year, .month], from: dateContainingMonth)
    }
    
    func dayOfWeekName(index: Int) -> String {
        let formatter = DateFormatter()
        // hardcoded czech locale
        formatter.locale = Locale(identifier: "cs_CZ")
        let names = formatter.weekdaySymbols ?? []
        guard names.indices.contains(index) else {
            return "error"
        }
        return String(names[index].prefix(2))
    }
    
    func getBackgroundOpacity(date: Date) -> Double {
        guard let selectedDate = selectedDate else { return 0 }
        if calendar.isDateInToday(date) { return 1 }
        if calendar.isDate(date, inSameDayAs: selectedDate) { return 0.2 }
        return 0
    }
}

private struct NextMonthButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.right")
                .frame(width: 35, height: 35)
        }
        .buttonStyle(.plain)
    }
}

private struct PrevMonthButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .frame(width: 35, height: 35)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CalendarView()
}
