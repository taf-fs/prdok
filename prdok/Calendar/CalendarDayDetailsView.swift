//
//  CalendarDayDetailsView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI
import Combine

final class CalendarDayDetailsViewModel: ObservableObject {
    @Published var offeredShifts: [Shift] = []
    @Published var plannedShifts: [Shift] = []
    @Published var actualShifts: [Shift] = []
    
    
    var shifts: [Shift] = []
    let repo = ShiftRepository()
    
    func fetchShift(date: Date?) {
        guard let date else { return }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        Task {
            do {
                let allShifts = try await repo.getShifts(for: date)
                await MainActor.run {
                    self.shifts = allShifts
                    
                    self.offeredShifts = allShifts.filter {
                        $0.kind == .offered && $0.dayStart == dayStart
                    }
                    self.plannedShifts = allShifts.filter {
                        $0.kind == .planned && $0.dayStart == dayStart
                    }
                    self.actualShifts = allShifts.filter {
                        $0.kind == .actual && $0.dayStart == dayStart
                    }
                }
            } catch {
                // TODO: you may want some error handling here
            }
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
                        
            ShiftIndicatorView(
                title: "calendarDayDetails.offered.shift",
                shifts: vm.offeredShifts)
            
            ShiftIndicatorView(
                title: "calendarDayDetails.planned.shift",
                shifts: vm.plannedShifts)
            
            ShiftIndicatorView(
                title: "calendarDayDetails.actual.shift",
                shifts: vm.actualShifts)
            
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
