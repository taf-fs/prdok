//
//  TempShiftView.swift
//  prdok
//
//  Created by David Horňák on 29.10.2025.
//

import SwiftUI
import Combine

final class TempShiftViewModel: ObservableObject {
    @Published var shifts: [Shift] = []
    @Published var error: String?
    @Published var isLoading = false
    
    let repo = ShiftRepository()
    let openDaysRepo = OpenDaysRepository()
    let bonusRepo = BonusRepository()

    func fetch(date: Date) {
        error = nil
        isLoading = true
        Task {
            do {
                let result = try await repo.getShifts(for: date)
                await MainActor.run {
                    self.shifts = result
                    self.isLoading = false
                }
                // Optional: also print to console
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .short
                print("Loaded \(result.count) shifts into TempShiftView")
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func clear() {
        Task {
            do {
                try repo.clearAllCache()
                try openDaysRepo.clearAllCache()
                try bonusRepo.clearAllCache()
                await MainActor.run {
                    self.shifts = []
                }
            } catch {
                self.error = error.localizedDescription
            }            
        }
    }
}

struct TempShiftView: View {
    @StateObject private var vm = TempShiftViewModel()
    @State var selectedYear: Date = Date()
    
    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        VStack {
            DatePicker("select.year", selection: $selectedYear)
                .datePickerStyle(.compact)
            
            Button("Fetch") {
                vm.fetch(date: selectedYear)
            }
            
            Button("Clear all cache") {
                vm.clear()
            }
            
            if let error = vm.error {
                Text("Error: \(error)").foregroundStyle(.red)
            }
            
            if !vm.shifts.isEmpty {
                List(vm.shifts, id: \.id) { shift in
                    VStack(alignment: .leading) {
                        Text(verbatim: "\(shift.kind.rawValue.capitalized), \(String(describing:shift.id))")
                            .font(.headline)
                        Text(verbatim: "\(df.string(from: shift.start)) → \(df.string(from: shift.end))")
                            .foregroundColor(Color.cpForegroundSecondary)
                    }
                }
            } else if !vm.isLoading && vm.error == nil {
                Text("No shifts loaded")
                    .foregroundColor(Color.cpForegroundSecondary)
            }
        }
        .onAppear {
            vm.fetch(date: selectedYear)
        }
    }
}

#Preview {
    TempShiftView()
}
