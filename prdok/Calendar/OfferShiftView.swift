//
//  OfferShiftView.swift
//  prdok
//
//  Created by David Horňák on 18.01.2026.
//

import SwiftUI
import Combine
import HorizonCalendar


final class OfferShiftsFromMonthViewModel: ObservableObject {
    @Published var offeredDays: Set<Date> = []
    
    let repo = ShiftRepository()
    
    func loadShifts(month: Date) {
        Task {
            do {
                let result = try await repo.getShifts(for: month)
                await MainActor.run {
                    offeredDays = result.offeredDaySet(using: calendar)
                }
            } catch {
                // TODO: some error handling
            }
        }
    }
}

struct OfferShiftsFromMonthView: View {    
    var displayedMonth: Date
    
    @Environment(\.dismiss) var dismiss
    @StateObject var vm = OfferShiftsFromMonthViewModel()
    @State var selectedDates: Set<Date> = []
    @State var startHour: Int = 7
    @State var endHour: Int = 25
    
    var startOfMonth: Date { calendar.dateInterval(of: .month, for: displayedMonth)!.start }
    var endOfMonth: Date { calendar.dateInterval(of: .month, for: displayedMonth)!.end.addingTimeInterval(-1) }
    var currentMonthLabel: String {
        let df = DateFormatter()
        df.calendar = calendar
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMMMy")
        return df.string(from: displayedMonth).capitalized(with: df.locale)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(currentMonthLabel)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.6))
            CalendarViewRepresentable(
                calendar: calendar,
                visibleDateRange: startOfMonth...endOfMonth,
                monthsLayout: .horizontal(options: HorizontalMonthsLayoutOptions()),
                dataDependency: (selectedDates),
            )
            .dayOfWeekHeaders { month, index in
                Text(dayOfWeekName(index: index).uppercased())
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.6))
            }
            .days { day in
                let date = calendar.date(from: day.components)!
                let dayKey = calendar.startOfDay(for: date)
                let hasOfferedShift = vm.offeredDays.contains(dayKey)
                let isSelected = selectedDates.contains(dayKey)
                
                CalendarDayCell(
                    dayNumber: day.day,
                    hasOfferedShift: hasOfferedShift,
                    isSelected: isSelected
                ) {
                    if (!hasOfferedShift && !isSelected) {
                        selectedDates.insert(dayKey)
                    } else if (isSelected) {
                        selectedDates.remove(dayKey)
                    }
                }
            }
            .monthHeaders { content in
                // empty view
            }
            .onAppear {
                vm.loadShifts(month: displayedMonth)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Text("shiftOffer.picker.start")
                        .frame(maxWidth: .infinity)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.primary.opacity(0.6))
                    Spacer()
                    Text("shiftOffer.picker.end")
                        .frame(maxWidth: .infinity)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.primary.opacity(0.6))
                    Spacer()
                }
            }
            
            // SHIFT HOUR PICKERS
            HStack(spacing: 0) {
                Picker("Start", selection: $startHour) {
                    ForEach(7...24, id: \.self) { number in
                        Text(hourString(from: number))
                            .font(.system(.title3, design: .monospaced))
                    }
                }
                .pickerStyle(.wheel)
                
                RoundedRectangle(cornerRadius: 3)
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(maxWidth: 15, maxHeight: 2)
                
                Picker("End", selection: $endHour) {
                    ForEach(8...25, id: \.self) { number in
                        Text(hourString(from: number))
                            .font(.system(.title3, design: .monospaced))
                    }
                }
                .pickerStyle(.wheel)
            }
            .frame(maxHeight: 150)
            
            Spacer()
            
            // SUBMIT SHIFTS BUTTON
            Button {
                // TODO: dismiss sheet and submit shifts
                dismiss()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .foregroundStyle(.tint.opacity(0.1))
                    Text("zapsat směnu") // add for multiple shifts text option, also
                        .font(.headline)
                        .opacity(selectedDates.isEmpty ? 0.5 : 1)
                        .foregroundStyle(.primary)
                }
                .aspectRatio(7, contentMode: .fit)
            }
            .disabled(selectedDates.isEmpty)
            .padding(.vertical, 20)
        }
        
        .padding(.horizontal, 12)
        .padding(.top, 24)
        
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
    
    func hourString(from hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

private struct CalendarDayCell: View {
    let dayNumber: Int
    let hasOfferedShift: Bool
    let isSelected: Bool
    
    let action: () -> Void
    

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .padding(3)
                    .foregroundStyle(.tint.opacity(isSelected ? 0.8 : 0))

                VStack(spacing: 5) {
                    Text("\(dayNumber)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)

                    HStack {
                        if hasOfferedShift {
                            Circle()
                                .frame(width: 5, height: 5)
                                .foregroundStyle(.tint.opacity(0.3))
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OfferShiftsFromMonthView(displayedMonth: Date())
}
