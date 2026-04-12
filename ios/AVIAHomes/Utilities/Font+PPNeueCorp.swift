import SwiftUI

extension Font {
    static func neueCorp(_ size: CGFloat) -> Font {
        .custom("PPNeueCorp-NormalRegular", size: size)
    }

    static func neueCorpMedium(_ size: CGFloat) -> Font {
        .custom("PPNeueCorp-NormalMedium", size: size)
    }

    static func neueCorpUltralight(_ size: CGFloat) -> Font {
        .custom("PPNeueCorp-NormalUltralight", size: size)
    }

    static var neueTitle: Font { .custom("PPNeueCorp-NormalRegular", size: 28) }
    static var neueTitle2: Font { .custom("PPNeueCorp-NormalRegular", size: 22) }
    static var neueTitle3: Font { .custom("PPNeueCorp-NormalRegular", size: 20) }
    static var neueHeadline: Font { .custom("PPNeueCorp-NormalMedium", size: 17) }
    static var neueSubheadline: Font { .custom("PPNeueCorp-NormalRegular", size: 15) }
    static var neueSubheadlineMedium: Font { .custom("PPNeueCorp-NormalMedium", size: 15) }
    static var neueBody: Font { .custom("PPNeueCorp-NormalRegular", size: 17) }
    static var neueCaption: Font { .custom("PPNeueCorp-NormalRegular", size: 12) }
    static var neueCaptionMedium: Font { .custom("PPNeueCorp-NormalMedium", size: 12) }
    static var neueCaption2: Font { .custom("PPNeueCorp-NormalRegular", size: 11) }
    static var neueCaption2Medium: Font { .custom("PPNeueCorp-NormalMedium", size: 11) }
}
