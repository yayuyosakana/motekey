import Foundation

enum HostCopy {
    enum Common {
        static let appTitle = "モテキー"
        static let notRegistered = "未登録"
        static let configured = "設定済み"
        static let notConfigured = "未設定"
    }

    enum S001 {
        static let setupSectionTitle = "初回セットアップ"
        static let textHabitTitle = "テキストハビットチェック"
        static let relationTitle = "リレーションチェック"
        static let permissionTitle = "キーボード・画面収録設定"
    }

    enum S002 {
        static let navigationTitle = "テキストハビットチェック"
        static let placeholderReplyInput = "返信を入力..."
        static let send = "送信"
        static let skip = "スキップ"
        static let loadingTitle = "解析中"
        static let loadingMessage = "テキストハビットを解析中..."
        static let retry = "もう一度試す"
        static let errorFallback = "解析に失敗しました。時間を置いて再試行してください。"
        static let emptySummary = "入力なし（後で再登録可能）"
    }

    enum S003 {
        static let doneTitle = "登録完了"
        static let doneMessage = "いつでも再編集できます"
        static let backToHome = "ホームに戻る"
        static let agreement = "入力内容と会話文脈がGemini APIに送信されることに同意する"
    }

    enum S004 {
        static let preparationTitle = "使用準備"
        static let completeTitle = "初期設定完了"
        static let tutorialTitle = "使い方"
        static let openSettings = "設定を開く"
        static let next = "次へ"
        static let start = "はじめる"
        static let close = "閉じる"
    }
}
