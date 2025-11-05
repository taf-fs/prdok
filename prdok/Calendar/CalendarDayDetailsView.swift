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

        Task {
            self.shifts = try await repo.getShifts(for: date)

            self.offeredShift = shifts.first(where: { $0.kind == .offered && calendar.startOfDay(for: $0.start) == dayStart })
            self.plannedShift = shifts.first(where: { $0.kind == .planned && calendar.startOfDay(for: $0.start) == dayStart })
            self.actualShift = shifts.first(where: { $0.kind == .actual && calendar.startOfDay(for: $0.start) == dayStart })
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

