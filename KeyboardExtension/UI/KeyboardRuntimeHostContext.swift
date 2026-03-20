protocol KeyboardRuntimeHostContext: AnyObject {
    func insertText(_ text: String)
    func clearMarkedText()
    func advanceToNextInputMode()
    var hasFullAccess: Bool { get }
}
