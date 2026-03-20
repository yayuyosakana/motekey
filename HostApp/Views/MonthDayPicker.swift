import SwiftUI

struct MonthDayPicker: View {
    @Binding var month: Int
    @Binding var day: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("月", selection: $month) {
                ForEach(1...12, id: \.self) { value in
                    Text("\(value)月").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("日", selection: $day) {
                ForEach(1...31, id: \.self) { value in
                    Text("\(value)日").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
    }
}
