import Foundation

enum HostRoute: Hashable {
    case textHabit(questionIndex: Int)
    case textHabitLoading
    case relation(step: RelationStep)
    case keyboardPermission
    case keyboardComplete
    case tutorial
}

enum RelationStep: Hashable {
    case nickname
    case relationship
    case datingDate
    case birthdayAndCaution
    case done
}
