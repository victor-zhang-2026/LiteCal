// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "LiteCal", platforms: [.macOS(.v13)], products: [.executable(name: "LiteCal", targets: ["LiteCal"])], targets: [.executableTarget(name: "LiteCal")], swiftLanguageModes: [.v5])
