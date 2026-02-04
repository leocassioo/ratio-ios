import Foundation
import Cocoa

// MARK: - Configuration
let basePath = "/Users/leonardofigueiredo/Projetos Mobile/ratio-ios/Ratio/Ratio/Assets.xcassets"

enum TintColor {
    case red, blue, green, purple, indigo, pink, gray, cyan, yellow, orange, black, white
    
    var hex: String {
        switch self {
        case .red: return "#E50914" // Netflix Red
        case .blue: return "#00A8E1" // Prime Blue
        case .green: return "#1DB954" // Spotify Green
        case .purple: return "#5865F2" // Discord/Generic Purple
        case .indigo: return "#4B0082" // Max Indigo
        case .pink: return "#FA243C" // Apple Music Pink
        case .gray: return "#2C2C2E" // Apple One Dark Gray (Better than light gray)
        case .cyan: return "#32ADE6" // iCloud Cyan
        case .yellow: return "#F4B400" // Google Yellow
        case .orange: return "#FF4500" // Globoplay Orange
        case .black: return "#000000" // Standard Black
        case .white: return "#FFFFFF" // Standard White
        }
    }
}

struct Service {
    let name: String
    let domain: String
    let tint: TintColor
}

let services: [Service] = [
    Service(name: "netflix", domain: "netflix.com", tint: .red),
    Service(name: "prime video", domain: "primevideo.com", tint: .blue),
    Service(name: "spotify", domain: "spotify.com", tint: .green),
    Service(name: "amazon prime", domain: "amazon.com", tint: .blue),
    Service(name: "disney+", domain: "disneyplus.com", tint: .purple), // Actually Dark Blue/Indigo usually, but keeping existing map
    Service(name: "max", domain: "max.com", tint: .indigo),
    Service(name: "youtube premium", domain: "youtube.com", tint: .red),
    Service(name: "apple music", domain: "apple.com", tint: .pink),
    Service(name: "apple one", domain: "apple.com", tint: .black), // Apple One usually black branding or multicolor
    Service(name: "icloud+", domain: "icloud.com", tint: .cyan),
    Service(name: "google one", domain: "google.com", tint: .yellow), // Multi-color, background might need check
    Service(name: "deezer", domain: "deezer.com", tint: .purple), // Deezer is purple now
    Service(name: "globoplay", domain: "globoplay.globo.com", tint: .orange),
    Service(name: "paramount+", domain: "paramountplus.com", tint: .blue),
    Service(name: "star+", domain: "starplus.com", tint: .orange), // Merged with Disney but assets exist
    Service(name: "chatgpt", domain: "openai.com", tint: .green), // Teal/Green
    Service(name: "microsoft 365", domain: "office.com", tint: .blue), // Office Blue
    Service(name: "adobe cc", domain: "adobe.com", tint: .red),
    Service(name: "canva pro", domain: "canva.com", tint: .purple)
]

// MARK: - Helpers

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else {
            return nil
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

func downloadImage(url: URL) -> NSImage? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return NSImage(data: data)
}

func makeWhite(image: NSImage) -> NSImage {
    let size = image.size
    let whiteImage = NSImage(size: size)
    
    whiteImage.lockFocus()
    
    // Draw original image
    image.draw(in: NSRect(origin: .zero, size: size))
    
    // Set fill to White
    NSColor.white.set()
    
    // Composite using SourceIn (Keeps alpha of original, fills content with set color)
    NSRect(origin: .zero, size: size).fill(using: .sourceIn)
    
    whiteImage.unlockFocus()
    return whiteImage
}

func createIcon(logo: NSImage, tint: TintColor, size: CGSize = CGSize(width: 512, height: 512)) -> NSImage? {
    let img = NSImage(size: size)
    img.lockFocus()
    
    // 1. Draw Background (Rounded Rect)
    let ctx = NSGraphicsContext.current?.cgContext
    let rect = CGRect(origin: .zero, size: size)
    let path = CGPath(roundedRect: rect, cornerWidth: size.width * 0.22, cornerHeight: size.height * 0.22, transform: nil)
    
    if let color = NSColor(hex: tint.hex) {
        ctx?.addPath(path)
        ctx?.setFillColor(color.cgColor)
        ctx?.fillPath()
    }
    
    // 2. Prepare Logo (Make it pure white)
    // Note: Some logos like Google One (multicolor) might look bad in pure white, 
    // but specific overrides would be needed. For contrast consistency requested by user, white on color is best.
    let whiteLogo = makeWhite(image: logo)
    
    // 3. Draw Logo (Centered, Scaled down)
    let logoSize = size.width * 0.6
    let origin = (size.width - logoSize) / 2
    let logoRect = CGRect(x: origin, y: origin, width: logoSize, height: logoSize)
    
    whiteLogo.draw(in: logoRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    
    img.unlockFocus()
    return img
}

func save(image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
    
    try? pngData.write(to: URL(fileURLWithPath: path))
}

// MARK: - Main Loop

print("🎨 Starting FIXED Icon Generation...")

for service in services {
    let folderPath = "\(basePath)/\(service.name).imageset"
    let filePath = "\(folderPath)/\(service.name).png"
    
    // Create Dir
    try? FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
    
    // Create Contents.json
    let jsonContent = """
    {
      "images" : [
        {
          "filename" : "\(service.name).png",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "idiom" : "universal",
          "scale" : "2x"
        },
        {
          "idiom" : "universal",
          "scale" : "3x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try? jsonContent.write(toFile: "\(folderPath)/Contents.json", atomically: true, encoding: .utf8)
    
    // Download Raw Logo
    print("⬇️ Downloading \(service.name)...")
    let urlString = "https://t2.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=http://\(service.domain)&size=256"
    if let url = URL(string: urlString),
       let rawLogo = downloadImage(url: url) {
        
        // Process
        if let icon = createIcon(logo: rawLogo, tint: service.tint) {
             save(image: icon, to: filePath)
             print("✅ Generated Icon for \(service.name)")
        } else {
            print("❌ Failed to generate icon for \(service.name)")
        }
    } else {
        print("❌ Download failed for \(service.name)")
    }
}

print("🏁 Done!")
