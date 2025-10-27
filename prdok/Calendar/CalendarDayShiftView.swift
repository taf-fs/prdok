//
//  CalendarDayShiftView.swift
//  prdok
//
//  Created by David Horňák on 12.10.2025.
//

import SwiftUI

struct CalendarDayShiftView: View {
    let color = Color(red: 234/255, green: 227/255, blue: 215/255)
    @Binding var date: Date?
    
    var fulldate: String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("dMMMMY")
        return df.string(from: date!)
    }
    var body: some View {
        VStack(spacing: 24) {
            Text(fulldate)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("lorem ipsum")
            Text("lorem ipsum")
            Text("lorem ipsum")
            Text("lorem ipsum")
            Spacer()
                
        }
        .padding(24)
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
        .background(color)
    }
}


// Classic preview compatible with iOS 15+
struct CalendarDayShiftView_Previews: PreviewProvider {
    @State static var date: Date? = Date()
    static var color = Color(red: 234/255, green: 227/255, blue: 215/255)
    static var previews: some View {
        CalendarDayShiftView(date: $date)
            .tint(color)
    }
}
