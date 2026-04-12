import UIKit
import SwiftUI
import PlayaDB

extension ThumbnailColors {
    var backgroundColor: UIColor {
        UIColor(red: bgRed, green: bgGreen, blue: bgBlue, alpha: bgAlpha)
    }

    var primaryColor: UIColor {
        UIColor(red: primaryRed, green: primaryGreen, blue: primaryBlue, alpha: primaryAlpha)
    }

    var secondaryColor: UIColor {
        UIColor(red: secondaryRed, green: secondaryGreen, blue: secondaryBlue, alpha: secondaryAlpha)
    }

    var detailColor: UIColor {
        UIColor(red: detailRed, green: detailGreen, blue: detailBlue, alpha: detailAlpha)
    }

    var imageColors: ImageColors {
        ImageColors(brcImageColors)
    }

    var brcImageColors: BRCImageColors {
        BRCImageColors(
            backgroundColor: backgroundColor,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            detailColor: detailColor
        )
    }

    init(objectId: String, brcColors: BRCImageColors) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        brcColors.backgroundColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let bgR = Double(r), bgG = Double(g), bgB = Double(b), bgA = Double(a)

        brcColors.primaryColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let pR = Double(r), pG = Double(g), pB = Double(b), pA = Double(a)

        brcColors.secondaryColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let sR = Double(r), sG = Double(g), sB = Double(b), sA = Double(a)

        brcColors.detailColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let dR = Double(r), dG = Double(g), dB = Double(b), dA = Double(a)

        self.init(
            objectId: objectId,
            bgRed: bgR, bgGreen: bgG, bgBlue: bgB, bgAlpha: bgA,
            primaryRed: pR, primaryGreen: pG, primaryBlue: pB, primaryAlpha: pA,
            secondaryRed: sR, secondaryGreen: sG, secondaryBlue: sB, secondaryAlpha: sA,
            detailRed: dR, detailGreen: dG, detailBlue: dB, detailAlpha: dA
        )
    }
}
