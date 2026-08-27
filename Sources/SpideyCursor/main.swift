import AppKit
import ApplicationServices
import QuartzCore

enum HeroStyle: Int, CaseIterable {
    case classic
    case mochi
    case comic

    var title: String {
        switch self {
        case .classic: return "经典大头"
        case .mochi: return "软萌团子"
        case .comic: return "漫画豆丁"
        }
    }
}

private enum MotionMode {
    case idle
    case aiming
    case swinging
    case landing
}

enum HeroPose {
    case idle
    case firing
    case swinging
    case hanging
}

private struct TrailPoint {
    var point: CGPoint
    var life: CGFloat
}

private func clamp(_ value: CGFloat, _ minimum: CGFloat, _ maximum: CGFloat) -> CGFloat {
    min(maximum, max(minimum, value))
}

private func pointDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(b.x - a.x, b.y - a.y)
}

private func quadratic(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    let inverse = 1 - t
    return CGPoint(
        x: inverse * inverse * a.x + 2 * inverse * t * control.x + t * t * b.x,
        y: inverse * inverse * a.y + 2 * inverse * t * control.y + t * t * b.y
    )
}

private func easeInOutCubic(_ value: CGFloat) -> CGFloat {
    value < 0.5
        ? 4 * value * value * value
        : 1 - pow(-2 * value + 2, 3) / 2
}

enum HeroRenderer {
    private static let ink = NSColor(calibratedRed: 0.035, green: 0.03, blue: 0.09, alpha: 1)
    private static let red = NSColor(calibratedRed: 1, green: 0.18, blue: 0.28, alpha: 1)
    private static let blue = NSColor(calibratedRed: 0.13, green: 0.27, blue: 0.9, alpha: 1)

    static func draw(style: HeroStyle, pose: HeroPose = .idle, webAngle: CGFloat = .pi / 3) {
        if pose == .hanging {
            drawHanging(style: style)
            return
        }
        switch style {
        case .classic: drawClassic(pose: pose, webAngle: webAngle)
        case .mochi: drawMochi(pose: pose, webAngle: webAngle)
        case .comic: drawComic(pose: pose, webAngle: webAngle)
        }
    }

    private static func fillStroke(_ path: NSBezierPath, fill: NSColor, width: CGFloat = 2.2) {
        fill.setFill()
        path.fill()
        ink.setStroke()
        path.lineWidth = width
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }

    private static func rounded(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    private static func eye(_ rect: CGRect, rotation: CGFloat = 0) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY)
        transform.rotate(byDegrees: rotation)
        transform.translateX(by: -rect.midX, yBy: -rect.midY)
        transform.concat()
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.midY))
        path.curve(
            to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.maxY - rect.height * 0.07),
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.12),
            controlPoint2: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY)
        )
        path.curve(
            to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.midY),
            controlPoint1: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.18),
            controlPoint2: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY)
        )
        path.close()
        fillStroke(path, fill: .white, width: 2.25)
        let glint = NSBezierPath(ovalIn: CGRect(
            x: rect.minX + rect.width * 0.34,
            y: rect.maxY - rect.height * 0.32,
            width: rect.width * 0.32,
            height: rect.height * 0.12
        ))
        NSColor(calibratedRed: 0.7, green: 0.93, blue: 1, alpha: 0.92).setFill()
        glint.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func webDetails(center: CGPoint, radius: CGFloat) {
        ink.withAlphaComponent(0.38).setStroke()
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            let path = NSBezierPath()
            path.move(to: center)
            path.line(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
            path.lineWidth = 0.65
            path.stroke()
        }
        for ring in [0.38, 0.68] as [CGFloat] {
            let path = NSBezierPath(ovalIn: CGRect(
                x: center.x - radius * ring,
                y: center.y - radius * ring,
                width: radius * ring * 2,
                height: radius * ring * 2
            ))
            path.lineWidth = 0.55
            path.stroke()
        }
    }

    private static func drawShadow(width: CGFloat) {
        let path = NSBezierPath(ovalIn: CGRect(x: -width / 2, y: -31, width: width, height: 7))
        NSColor(calibratedWhite: 0, alpha: 0.28).setFill()
        path.fill()
    }

    private static func armGeometry(style: HeroStyle, webAngle: CGFloat) -> (shoulder: CGPoint, length: CGFloat, thickness: CGFloat) {
        let side: CGFloat = cos(webAngle) >= 0 ? 1 : -1
        switch style {
        case .classic:
            return (CGPoint(x: side * 10.5, y: 8), 29, 9)
        case .mochi:
            return (CGPoint(x: side * 12.5, y: 7), 27, 10)
        case .comic:
            return (CGPoint(x: side * 11.5, y: 10), 30, 8.5)
        }
    }

    static func webHandPoint(style: HeroStyle, webAngle: CGFloat) -> CGPoint {
        let geometry = armGeometry(style: style, webAngle: webAngle)
        let reach = geometry.length + 4
        return CGPoint(
            x: geometry.shoulder.x + cos(webAngle) * reach,
            y: geometry.shoulder.y + sin(webAngle) * reach
        )
    }

    private static func drawFiringArm(style: HeroStyle, webAngle: CGFloat, sleeve: NSColor, glove: NSColor) {
        let geometry = armGeometry(style: style, webAngle: webAngle)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: geometry.shoulder.x, yBy: geometry.shoulder.y)
        transform.rotate(byDegrees: webAngle * 180 / .pi)
        transform.concat()

        let upperArm = rounded(
            CGRect(x: -3, y: -geometry.thickness / 2, width: geometry.length - 8, height: geometry.thickness),
            radius: geometry.thickness / 2
        )
        fillStroke(upperArm, fill: sleeve, width: 1.8)

        let gauntlet = rounded(
            CGRect(x: geometry.length - 15, y: -geometry.thickness * 0.62, width: 13, height: geometry.thickness * 1.24),
            radius: geometry.thickness * 0.45
        )
        fillStroke(gauntlet, fill: glove, width: 1.7)

        let cuff = rounded(
            CGRect(x: geometry.length - 15, y: -geometry.thickness * 0.66, width: 4.2, height: geometry.thickness * 1.32),
            radius: 1.6
        )
        NSColor(calibratedRed: 0.76, green: 0.84, blue: 0.91, alpha: 1).setFill()
        cuff.fill()
        ink.setStroke()
        cuff.lineWidth = 1.2
        cuff.stroke()

        let shooter = NSBezierPath(ovalIn: CGRect(x: geometry.length - 13.8, y: -2.2, width: 3.4, height: 4.4))
        NSColor.white.setFill()
        shooter.fill()
        ink.setStroke()
        shooter.lineWidth = 0.8
        shooter.stroke()

        for y in [-1.55, 1.35] as [CGFloat] {
            let finger = NSBezierPath()
            finger.move(to: CGPoint(x: geometry.length - 6, y: y))
            finger.curve(
                to: CGPoint(x: geometry.length + 4, y: y * 0.48),
                controlPoint1: CGPoint(x: geometry.length - 1, y: y),
                controlPoint2: CGPoint(x: geometry.length + 2, y: y * 0.7)
            )
            ink.setStroke()
            finger.lineCapStyle = .round
            finger.lineWidth = 3.1
            finger.stroke()
            glove.setStroke()
            finger.lineWidth = 1.7
            finger.stroke()
        }

        let bentFinger = NSBezierPath()
        bentFinger.move(to: CGPoint(x: geometry.length - 5, y: -geometry.thickness * 0.33))
        bentFinger.curve(
            to: CGPoint(x: geometry.length - 1, y: -geometry.thickness * 0.52),
            controlPoint1: CGPoint(x: geometry.length - 3, y: -geometry.thickness * 0.55),
            controlPoint2: CGPoint(x: geometry.length, y: -geometry.thickness * 0.56)
        )
        ink.setStroke()
        bentFinger.lineWidth = 1.35
        bentFinger.lineCapStyle = .round
        bentFinger.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawStaticArms(left: Bool, right: Bool, color: NSColor) {
        if left {
            fillStroke(rounded(CGRect(x: -21, y: -8, width: 10, height: 25), radius: 5), fill: color)
        }
        if right {
            fillStroke(rounded(CGRect(x: 11, y: -8, width: 10, height: 25), radius: 5), fill: color)
        }
    }

    private static func drawChestSpider(center: CGPoint, scale: CGFloat, color: NSColor = ink) {
        color.setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - 2.2 * scale, y: center.y - 4 * scale, width: 4.4 * scale, height: 8 * scale)).fill()
        NSBezierPath(ovalIn: CGRect(x: center.x - 1.5 * scale, y: center.y + 2.7 * scale, width: 3 * scale, height: 4 * scale)).fill()
        color.setStroke()
        for side in [-1, 1] as [CGFloat] {
            for level in 0..<4 {
                let offset = CGFloat(level) - 1.5
                let leg = NSBezierPath()
                leg.move(to: CGPoint(x: center.x + side * 1.5 * scale, y: center.y + offset * 1.8 * scale))
                leg.line(to: CGPoint(x: center.x + side * (4.4 + abs(offset) * 0.65) * scale, y: center.y + offset * 2.7 * scale))
                leg.line(to: CGPoint(x: center.x + side * (5.6 + abs(offset) * 0.45) * scale, y: center.y + offset * 1.5 * scale))
                leg.lineWidth = max(0.75, 1.05 * scale)
                leg.lineCapStyle = .round
                leg.lineJoinStyle = .round
                leg.stroke()
            }
        }
    }

    private static func drawTorsoSeams() {
        ink.withAlphaComponent(0.55).setStroke()
        let waist = NSBezierPath()
        waist.move(to: CGPoint(x: -12, y: -4))
        waist.curve(to: CGPoint(x: 12, y: -4), controlPoint1: CGPoint(x: -5, y: -7), controlPoint2: CGPoint(x: 5, y: -7))
        waist.lineWidth = 1
        waist.stroke()
        for side in [-1, 1] as [CGFloat] {
            let seam = NSBezierPath()
            seam.move(to: CGPoint(x: side * 7, y: 13))
            seam.curve(to: CGPoint(x: side * 11, y: -4), controlPoint1: CGPoint(x: side * 9, y: 8), controlPoint2: CGPoint(x: side * 10, y: 1))
            seam.lineWidth = 0.85
            seam.stroke()
        }
    }

    private static func drawHanging(style: HeroStyle) {
        let suitRed: NSColor
        let suitBlue: NSColor
        switch style {
        case .classic:
            suitRed = red
            suitBlue = blue
        case .mochi:
            suitRed = NSColor(calibratedRed: 1, green: 0.35, blue: 0.43, alpha: 1)
            suitBlue = NSColor(calibratedRed: 0.27, green: 0.43, blue: 0.92, alpha: 1)
        case .comic:
            suitRed = NSColor(calibratedRed: 0.97, green: 0.14, blue: 0.2, alpha: 1)
            suitBlue = NSColor(calibratedRed: 0.08, green: 0.31, blue: 0.76, alpha: 1)
        }

        // 蜷在面罩上方的小身体，造型取自参考图的“大头、小身体”比例。
        fillStroke(rounded(CGRect(x: -18, y: 25, width: 13, height: 15), radius: 6), fill: suitBlue, width: 2)
        fillStroke(rounded(CGRect(x: 5, y: 25, width: 13, height: 15), radius: 6), fill: suitBlue, width: 2)
        let tinyBody = rounded(CGRect(x: -14, y: 14, width: 28, height: 23), radius: 11)
        fillStroke(tinyBody, fill: suitBlue, width: 2.4)
        let tinyChest = rounded(CGRect(x: -8, y: 17, width: 16, height: 17), radius: 7)
        suitRed.setFill()
        tinyChest.fill()
        drawChestSpider(center: CGPoint(x: 0, y: 24), scale: 0.48)

        for side in [-1, 1] as [CGFloat] {
            NSGraphicsContext.saveGraphicsState()
            let armTransform = NSAffineTransform()
            armTransform.translateX(by: side * 8, yBy: 26)
            armTransform.rotate(byDegrees: side * -32)
            armTransform.concat()
            fillStroke(rounded(CGRect(x: -4.5, y: -3.8, width: 20, height: 8), radius: 4), fill: suitRed, width: 1.8)
            NSGraphicsContext.restoreGraphicsState()
        }

        // 白色蛛丝穿过双手，手掌紧握在一起。
        let innerWeb = NSBezierPath()
        innerWeb.move(to: CGPoint(x: 0, y: 47))
        innerWeb.line(to: CGPoint(x: 0, y: 29))
        NSColor.white.setStroke()
        innerWeb.lineWidth = 2.4
        innerWeb.lineCapStyle = .round
        innerWeb.stroke()
        fillStroke(NSBezierPath(ovalIn: CGRect(x: -8, y: 31, width: 10, height: 10)), fill: suitRed, width: 1.8)
        fillStroke(NSBezierPath(ovalIn: CGRect(x: -2, y: 31, width: 10, height: 10)), fill: suitRed, width: 1.8)

        let head = NSBezierPath(ovalIn: CGRect(x: -26, y: -32, width: 52, height: 52))
        fillStroke(head, fill: suitRed, width: 3)
        webDetails(center: CGPoint(x: 0, y: -6), radius: 23)
        eye(CGRect(x: -21, y: -14, width: 19, height: 24), rotation: -15)
        eye(CGRect(x: 2, y: -14, width: 19, height: 24), rotation: 15)
    }

    private static func drawClassic(pose: HeroPose, webAngle: CGFloat) {
        drawShadow(width: 32)

        fillStroke(rounded(CGRect(x: -13, y: -24, width: 10, height: 25), radius: 5), fill: blue)
        fillStroke(rounded(CGRect(x: 3, y: -24, width: 10, height: 25), radius: 5), fill: blue)
        fillStroke(rounded(CGRect(x: -13.5, y: -25, width: 11, height: 10), radius: 4), fill: red, width: 1.7)
        fillStroke(rounded(CGRect(x: 2.5, y: -25, width: 11, height: 10), radius: 4), fill: red, width: 1.7)

        if pose == .idle {
            drawStaticArms(left: true, right: true, color: red)
        } else {
            let firesRight = cos(webAngle) >= 0
            drawStaticArms(left: firesRight, right: !firesRight, color: red)
            drawFiringArm(style: .classic, webAngle: webAngle, sleeve: blue, glove: red)
        }

        let torso = rounded(CGRect(x: -14, y: -11, width: 28, height: 28), radius: 11)
        fillStroke(torso, fill: blue)
        let chest = rounded(CGRect(x: -8, y: -8, width: 16, height: 23), radius: 7)
        red.setFill(); chest.fill()
        ink.withAlphaComponent(0.7).setStroke(); chest.lineWidth = 1; chest.stroke()
        drawTorsoSeams()
        drawChestSpider(center: CGPoint(x: 0, y: 3.5), scale: 0.72)

        let head = rounded(CGRect(x: -23, y: 7, width: 46, height: 42), radius: 21)
        fillStroke(head, fill: red, width: 2.5)
        webDetails(center: CGPoint(x: 0, y: 28), radius: 17)
        eye(CGRect(x: -18, y: 18, width: 15, height: 21), rotation: -11)
        eye(CGRect(x: 3, y: 18, width: 15, height: 21), rotation: 11)
    }

    private static func drawMochi(pose: HeroPose, webAngle: CGFloat) {
        let softInk = NSColor(calibratedRed: 0.16, green: 0.08, blue: 0.18, alpha: 1)
        let coral = NSColor(calibratedRed: 1, green: 0.35, blue: 0.43, alpha: 1)
        let softBlue = NSColor(calibratedRed: 0.27, green: 0.43, blue: 0.92, alpha: 1)

        drawShadow(width: 34)
        fillStroke(rounded(CGRect(x: -15, y: -25, width: 12, height: 23), radius: 6), fill: softBlue)
        fillStroke(rounded(CGRect(x: 3, y: -25, width: 12, height: 23), radius: 6), fill: softBlue)
        if pose == .idle {
            fillStroke(rounded(CGRect(x: -22, y: -7, width: 11, height: 22), radius: 6), fill: coral)
            fillStroke(rounded(CGRect(x: 11, y: -7, width: 11, height: 22), radius: 6), fill: coral)
        } else {
            let firesRight = cos(webAngle) >= 0
            if firesRight { fillStroke(rounded(CGRect(x: -22, y: -7, width: 11, height: 22), radius: 6), fill: coral) }
            else { fillStroke(rounded(CGRect(x: 11, y: -7, width: 11, height: 22), radius: 6), fill: coral) }
            drawFiringArm(style: .mochi, webAngle: webAngle, sleeve: softBlue, glove: coral)
        }

        let body = NSBezierPath(ovalIn: CGRect(x: -17, y: -14, width: 34, height: 33))
        softBlue.setFill(); body.fill(); softInk.setStroke(); body.lineWidth = 2.2; body.stroke()
        let belly = NSBezierPath(ovalIn: CGRect(x: -10, y: -9, width: 20, height: 25))
        coral.setFill(); belly.fill()
        softInk.withAlphaComponent(0.55).setStroke()
        belly.lineWidth = 0.9
        belly.stroke()
        drawChestSpider(center: CGPoint(x: 0, y: 3), scale: 0.66, color: softInk)

        let head = rounded(CGRect(x: -23, y: 8, width: 46, height: 40), radius: 20)
        coral.setFill(); head.fill(); softInk.setStroke(); head.lineWidth = 2.5; head.stroke()
        NSColor.white.withAlphaComponent(0.19).setFill()
        NSBezierPath(ovalIn: CGRect(x: -15, y: 35, width: 15, height: 6)).fill()
        webDetails(center: CGPoint(x: 0, y: 28), radius: 18)
        eye(CGRect(x: -16, y: 20, width: 13, height: 18), rotation: -5)
        eye(CGRect(x: 3, y: 20, width: 13, height: 18), rotation: 5)
    }

    private static func drawComic(pose heroPose: HeroPose, webAngle: CGFloat) {
        drawShadow(width: 31)
        NSGraphicsContext.saveGraphicsState()
        let pose = NSAffineTransform()
        pose.rotate(byDegrees: -7)
        pose.concat()

        fillStroke(rounded(CGRect(x: -17, y: -22, width: 10, height: 24), radius: 4), fill: blue)
        fillStroke(rounded(CGRect(x: 6, y: -19, width: 10, height: 25), radius: 4), fill: red)
        if heroPose == .idle {
            fillStroke(rounded(CGRect(x: -25, y: 0, width: 10, height: 27), radius: 4), fill: red)
            fillStroke(rounded(CGRect(x: 14, y: 4, width: 10, height: 28), radius: 4), fill: blue)
        } else {
            let firesRight = cos(webAngle) >= 0
            if firesRight { fillStroke(rounded(CGRect(x: -25, y: 0, width: 10, height: 27), radius: 4), fill: red) }
            else { fillStroke(rounded(CGRect(x: 14, y: 4, width: 10, height: 28), radius: 4), fill: blue) }
            drawFiringArm(style: .comic, webAngle: webAngle, sleeve: blue, glove: red)
        }

        let torso = rounded(CGRect(x: -14, y: -9, width: 29, height: 29), radius: 8)
        fillStroke(torso, fill: red, width: 2.6)
        let side = rounded(CGRect(x: 4, y: -7, width: 10, height: 25), radius: 4)
        blue.setFill(); side.fill()
        drawTorsoSeams()
        drawChestSpider(center: CGPoint(x: -1, y: 4), scale: 0.7)

        let head = NSBezierPath()
        head.move(to: CGPoint(x: -19, y: 15))
        head.curve(to: CGPoint(x: -16, y: 44), controlPoint1: CGPoint(x: -25, y: 28), controlPoint2: CGPoint(x: -22, y: 42))
        head.curve(to: CGPoint(x: 17, y: 44), controlPoint1: CGPoint(x: -4, y: 51), controlPoint2: CGPoint(x: 8, y: 49))
        head.curve(to: CGPoint(x: 20, y: 16), controlPoint1: CGPoint(x: 24, y: 40), controlPoint2: CGPoint(x: 25, y: 27))
        head.curve(to: CGPoint(x: -19, y: 15), controlPoint1: CGPoint(x: 11, y: 8), controlPoint2: CGPoint(x: -11, y: 8))
        head.close()
        fillStroke(head, fill: red, width: 2.8)
        webDetails(center: CGPoint(x: 0, y: 29), radius: 17)
        eye(CGRect(x: -14, y: 23, width: 11, height: 17), rotation: -15)
        eye(CGRect(x: 4, y: 25, width: 11, height: 17), rotation: 14)
        NSGraphicsContext.restoreGraphicsState()
    }

    static func renderPreview(to path: String) throws {
        let size = CGSize(width: 1160, height: 330)
        let image = NSImage(size: size)
        image.lockFocus()

        let background = NSBezierPath(roundedRect: CGRect(origin: .zero, size: size), xRadius: 28, yRadius: 28)
        NSColor(calibratedRed: 0.035, green: 0.035, blue: 0.09, alpha: 1).setFill()
        background.fill()

        let title = "蛛网小英雄 · 参考图萌系比例 + 悬挂待机"
        title.draw(at: CGPoint(x: 36, y: 278), withAttributes: [
            .font: NSFont.systemFont(ofSize: 25, weight: .bold),
            .foregroundColor: NSColor.white
        ])

        for index in 0..<4 {
            let cardX = CGFloat(28 + index * 280)
            let card = NSBezierPath(roundedRect: CGRect(x: cardX, y: 30, width: 264, height: 225), xRadius: 22, yRadius: 22)
            NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.18, alpha: 1).setFill()
            card.fill()
            NSColor(calibratedRed: 0.25, green: 0.3, blue: 0.6, alpha: 0.55).setStroke()
            card.lineWidth = 1.2
            card.stroke()

            NSGraphicsContext.saveGraphicsState()
            let context = NSGraphicsContext.current!.cgContext
            let isHangingCard = index == 3
            let style = isHangingCard ? HeroStyle.classic : HeroStyle.allCases[index]
            context.translateBy(x: cardX + 132, y: isHangingCard ? 134 : 132)
            context.scaleBy(x: isHangingCard ? 1.5 : 1.65, y: isHangingCard ? 1.5 : 1.65)
            if isHangingCard {
                context.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
                context.setLineWidth(1.7)
                context.move(to: CGPoint(x: 0, y: 72))
                context.addLine(to: CGPoint(x: 0, y: 42))
                context.strokePath()
                draw(style: style, pose: .hanging)
            } else {
                draw(style: style, pose: .firing, webAngle: .pi / 3.2)
            }
            NSGraphicsContext.restoreGraphicsState()

            let label = isHangingCard ? "悬挂待机" : style.title
            label.draw(at: CGPoint(x: cardX + (isHangingCard ? 91 : 86), y: 50), withAttributes: [
                .font: NSFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: NSColor.white
            ])
        }

        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SpideyCursor", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法生成预览图"])
        }
        try png.write(to: URL(fileURLWithPath: path))
    }
}

final class OverlayView: NSView {
    var heroStyle: HeroStyle = .classic { didSet { needsDisplay = true } }
    var heroPosition: CGPoint = .zero
    var isEffectEnabled = true { didSet { needsDisplay = true } }
    private(set) var isHangingIdle = false
    var onHangingReleased: (() -> Void)?

    private var mode: MotionMode = .idle
    private var startPoint: CGPoint = .zero
    private var targetPoint: CGPoint = .zero
    private var controlPoint: CGPoint = .zero
    private var previousPoint: CGPoint = .zero
    private var startedAt: CFTimeInterval = 0
    private var duration: CFTimeInterval = 0.72
    private var heroAngle: CGFloat = 0
    private var heroScale: CGFloat = 1
    private var trail: [TrailPoint] = []
    private var timer: Timer?
    private var isPullingHang = false
    private var isReturningToHang = false
    private var pullReady = false
    private var pullDistance: CGFloat = 0
    private var pullPointerStart: CGPoint = .zero
    private var hangingRestPoint: CGPoint = .zero
    private var hangingReturnFrom: CGPoint = .zero
    private var hangingReturnStartedAt: CFTimeInterval = 0

    private let pullReleaseThreshold: CGFloat = 112

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        startTimer()
    }

    required init?(coder: NSCoder) { nil }

    deinit { timer?.invalidate() }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func beginAim(at point: CGPoint) {
        guard isEffectEnabled else { return }
        if isHangingIdle {
            beginHangingPull(at: point)
            return
        }
        guard mode == .idle else { return }
        startPoint = heroPosition
        targetPoint = point
        previousPoint = heroPosition
        mode = .aiming
        needsDisplay = true
    }

    func updateAim(to point: CGPoint) {
        if isHangingIdle {
            updateHangingPull(to: point)
            return
        }
        guard mode == .aiming else { return }
        targetPoint = point
        let dx = point.x - startPoint.x
        let dy = point.y - startPoint.y
        heroAngle = clamp(atan2(dy, dx) * 180 / .pi * 0.12, -12, 12)
        needsDisplay = true
    }

    func releaseAim(at point: CGPoint) {
        if isHangingIdle {
            releaseHangingPull(at: point)
            return
        }
        guard mode == .aiming else { return }
        targetPoint = point
        let span = pointDistance(startPoint, targetPoint)
        duration = CFTimeInterval(span < 20 ? 0.35 : clamp(0.48 + span * 0.0011, 0.5, 1.05))
        controlPoint = span < 20
            ? CGPoint(x: startPoint.x, y: startPoint.y + 36)
            : CGPoint(
                x: (startPoint.x + targetPoint.x) / 2,
                y: max(34, min(startPoint.y, targetPoint.y) - min(150, 28 + span * 0.25))
            )
        previousPoint = startPoint
        startedAt = CACurrentMediaTime()
        trail.removeAll(keepingCapacity: true)
        mode = .swinging
    }

    func cancelAim() {
        guard mode == .aiming else { return }
        heroPosition = startPoint
        heroAngle = 0
        mode = .idle
        needsDisplay = true
    }

    func moveHero(to point: CGPoint) {
        guard !isHangingIdle else { return }
        heroPosition = point
        startPoint = point
        targetPoint = point
        previousPoint = point
        mode = .idle
        heroAngle = 0
        trail.removeAll()
        needsDisplay = true
    }

    func setHangingIdle(_ enabled: Bool) {
        isHangingIdle = enabled
        isPullingHang = false
        isReturningToHang = false
        pullReady = false
        pullDistance = 0
        mode = .idle
        heroAngle = 0
        heroScale = 1
        trail.removeAll()
        if enabled {
            heroPosition = CGPoint(x: bounds.midX, y: bounds.maxY - 82)
            hangingRestPoint = heroPosition
            startPoint = heroPosition
            targetPoint = heroPosition
            previousPoint = heroPosition
        }
        needsDisplay = true
    }

    private func beginHangingPull(at point: CGPoint) {
        guard !isReturningToHang else { return }
        let hitX = abs(point.x - heroPosition.x) <= 38
        let hitY = point.y >= heroPosition.y - 36 && point.y <= heroPosition.y + 48
        guard hitX, hitY else { return }
        isPullingHang = true
        pullReady = false
        pullDistance = 0
        pullPointerStart = point
        hangingRestPoint = heroPosition
        needsDisplay = true
    }

    private func updateHangingPull(to point: CGPoint) {
        guard isPullingHang else { return }
        let rawPull = max(0, pullPointerStart.y - point.y)
        pullDistance = min(rawPull, 168)
        pullReady = rawPull >= pullReleaseThreshold
        let sideways = clamp((point.x - pullPointerStart.x) * 0.28, -42, 42)
        heroPosition = CGPoint(
            x: hangingRestPoint.x + sideways,
            y: hangingRestPoint.y - pullDistance
        )
        heroScale = 1 + min(0.08, pullDistance / 1_600)
        needsDisplay = true
    }

    private func releaseHangingPull(at point: CGPoint) {
        guard isPullingHang else { return }
        updateHangingPull(to: point)
        isPullingHang = false

        if pullReady {
            isHangingIdle = false
            isReturningToHang = false
            pullReady = false
            pullDistance = 0
            heroScale = 1.12
            heroAngle = 0
            startPoint = heroPosition
            targetPoint = heroPosition
            previousPoint = heroPosition
            startedAt = CACurrentMediaTime()
            duration = 0.28
            mode = .landing
            onHangingReleased?()
        } else {
            hangingReturnFrom = heroPosition
            hangingReturnStartedAt = CACurrentMediaTime()
            isReturningToHang = true
        }
        needsDisplay = true
    }

    private func tick() {
        guard isEffectEnabled else { return }
        let now = CACurrentMediaTime()

        if isHangingIdle {
            if isReturningToHang {
                let raw = CGFloat(clamp(CGFloat((now - hangingReturnStartedAt) / 0.34), 0, 1))
                let eased = 1 - pow(1 - raw, 3)
                heroPosition = CGPoint(
                    x: hangingReturnFrom.x + (hangingRestPoint.x - hangingReturnFrom.x) * eased,
                    y: hangingReturnFrom.y + (hangingRestPoint.y - hangingReturnFrom.y) * eased + sin(raw * .pi) * 7
                )
                heroScale = 1 + sin(raw * .pi) * 0.06
                if raw >= 1 {
                    heroPosition = hangingRestPoint
                    heroScale = 1
                    pullDistance = 0
                    pullReady = false
                    isReturningToHang = false
                }
                needsDisplay = true
            }
            return
        }

        if mode == .swinging {
            let raw = CGFloat(clamp(CGFloat((now - startedAt) / duration), 0, 1))
            let eased = easeInOutCubic(raw)
            let next = quadratic(startPoint, controlPoint, targetPoint, eased)
            let velocity = CGPoint(x: next.x - previousPoint.x, y: next.y - previousPoint.y)
            heroPosition = next
            heroAngle = clamp(atan2(velocity.y, velocity.x) * 180 / .pi, -58, 58)
            heroScale = 1 + sin(raw * .pi) * 0.08
            if pointDistance(previousPoint, next) > 1.5 {
                trail.append(TrailPoint(point: previousPoint, life: 1))
                if trail.count > 12 { trail.removeFirst() }
            }
            previousPoint = next

            if raw >= 1 {
                heroPosition = targetPoint
                previousPoint = targetPoint
                heroAngle = 0
                heroScale = 1
                startedAt = now
                duration = 0.2
                mode = .landing
            }
        } else if mode == .landing {
            let value = CGFloat(clamp(CGFloat((now - startedAt) / duration), 0, 1))
            heroScale = 1 + sin(value * .pi) * 0.16
            heroAngle = sin(value * .pi * 2) * 4
            if value >= 1 {
                heroScale = 1
                heroAngle = 0
                trail.removeAll()
                mode = .idle
            }
        }

        for index in trail.indices { trail[index].life -= 0.06 }
        trail.removeAll { $0.life <= 0 }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isEffectEnabled, let context = NSGraphicsContext.current?.cgContext else { return }

        if isHangingIdle {
            drawHangingIdle(context: context)
            return
        }

        if trail.count > 1 {
            context.saveGState()
            context.setLineCap(.round)
            for index in 1..<trail.count {
                let from = trail[index - 1]
                let to = trail[index]
                context.setStrokeColor(NSColor(calibratedRed: 1, green: 0.2, blue: 0.4, alpha: to.life * 0.22).cgColor)
                context.setLineWidth(2 + to.life * 2.5)
                context.move(to: from.point)
                context.addLine(to: to.point)
                context.strokePath()
            }
            context.restoreGState()
        }

        let heroRotation = heroAngle * .pi / 180
        let webDelta = CGPoint(x: targetPoint.x - heroPosition.x, y: targetPoint.y - heroPosition.y)
        let worldWebAngle: CGFloat = hypot(webDelta.x, webDelta.y) > 1
            ? atan2(webDelta.y, webDelta.x)
            : .pi / 3
        let localWebAngle = worldWebAngle - heroRotation
        let displayScale = heroScale * 0.75
        let localHand = HeroRenderer.webHandPoint(style: heroStyle, webAngle: localWebAngle)
        let scaledHand = CGPoint(x: localHand.x * displayScale, y: localHand.y * displayScale)
        let worldHand = CGPoint(
            x: heroPosition.x + scaledHand.x * cos(heroRotation) - scaledHand.y * sin(heroRotation),
            y: heroPosition.y + scaledHand.x * sin(heroRotation) + scaledHand.y * cos(heroRotation)
        )

        if mode == .aiming || mode == .swinging {
            drawWeb(context: context, start: worldHand)
            drawAnchorWeb(context: context)
        }

        context.saveGState()
        context.translateBy(x: heroPosition.x, y: heroPosition.y)
        context.rotate(by: heroRotation)
        context.scaleBy(x: displayScale, y: displayScale)
        let pose: HeroPose = mode == .aiming ? .firing : (mode == .swinging ? .swinging : .idle)
        HeroRenderer.draw(style: heroStyle, pose: pose, webAngle: localWebAngle)
        context.restoreGState()
    }

    private func drawHangingIdle(context: CGContext) {
        let hangingScale: CGFloat = 0.86
        let handPoint = CGPoint(x: heroPosition.x, y: heroPosition.y + 41 * hangingScale)

        context.saveGState()
        context.setLineCap(.round)
        context.setShadow(offset: .zero, blur: 5, color: NSColor.white.withAlphaComponent(0.58).cgColor)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(2.1)
        context.move(to: CGPoint(x: heroPosition.x, y: bounds.maxY))
        context.addLine(to: handPoint)
        context.strokePath()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.68).cgColor)
        context.setLineWidth(0.75)
        context.move(to: CGPoint(x: heroPosition.x + 1.7, y: bounds.maxY))
        context.addLine(to: CGPoint(x: handPoint.x + 1.7, y: handPoint.y))
        context.strokePath()
        context.restoreGState()

        context.saveGState()
        context.translateBy(x: heroPosition.x, y: heroPosition.y)
        context.scaleBy(x: hangingScale, y: hangingScale)
        HeroRenderer.draw(style: heroStyle, pose: .hanging)
        context.restoreGState()

        if isPullingHang {
            drawPullReleaseCue(context: context)
        }
    }

    private func drawPullReleaseCue(context: CGContext) {
        let progress = clamp(pullDistance / pullReleaseThreshold, 0, 1)
        let radius = 31 + progress * 8
        context.saveGState()
        context.setLineCap(.round)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.35 + progress * 0.6).cgColor)
        context.setLineWidth(pullReady ? 2.4 : 1.25)
        context.setLineDash(phase: 0, lengths: pullReady ? [] : [4, 4])
        context.strokeEllipse(in: CGRect(
            x: heroPosition.x - radius,
            y: heroPosition.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        if pullReady {
            context.setLineDash(phase: 0, lengths: [])
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                let inner = CGPoint(x: heroPosition.x + cos(angle) * (radius + 4), y: heroPosition.y + sin(angle) * (radius + 4))
                let outer = CGPoint(x: heroPosition.x + cos(angle) * (radius + 11), y: heroPosition.y + sin(angle) * (radius + 11))
                context.move(to: inner)
                context.addLine(to: outer)
                context.strokePath()
            }
        }
        context.restoreGState()
    }

    private func drawWeb(context: CGContext, start hand: CGPoint) {
        let dx = targetPoint.x - hand.x
        let dy = targetPoint.y - hand.y
        let length = max(1, hypot(dx, dy))
        let normal = CGPoint(x: -dy / length, y: dx / length)
        let center = CGPoint(
            x: (hand.x + targetPoint.x) / 2 + normal.x * 2,
            y: (hand.y + targetPoint.y) / 2 + normal.y * 2 - min(10, length * 0.025)
        )

        context.saveGState()
        context.setLineCap(.round)
        context.setShadow(offset: .zero, blur: 6, color: NSColor.white.withAlphaComponent(0.7).cgColor)
        for offset in [-1.2, 1.2] as [CGFloat] {
            context.move(to: CGPoint(x: hand.x + normal.x * offset, y: hand.y + normal.y * offset))
            context.addQuadCurve(
                to: CGPoint(x: targetPoint.x + normal.x * offset, y: targetPoint.y + normal.y * offset),
                control: CGPoint(x: center.x + normal.x * offset, y: center.y + normal.y * offset)
            )
            context.setStrokeColor(NSColor.white.withAlphaComponent(offset < 0 ? 1 : 0.82).cgColor)
            context.setLineWidth(offset < 0 ? 2.1 : 0.9)
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawAnchorWeb(context: CGContext) {
        let radius: CGFloat = 22
        let spokeCount = 10
        let points: [CGPoint] = (0..<spokeCount).map { index in
            let angle = CGFloat(index) * 2 * .pi / CGFloat(spokeCount)
            let wobble = 0.82 + CGFloat((index * 7) % 5) * 0.05
            return CGPoint(x: cos(angle) * radius * wobble, y: sin(angle) * radius * wobble)
        }

        context.saveGState()
        context.translateBy(x: targetPoint.x, y: targetPoint.y)
        context.setShadow(offset: .zero, blur: 6, color: NSColor.white.withAlphaComponent(0.72).cgColor)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.97).cgColor)
        context.setLineWidth(1.05)
        for point in points {
            context.move(to: .zero)
            context.addLine(to: point)
            context.strokePath()
        }
        for ring in [0.34, 0.62, 0.9] as [CGFloat] {
            context.beginPath()
            for (index, point) in points.enumerated() {
                let scaled = CGPoint(x: point.x * ring, y: point.y * ring)
                if index == 0 { context.move(to: scaled) } else { context.addLine(to: scaled) }
            }
            context.closePath()
            context.strokePath()
        }
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: -3, y: -3, width: 6, height: 6))
        context.restoreGState()
    }
}

final class OverlayController {
    private var window: NSWindow?
    private(set) var view: OverlayView?
    private var storedStyle: HeroStyle = .classic
    private var storedHangingIdle = false
    var onHangingReleased: (() -> Void)?

    init() {
        let rawStyle = UserDefaults.standard.integer(forKey: "heroStyle")
        storedStyle = HeroStyle(rawValue: rawStyle) ?? .classic
        storedHangingIdle = UserDefaults.standard.bool(forKey: "hangingIdle")
        rebuildWindow()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildWindow()
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func screenUnion() -> CGRect {
        NSScreen.screens.map(\.frame).reduce(.null) { $0.union($1) }
    }

    private func rebuildWindow() {
        let previousGlobal = window.flatMap { oldWindow in
            view.map { oldWindow.convertPoint(toScreen: $0.heroPosition) }
        } ?? NSEvent.mouseLocation
        window?.orderOut(nil)

        let frame = screenUnion()
        let overlay = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.ignoresMouseEvents = true
        overlay.isReleasedWhenClosed = false
        overlay.level = .floating
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let overlayView = OverlayView(frame: CGRect(origin: .zero, size: frame.size))
        overlayView.heroStyle = storedStyle
        overlayView.onHangingReleased = { [weak self] in
            guard let self else { return }
            self.storedHangingIdle = false
            UserDefaults.standard.set(false, forKey: "hangingIdle")
            self.onHangingReleased?()
        }
        overlay.contentView = overlayView
        overlayView.heroPosition = overlay.convertPoint(fromScreen: previousGlobal)
        overlayView.setHangingIdle(storedHangingIdle)
        overlay.orderFrontRegardless()

        window = overlay
        view = overlayView
    }

    func localPoint(from globalPoint: CGPoint) -> CGPoint? {
        window?.convertPoint(fromScreen: globalPoint)
    }

    func setStyle(_ style: HeroStyle) {
        storedStyle = style
        view?.heroStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: "heroStyle")
    }

    func setEnabled(_ enabled: Bool) {
        view?.isEffectEnabled = enabled
        if !enabled { view?.cancelAim() }
    }

    func setHangingIdle(_ enabled: Bool) {
        storedHangingIdle = enabled
        view?.setHangingIdle(enabled)
        UserDefaults.standard.set(enabled, forKey: "hangingIdle")
    }

    func moveHeroToMouse() {
        guard let point = localPoint(from: NSEvent.mouseLocation) else { return }
        view?.moveHero(to: point)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlay: OverlayController!
    private var globalMonitor: Any?
    private var enabled = true
    private var toggleItem: NSMenuItem!
    private var hangingItem: NSMenuItem!
    private var styleItems: [HeroStyle: NSMenuItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlay = OverlayController()
        setupStatusItem()
        overlay.onHangingReleased = { [weak self] in
            self?.hangingItem.state = .off
        }
        installMouseMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cursorarrow.motionlines", accessibilityDescription: "蛛网小英雄")
            if button.image == nil { button.title = "🕸" }
        }

        let menu = NSMenu()
        let title = NSMenuItem(title: "蛛网小英雄", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        toggleItem = NSMenuItem(title: "启用桌面动画", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = .on
        menu.addItem(toggleItem)

        hangingItem = NSMenuItem(title: "悬挂待机（下拉可挣脱）", action: #selector(toggleHangingIdle), keyEquivalent: "")
        hangingItem.target = self
        hangingItem.state = UserDefaults.standard.bool(forKey: "hangingIdle") ? .on : .off
        menu.addItem(hangingItem)
        menu.addItem(.separator())

        let styleParent = NSMenuItem(title: "角色样式", action: nil, keyEquivalent: "")
        let styleMenu = NSMenu()
        let selected = HeroStyle(rawValue: UserDefaults.standard.integer(forKey: "heroStyle")) ?? .classic
        for style in HeroStyle.allCases {
            let item = NSMenuItem(title: style.title, action: #selector(selectStyle(_:)), keyEquivalent: "")
            item.target = self
            item.tag = style.rawValue
            item.state = style == selected ? .on : .off
            styleMenu.addItem(item)
            styleItems[style] = item
        }
        styleParent.submenu = styleMenu
        menu.addItem(styleParent)

        let relocate = NSMenuItem(title: "把角色移到鼠标位置", action: #selector(relocateHero), keyEquivalent: "")
        relocate.target = self
        menu.addItem(relocate)

        let permission = NSMenuItem(title: "请求辅助功能权限…", action: #selector(requestPermission), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)

        menu.addItem(.separator())

        let note = NSMenuItem(title: "点击仍会传给原来的应用", action: nil, keyEquivalent: "")
        note.isEnabled = false
        menu.addItem(note)

        let quit = NSMenuItem(title: "退出蛛网小英雄", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func installMouseMonitor() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let eventType = event.type
            let point = NSEvent.mouseLocation
            DispatchQueue.main.async { [weak self] in
                self?.handleMouse(eventType, globalPoint: point)
            }
        }
    }

    private func handleMouse(_ type: NSEvent.EventType, globalPoint: CGPoint) {
        guard enabled,
              let point = overlay.localPoint(from: globalPoint),
              let view = overlay.view else { return }
        switch type {
        case .leftMouseDown: view.beginAim(at: point)
        case .leftMouseDragged: view.updateAim(to: point)
        case .leftMouseUp: view.releaseAim(at: point)
        default: break
        }
    }

    @objc private func toggleEnabled() {
        enabled.toggle()
        toggleItem.state = enabled ? .on : .off
        overlay.setEnabled(enabled)
    }

    @objc private func toggleHangingIdle() {
        let shouldHang = hangingItem.state != .on
        hangingItem.state = shouldHang ? .on : .off
        overlay.setHangingIdle(shouldHang)
    }

    @objc private func selectStyle(_ sender: NSMenuItem) {
        guard let style = HeroStyle(rawValue: sender.tag) else { return }
        overlay.setStyle(style)
        for (candidate, item) in styleItems { item.state = candidate == style ? .on : .off }
    }

    @objc private func relocateHero() { overlay.moveHeroToMouse() }

    @objc private func requestPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}

if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--render-preview" {
    do {
        try HeroRenderer.renderPreview(to: CommandLine.arguments[2])
        exit(EXIT_SUCCESS)
    } catch {
        fputs("\(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.run()
