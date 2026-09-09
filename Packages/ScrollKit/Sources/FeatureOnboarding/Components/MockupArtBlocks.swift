import CoreGraphics

/// The four placeholder layouts, laid out in the 228 x 478 pt mock screen space.
/// Coordinates are traced off `Reference/onboarding-slide*.png` (frame interior).
extension MockBlock {
    /// Reader with the verse action sheet up — `Reference/onboarding-slide1-feed.png`.
    static var reader: [MockBlock] {
        var blocks: [MockBlock] = [
            MockBlock(0, 0, 228, 196, 0, .dim),
            MockBlock(16, 34, 26, 26, 13, .wash),
            MockBlock(50, 34, 30, 26, 13, .wash),
            MockBlock(152, 34, 60, 26, 13, .wash),
            MockBlock(88, 68, 52, 52, 12, .wash),
            MockBlock(0, 190, 228, 288, 18, .card),
            MockBlock(106, 196, 16, 3, 1.5, .line),
            MockBlock(12, 206, 46, 22, 11, .wash),
            MockBlock(86, 250, 56, 9, 4.5, .lineStrong),
        ]
        blocks += lines(x: 22, y: 268, widths: [184, 172, 148], height: 6, pitch: 11, centred: true)
        blocks.append(MockBlock(20, 312, 188, 1, 0.5, .line))
        for row in 0 ..< 5 {
            let y = 324 + CGFloat(row) * 30
            blocks.append(MockBlock(20, y, 13, 13, 3, .lineStrong))
            blocks.append(MockBlock(44, y + 3, 78, 8, 4, .lineStrong))
            blocks.append(MockBlock(196, y + 3, 7, 8, 2, .line))
        }
        return blocks
    }

    /// Reading plans — `Reference/onboarding-slide2-plans.png`.
    static var plans: [MockBlock] {
        var blocks: [MockBlock] = [
            MockBlock(0, 0, 228, 30, 0, .wash),
            MockBlock(76, 44, 76, 11, 5, .lineStrong),
            MockBlock(172, 40, 44, 22, 11, .card),
            MockBlock(14, 68, 62, 5, 2.5, .line),
            MockBlock(14, 80, 200, 76, 14, .card),
            MockBlock(22, 88, 52, 52, 8, .dim),
        ]
        blocks += lines(x: 82, y: 92, widths: [104, 122, 118, 96], height: 6, pitch: 11)
        blocks += [
            MockBlock(82, 140, 62, 6, 3, .lineStrong),
            MockBlock(14, 166, 66, 5, 2.5, .line),
            MockBlock(14, 178, 128, 11, 5, .lineStrong),
        ]
        blocks += lines(x: 14, y: 196, widths: [196, 190, 138], height: 6, pitch: 11)
        for column in 0 ..< 2 {
            for row in 0 ..< 2 {
                let x = 14 + CGFloat(column) * 104
                let y = 236 + CGFloat(row) * 124
                blocks.append(MockBlock(x, y, 96, 118, 12, .card))
                blocks.append(MockBlock(x, y, 96, 72, 12, .dark))
                blocks.append(MockBlock(x + 8, y + 82, 62, 8, 4, .lineStrong))
                blocks.append(MockBlock(x + 8, y + 98, 76, 5, 2.5, .line))
            }
        }
        return blocks
    }

    /// Discover feed card — `Reference/onboarding-slide3-discover.png`.
    static var discover: [MockBlock] {
        var blocks: [MockBlock] = [
            MockBlock(14, 12, 200, 46, 16, .card),
            MockBlock(56, 28, 14, 16, 3, .line),
            MockBlock(106, 28, 16, 16, 3, .line),
            MockBlock(158, 28, 14, 16, 3, .line),
            MockBlock(14, 66, 200, 350, 16, .card),
            MockBlock(84, 78, 60, 18, 9, .wash),
            MockBlock(66, 106, 96, 14, 6, .lineStrong),
        ]
        blocks += lines(x: 24, y: 132, widths: [180, 172, 178, 140], height: 6, pitch: 12, centred: true)
        blocks.append(MockBlock(24, 186, 76, 5, 2.5, .line))
        blocks += lines(x: 24, y: 198, widths: [180, 156, 182, 168], height: 7, pitch: 13, tone: .lineStrong)
        blocks.append(MockBlock(22, 254, 184, 62, 10, .wash))
        blocks += lines(x: 30, y: 266, widths: [150, 160, 152], height: 6, pitch: 12, tone: .lineStrong)
        blocks += [
            MockBlock(24, 328, 62, 18, 9, .wash),
            MockBlock(92, 328, 76, 18, 9, .wash),
            MockBlock(80, 358, 64, 7, 3.5, .line),
            MockBlock(56, 384, 14, 16, 3, .line),
            MockBlock(106, 384, 16, 16, 3, .line),
            MockBlock(158, 384, 14, 16, 3, .line),
        ]
        return blocks + tabBar
    }

    /// Verse search and deep study — `Reference/onboarding-slide4-search.png`.
    static var deepStudy: [MockBlock] {
        var blocks: [MockBlock] = [
            MockBlock(14, 12, 200, 296, 16, .card),
            MockBlock(106, 26, 18, 18, 9, .lineStrong),
            MockBlock(70, 54, 90, 14, 6, .lineStrong),
            MockBlock(60, 78, 110, 6, 3, .line),
            MockBlock(66, 96, 34, 8, 4, .line),
            MockBlock(112, 96, 48, 8, 4, .lineStrong),
        ]
        for row in 0 ..< 5 {
            let y = 122 + CGFloat(row) * 22
            let strong = row == 2
            blocks.append(MockBlock(30, y, 70, 10, 5, strong ? .lineStrong : .line))
            blocks.append(MockBlock(122, y, 12, 10, 5, strong ? .lineStrong : .line))
            blocks.append(MockBlock(158, y, 20, 10, 5, strong ? .lineStrong : .line))
        }
        blocks += [
            MockBlock(26, 238, 176, 34, 17, .dark),
            MockBlock(38, 282, 152, 5, 2.5, .line),
            MockBlock(14, 318, 200, 100, 16, .card),
            MockBlock(22, 326, 76, 76, 10, .dim),
            MockBlock(106, 332, 88, 12, 6, .lineStrong),
            MockBlock(106, 352, 70, 8, 4, .lineStrong),
            MockBlock(106, 368, 50, 7, 3.5, .line),
            MockBlock(106, 382, 44, 6, 3, .line),
            MockBlock(22, 408, 180, 6, 3, .wash),
            MockBlock(22, 408, 34, 6, 3, .dark),
        ]
        return blocks + tabBar
    }
}
