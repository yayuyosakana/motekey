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

        let hosting = KeyboardRuntimeInstaller.embed(into: self, appState: appState) { [weak self] in
            JapaneseKeyboardView(
                onInsert: { [weak self] text in
                    self?.textDocumentProxy.insertText(text)
                },
                onDeleteBackward: { [weak self] in
                    self?.textDocumentProxy.deleteBackward()
                },
                onAdvanceInputMode: { [weak self] in
                    self?.advanceToNextInputMode()
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
        // ステージバー + 予測変換バー + フリックキー + 下部タブ を収めるための高さ。
        let height: CGFloat = 320
        let constraint = view.heightAnchor.constraint(equalToConstant: height)
        constraint.priority = UILayoutPriority(999)
        constraint.isActive = true
        keyboardHeightConstraint = constraint
    }
}
#endif
