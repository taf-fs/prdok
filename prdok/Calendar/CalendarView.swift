//
//  CalendarView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI
import Combine
import HorizonCalendar

let calendar = Calendar.current

final class CalendarViewModel: ObservableObject {
    @Published var plannedDays: Set<Date> = []
    @Published var offeredDays: Set<Date> = []
    
    let repo = ShiftRepository()
    var loadedYear: Int?
    
    func year(_ date: Date ) -> Int {
        return calendar.component(.year, from: date)
    }
    
    func loadShiftsForYear(dateContainingYear: Date) {
        let year = year(dateContainingYear)
        Task {
            do {
                let result = try await repo.preloadYear(year)
                await MainActor.run {
                    plannedDays = result.plannedDaySet(using: calendar)
                    offeredDays = result.offeredDaySet(using: calendar)
                    loadedYear = year
                }
            } catch {
                // TODO: some error handling
            }
        }
    }
    
    func checkYear(displayedMonthAndYear: DateComponents) {
        guard let displayedYear = displayedMonthAndYear.year else { return }
        guard loadedYear != displayedYear else { return }
        
        if let date = calendar.date(from: displayedMonthAndYear) {
            loadShiftsForYear(dateContainingYear: date)
        }
    }
}

struct CalendarView: View {
    @State var calendarStartBound = calendar.date(byAdding: .year, value: -1, to: Date())!
    @State var calendarEndBound = calendar.date(byAdding: .year, value: 1, to: Date())!
    
    @StateObject var vm = CalendarViewModel()
    @StateObject var proxy: CalendarViewProxy = .init()
    
    @State var selectedDate: Date?
    @State var displayedMonth: DateComponents = calendar.dateComponents([.year, .month], from: Date())
    @State var daySheetIsPresented: Bool = false
    
    var currentMonthLabel: String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMMMy")
        let date = calendar.date(from: displayedMonth)!
        return df.string(from: date).capitalized(with: df.locale)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("calendar.title")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                
                HStack {
                    Text(currentMonthLabel)
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
                    visibleDateRange: calendarStartBound...calendarEndBound,
                    monthsLayout: .horizontal(options: HorizontalMonthsLayoutOptions()),
                    dataDependency: (selectedDate, vm.plannedDays, vm.offeredDays),
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

                    let dayKey = calendar.startOfDay(for: date)
                    let hasPlannedShift = vm.plannedDays.contains(dayKey)
                    let hasOfferedShift = vm.offeredDays.contains(dayKey)

                    CalendarDayCell(
                        dayNumber: day.day,
                        isToday: isToday,
                        hasPlannedShift: hasPlannedShift,
                        hasOfferedShift: hasOfferedShift,
                        backgroundOpacity: backgroundOpacity
                    ) {
                        selectedDate = date
                        daySheetIsPresented = true
                    }
                }
                .monthHeaders { content in
                    // empty view
                }
                .onDeceleratingEnd { visibleDayRange in
                    displayedMonth = visibleDayRange.lowerBound.components // this updates the header at the same time
                    if let dateContainingMonth = calendar.date(from: displayedMonth) {
                        setVisibleRange(around: dateContainingMonth)
                    }
                    vm.checkYear(displayedMonthAndYear: displayedMonth)
                }
                .onAppear {
                    selectedDate = Date()
                    scrollToMonthAndUpdateState(dateContainingMonth: selectedDate!, animated: false)
                    vm.loadShiftsForYear(dateContainingYear: selectedDate!)
                }
                .sheet(isPresented: $daySheetIsPresented) {
                    if #available(iOS 16, *) {
                        CalendarDayDetailsView(date: $selectedDate)
                            .presentationDetents([.medium])
                    } else {
                        CalendarDayDetailsView(date: $selectedDate)
                    }
                }
                
                RoundedRectangle(cornerRadius: 2)
                    .foregroundStyle(.tint)
                    .frame(maxHeight: 2)
                
                Spacer()
                Button("calendar.force.refresh.month") {
                    Task {
                        if let date = calendar.date(from: displayedMonth) {
                            try await vm.repo.refresh(for: date)
                            vm.loadShiftsForYear(dateContainingYear: date)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 24)
        }
    }
    
    func scrollToMonthAndUpdateState(dateContainingMonth: Date, animated: Bool = true) {
        setVisibleRange(around: dateContainingMonth)
        DispatchQueue.main.async {
            proxy.scrollToMonth(containing: dateContainingMonth, scrollPosition: .centered, animated: animated)
        }
        displayedMonth = calendar.dateComponents([.year, .month], from: dateContainingMonth)
        vm.checkYear(displayedMonthAndYear: displayedMonth)
    }
    
    func dayOfWeekName(index: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
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
    
    func setVisibleRange(around date: Date, monthsBefore: Int = 12, monthsAfter: Int = 12) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: comps),
              let start = calendar.date(byAdding: .month, value: -monthsBefore, to: startOfMonth),
              let endMonthStart = calendar.date(byAdding: .month, value: monthsAfter + 1, to: startOfMonth),
              let end = calendar.date(byAdding: .day, value: -1, to: endMonthStart) else { return }

        calendarStartBound = start
        calendarEndBound = end
    }
}

private struct CalendarDayCell: View {
    let dayNumber: Int
    let isToday: Bool
    let hasPlannedShift: Bool
    let hasOfferedShift: Bool
    let backgroundOpacity: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .padding(2)
                    .foregroundStyle(.tint.opacity(backgroundOpacity))

                VStack(spacing: 5) {
                    Text("\(dayNumber)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(isToday ? Color.white : Color.primary)

                    HStack {
                        if hasOfferedShift {
                            Circle()
                                .frame(width: 5, height: 5)
                                .foregroundStyle(.tint.opacity(hasPlannedShift ? 1 : 0.3))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
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

private extension Collection where Element == Shift {
    func plannedDaySet(using calendar: Calendar) -> Set<Date> {
        Set(self.filter { $0.kind == .planned }.map { calendar.startOfDay(for: $0.start) })
    }
    
    func offeredDaySet(using calendar: Calendar) -> Set<Date> {
        Set(self.filter { $0.kind == .offered }.map { calendar.startOfDay(for: $0.start) })
    }
}


#Preview {
    CalendarView()
}
