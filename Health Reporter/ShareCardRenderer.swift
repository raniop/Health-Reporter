import UIKit

enum ShareCardRenderer {

    // MARK: - Public

    static func render(
        name: String,
        score: Int,
        carName: String,
        carEmoji: String,
        tierColor: UIColor
    ) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let context = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // ── Background ──
            UIColor(red: 13/255, green: 13/255, blue: 15/255, alpha: 1).setFill()
            context.fill(rect)

            // ── Subtle radial glow behind ring ──
            let glowColors = [tierColor.withAlphaComponent(0.08).cgColor, UIColor.clear.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1]) {
                context.drawRadialGradient(gradient, startCenter: CGPoint(x: 540, y: 400), startRadius: 0, endCenter: CGPoint(x: 540, y: 400), endRadius: 400, options: [])
            }

            // ── "AION HEALTH" header ──
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.35),
                .kern: 8.0
            ]
            let headerText = "AION HEALTH"
            let headerSize = headerText.size(withAttributes: headerAttrs)
            headerText.draw(at: CGPoint(x: (1080 - headerSize.width) / 2, y: 110), withAttributes: headerAttrs)

            // ── Score Ring ──
            let ringCenter = CGPoint(x: 540, y: 420)
            let ringRadius: CGFloat = 170
            let ringWidth: CGFloat = 20

            // Track
            context.setStrokeColor(UIColor(white: 0.11, alpha: 1).cgColor)
            context.setLineWidth(ringWidth)
            context.addArc(center: ringCenter, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.strokePath()

            // Gradient arc
            let clampedScore = max(0, min(100, score))
            if clampedScore > 0 {
                let startAngle: CGFloat = -.pi / 2
                let endAngle: CGFloat = startAngle + (.pi * 2) * (CGFloat(clampedScore) / 100.0)

                let arcPath = UIBezierPath(arcCenter: ringCenter, radius: ringRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                arcPath.lineWidth = ringWidth
                arcPath.lineCapStyle = .round

                // Create stroked copy for clipping
                let strokedPath = arcPath.cgPath.copy(strokingWithWidth: ringWidth, lineCap: .round, lineJoin: .round, miterLimit: 0)

                context.saveGState()
                context.addPath(strokedPath)
                context.clip()

                // Draw gradient within clipped region
                let gradientColors = Self.gradientColorsForScore(clampedScore)
                let cgColors = gradientColors.map { $0.cgColor } as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: [0, 1]) {
                    // Gradient follows the arc: from top-center clockwise
                    let startPt = CGPoint(x: ringCenter.x, y: ringCenter.y - ringRadius)
                    let endPt: CGPoint
                    if clampedScore <= 50 {
                        endPt = CGPoint(x: ringCenter.x + ringRadius * sin(endAngle + .pi / 2),
                                        y: ringCenter.y - ringRadius * cos(endAngle + .pi / 2))
                    } else {
                        endPt = CGPoint(x: ringCenter.x, y: ringCenter.y + ringRadius)
                    }
                    context.drawLinearGradient(gradient, start: startPt, end: endPt, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
                context.restoreGState()
            }

            // Score text in center
            let scoreStr = "\(clampedScore)"
            let scoreAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 180, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let scoreSize = scoreStr.size(withAttributes: scoreAttrs)
            scoreStr.draw(at: CGPoint(x: (1080 - scoreSize.width) / 2, y: ringCenter.y - scoreSize.height / 2 - 16), withAttributes: scoreAttrs)

            // "/100" below score
            let denomAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.3)
            ]
            let denomStr = "/100"
            let denomSize = denomStr.size(withAttributes: denomAttrs)
            denomStr.draw(at: CGPoint(x: (1080 - denomSize.width) / 2, y: ringCenter.y + scoreSize.height / 2 - 36), withAttributes: denomAttrs)

            // ── User Name ──
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64, weight: .semibold),
                .foregroundColor: UIColor.white
            ]
            let displayName = name.count > 20 ? String(name.prefix(18)) + "..." : name
            let nameSize = displayName.size(withAttributes: nameAttrs)
            displayName.draw(at: CGPoint(x: (1080 - nameSize.width) / 2, y: 655), withAttributes: nameAttrs)

            // ── Car Emoji + Name ──
            let carStr = "\(carEmoji)  \(carName)"
            let carAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .medium),
                .foregroundColor: tierColor
            ]
            let carSize = carStr.size(withAttributes: carAttrs)
            carStr.draw(at: CGPoint(x: (1080 - carSize.width) / 2, y: 740), withAttributes: carAttrs)

            // ── Gradient separator line ──
            let lineY: CGFloat = 850
            let lineWidth: CGFloat = 500
            let lineX = (1080 - lineWidth) / 2
            let lineRect = CGRect(x: lineX, y: lineY, width: lineWidth, height: 3)

            context.saveGState()
            context.clip(to: lineRect)
            let lineColors = [
                UIColor(red: 0, green: 0.706, blue: 0.847, alpha: 1).cgColor,  // cyan
                UIColor(red: 0, green: 0.788, blue: 0.655, alpha: 1).cgColor,  // turquoise
                UIColor(red: 0.482, green: 0.929, blue: 0.624, alpha: 1).cgColor // lime
            ] as CFArray
            if let lineGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: lineColors, locations: [0, 0.5, 1]) {
                context.drawLinearGradient(lineGradient, start: CGPoint(x: lineX, y: lineY), end: CGPoint(x: lineX + lineWidth, y: lineY), options: [])
            }
            context.restoreGState()

            // ── AION Logo ──
            if let logo = UIImage(named: "AIONLogoClear") {
                let logoSize: CGFloat = 100
                let logoRect = CGRect(x: (1080 - logoSize) / 2, y: 890, width: logoSize, height: logoSize)
                logo.draw(in: logoRect)
            }

            // ── "aionapp.co" ──
            let urlAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.3)
            ]
            let urlStr = "aionapp.co"
            let urlSize = urlStr.size(withAttributes: urlAttrs)
            urlStr.draw(at: CGPoint(x: (1080 - urlSize.width) / 2, y: 1000), withAttributes: urlAttrs)
        }
    }

    // MARK: - Private

    private static func gradientColorsForScore(_ score: Int) -> [UIColor] {
        switch score {
        case 82...100: return [UIColor(hex: "#6EE7B7")!, UIColor(hex: "#34D399")!]
        case 65...81:  return [UIColor(hex: "#00CED1")!, UIColor(hex: "#00BFFF")!]
        case 45...64:  return [UIColor(hex: "#00BFFF")!, UIColor(hex: "#00CED1")!]
        case 25...44:  return [UIColor(hex: "#FF6B35")!, UIColor(hex: "#00BFFF")!]
        default:       return [UIColor(hex: "#EF4444")!, UIColor(hex: "#FF6B35")!]
        }
    }
}
