import Foundation

struct S002ScenarioCopy {
    let title: String
    let messages: [S002MessageCopy]
}

struct S002MessageCopy {
    let text: String
    let isUserSide: Bool
}

enum HostCopy {
    enum Common {
        static let appTitle = "モテキー"
        static let notRegistered = "未登録"
        static let configured = "設定済み"
        static let notConfigured = "未設定"
        static let defaultPartnerName = "パートナー"
    }

    enum S001 {
        static let homeTitle = "あなたのメッセージスタイルを教えてください"
        static let homeSubtitle = "実際にメッセージを打ってもらうだけでOK。AIがあなたの語尾・口調・癖を自動で読み取ります。"
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

        static let scenarios: [S002ScenarioCopy] = [
            .init(title: "デート提案", messages: [
                .init(text: "今夜、どこか外食いかない？", isUserSide: false),
                .init(text: "いいよ！どこ行こうか", isUserSide: true),
                .init(text: "決めていいよ！", isUserSide: false)
            ]),
            .init(title: "愚痴・共感", messages: [
                .init(text: "ちょっと悲しいことがあって、聞いてほしい", isUserSide: false)
            ]),
            .init(title: "仕事の愚痴", messages: [
                .init(text: "今日も残業だった…もう疲れた", isUserSide: false),
                .init(text: "お疲れ。大変だったね", isUserSide: true),
                .init(text: "なんか頑張る気力もなくなってきた", isUserSide: false)
            ]),
            .init(title: "週末の予定", messages: [
                .init(text: "今週末、何する？", isUserSide: false),
                .init(text: "特に決めてないけど、どっか行く？", isUserSide: true),
                .init(text: "うーん、家でのんびりでもいいかな", isUserSide: false)
            ]),
            .init(title: "ちょっとした喧嘩後", messages: [
                .init(text: "さっきはごめんね。言いすぎた", isUserSide: false)
            ]),
            .init(title: "不安な気持ち", messages: [
                .init(text: "最近、私のこと好き？", isUserSide: false)
            ]),
            .init(title: "体調不良", messages: [
                .init(text: "なんか頭痛がひどくて…", isUserSide: false),
                .init(text: "大丈夫？何かできることある？", isUserSide: true),
                .init(text: "大丈夫だよ、心配してくれてありがと", isUserSide: false)
            ]),
            .init(title: "嬉しい報告", messages: [
                .init(text: "やった！仕事でめっちゃ褒められた！", isUserSide: false)
            ]),
            .init(title: "悩み相談", messages: [
                .init(text: "友達と最近うまくいってなくて…", isUserSide: false),
                .init(text: "何かあったの？", isUserSide: true),
                .init(text: "向こうから急に冷たくなった気がして、理由もわからなくて不安", isUserSide: false)
            ]),
            .init(title: "趣味・買い物報告", messages: [
                .init(text: "かわいい服見つけたんだけど、ちょっと高くて迷ってる", isUserSide: false),
                .init(text: "いくらくらい？", isUserSide: true),
                .init(text: "1万5千円…。似合うと思う？写真送る", isUserSide: false)
            ])
        ]
    }

    enum S003 {
        static let relationPrompt = "どんな関係ですか？"
        static let nicknamePrompt = "パートナーの呼び名を教えてください"
        static let nicknamePlaceholder = "ゆいちゃん、妻、など"
        static let nicknameSkip = "わからない・決めていない"
        static let datingDatePrompt = "付き合い始めたのはいつ？"
        static let datingDateLabel = "付き合い始めた日"
        static let datingOnly = "付き合った日のみ"
        static let marriageToggle = "入籍日も追加"
        static let marriageNote = "※ 結婚している場合は入籍日も入力できます"
        static let marriageDateLabel = "入籍日"
        static let birthdayAndCautionPrompt = "誕生日を教えてください"
        static let birthdayDescription = "誕生日の前後7日は、AIが自動で気の利いた返信を提案します"
        static let cautionPrompt = "最近の出来事や気をつけることはありますか？"
        static let cautionDescription = "最近の関係の変化、過去に怒らせたこと、ケンカしたことなど"
        static let birthdayToggle = "誕生日を登録する"
        static let birthdaySkip = "不明・スキップ"
        static let cautionPlaceholder = "例：来週が記念日、最近仕事が忙しくて余裕がない、返信が遅いと怒りやすい、など"
        static let cautionSkip = "特にない・わからない"
        static let register = "登録する"
        static let next = "次へ"
        static let step1 = "ステップ 1 / 4"
        static let step2 = "ステップ 2 / 4"
        static let step3 = "ステップ 3 / 4"
        static let step4 = "ステップ 4 / 4"
        static let doneTitle = "登録完了！"
        static let doneMessage = "いつでもアプリから変更できます"
        static let backToHome = "ホームに戻る"
        static let agreement = "入力した内容およびLINEの会話文脈はAI（Gemini API）に送信されます。相手がこのことを知っていない場合、送信前に共有することを推奨します。"
    }

    enum S004 {
        static let preparationTitle = "使用準備"
        static let completeTitle = "初期設定完了"
        static let tutorialTitle = "使い方"
        static let openSettings = "設定を開く"
        static let next = "次へ"
        static let start = "はじめる"
        static let close = "閉じる"
        static let prepHeadline = "キーボードと画面収録の準備をお願いします"
        static let prepSubheadline = "`mote+AI` を使うために、キーボードの有効化と画面収録の開始が必要です"
        static let sectionKeyboard = "1. キーボードを有効にする"
        static let sectionRecording = "2. 画面収録を開始する"
        static let keyboardStep1 = "1) iOSの設定アプリを開く"
        static let keyboardStep2 = "2) 一般 > キーボード > キーボード"
        static let keyboardStep3 = "3) 新しいキーボードを追加 > モテキー"
        static let keyboardStep4 = "4) モテキー > フルアクセスを許可 をオン"
        static let keyboardStep5 = "5) 確認ダイアログで「許可」をタップ"
        static let recordingStep1 = "1) コントロールセンターを開く"
        static let recordingStep2 = "2) 画面収録を長押し"
        static let recordingStep3 = "3) モテキーを選択して開始"
        static let recordingStep4 = "4) ブロードキャストを開始 をタップ"
        static let recordingStep5 = "5) LINEに戻る"
        static let recordingAcknowledgement = "画面収録の開始手順を確認した"
        static let keyboardManualConfirmation = "モテキーを追加し、フルアクセスを許可した"
        static let keyboardDetectionFailedHint = "自動検出に失敗する場合は、このチェックをオンにして進んでください。"
        static let permissionError = "キーボードの追加またはフルアクセス許可が完了していないようです。"
        static let reopenSettings = "もう一度設定を開く"
        static let completeHeadline = "準備完了です"
        static let completeSubheadline = "キーボードと画面収録の準備ができました。次にメッセージアプリでモテキーへ切り替える手順を確認します。"
        static let viewTutorial = "メッセージアプリの使い方を見る"
        static let later = "あとで"
        static let tutorialStep1 = "1. メッセージアプリを開く"
        static let tutorialStep2 = "2. テキスト入力欄をタップしてキーボードを表示する"
        static let tutorialStep3 = "3. 地球儀アイコンを長押し"
        static let tutorialStep4 = "4. モテキーを選択"
        static let tutorialStep5 = "5. mote+AI をタップして開始"
        static let keyboardIdentifierHints = [
            "motekeyapp",
            "motekey",
            "com.motekey.app.keyboard",
            "com.motekey.app"
        ]
    }
}
