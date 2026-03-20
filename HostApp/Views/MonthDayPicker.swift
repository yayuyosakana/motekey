import SwiftUI

#if canImport(UIKit)
import UIKit

struct MonthDayPicker: UIViewRepresentable {
    @Binding var month: Int
    @Binding var day: Int

    private let months = Array(1...12)
    private let days = Array(1...31)

    func makeCoordinator() -> Coordinator {
        Coordinator(month: $month, day: $day, months: months, days: days)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        picker.selectRow(max(0, month - 1), inComponent: 0, animated: false)
        picker.selectRow(max(0, day - 1), inComponent: 1, animated: false)
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        let monthRow = max(0, min(month - 1, months.count - 1))
        let dayRow = max(0, min(day - 1, days.count - 1))

        if uiView.selectedRow(inComponent: 0) != monthRow {
            uiView.selectRow(monthRow, inComponent: 0, animated: false)
        }
        if uiView.selectedRow(inComponent: 1) != dayRow {
            uiView.selectRow(dayRow, inComponent: 1, animated: false)
        }
    }

    final class Coordinator: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
        @Binding private var month: Int
        @Binding private var day: Int
        private let months: [Int]
        private let days: [Int]

        init(month: Binding<Int>, day: Binding<Int>, months: [Int], days: [Int]) {
            _month = month
            _day = day
            self.months = months
            self.days = days
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            2
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            component == 0 ? months.count : days.count
        }

        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            if component == 0 {
                return "\(months[row])月"
            }
            return "\(days[row])日"
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            if component == 0 {
                month = months[row]
            } else {
                day = days[row]
            }
        }
    }
}
#else
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
#endif
