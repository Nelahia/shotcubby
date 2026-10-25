import Foundation

/// The text in the language the Mac is set to for this app. The English text is
/// the key, looked up in `fr.lproj/Localizable.strings`; a text with no entry is
/// shown in English, so nothing is ever blank. For the places that need a
/// `String` (alerts, menus, errors); SwiftUI literals are looked up on their own.
func tr(_ english: String) -> String {
    NSLocalizedString(english, comment: "")
}
