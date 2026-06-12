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

    // Each preset is anchored to its matching system text style so Dynamic Type
    // scales headings like headings and captions like captions (instead of
    // everything scaling relative to .body, which distorted hierarchy at
    // accessibility sizes).
    static var neueTitle: Font { .custom("PPNeueCorp-NormalRegular", size: 28, relativeTo: .title) }
    static var neueTitle2: Font { .custom("PPNeueCorp-NormalRegular", size: 22, relativeTo: .title2) }
    static var neueTitle3: Font { .custom("PPNeueCorp-NormalRegular", size: 20, relativeTo: .title3) }
    static var neueHeadline: Font { .custom("PPNeueCorp-NormalMedium", size: 17, relativeTo: .headline) }
    static var neueSubheadline: Font { .custom("PPNeueCorp-NormalRegular", size: 15, relativeTo: .subheadline) }
    static var neueSubheadlineMedium: Font { .custom("PPNeueCorp-NormalMedium", size: 15, relativeTo: .subheadline) }
    static var neueBody: Font { .custom("PPNeueCorp-NormalRegular", size: 17, relativeTo: .body) }
    static var neueCaption: Font { .custom("PPNeueCorp-NormalRegular", size: 12, relativeTo: .caption) }
    static var neueCaptionMedium: Font { .custom("PPNeueCorp-NormalMedium", size: 12, relativeTo: .caption) }
    static var neueCaption2: Font { .custom("PPNeueCorp-NormalRegular", size: 11, relativeTo: .caption2) }
    static var neueCaption2Medium: Font { .custom("PPNeueCorp-NormalMedium", size: 11, relativeTo: .caption2) }
}
