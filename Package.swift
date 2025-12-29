// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MangaReader",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "MangaReader",
            targets: ["MangaReader"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        .package(url: "https://github.com/onevcat/Kingfisher", from: "7.10.0")
    ],
    targets: [
        .executableTarget(
            name: "MangaReader",
            dependencies: [
                "Alamofire",
                "Kingfisher"
            ],
            exclude: [
                "Info.plist"
            ]
        )
    ]
)
