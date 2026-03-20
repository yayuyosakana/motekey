import SwiftUI

private func maximumDay(for month: Int) -> Int {
    switch month {
    case 2:
        return 29
    case 4, 6, 9, 11:
        return 30
    default:
        return 31
    }
}

#if canImport(UIKit)
import UIKit

struct MonthDayPicker: UIViewRepresentable {
    @Binding var month: Int
    @Binding var day: Int

    private let months = Array(1...12)

    func makeCoordinator() -> Coordinator {
        Coordinator(month: $month, day: $day, months: months)
    }

    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        context.coordinator.attachPickerViewIfNeeded(picker)
        let normalizedMonth = min(max(month, 1), 12)
        let normalizedDay = min(max(day, 1), maximumDay(for: normalizedMonth))
        picker.selectRow(max(0, normalizedMonth - 1), inComponent: 0, animated: false)
        picker.selectRow(max(0, min(normalizedDay - 1, context.coordinator.currentDayCount - 1)), inComponent: 1, animated: false)
        return picker
    }

    func updateUIView(_ uiView: UIPickerView, context: Context) {
        let normalizedMonth = min(max(month, 1), 12)
        if month != normalizedMonth {
            month = normalizedMonth
        }

        context.coordinator.updateDayRows(for: normalizedMonth)

        let normalizedDay = min(max(day, 1), maximumDay(for: normalizedMonth))
        if day != normalizedDay {
            day = normalizedDay
        }

        let monthRow = max(0, min(normalizedMonth - 1, months.count - 1))
        let dayRow = max(0, min(normalizedDay - 1, context.coordinator.currentDayCount - 1))
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
        private var days: [Int]
        private weak var pickerView: UIPickerView?

        var currentDayCount: Int { days.count }

        init(month: Binding<Int>, day: Binding<Int>, months: [Int]) {
            _month = month
            _day = day
            self.months = months
            let normalizedMonth = min(max(month.wrappedValue, 1), 12)
            self.days = Array(1...maximumDay(for: normalizedMonth))
        }

        func attachPickerViewIfNeeded(_ pickerView: UIPickerView) {
            if self.pickerView == nil {
                self.pickerView = pickerView
            }
        }

        func updateDayRows(for month: Int) {
            let targetDays = Array(1...maximumDay(for: month))
            guard targetDays.count != days.count else { return }
            days = targetDays
            pickerView?.reloadComponent(1)
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
                let selectedMonth = months[row]
                month = selectedMonth
                updateDayRows(for: selectedMonth)
                let maxDay = maximumDay(for: selectedMonth)
                if day > maxDay {
                    day = maxDay
                    pickerView.selectRow(max(0, day - 1), inComponent: 1, animated: true)
                }
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

    private var days: [Int] {
        Array(1...maximumDay(for: month))
    }

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
                ForEach(days, id: \.self) { value in
                    Text("\(value)日").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 120)
        .onChange(of: month) { _, newMonth in
            let normalizedMonth = min(max(newMonth, 1), 12)
            if month != normalizedMonth {
                month = normalizedMonth
            }
            let maxDay = maximumDay(for: normalizedMonth)
            if day > maxDay {
                day = maxDay
            } else if day < 1 {
                day = 1
            }
        }
        .onChange(of: day) { _, newDay in
            let maxDay = maximumDay(for: month)
            if newDay > maxDay {
                day = maxDay
            } else if newDay < 1 {
                day = 1
            }
        }
    }
}
#endif
