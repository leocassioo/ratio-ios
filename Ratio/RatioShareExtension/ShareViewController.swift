import UIKit
import SwiftUI

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Host the SwiftUI View
        // Pass extensionContext to allow the view to close itself
        var swiftUIView = ShareView()
        swiftUIView.extensionContext = extensionContext
        
        let hostingController = UIHostingController(rootView: swiftUIView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
}
