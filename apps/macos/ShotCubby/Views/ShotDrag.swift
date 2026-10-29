import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Lets a screenshot be dragged out of the window onto the Desktop, a Finder
    /// folder, a chat, a mail… The drag starts after a press and a small move, so
    /// a plain click or double-click still opens or renames it.
    func shotDrag(_ shot: Shot) -> some View {
        onDrag { shot.dragProvider }
    }
}

private extension Shot {
    /// The file is offered as a copy to be made at the drop, not as its own
    /// path: dropped in a Finder folder on the same disk, the path would be
    /// moved out of the screenshots folder instead.
    var dragProvider: NSItemProvider {
        let provider = NSItemProvider()
        provider.suggestedName = name
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        let file = url
        provider.registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all) { done in
            done(file, false, nil)
            return nil
        }
        return provider
    }
}
