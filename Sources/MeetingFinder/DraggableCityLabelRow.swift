import AppKit
import SwiftUI

struct TimeZoneReorderSession: Equatable {
  let cityID: String
  let sourceIndex: Int
  private(set) var translation: CGFloat = 0

  mutating func update(translation: CGFloat, rowHeight: CGFloat, itemCount: Int) {
    guard rowHeight > 0, itemCount > 0 else {
      self.translation = 0
      return
    }

    let minimum = -CGFloat(sourceIndex) * rowHeight
    let maximum = CGFloat(itemCount - sourceIndex - 1) * rowHeight
    self.translation = min(max(translation, minimum), maximum)
  }

  func destinationIndex(rowHeight: CGFloat, itemCount: Int) -> Int {
    guard rowHeight > 0, itemCount > 0 else { return sourceIndex }
    let proposedIndex = sourceIndex + Int((translation / rowHeight).rounded())
    return min(max(proposedIndex, 0), itemCount - 1)
  }

  func offset(
    for candidateCityID: String,
    at candidateIndex: Int,
    rowHeight: CGFloat,
    itemCount: Int
  ) -> CGFloat {
    if candidateCityID == cityID {
      return translation
    }

    let destination = destinationIndex(rowHeight: rowHeight, itemCount: itemCount)
    if destination > sourceIndex,
      candidateIndex > sourceIndex,
      candidateIndex <= destination
    {
      return -rowHeight
    }
    if destination < sourceIndex,
      candidateIndex >= destination,
      candidateIndex < sourceIndex
    {
      return rowHeight
    }
    return 0
  }

  func reordered<Element>(_ items: [Element], rowHeight: CGFloat) -> [Element] {
    guard items.indices.contains(sourceIndex) else { return items }
    let destination = destinationIndex(rowHeight: rowHeight, itemCount: items.count)
    guard destination != sourceIndex else { return items }

    var reorderedItems = items
    let item = reorderedItems.remove(at: sourceIndex)
    reorderedItems.insert(item, at: destination)
    return reorderedItems
  }

  func reorderedIDs(_ ids: [String], rowHeight: CGFloat) -> [String] {
    reordered(ids, rowHeight: rowHeight)
  }
}

enum ReorderPresentation {
  static let selectorLayer: Double = 10
  static let siblingAnimation = Animation.spring(response: 0.16, dampingFraction: 0.92)
  static let settleAnimation = Animation.spring(response: 0.18, dampingFraction: 0.90)

  static func layer(for cityID: String, session: TimeZoneReorderSession?) -> Double {
    session?.cityID == cityID ? 100 : 0
  }

  static func timelineRowsLayer(for session: TimeZoneReorderSession?) -> Double {
    session == nil ? 0 : 20
  }
}

struct DraggableCityLabelRow: View {
  let city: City
  let cityIndex: Int
  let rowHeight: CGFloat
  @ObservedObject var model: MeetingViewModel
  @Binding var reorderSession: TimeZoneReorderSession?

  @State private var isHoveringHandle = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      VStack(spacing: 2) {
        ForEach(0..<3, id: \.self) { _ in
          HStack(spacing: 2) {
            Circle().frame(width: 1.7, height: 1.7)
            Circle().frame(width: 1.7, height: 1.7)
          }
        }
      }
      .foregroundStyle(Color.black.opacity(gripOpacity))
      .frame(width: 14, height: 23)
      .contentShape(Rectangle())
      .gesture(reorderGesture)
      .onContinuousHover { phase in
        switch phase {
        case .active:
          isHoveringHandle = true
          if !isDragging {
            NSCursor.openHand.set()
          }
        case .ended:
          isHoveringHandle = false
          if !isDragging {
            NSCursor.arrow.set()
          }
        }
      }
      .help("Drag to reorder \(city.name)")
      .accessibilityLabel("Reorder \(city.name)")
      .accessibilityAction(named: Text("Move up")) {
        model.moveTimeZone(id: city.id, by: -1)
      }
      .accessibilityAction(named: Text("Move down")) {
        model.moveTimeZone(id: city.id, by: 1)
      }

      Circle()
        .fill(city.color)
        .frame(width: 6.5, height: 6.5)
        .padding(.top, 5)

      VStack(alignment: .leading, spacing: 1) {
        Text(city.name)
          .font(.system(size: 13, weight: .medium, design: .rounded))
          .foregroundStyle(Color(red: 0.12, green: 0.12, blue: 0.13))
          .lineLimit(1)
        Text(city.offsetLabel)
          .font(.system(size: 10.5, weight: .regular, design: .rounded))
          .foregroundStyle(Color.black.opacity(0.40))
      }
    }
    .frame(height: rowHeight, alignment: .topLeading)
    .offset(y: rowOffset)
    .zIndex(ReorderPresentation.layer(for: city.id, session: reorderSession))
    .animation(siblingReorderAnimation, value: reorderDestinationIndex)
    .animation(.easeOut(duration: 0.12), value: isHoveringHandle)
  }

  private var reorderGesture: some Gesture {
    DragGesture(minimumDistance: 2)
      .onChanged { value in
        var session =
          reorderSession?.cityID == city.id
          ? reorderSession!
          : TimeZoneReorderSession(cityID: city.id, sourceIndex: cityIndex)
        session.update(
          translation: value.translation.height,
          rowHeight: rowHeight,
          itemCount: model.state.cities.count
        )
        reorderSession = session
        NSCursor.closedHand.set()
      }
      .onEnded { value in
        var session =
          reorderSession?.cityID == city.id
          ? reorderSession!
          : TimeZoneReorderSession(cityID: city.id, sourceIndex: cityIndex)
        session.update(
          translation: value.translation.height,
          rowHeight: rowHeight,
          itemCount: model.state.cities.count
        )
        let destination = session.destinationIndex(
          rowHeight: rowHeight,
          itemCount: model.state.cities.count
        )
        let moveOffset = destination - session.sourceIndex

        let commitMove = {
          if moveOffset != 0 {
            model.moveTimeZone(id: city.id, by: moveOffset)
          }
          reorderSession = nil
        }

        if reduceMotion {
          commitMove()
        } else {
          withAnimation(ReorderPresentation.settleAnimation) {
            commitMove()
          }
        }

        if isHoveringHandle {
          NSCursor.openHand.set()
        } else {
          NSCursor.arrow.set()
        }
      }
  }

  private var gripOpacity: Double {
    if isDragging { return 0.58 }
    return isHoveringHandle ? 0.44 : 0.18
  }

  private var isDragging: Bool {
    reorderSession?.cityID == city.id
  }

  private var reorderDestinationIndex: Int? {
    reorderSession?.destinationIndex(
      rowHeight: rowHeight,
      itemCount: model.state.cities.count
    )
  }

  private var siblingReorderAnimation: Animation? {
    guard !reduceMotion, !isDragging else { return nil }
    return ReorderPresentation.siblingAnimation
  }

  private var rowOffset: CGFloat {
    reorderSession?.offset(
      for: city.id,
      at: cityIndex,
      rowHeight: rowHeight,
      itemCount: model.state.cities.count
    ) ?? 0
  }
}
