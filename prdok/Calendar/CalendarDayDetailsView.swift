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
    @State var isSheetPresented: Bool = false
    
    var fulldate: String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("dMMMMY")
        guard let date else { return "-" }
        return df.string(from: date)
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
            
            HStack {
                Button("calendarDayDetails.plan.shift") {
                    // plan the shift
                }
                .buttonStyle(.borderedProminent)
                Button("calendarDayDetails.show.webWiew") {
                    isSheetPresented = true
                }
                .buttonStyle(.borderedProminent)
            }
            if #unavailable(iOS 16) {
                Spacer()
            }
                
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $isSheetPresented) {
            if let date {
                ShiftsListWebView(date: date)
            } else {
                // fallback
                Text("No date selected")
            }
        }
        .onAppear {
            vm.fetchShift(date: date)
        }
    }
}


// A wrapper just for previewing the sheet presentation style
private struct CalendarDayDetailsSheetPreviewContainer: View {
    @State private var isPresented = true
    @State private var date: Date? = Date()
    
    var body: some View {
        Color.clear
            .sheet(isPresented: $isPresented) {
                if #available(iOS 16, *) {
                    CalendarDayDetailsView(date: $date)
                        .presentationDetents([.medium])
                } else {
                    CalendarDayDetailsView(date: $date)
                }
            }
    }
}

// Classic preview compatible with iOS 15+
struct CalendarDayDetailsViewPreviews: PreviewProvider {
    static var previews: some View {
        CalendarDayDetailsSheetPreviewContainer()
    }
}

