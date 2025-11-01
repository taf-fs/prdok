//
//  CalendarDayDetailsView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI
import Combine

final class CalendarDayDetailsViewModel: ObservableObject {
    @Published var offeredShift: Shift?
    @Published var plannedShift: Shift?
    @Published var actualShift: Shift?
    
    var shifts: [Shift] = []
    let repo = ShiftRepository()
    
    func fetchShift(date: Date?) {
        guard let date else { return }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }

        Task {
            self.shifts = try await repo.getShifts(for: date)
            print("loaded \(shifts.count) shifts for \(dayStart)–\(dayEnd).")

            // Match any shift that intersects the selected day's interval [dayStart, dayEnd)
            self.offeredShift = shifts.first(where: { $0.kind == .offered && $0.start < dayEnd && $0.end > dayStart })
            self.plannedShift = shifts.first(where: { $0.kind == .planned && $0.start < dayEnd && $0.end > dayStart })
            self.actualShift = shifts.first(where: { $0.kind == .actual && $0.start < dayEnd && $0.end > dayStart })
        }
    }
}


struct CalendarDayDetailsView: View {
    @StateObject var vm = CalendarDayDetailsViewModel()
    @Binding var date: Date?
    
    var fulldate: String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("dMMMMY")
        return df.string(from: date!)
    }
    var body: some View {
        VStack(spacing: 20) {
            Text(fulldate)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            Text("calendarDayDetails.offered.shift")
            Text(vm.offeredShift?.timeRangeString ?? "-")
            Divider()
            Text("calendarDayDetails.planned.shift")
            Text(vm.plannedShift?.timeRangeString ?? "-")
            Divider()
            Text("calendarDayDetails.actual.shift")
            Text(vm.actualShift?.timeRangeString ?? "-")
            Spacer()
                
        }
        .padding(24)
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
        .onAppear {
            vm.fetchShift(date: date)
        }
    }
}


// Classic preview compatible with iOS 15+
struct CalendarDayDetailsViewPreviews: PreviewProvider {
    @State static var date: Date? = Date()
    static var previews: some View {
        CalendarDayDetailsView(date: $date)
    }
}

