import Foundation

enum ResourceLocator {
    static func url(forResource name: String, withExtension extensionName: String) -> URL? {
        if let mainURL = Bundle.main.url(forResource: name, withExtension: extensionName) {
            return mainURL
        }
#if SWIFT_PACKAGE
        return Bundle.module.url(forResource: name, withExtension: extensionName)
#else
        return nil
#endif
    }
}
