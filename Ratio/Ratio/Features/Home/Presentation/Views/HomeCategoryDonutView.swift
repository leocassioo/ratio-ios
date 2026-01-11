//
//  HomeCategoryDonutView.swift
//  Ratio
//
//  Created by Codex on 09/01/26.
//

import SwiftUI

struct HomeCategoryDonutView: View {
    let items: [CategorySpendItem]

    var body: some View {
        ZStack {
            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                DonutSegmentShape(startAngle: segment.startAngle, endAngle: segment.endAngle)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
            }
        }
    }

    private var segments: [DonutSegment] {
        let total = items.reduce(0) { $0 + $1.amount }
        var currentAngle: Double = -90
        return items.map { item in
            let fraction = total > 0 ? item.amount / total : 0
            let endAngle = currentAngle + fraction * 360
            defer { currentAngle = endAngle }
            return DonutSegment(
                startAngle: Angle(degrees: currentAngle),
                endAngle: Angle(degrees: endAngle),
                color: item.color
            )
        }
    }
}
