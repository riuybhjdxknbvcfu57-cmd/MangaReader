// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MangaReader",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MangaReader",
            targets: ["MangaReader"]
        )
    ],
    dependencies: [
        // .package(url: "https://github.com/JRomainG/MangaDexLib", branch: "dev"),
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
        .package(url: "https://github.com/onevcat/Kingfisher", from: "7.10.0")
    ],
    targets: [
        .target(
            name: "MangaReader",
            dependencies: [
                // "MangaDexLib",
                "Alamofire",
                "Kingfisher"
            ]
        )
    ]
)
