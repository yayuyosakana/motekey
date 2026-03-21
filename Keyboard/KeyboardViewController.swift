#if canImport(UIKit)
import UIKit
import SwiftUI

final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardRuntimeRootView>?
    private var fallbackContainer: UIView?
    private var keyboardHeightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureKeyboardHeightIfNeeded()
        installGuaranteedFallbackUIIfNeeded()
        installRuntimeIfNeeded()
    }

    private func installRuntimeIfNeeded() {
        guard hostingController == nil else { return }
        guard let appState = KeyboardRuntimeInstaller.makeAppState(in: self) else { return }

        let hosting = KeyboardRuntimeInstaller.embed(into: self, appState: appState) {
            KeyboardBasePlaceholderView(
                onInsertText: { [weak self] text in
                    self?.textDocumentProxy.insertText(text)
                },
                onDeleteBackward: { [weak self] in
                    self?.textDocumentProxy.deleteBackward()
                }
            )
        }
        hostingController = hosting
        fallbackContainer?.removeFromSuperview()
        fallbackContainer = nil
    }

    private func installGuaranteedFallbackUIIfNeeded() {
        guard fallbackContainer == nil else { return }
        view.backgroundColor = .systemGray6

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .systemGray6

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "モテキー"
        titleLabel.textAlignment = .center
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label

        let hintLabel = UILabel()
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.text = "キーボードを読み込み中です"
        hintLabel.textAlignment = .center
        hintLabel.font = .preferredFont(forTextStyle: .caption1)
        hintLabel.textColor = .secondaryLabel

        container.addSubview(titleLabel)
        container.addSubview(hintLabel)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -8),
            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            hintLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])

        fallbackContainer = container
    }

    private func configureKeyboardHeightIfNeeded() {
        guard keyboardHeightConstraint == nil else { return }
        let height: CGFloat = 300
        let constraint = view.heightAnchor.constraint(equalToConstant: height)
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        keyboardHeightConstraint = constraint
    }
}

private struct KeyboardBasePlaceholderView: View {
    let onInsertText: (String) -> Void
    let onDeleteBackward: () -> Void

    private let rows: [[String]] = [
        ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ"],
        ["い", "き", "し", "ち", "に", "ひ", "み", "り", "を"],
        ["う", "く", "す", "つ", "ぬ", "ふ", "む", "ゆ", "る", "ん"]
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        Button(action: { onInsertText(key) }) {
                            Text(key)
                                .font(.system(size: 18, weight: .medium))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color.white)
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 6) {
                Button(action: { onInsertText(" ") }) {
                    Text("スペース")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.white)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: { onInsertText("\n") }) {
                    Text("改行")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(Color.white)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button(action: onDeleteBackward) {
                    Text("⌫")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 56, height: 42)
                        .background(Color.white)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(white: 0.9))
    }
}
#endif
