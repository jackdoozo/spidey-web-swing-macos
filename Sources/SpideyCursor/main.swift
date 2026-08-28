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
    case landing
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
    private static let red = NSColor(calibratedRed: 0.94, green: 0.075, blue: 0.13, alpha: 1)
    private static let redLight = NSColor(calibratedRed: 1, green: 0.29, blue: 0.31, alpha: 1)
    private static let redDark = NSColor(calibratedRed: 0.58, green: 0.018, blue: 0.07, alpha: 1)
    private static let blue = NSColor(calibratedRed: 0.045, green: 0.18, blue: 0.56, alpha: 1)
    private static let blueLight = NSColor(calibratedRed: 0.12, green: 0.38, blue: 0.88, alpha: 1)
    private static let blueDark = NSColor(calibratedRed: 0.018, green: 0.07, blue: 0.25, alpha: 1)

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

    private static func gradientFillStroke(_ path: NSBezierPath, colors: [NSColor], angle: CGFloat, width: CGFloat = 2.2) {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSGradient(colors: colors)?.draw(in: path.bounds, angle: angle)
        NSGraphicsContext.restoreGraphicsState()
        ink.setStroke()
        path.lineWidth = width
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
    }

    private static func rounded(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    private static func eye(_ rect: CGRect, mirrored: Bool = false, rotation: CGFloat = 0) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY)
        transform.rotate(byDegrees: rotation)
        if mirrored { transform.scaleX(by: -1, yBy: 1) }
        transform.translateX(by: -rect.midX, yBy: -rect.midY)
        transform.concat()
        let path = NSBezierPath()
        // 参考图眼型：外眼角高、鼻梁侧尖角低，整体是一片向内下方收尖的杏仁叶片。
        let outerTop = CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.02)
        let innerTip = CGPoint(x: rect.maxX - rect.width * 0.01, y: rect.minY + rect.height * 0.2)
        let lowerPoint = CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 0.01)
        let outerBulge = CGPoint(x: rect.minX + rect.width * 0.01, y: rect.minY + rect.height * 0.5)
        path.move(to: outerTop)
        path.curve(
            to: innerTip,
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.maxY + rect.height * 0.015),
            controlPoint2: CGPoint(x: rect.maxX - rect.width * 0.11, y: rect.minY + rect.height * 0.43)
        )
        path.curve(
            to: lowerPoint,
            controlPoint1: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY + rect.height * 0.09),
            controlPoint2: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY - rect.height * 0.015)
        )
        path.curve(
            to: outerBulge,
            controlPoint1: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY - rect.height * 0.005),
            controlPoint2: CGPoint(x: rect.minX - rect.width * 0.015, y: rect.minY + rect.height * 0.26)
        )
        path.curve(
            to: outerTop,
            controlPoint1: CGPoint(x: rect.minX - rect.width * 0.015, y: rect.minY + rect.height * 0.75),
            controlPoint2: CGPoint(x: rect.minX + rect.width * 0.015, y: rect.maxY - rect.height * 0.1)
        )
        path.close()
        // 黑色框是独立的完整形状，白色镜片缩在框内，避免细描边产生“眼镜”感。
        ink.setFill()
        path.fill()
        NSGraphicsContext.saveGraphicsState()
        let lensInset = NSAffineTransform()
        lensInset.translateX(by: rect.midX, yBy: rect.midY)
        lensInset.scaleX(by: 0.72, yBy: 0.75)
        lensInset.translateX(by: -rect.midX, yBy: -rect.midY)
        lensInset.concat()
        NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
        path.fill()
        // 镜片只保留完整白色面，不叠加浅色上沿；浅色描边在小尺寸下会像一条白眉毛。
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func webDetails(center: CGPoint, radius: CGFloat) {
        let spokeCount = 8
        ink.withAlphaComponent(0.48).setStroke()
        for index in 0..<spokeCount {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(spokeCount)
            let path = NSBezierPath()
            path.move(to: center)
            path.line(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
            path.lineWidth = index % 2 == 0 ? 0.82 : 0.62
            path.lineCapStyle = .round
            path.stroke()
        }
        for ring in [0.32, 0.57, 0.82] as [CGFloat] {
            let path = NSBezierPath()
            for index in 0...spokeCount {
                let angle = -CGFloat.pi / 2 + CGFloat(index % spokeCount) * 2 * .pi / CGFloat(spokeCount)
                let ripple = ring * (index % 2 == 0 ? 0.96 : 1.04)
                let point = CGPoint(x: center.x + cos(angle) * radius * ripple, y: center.y + sin(angle) * radius * ripple)
                if index == 0 { path.move(to: point) } else { path.line(to: point) }
            }
            path.close()
            path.lineJoinStyle = .round
            path.lineWidth = 0.55
            path.stroke()
        }
        ink.withAlphaComponent(0.62).setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - 1.25, y: center.y - 1.25, width: 2.5, height: 2.5)).fill()
    }

    private static func drawLimb(from: CGPoint, to: CGPoint, width: CGFloat, color: NSColor, outline: CGFloat = 1.8) {
        let length = pointDistance(from, to)
        guard length > 0.5 else { return }
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: from.x, yBy: from.y)
        transform.rotate(byDegrees: atan2(to.y - from.y, to.x - from.x) * 180 / .pi)
        transform.concat()
        let limb = rounded(CGRect(x: -width * 0.18, y: -width / 2, width: length + width * 0.36, height: width), radius: width / 2)
        let light = color.blended(withFraction: 0.26, of: .white) ?? color
        let dark = color.blended(withFraction: 0.34, of: .black) ?? color
        gradientFillStroke(limb, colors: [light, color, dark], angle: -90, width: outline)
        let highlight = NSBezierPath()
        highlight.move(to: CGPoint(x: width * 0.05, y: width * 0.2))
        highlight.line(to: CGPoint(x: max(width * 0.2, length - width * 0.35), y: width * 0.2))
        NSColor.white.withAlphaComponent(0.16).setStroke()
        highlight.lineWidth = 0.55
        highlight.lineCapStyle = .round
        highlight.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawBoot(at point: CGPoint, angle: CGFloat, scale: CGFloat = 1) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: point.x, yBy: point.y)
        transform.rotate(byDegrees: angle)
        transform.concat()
        let boot = rounded(CGRect(x: -5 * scale, y: -4.2 * scale, width: 13 * scale, height: 8.4 * scale), radius: 4 * scale)
        gradientFillStroke(boot, colors: [redLight, red, redDark], angle: -90, width: 1.55)
        ink.withAlphaComponent(0.52).setStroke()
        let webBand = NSBezierPath()
        webBand.move(to: CGPoint(x: -1.5 * scale, y: -3.2 * scale))
        webBand.curve(to: CGPoint(x: 0.2 * scale, y: 3.2 * scale), controlPoint1: CGPoint(x: 0, y: -1.5 * scale), controlPoint2: CGPoint(x: 0, y: 1.5 * scale))
        webBand.lineWidth = 0.55
        webBand.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawFingerCapsule(from: CGPoint, to: CGPoint, width: CGFloat, color: NSColor) {
        let length = pointDistance(from, to)
        guard length > 0.4 else { return }
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: from.x, yBy: from.y)
        transform.rotate(byDegrees: atan2(to.y - from.y, to.x - from.x) * 180 / .pi)
        transform.concat()
        let finger = rounded(CGRect(x: -width * 0.12, y: -width / 2, width: length + width * 0.24, height: width), radius: width / 2)
        let light = color.blended(withFraction: 0.24, of: .white) ?? color
        let dark = color.blended(withFraction: 0.32, of: .black) ?? color
        gradientFillStroke(finger, colors: [light, color, dark], angle: -90, width: 1.05)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawSplayedHand(at point: CGPoint, angle: CGFloat, scale: CGFloat = 1) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: point.x, yBy: point.y)
        transform.rotate(byDegrees: angle)
        transform.concat()

        // 手指是互相独立的填充轮廓，避免缩小时描边交叉成“麻花”。
        drawFingerCapsule(from: CGPoint(x: 1.4 * scale, y: 2 * scale), to: CGPoint(x: 9.1 * scale, y: 4 * scale), width: 2.35 * scale, color: red)
        drawFingerCapsule(from: CGPoint(x: 2 * scale, y: 0.45 * scale), to: CGPoint(x: 10.2 * scale, y: 0.7 * scale), width: 2.2 * scale, color: red)
        drawFingerCapsule(from: CGPoint(x: 1.5 * scale, y: -1.6 * scale), to: CGPoint(x: 8.8 * scale, y: -3.3 * scale), width: 2.1 * scale, color: red)
        drawFingerCapsule(from: CGPoint(x: -0.8 * scale, y: -2.3 * scale), to: CGPoint(x: 3.2 * scale, y: -6.1 * scale), width: 2.45 * scale, color: red)

        let palm = rounded(CGRect(x: -4.8 * scale, y: -4.1 * scale, width: 10 * scale, height: 8.2 * scale), radius: 3.6 * scale)
        gradientFillStroke(palm, colors: [redLight, red, redDark], angle: -90, width: 1.45)
        ink.withAlphaComponent(0.48).setStroke()
        let palmSeam = NSBezierPath()
        palmSeam.move(to: CGPoint(x: -2.6 * scale, y: 0))
        palmSeam.curve(to: CGPoint(x: 3.2 * scale, y: 0), controlPoint1: CGPoint(x: -0.8 * scale, y: -1.5 * scale), controlPoint2: CGPoint(x: 1.4 * scale, y: -1.5 * scale))
        palmSeam.lineWidth = 0.5 * scale
        palmSeam.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func strokeSuitPath(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        ink.setStroke(); path.lineWidth = width + 3; path.stroke()
        let dark = color.blended(withFraction: 0.34, of: .black) ?? color
        dark.setStroke(); path.lineWidth = width; path.stroke()
        color.setStroke(); path.lineWidth = max(1, width - 1.25); path.stroke()
        NSColor.white.withAlphaComponent(0.14).setStroke()
        path.lineWidth = max(0.5, width * 0.16)
        path.stroke()
    }

    private static func drawContinuousLeg(hip: CGPoint, knee: CGPoint, ankle: CGPoint, foot: CGPoint) {
        func direction(from: CGPoint, to: CGPoint) -> CGPoint {
            let dx = to.x - from.x
            let dy = to.y - from.y
            let length = max(0.001, hypot(dx, dy))
            return CGPoint(x: dx / length, y: dy / length)
        }
        func perpendicular(_ value: CGPoint) -> CGPoint { CGPoint(x: -value.y, y: value.x) }
        func normalized(_ value: CGPoint) -> CGPoint {
            let length = max(0.001, hypot(value.x, value.y))
            return CGPoint(x: value.x / length, y: value.y / length)
        }
        func shifted(_ point: CGPoint, _ normal: CGPoint, _ amount: CGFloat) -> CGPoint {
            CGPoint(x: point.x + normal.x * amount, y: point.y + normal.y * amount)
        }

        let thighDirection = direction(from: hip, to: knee)
        let calfDirection = direction(from: knee, to: ankle)
        let hipNormal = perpendicular(thighDirection)
        let ankleNormal = perpendicular(calfDirection)
        let kneeNormal = normalized(CGPoint(x: hipNormal.x + ankleNormal.x, y: hipNormal.y + ankleNormal.y))
        let thighLength = pointDistance(hip, knee)
        let calfLength = pointDistance(knee, ankle)

        let outerHip = shifted(hip, hipNormal, 4.55)
        let outerThighKnee = shifted(
            CGPoint(x: knee.x - thighDirection.x * 1.45, y: knee.y - thighDirection.y * 1.45),
            hipNormal,
            4.35
        )
        let outerKnee = shifted(knee, kneeNormal, 4.5)
        let outerCalfKnee = shifted(
            CGPoint(x: knee.x + calfDirection.x * 1.55, y: knee.y + calfDirection.y * 1.55),
            ankleNormal,
            4.05
        )
        let outerAnkle = shifted(ankle, ankleNormal, 3.05)
        let innerAnkle = shifted(ankle, ankleNormal, -3.05)
        let innerCalfKnee = shifted(
            CGPoint(x: knee.x + calfDirection.x * 1.55, y: knee.y + calfDirection.y * 1.55),
            ankleNormal,
            -3.55
        )
        let innerKnee = shifted(knee, kneeNormal, -3.8)
        let innerThighKnee = shifted(
            CGPoint(x: knee.x - thighDirection.x * 1.45, y: knee.y - thighDirection.y * 1.45),
            hipNormal,
            -4.05
        )
        let innerHip = shifted(hip, hipNormal, -4.55)

        // 封闭轮廓让大腿、膝盖、小腿和脚踝拥有不同宽度，不再是等宽软管。
        let leg = NSBezierPath()
        leg.move(to: outerHip)
        leg.curve(
            to: outerThighKnee,
            controlPoint1: CGPoint(x: outerHip.x + thighDirection.x * thighLength * 0.42, y: outerHip.y + thighDirection.y * thighLength * 0.42),
            controlPoint2: CGPoint(x: outerThighKnee.x - thighDirection.x * thighLength * 0.18, y: outerThighKnee.y - thighDirection.y * thighLength * 0.18)
        )
        leg.curve(
            to: outerCalfKnee,
            controlPoint1: outerKnee,
            controlPoint2: outerKnee
        )
        leg.curve(
            to: outerAnkle,
            controlPoint1: CGPoint(x: outerCalfKnee.x + calfDirection.x * calfLength * 0.2, y: outerCalfKnee.y + calfDirection.y * calfLength * 0.2),
            controlPoint2: CGPoint(x: outerAnkle.x - calfDirection.x * calfLength * 0.27, y: outerAnkle.y - calfDirection.y * calfLength * 0.27)
        )
        leg.line(to: innerAnkle)
        leg.curve(
            to: innerCalfKnee,
            controlPoint1: CGPoint(x: innerAnkle.x - calfDirection.x * calfLength * 0.24, y: innerAnkle.y - calfDirection.y * calfLength * 0.24),
            controlPoint2: CGPoint(x: innerCalfKnee.x + calfDirection.x * calfLength * 0.18, y: innerCalfKnee.y + calfDirection.y * calfLength * 0.18)
        )
        leg.curve(
            to: innerThighKnee,
            controlPoint1: innerKnee,
            controlPoint2: innerKnee
        )
        leg.curve(
            to: innerHip,
            controlPoint1: CGPoint(x: innerThighKnee.x - thighDirection.x * thighLength * 0.18, y: innerThighKnee.y - thighDirection.y * thighLength * 0.18),
            controlPoint2: CGPoint(x: innerHip.x + thighDirection.x * thighLength * 0.42, y: innerHip.y + thighDirection.y * thighLength * 0.42)
        )
        leg.close()
        gradientFillStroke(leg, colors: [blueLight, blue, blueDark], angle: -72, width: 1.85)

        // 不画圆形膝盖片或横向关节线，只用顺着肌肉方向的低反光表达体积。
        let legHighlight = NSBezierPath()
        let highlightStart = shifted(
            CGPoint(x: hip.x + thighDirection.x * thighLength * 0.22, y: hip.y + thighDirection.y * thighLength * 0.22),
            hipNormal,
            2.35
        )
        let highlightEnd = shifted(
            CGPoint(x: ankle.x - calfDirection.x * calfLength * 0.2, y: ankle.y - calfDirection.y * calfLength * 0.2),
            ankleNormal,
            1.45
        )
        legHighlight.move(to: highlightStart)
        legHighlight.curve(to: outerKnee, controlPoint1: outerThighKnee, controlPoint2: outerThighKnee)
        legHighlight.curve(to: highlightEnd, controlPoint1: outerCalfKnee, controlPoint2: outerCalfKnee)
        NSColor.white.withAlphaComponent(0.13).setStroke()
        legHighlight.lineCapStyle = .round
        legHighlight.lineWidth = 0.72
        legHighlight.stroke()

        let bootDirection = direction(from: ankle, to: foot)
        let bootNormal = perpendicular(bootDirection)
        let toe = CGPoint(x: foot.x + bootDirection.x * 1.65, y: foot.y + bootDirection.y * 1.65)
        let bootTop = CGPoint(x: ankle.x - calfDirection.x * 4.1, y: ankle.y - calfDirection.y * 4.1)
        let boot = NSBezierPath()
        boot.move(to: shifted(bootTop, ankleNormal, 3.35))
        boot.curve(
            to: shifted(foot, bootNormal, 3.0),
            controlPoint1: CGPoint(x: bootTop.x + calfDirection.x * 2.5 + ankleNormal.x * 3.45, y: bootTop.y + calfDirection.y * 2.5 + ankleNormal.y * 3.45),
            controlPoint2: CGPoint(x: foot.x - bootDirection.x * 1.55 + bootNormal.x * 3.15, y: foot.y - bootDirection.y * 1.55 + bootNormal.y * 3.15)
        )
        let toeTop = shifted(toe, bootNormal, 1.75)
        let toeBottom = shifted(toe, bootNormal, -1.75)
        boot.curve(to: toeTop, controlPoint1: shifted(foot, bootNormal, 2.8), controlPoint2: shifted(toeTop, bootNormal, 0.55))
        boot.curve(
            to: toeBottom,
            controlPoint1: CGPoint(x: toeTop.x + bootDirection.x * 0.9, y: toeTop.y + bootDirection.y * 0.9),
            controlPoint2: CGPoint(x: toeBottom.x + bootDirection.x * 0.9, y: toeBottom.y + bootDirection.y * 0.9)
        )
        boot.curve(to: shifted(foot, bootNormal, -2.65), controlPoint1: shifted(toeBottom, bootNormal, -0.5), controlPoint2: shifted(foot, bootNormal, -2.4))
        boot.curve(
            to: shifted(bootTop, ankleNormal, -3.35),
            controlPoint1: CGPoint(x: foot.x - bootDirection.x * 1.1 - bootNormal.x * 2.8, y: foot.y - bootDirection.y * 1.1 - bootNormal.y * 2.8),
            controlPoint2: CGPoint(x: bootTop.x + calfDirection.x * 2.4 - ankleNormal.x * 3.4, y: bootTop.y + calfDirection.y * 2.4 - ankleNormal.y * 3.4)
        )
        boot.close()
        gradientFillStroke(boot, colors: [redLight, red, redDark], angle: -72, width: 1.55)

        ink.withAlphaComponent(0.5).setStroke()
        let ankleBand = NSBezierPath()
        ankleBand.move(to: shifted(bootTop, ankleNormal, -3.05))
        ankleBand.curve(
            to: shifted(bootTop, ankleNormal, 3.05),
            controlPoint1: CGPoint(x: bootTop.x - calfDirection.x * 0.7 - ankleNormal.x * 1.35, y: bootTop.y - calfDirection.y * 0.7 - ankleNormal.y * 1.35),
            controlPoint2: CGPoint(x: bootTop.x - calfDirection.x * 0.7 + ankleNormal.x * 1.35, y: bootTop.y - calfDirection.y * 0.7 + ankleNormal.y * 1.35)
        )
        ankleBand.lineWidth = 0.65
        ankleBand.stroke()
    }

    private static func drawContinuousArm(shoulder: CGPoint, elbow: CGPoint, wrist: CGPoint, handAngle: CGFloat) {
        let arm = NSBezierPath()
        arm.move(to: shoulder)
        arm.curve(
            to: elbow,
            controlPoint1: CGPoint(x: shoulder.x + (elbow.x - shoulder.x) * 0.45, y: shoulder.y + (elbow.y - shoulder.y) * 0.22),
            controlPoint2: CGPoint(x: elbow.x - (elbow.x - shoulder.x) * 0.2, y: elbow.y - (elbow.y - shoulder.y) * 0.15)
        )
        arm.curve(
            to: wrist,
            controlPoint1: CGPoint(x: elbow.x + (wrist.x - elbow.x) * 0.28, y: elbow.y + (wrist.y - elbow.y) * 0.18),
            controlPoint2: CGPoint(x: wrist.x - (wrist.x - elbow.x) * 0.16, y: wrist.y - (wrist.y - elbow.y) * 0.12)
        )
        strokeSuitPath(arm, color: blue, width: 7.8)

        let forearm = NSBezierPath()
        forearm.move(to: elbow)
        forearm.curve(
            to: wrist,
            controlPoint1: CGPoint(x: elbow.x + (wrist.x - elbow.x) * 0.32, y: elbow.y + (wrist.y - elbow.y) * 0.2),
            controlPoint2: CGPoint(x: wrist.x - (wrist.x - elbow.x) * 0.15, y: wrist.y - (wrist.y - elbow.y) * 0.12)
        )
        strokeSuitPath(forearm, color: red, width: 6.8)
        drawSplayedHand(at: wrist, angle: handAngle, scale: 0.76)
    }

    private static func drawSwingGripArm(webAngle: CGFloat) {
        let geometry = armGeometry(style: .classic, webAngle: webAngle)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: geometry.shoulder.x, yBy: geometry.shoulder.y)
        transform.rotate(byDegrees: webAngle * 180 / .pi)
        transform.concat()

        let arm = NSBezierPath()
        arm.move(to: CGPoint(x: -2, y: 0))
        arm.curve(
            to: CGPoint(x: geometry.length - 1, y: 0),
            controlPoint1: CGPoint(x: geometry.length * 0.32, y: 1.5),
            controlPoint2: CGPoint(x: geometry.length * 0.72, y: -1.1)
        )
        strokeSuitPath(arm, color: blue, width: 8.7)

        let forearm = NSBezierPath()
        forearm.move(to: CGPoint(x: geometry.length - 14, y: 0))
        forearm.line(to: CGPoint(x: geometry.length + 1, y: 0))
        strokeSuitPath(forearm, color: red, width: 7.4)

        let cuff = rounded(CGRect(x: geometry.length - 14.8, y: -5.1, width: 4.2, height: 10.2), radius: 1.5)
        gradientFillStroke(cuff, colors: [NSColor.white, NSColor(calibratedWhite: 0.48, alpha: 1)], angle: -90, width: 1)
        let fist = NSBezierPath()
        fist.move(to: CGPoint(x: geometry.length - 1.2, y: -3.8))
        fist.curve(to: CGPoint(x: geometry.length + 2.2, y: -5.1), controlPoint1: CGPoint(x: geometry.length - 0.2, y: -4.8), controlPoint2: CGPoint(x: geometry.length + 1, y: -5.2))
        fist.line(to: CGPoint(x: geometry.length + 6.2, y: -3.2))
        fist.curve(to: CGPoint(x: geometry.length + 7.1, y: 1.1), controlPoint1: CGPoint(x: geometry.length + 7, y: -2.2), controlPoint2: CGPoint(x: geometry.length + 7.4, y: -0.4))
        fist.curve(to: CGPoint(x: geometry.length + 4.8, y: 4.8), controlPoint1: CGPoint(x: geometry.length + 6.9, y: 2.8), controlPoint2: CGPoint(x: geometry.length + 6, y: 4.1))
        fist.curve(to: CGPoint(x: geometry.length, y: 3.7), controlPoint1: CGPoint(x: geometry.length + 3, y: 5.3), controlPoint2: CGPoint(x: geometry.length + 1, y: 4.5))
        fist.close()
        gradientFillStroke(fist, colors: [redLight, red, redDark], angle: -90, width: 1.55)
        ink.withAlphaComponent(0.58).setStroke()
        for y in [-2.15, 0, 2.05] as [CGFloat] {
            let knuckle = NSBezierPath()
            knuckle.move(to: CGPoint(x: geometry.length + 1.2, y: y))
            knuckle.line(to: CGPoint(x: geometry.length + 5.2, y: y * 0.76))
            knuckle.lineWidth = 0.55
            knuckle.stroke()
        }
        let wrappedThumb = NSBezierPath()
        wrappedThumb.move(to: CGPoint(x: geometry.length + 0.5, y: -2.8))
        wrappedThumb.curve(to: CGPoint(x: geometry.length + 4.3, y: -0.8), controlPoint1: CGPoint(x: geometry.length + 2.2, y: -2.6), controlPoint2: CGPoint(x: geometry.length + 3.7, y: -2))
        wrappedThumb.lineWidth = 0.72
        wrappedThumb.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawShadow(width: CGFloat) {
        let path = NSBezierPath(ovalIn: CGRect(x: -width / 2, y: -31, width: width, height: 7))
        NSColor(calibratedWhite: 0, alpha: 0.28).setFill()
        path.fill()
    }

    private static func armGeometry(style: HeroStyle, webAngle: CGFloat, lengthOverride: CGFloat? = nil) -> (shoulder: CGPoint, length: CGFloat, thickness: CGFloat) {
        let side: CGFloat = cos(webAngle) >= 0 ? 1 : -1
        let geometry: (shoulder: CGPoint, length: CGFloat, thickness: CGFloat)
        switch style {
        case .classic:
            geometry = (CGPoint(x: side * 10.5, y: 8), 34, 9)
        case .mochi:
            geometry = (CGPoint(x: side * 12.5, y: 7), 27, 10)
        case .comic:
            geometry = (CGPoint(x: side * 11.5, y: 10), 30, 8.5)
        }
        return (geometry.shoulder, lengthOverride ?? geometry.length, geometry.thickness)
    }

    static func webHandPoint(style: HeroStyle, webAngle: CGFloat, lengthOverride: CGFloat? = nil) -> CGPoint {
        let geometry = armGeometry(style: style, webAngle: webAngle, lengthOverride: lengthOverride)
        // 电影设定中蛛丝从腕部发射口射出，而不是从指尖射出。
        let reach = style == .classic ? geometry.length - 12 : geometry.length + 4
        return CGPoint(
            x: geometry.shoulder.x + cos(webAngle) * reach,
            y: geometry.shoulder.y + sin(webAngle) * reach
        )
    }

    private static func drawFiringArm(style: HeroStyle, webAngle: CGFloat, sleeve: NSColor, glove: NSColor, lengthOverride: CGFloat? = nil) {
        let geometry = armGeometry(style: style, webAngle: webAngle, lengthOverride: lengthOverride)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: geometry.shoulder.x, yBy: geometry.shoulder.y)
        transform.rotate(byDegrees: webAngle * 180 / .pi)
        transform.concat()

        let upperArm = rounded(
            CGRect(x: -3, y: -geometry.thickness / 2, width: geometry.length - 8, height: geometry.thickness),
            radius: geometry.thickness / 2
        )
        if style == .classic {
            gradientFillStroke(upperArm, colors: [blueLight, sleeve, blueDark], angle: -90, width: 1.8)
        } else {
            fillStroke(upperArm, fill: sleeve, width: 1.8)
        }

        let gauntlet = rounded(
            CGRect(x: geometry.length - 15, y: -geometry.thickness * 0.62, width: 13, height: geometry.thickness * 1.24),
            radius: geometry.thickness * 0.45
        )
        if style == .classic {
            gradientFillStroke(gauntlet, colors: [redLight, glove, redDark], angle: -90, width: 1.7)
        } else {
            fillStroke(gauntlet, fill: glove, width: 1.7)
        }

        let cuff = rounded(
            CGRect(x: geometry.length - 15, y: -geometry.thickness * 0.66, width: 4.2, height: geometry.thickness * 1.32),
            radius: 1.6
        )
        gradientFillStroke(cuff, colors: [
            NSColor(calibratedRed: 0.95, green: 0.98, blue: 1, alpha: 1),
            NSColor(calibratedRed: 0.44, green: 0.55, blue: 0.65, alpha: 1)
        ], angle: -90, width: 1.2)

        if style == .classic {
            ink.withAlphaComponent(0.58).setStroke()
            for offset in [0.25, 0.68] as [CGFloat] {
                let band = NSBezierPath()
                let x = geometry.length - 15 + 4.2 * offset
                band.move(to: CGPoint(x: x, y: -geometry.thickness * 0.56))
                band.line(to: CGPoint(x: x, y: geometry.thickness * 0.56))
                band.lineWidth = 0.45
                band.stroke()
            }
        }

        let shooter = NSBezierPath(ovalIn: CGRect(x: geometry.length - 13.8, y: -2.2, width: 3.4, height: 4.4))
        NSColor.white.setFill()
        shooter.fill()
        ink.setStroke()
        shooter.lineWidth = 0.8
        shooter.stroke()

        // 经典射丝手势采用互不交叉的填充指节，不用重叠描边线模拟手指。
        let fingerColor = style == .classic ? red : glove
        drawFingerCapsule(
            from: CGPoint(x: geometry.length - 1.1, y: 2.25),
            to: CGPoint(x: geometry.length + 7.4, y: 5),
            width: 2.35,
            color: fingerColor
        )
        drawFingerCapsule(
            from: CGPoint(x: geometry.length - 1.2, y: -2.3),
            to: CGPoint(x: geometry.length + 5.8, y: -4.9),
            width: 2.05,
            color: fingerColor
        )
        drawFingerCapsule(
            from: CGPoint(x: geometry.length - 3.2, y: -2.5),
            to: CGPoint(x: geometry.length + 0.2, y: -6),
            width: 2.35,
            color: fingerColor
        )

        let palm = rounded(CGRect(x: geometry.length - 7.2, y: -4.5, width: 9.6, height: 9), radius: 4.1)
        if style == .classic {
            gradientFillStroke(palm, colors: [redLight, red, redDark], angle: -90, width: 1.45)
        } else {
            fillStroke(palm, fill: glove, width: 1.45)
        }

        // 扣回掌心的两指用低对比指节面表示，不再叠加第二圈黑色轮廓。
        for y in [-1.35, 0.75] as [CGFloat] {
            let folded = rounded(CGRect(x: geometry.length - 4.4, y: y, width: 4.8, height: 1.55), radius: 0.75)
            redDark.withAlphaComponent(0.82).setFill()
            folded.fill()
            let foldedHighlight = rounded(CGRect(x: geometry.length - 3.9, y: y + 0.75, width: 3.5, height: 0.42), radius: 0.2)
            redLight.withAlphaComponent(0.68).setFill()
            foldedHighlight.fill()
        }

        if style == .classic {
            ink.withAlphaComponent(0.48).setStroke()
            for offset in [-2.6, 0, 2.6] as [CGFloat] {
                let gloveWeb = NSBezierPath()
                gloveWeb.move(to: CGPoint(x: geometry.length - 12, y: 0))
                gloveWeb.line(to: CGPoint(x: geometry.length - 4.5, y: offset))
                gloveWeb.lineWidth = 0.45
                gloveWeb.stroke()
            }
            let gloveRing = NSBezierPath()
            gloveRing.move(to: CGPoint(x: geometry.length - 11.5, y: -3.1))
            gloveRing.curve(to: CGPoint(x: geometry.length - 11.5, y: 3.1), controlPoint1: CGPoint(x: geometry.length - 7.2, y: -1.8), controlPoint2: CGPoint(x: geometry.length - 7.2, y: 1.8))
            gloveRing.lineWidth = 0.42
            gloveRing.stroke()
        }
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

        // 蛛丝固定在并拢的脚踝之间；脚在最上，头在最下，保证倒挂方向真实。
        let innerWeb = NSBezierPath()
        innerWeb.move(to: CGPoint(x: 0, y: 61))
        innerWeb.line(to: CGPoint(x: 0, y: 43))
        NSColor.white.setStroke()
        innerWeb.lineWidth = 2.2
        innerWeb.lineCapStyle = .round
        innerWeb.stroke()

        // 双腿从腰部向两侧屈膝，再回收到中间脚踝，形成倒挂时自然的菱形剪影。
        drawLimb(from: CGPoint(x: -7, y: 22), to: CGPoint(x: -19, y: 33), width: 11.2, color: suitBlue, outline: 1.85)
        drawLimb(from: CGPoint(x: -19, y: 33), to: CGPoint(x: -4.5, y: 47), width: 9.6, color: suitBlue, outline: 1.75)
        drawLimb(from: CGPoint(x: 7, y: 22), to: CGPoint(x: 19, y: 33), width: 11.2, color: suitBlue, outline: 1.85)
        drawLimb(from: CGPoint(x: 19, y: 33), to: CGPoint(x: 4.5, y: 47), width: 9.6, color: suitBlue, outline: 1.75)
        drawBoot(at: CGPoint(x: -4.7, y: 48), angle: 34, scale: 0.9)
        drawBoot(at: CGPoint(x: 4.7, y: 48), angle: 146, scale: 0.9)

        let ankleWrap = NSBezierPath(ovalIn: CGRect(x: -5.8, y: 45.2, width: 11.6, height: 6.2))
        NSColor.white.withAlphaComponent(0.94).setStroke()
        ankleWrap.lineWidth = 1.05
        ankleWrap.stroke()

        // 倒置躯干：上方腰窄、下方肩宽，而不是把一个正立身体放到头顶。
        let torso = NSBezierPath()
        torso.move(to: CGPoint(x: -8, y: 32))
        torso.curve(to: CGPoint(x: -17, y: 13), controlPoint1: CGPoint(x: -11.5, y: 27), controlPoint2: CGPoint(x: -16.5, y: 20))
        torso.curve(to: CGPoint(x: -10, y: 4), controlPoint1: CGPoint(x: -18, y: 8.5), controlPoint2: CGPoint(x: -14, y: 4.5))
        torso.line(to: CGPoint(x: 10, y: 4))
        torso.curve(to: CGPoint(x: 17, y: 13), controlPoint1: CGPoint(x: 14, y: 4.5), controlPoint2: CGPoint(x: 18, y: 8.5))
        torso.curve(to: CGPoint(x: 8, y: 32), controlPoint1: CGPoint(x: 16.5, y: 20), controlPoint2: CGPoint(x: 11.5, y: 27))
        torso.close()
        if style == .classic {
            gradientFillStroke(torso, colors: [blueLight, blue, blueDark], angle: -76, width: 2.25)
        } else {
            fillStroke(torso, fill: suitBlue, width: 2.25)
        }

        let invertedChest = NSBezierPath()
        invertedChest.move(to: CGPoint(x: -7, y: 29))
        invertedChest.curve(to: CGPoint(x: -13.2, y: 9), controlPoint1: CGPoint(x: -9, y: 23.5), controlPoint2: CGPoint(x: -12.7, y: 16))
        invertedChest.curve(to: CGPoint(x: 13.2, y: 9), controlPoint1: CGPoint(x: -5, y: 5.8), controlPoint2: CGPoint(x: 5, y: 5.8))
        invertedChest.curve(to: CGPoint(x: 7, y: 29), controlPoint1: CGPoint(x: 12.7, y: 16), controlPoint2: CGPoint(x: 9, y: 23.5))
        invertedChest.close()
        if style == .classic {
            gradientFillStroke(invertedChest, colors: [redLight, red, redDark], angle: -78, width: 0.85)
        } else {
            suitRed.setFill(); invertedChest.fill()
        }

        NSGraphicsContext.saveGraphicsState()
        let chestRotation = NSAffineTransform()
        chestRotation.translateX(by: 0, yBy: 19)
        chestRotation.rotate(byDegrees: 180)
        chestRotation.translateX(by: 0, yBy: -19)
        chestRotation.concat()
        drawChestSpider(center: CGPoint(x: 0, y: 19), scale: 0.58)
        NSGraphicsContext.restoreGraphicsState()

        // 手臂从下方肩部向上抱住小腿，手掌在蛛丝两侧，强化倒挂受力关系。
        for side in [-1, 1] as [CGFloat] {
            drawLimb(from: CGPoint(x: side * 14, y: 12), to: CGPoint(x: side * 23, y: 24), width: 9.4, color: suitBlue, outline: 1.7)
            drawLimb(from: CGPoint(x: side * 23, y: 24), to: CGPoint(x: side * 8.5, y: 37), width: 8.5, color: suitRed, outline: 1.65)
            let hand = NSBezierPath(ovalIn: CGRect(x: side * 8.5 - 5.25, y: 32.5, width: 10.5, height: 10.5))
            fillStroke(hand, fill: suitRed, width: 1.55)
        }

        let head = NSBezierPath(ovalIn: CGRect(x: -25, y: -38, width: 50, height: 50))
        if style == .classic {
            gradientFillStroke(head, colors: [redLight, red, redDark], angle: -58, width: 3)
        } else {
            fillStroke(head, fill: suitRed, width: 3)
        }

        // 面罩整体旋转 180°：倒挂时眼型与下巴方向也必须倒转。
        NSGraphicsContext.saveGraphicsState()
        let faceRotation = NSAffineTransform()
        faceRotation.translateX(by: 0, yBy: -13)
        faceRotation.rotate(byDegrees: 180)
        faceRotation.translateX(by: 0, yBy: 13)
        faceRotation.concat()
        webDetails(center: CGPoint(x: 0, y: -13), radius: 22)
        eye(CGRect(x: -19.2, y: -23.5, width: 17.5, height: 21.5))
        eye(CGRect(x: 1.7, y: -23.5, width: 17.5, height: 21.5), mirrored: true)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawClassic(pose: HeroPose, webAngle: CGFloat) {
        let firingRight = cos(webAngle) >= 0

        // 每个状态使用独立剪影，小尺寸下仍能一眼分辨动作。
        switch pose {
        case .idle:
            drawShadow(width: 36)
            drawLimb(from: CGPoint(x: -6, y: -5), to: CGPoint(x: -10, y: -24), width: 9.5, color: blue)
            drawLimb(from: CGPoint(x: 6, y: -5), to: CGPoint(x: 11, y: -23), width: 9.5, color: blue)
            drawBoot(at: CGPoint(x: -10, y: -24), angle: 174)
            drawBoot(at: CGPoint(x: 10, y: -23), angle: 6)
            drawLimb(from: CGPoint(x: -11, y: 9), to: CGPoint(x: -19, y: -7), width: 8.5, color: blue)
            drawLimb(from: CGPoint(x: -19, y: -7), to: CGPoint(x: -15, y: -16), width: 8.5, color: red)
            drawLimb(from: CGPoint(x: 11, y: 9), to: CGPoint(x: 19, y: -5), width: 8.5, color: blue)
            drawLimb(from: CGPoint(x: 19, y: -5), to: CGPoint(x: 16, y: -14), width: 8.5, color: red)
        case .firing:
            drawShadow(width: 37)
            drawLimb(from: CGPoint(x: -6, y: -5), to: CGPoint(x: -17, y: -18), width: 9.4, color: blue)
            drawLimb(from: CGPoint(x: 6, y: -5), to: CGPoint(x: 15, y: -18), width: 9.4, color: blue)
            drawBoot(at: CGPoint(x: -17, y: -18), angle: 158)
            drawBoot(at: CGPoint(x: 15, y: -18), angle: 22)
            let braceSide: CGFloat = firingRight ? -1 : 1
            drawLimb(from: CGPoint(x: braceSide * 11, y: 8), to: CGPoint(x: braceSide * 20, y: -2), width: 8.6, color: blue)
            drawLimb(from: CGPoint(x: braceSide * 20, y: -2), to: CGPoint(x: braceSide * 13, y: -11), width: 8.4, color: red)
            drawFiringArm(style: .classic, webAngle: webAngle, sleeve: blue, glove: red)
        case .swinging:
            let motionSide: CGFloat = firingRight ? 1 : -1
            // A2 官方动作骨架：射丝手向前上方、空闲手后下展开、一腿舒展、一腿交叉收起。
            drawContinuousLeg(
                hip: CGPoint(x: motionSide * 5.2, y: -5.5),
                knee: CGPoint(x: motionSide * 18, y: -3.5),
                ankle: CGPoint(x: motionSide * 30, y: 1.5),
                foot: CGPoint(x: motionSide * 36, y: 3.5)
            )
            drawContinuousLeg(
                hip: CGPoint(x: -motionSide * 5.1, y: -6),
                knee: CGPoint(x: motionSide * 1.5, y: -17),
                ankle: CGPoint(x: motionSide * 9.5, y: -24),
                foot: CGPoint(x: motionSide * 14, y: -27.5)
            )
            drawContinuousArm(
                shoulder: CGPoint(x: -motionSide * 10.5, y: 8),
                elbow: CGPoint(x: -motionSide * 21.5, y: 1.5),
                wrist: CGPoint(x: -motionSide * 31, y: -5),
                handAngle: motionSide > 0 ? 205 : -25
            )
            drawFiringArm(style: .classic, webAngle: webAngle, sleeve: blue, glove: red, lengthOverride: 47)
        case .landing:
            drawShadow(width: 62)
            // 5 号参考的低重心蜘蛛式落地：两腿外张、一手撑地、另一手保持平衡。
            drawLimb(from: CGPoint(x: -5, y: -8), to: CGPoint(x: -19, y: -14), width: 10.2, color: blue)
            drawLimb(from: CGPoint(x: -19, y: -14), to: CGPoint(x: -31, y: -24), width: 8.8, color: blue)
            drawBoot(at: CGPoint(x: -31, y: -24), angle: 172, scale: 1.05)
            drawLimb(from: CGPoint(x: 5, y: -8), to: CGPoint(x: 20, y: -13), width: 10.2, color: blue)
            drawLimb(from: CGPoint(x: 20, y: -13), to: CGPoint(x: 33, y: -19), width: 8.8, color: blue)
            drawBoot(at: CGPoint(x: 33, y: -19), angle: 5, scale: 1.05)

            drawLimb(from: CGPoint(x: 10, y: 5), to: CGPoint(x: 18, y: -8), width: 8.6, color: blue)
            drawLimb(from: CGPoint(x: 18, y: -8), to: CGPoint(x: 24, y: -25), width: 8.1, color: red)
            drawSplayedHand(at: CGPoint(x: 24, y: -26), angle: -7, scale: 0.88)

            drawLimb(from: CGPoint(x: -10, y: 7), to: CGPoint(x: -22, y: 12), width: 8.5, color: blue)
            drawLimb(from: CGPoint(x: -22, y: 12), to: CGPoint(x: -31, y: 19), width: 7.9, color: red)
            drawSplayedHand(at: CGPoint(x: -32, y: 19), angle: 176, scale: 0.82)
        case .hanging:
            break
        }

        let torsoY: CGFloat = pose == .landing ? -13 : -11
        let torso = rounded(CGRect(x: -14, y: torsoY, width: 28, height: 30), radius: 11)
        gradientFillStroke(torso, colors: [blueLight, blue, blueDark], angle: -72, width: 2.45)

        // 电影战衣的深蓝侧腹护片和反光滚边。
        for side in [-1, 1] as [CGFloat] {
            let sidePanel = NSBezierPath()
            sidePanel.move(to: CGPoint(x: side * 8.3, y: torsoY + 3))
            sidePanel.curve(
                to: CGPoint(x: side * 10.4, y: torsoY + 24),
                controlPoint1: CGPoint(x: side * 12.6, y: torsoY + 8),
                controlPoint2: CGPoint(x: side * 12.2, y: torsoY + 18)
            )
            sidePanel.line(to: CGPoint(x: side * 7.1, y: torsoY + 21.5))
            sidePanel.curve(to: CGPoint(x: side * 8.3, y: torsoY + 3), controlPoint1: CGPoint(x: side * 8.4, y: torsoY + 14), controlPoint2: CGPoint(x: side * 8.2, y: torsoY + 8))
            sidePanel.close()
            blueDark.withAlphaComponent(0.78).setFill(); sidePanel.fill()
            blueLight.withAlphaComponent(0.68).setStroke(); sidePanel.lineWidth = 0.52; sidePanel.stroke()
        }
        let chest = NSBezierPath()
        chest.move(to: CGPoint(x: -9, y: torsoY + 4))
        chest.curve(to: CGPoint(x: -11, y: torsoY + 24), controlPoint1: CGPoint(x: -10, y: torsoY + 12), controlPoint2: CGPoint(x: -12, y: torsoY + 19))
        chest.curve(to: CGPoint(x: 11, y: torsoY + 24), controlPoint1: CGPoint(x: -3, y: torsoY + 28), controlPoint2: CGPoint(x: 3, y: torsoY + 28))
        chest.curve(to: CGPoint(x: 9, y: torsoY + 4), controlPoint1: CGPoint(x: 12, y: torsoY + 19), controlPoint2: CGPoint(x: 10, y: torsoY + 11))
        chest.close()
        gradientFillStroke(chest, colors: [redLight, red, redDark], angle: -82, width: 1.15)

        let collar = NSBezierPath()
        collar.move(to: CGPoint(x: -7.5, y: torsoY + 23.4))
        collar.curve(to: CGPoint(x: 7.5, y: torsoY + 23.4), controlPoint1: CGPoint(x: -3.2, y: torsoY + 20.8), controlPoint2: CGPoint(x: 3.2, y: torsoY + 20.8))
        ink.withAlphaComponent(0.72).setStroke(); collar.lineWidth = 1.1; collar.stroke()

        // 胸甲蛛网只保留在红色面板内，避免小图标变成噪点。
        ink.withAlphaComponent(0.58).setStroke()
        for x in [-6, -3, 0, 3, 6] as [CGFloat] {
            let seam = NSBezierPath()
            seam.move(to: CGPoint(x: 0, y: torsoY + 23))
            seam.line(to: CGPoint(x: x, y: torsoY + 8))
            seam.lineWidth = x == 0 ? 0.65 : 0.45
            seam.stroke()
        }
        for offset in [15.8, 19.5] as [CGFloat] {
            let chestRing = NSBezierPath()
            chestRing.move(to: CGPoint(x: -8, y: torsoY + offset))
            chestRing.curve(to: CGPoint(x: 8, y: torsoY + offset), controlPoint1: CGPoint(x: -3.3, y: torsoY + offset - 3.1), controlPoint2: CGPoint(x: 3.3, y: torsoY + offset - 3.1))
            chestRing.lineWidth = 0.48
            chestRing.stroke()
        }
        drawChestSpider(center: CGPoint(x: 0, y: torsoY + 12.2), scale: 0.72)

        let belt = NSBezierPath()
        belt.move(to: CGPoint(x: -10, y: torsoY + 4.2))
        belt.curve(to: CGPoint(x: 10, y: torsoY + 4.2), controlPoint1: CGPoint(x: -4, y: torsoY + 1.8), controlPoint2: CGPoint(x: 4, y: torsoY + 1.8))
        NSColor(calibratedRed: 0.35, green: 0.48, blue: 0.88, alpha: 0.68).setStroke()
        belt.lineWidth = 0.62; belt.stroke()

        let headY: CGFloat = pose == .landing ? -0.5 : 6.5
        let head = rounded(CGRect(x: -24.5, y: headY, width: 49, height: 45), radius: 22.5)
        gradientFillStroke(head, colors: [redLight, red, redDark], angle: -58, width: 2.85)
        redDark.withAlphaComponent(0.26).setFill()
        NSBezierPath(ovalIn: CGRect(x: 10, y: headY + 6, width: 10, height: 27)).fill()
        let maskCenter = CGPoint(x: 0, y: headY + 22)
        webDetails(center: maskCenter, radius: 19)
        eye(CGRect(x: -19.2, y: headY + 11.5, width: 17.5, height: 21.5))
        eye(CGRect(x: 1.7, y: headY + 11.5, width: 17.5, height: 21.5), mirrored: true)
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
        eye(CGRect(x: 3, y: 20, width: 13, height: 18), mirrored: true, rotation: 5)
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
        eye(CGRect(x: 4, y: 25, width: 11, height: 17), mirrored: true, rotation: 14)
        NSGraphicsContext.restoreGraphicsState()
    }

    static func renderPreview(to path: String) throws {
        let size = CGSize(width: 1440, height: 350)
        let image = NSImage(size: size)
        image.lockFocus()

        let background = NSBezierPath(roundedRect: CGRect(origin: .zero, size: size), xRadius: 28, yRadius: 28)
        NSColor(calibratedRed: 0.035, green: 0.035, blue: 0.09, alpha: 1).setFill()
        background.fill()

        let title = "蛛网小英雄 · 精细电影战衣版"
        title.draw(at: CGPoint(x: 36, y: 298), withAttributes: [
            .font: NSFont.systemFont(ofSize: 25, weight: .bold),
            .foregroundColor: NSColor.white
        ])
        "截图同款窄长尖角镜片 · A2 射丝摆荡骨架 · 蜘蛛式落地".draw(
            at: CGPoint(x: 36, y: 273),
            withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.white.withAlphaComponent(0.62)]
        )

        let poses: [HeroPose] = [.idle, .firing, .swinging, .landing, .hanging]
        let labels = ["萌系待机", "手腕射丝", "A2 射丝摆荡", "蜘蛛式落地", "悬挂待机"]
        for index in poses.indices {
            let cardX = CGFloat(28 + index * 280)
            let cardY: CGFloat = 30
            let cardWidth: CGFloat = 264
            let card = NSBezierPath(roundedRect: CGRect(x: cardX, y: cardY, width: cardWidth, height: 225), xRadius: 22, yRadius: 22)
            NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.18, alpha: 1).setFill()
            card.fill()
            NSColor(calibratedRed: 0.25, green: 0.3, blue: 0.6, alpha: 0.55).setStroke()
            card.lineWidth = 1.2
            card.stroke()

            NSGraphicsContext.saveGraphicsState()
            let context = NSGraphicsContext.current!.cgContext
            let pose = poses[index]
            let isHangingCard = pose == .hanging
            context.translateBy(x: cardX + cardWidth / 2, y: cardY + (isHangingCard ? 107 : 115))
            context.scaleBy(x: isHangingCard ? 1.68 : 1.95, y: isHangingCard ? 1.68 : 1.95)
            if isHangingCard {
                context.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
                context.setLineWidth(1.7)
                context.move(to: CGPoint(x: 0, y: 72))
                context.addLine(to: CGPoint(x: 0, y: 42))
                context.strokePath()
                draw(style: .classic, pose: .hanging)
            } else {
                if pose == .firing || pose == .swinging {
                    let hand = webHandPoint(
                        style: .classic,
                        webAngle: .pi / 3.2,
                        lengthOverride: pose == .swinging ? 47 : nil
                    )
                    context.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
                    context.setLineWidth(1.5)
                    context.move(to: hand)
                    context.addLine(to: CGPoint(x: 55, y: 68))
                    context.strokePath()
                }
                draw(style: .classic, pose: pose, webAngle: .pi / 3.2)
            }
            NSGraphicsContext.restoreGraphicsState()

            let label = labels[index]
            let labelWidth = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .semibold)]).width
            label.draw(at: CGPoint(x: cardX + (cardWidth - labelWidth) / 2, y: cardY + 20), withAttributes: [
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

    static func renderAppIcon(to path: String) throws {
        let size = CGSize(width: 1024, height: 1024)
        let image = NSImage(size: size)
        image.lockFocus()

        let tile = NSBezierPath(roundedRect: CGRect(x: 42, y: 42, width: 940, height: 940), xRadius: 218, yRadius: 218)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.035, green: 0.045, blue: 0.16, alpha: 1),
            NSColor(calibratedRed: 0.12, green: 0.08, blue: 0.3, alpha: 1)
        ])!
        gradient.draw(in: tile, angle: -55)
        NSColor(calibratedRed: 0.3, green: 0.42, blue: 1, alpha: 0.45).setStroke()
        tile.lineWidth = 18
        tile.stroke()

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext.current!.cgContext
        context.translateBy(x: 512, y: 535)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.13).cgColor)
        context.setLineWidth(7)
        for index in 0..<12 {
            let angle = CGFloat(index) * 2 * .pi / 12
            context.move(to: .zero)
            context.addLine(to: CGPoint(x: cos(angle) * 390, y: sin(angle) * 390))
            context.strokePath()
        }
        for radius in [118, 230, 350] as [CGFloat] {
            context.strokeEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        }
        context.scaleBy(x: 9.1, y: 9.1)
        draw(style: .classic, pose: .idle)
        NSGraphicsContext.restoreGraphicsState()

        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SpideyCursor", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法生成应用图标"])
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
                let color = index.isMultiple(of: 2)
                    ? NSColor(calibratedRed: 1, green: 0.16, blue: 0.28, alpha: to.life * 0.24)
                    : NSColor(calibratedRed: 0.18, green: 0.42, blue: 1, alpha: to.life * 0.2)
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(1.5 + to.life * 2.2)
                context.move(to: from.point)
                context.addLine(to: to.point)
                context.strokePath()
            }
            context.restoreGState()
        }

        let idlePhase = CGFloat(CACurrentMediaTime().truncatingRemainder(dividingBy: 2.4) / 2.4) * 2 * .pi
        let idleBob = mode == .idle ? sin(idlePhase) * 0.7 : 0
        let renderPosition = CGPoint(x: heroPosition.x, y: heroPosition.y + idleBob)
        let heroRotation = heroAngle * .pi / 180
        let webDelta = CGPoint(x: targetPoint.x - heroPosition.x, y: targetPoint.y - heroPosition.y)
        let worldWebAngle: CGFloat = hypot(webDelta.x, webDelta.y) > 1
            ? atan2(webDelta.y, webDelta.x)
            : .pi / 3
        let localWebAngle = worldWebAngle - heroRotation
        let displayScale = heroScale * 0.75
        let swingArmLength: CGFloat? = mode == .swinging && heroStyle == .classic ? 47 : nil
        let localHand = HeroRenderer.webHandPoint(style: heroStyle, webAngle: localWebAngle, lengthOverride: swingArmLength)
        let scaledHand = CGPoint(x: localHand.x * displayScale, y: localHand.y * displayScale)
        let worldHand = CGPoint(
            x: renderPosition.x + scaledHand.x * cos(heroRotation) - scaledHand.y * sin(heroRotation),
            y: renderPosition.y + scaledHand.x * sin(heroRotation) + scaledHand.y * cos(heroRotation)
        )

        if mode == .aiming || mode == .swinging {
            drawWeb(context: context, start: worldHand)
            drawAnchorWeb(context: context)
            if mode == .aiming { drawWristFlash(context: context, at: worldHand, angle: worldWebAngle) }
        } else if mode == .landing {
            drawLandingBurst(context: context)
        }

        context.saveGState()
        context.translateBy(x: renderPosition.x, y: renderPosition.y)
        context.rotate(by: heroRotation)
        context.scaleBy(x: displayScale, y: displayScale)
        let pose: HeroPose
        switch mode {
        case .aiming: pose = .firing
        case .swinging: pose = .swinging
        case .landing: pose = .landing
        case .idle: pose = .idle
        }
        HeroRenderer.draw(style: heroStyle, pose: pose, webAngle: localWebAngle)
        context.restoreGState()
    }

    private func drawHangingIdle(context: CGContext) {
        let hangingScale: CGFloat = 0.86
        let handPoint = CGPoint(x: heroPosition.x, y: heroPosition.y + 49 * hangingScale)

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

        // 两股主丝之间加入细小横向连接，形成编织蛛丝，而不是一根发光直线。
        for sample in stride(from: CGFloat(0.14), through: 0.88, by: 0.105) {
            let point = quadratic(hand, center, targetPoint, sample)
            let tangent = CGPoint(
                x: 2 * (1 - sample) * (center.x - hand.x) + 2 * sample * (targetPoint.x - center.x),
                y: 2 * (1 - sample) * (center.y - hand.y) + 2 * sample * (targetPoint.y - center.y)
            )
            let tangentLength = max(1, hypot(tangent.x, tangent.y))
            let sampleNormal = CGPoint(x: -tangent.y / tangentLength, y: tangent.x / tangentLength)
            let halfWidth: CGFloat = sample.truncatingRemainder(dividingBy: 0.21) < 0.105 ? 2.7 : 2.1
            context.move(to: CGPoint(x: point.x - sampleNormal.x * halfWidth, y: point.y - sampleNormal.y * halfWidth))
            context.addLine(to: CGPoint(x: point.x + sampleNormal.x * halfWidth, y: point.y + sampleNormal.y * halfWidth))
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.72).cgColor)
            context.setLineWidth(0.72)
            context.strokePath()
        }

        let pulse = CGFloat(CACurrentMediaTime().truncatingRemainder(dividingBy: 0.8) / 0.8)
        let pulsePoint = quadratic(hand, center, targetPoint, pulse)
        context.setShadow(offset: .zero, blur: 7, color: NSColor.white.cgColor)
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: pulsePoint.x - 1.8, y: pulsePoint.y - 1.8, width: 3.6, height: 3.6))
        context.restoreGState()
    }

    private func drawWristFlash(context: CGContext, at point: CGPoint, angle: CGFloat) {
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: angle)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.88).cgColor)
        context.setLineCap(.round)
        for index in 0..<5 {
            let ray = CGFloat(index - 2) * 0.22
            context.setLineWidth(index == 2 ? 1.7 : 0.85)
            context.move(to: CGPoint(x: 1.5, y: 0))
            context.addLine(to: CGPoint(x: 8 + CGFloat(abs(index - 2)), y: ray * 11))
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawLandingBurst(context: CGContext) {
        let progress = clamp(CGFloat((CACurrentMediaTime() - startedAt) / max(duration, 0.01)), 0, 1)
        let alpha = pow(1 - progress, 2)
        let radius = 12 + progress * 28
        context.saveGState()
        context.translateBy(x: heroPosition.x, y: heroPosition.y - 17)
        context.setStrokeColor(NSColor.white.withAlphaComponent(alpha * 0.82).cgColor)
        context.setLineCap(.round)
        for index in 0..<10 {
            let angle = CGFloat(index) * 2 * .pi / 10
            let inner = CGPoint(x: cos(angle) * radius * 0.55, y: sin(angle) * radius * 0.32)
            let outer = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.56)
            context.setLineWidth(index.isMultiple(of: 2) ? 1.6 : 0.8)
            context.move(to: inner)
            context.addLine(to: outer)
            context.strokePath()
        }
        context.setLineWidth(0.9)
        context.strokeEllipse(in: CGRect(x: -radius * 0.7, y: -radius * 0.26, width: radius * 1.4, height: radius * 0.52))
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
        for index in stride(from: 0, to: spokeCount, by: 2) {
            let point = points[index]
            context.fillEllipse(in: CGRect(x: point.x - 1.7, y: point.y - 1.7, width: 3.4, height: 3.4))
        }
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

    private func makeMenuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let mask = NSBezierPath(ovalIn: CGRect(x: 2.3, y: 1.4, width: 13.4, height: 15.2))
            NSColor.black.setFill()
            mask.fill()

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            let leftEye = NSBezierPath()
            leftEye.move(to: CGPoint(x: 4.2, y: 10.7))
            leftEye.curve(to: CGPoint(x: 8, y: 12.7), controlPoint1: CGPoint(x: 5.2, y: 12.7), controlPoint2: CGPoint(x: 6.8, y: 13.3))
            leftEye.curve(to: CGPoint(x: 4.2, y: 10.7), controlPoint1: CGPoint(x: 7.9, y: 8.8), controlPoint2: CGPoint(x: 5.5, y: 8.1))
            leftEye.fill()
            let rightEye = NSBezierPath()
            rightEye.move(to: CGPoint(x: 13.8, y: 10.7))
            rightEye.curve(to: CGPoint(x: 10, y: 12.7), controlPoint1: CGPoint(x: 12.8, y: 12.7), controlPoint2: CGPoint(x: 11.2, y: 13.3))
            rightEye.curve(to: CGPoint(x: 13.8, y: 10.7), controlPoint1: CGPoint(x: 10.1, y: 8.8), controlPoint2: CGPoint(x: 12.5, y: 8.1))
            rightEye.fill()
            NSGraphicsContext.restoreGraphicsState()

            NSColor.black.withAlphaComponent(0.72).setStroke()
            for x in [6.3, 9, 11.7] as [CGFloat] {
                let web = NSBezierPath()
                web.move(to: CGPoint(x: 9, y: 9.2))
                web.line(to: CGPoint(x: x, y: 15.2))
                web.lineWidth = 0.55
                web.stroke()
            }
            let ring = NSBezierPath(ovalIn: CGRect(x: 5.1, y: 6.3, width: 7.8, height: 6.4))
            ring.lineWidth = 0.5
            ring.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "蛛网小英雄"
        return image
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = makeMenuBarIcon()
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        let title = NSMenuItem(title: "蛛网小英雄", action: nil, keyEquivalent: "")
        title.isEnabled = false
        title.image = makeMenuBarIcon()
        menu.addItem(title)

        toggleItem = NSMenuItem(title: "启用桌面动画", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = .on
        toggleItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        menu.addItem(toggleItem)

        hangingItem = NSMenuItem(title: "悬挂待机（下拉可挣脱）", action: #selector(toggleHangingIdle), keyEquivalent: "")
        hangingItem.target = self
        hangingItem.state = UserDefaults.standard.bool(forKey: "hangingIdle") ? .on : .off
        hangingItem.image = NSImage(systemSymbolName: "arrow.down.to.line.compact", accessibilityDescription: nil)
        menu.addItem(hangingItem)
        menu.addItem(.separator())

        let styleParent = NSMenuItem(title: "角色样式", action: nil, keyEquivalent: "")
        styleParent.image = NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: nil)
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
        relocate.image = NSImage(systemSymbolName: "scope", accessibilityDescription: nil)
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
} else if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--render-app-icon" {
    do {
        try HeroRenderer.renderAppIcon(to: CommandLine.arguments[2])
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
