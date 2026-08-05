import AppKit
import SwiftUI

enum TimelineMetrics {
  static let labelHeight: CGFloat = 24
  static let rowHeight: CGFloat = 34
  static let rowGap: CGFloat = 6
  static let hourGap: CGFloat = 3.5
  static let timeLabelGap: CGFloat = 10
  static let cardVerticalPadding: CGFloat = 28

  static func rowHeight(for _: Int) -> CGFloat {
    rowHeight
  }

  static func cellHeight(for cityCount: Int) -> CGFloat {
    rowHeight(for: cityCount) - rowGap
  }

  static func availableHeight(for cityCount: Int) -> CGFloat {
    labelHeight + (CGFloat(cityCount) * rowHeight(for: cityCount))
  }

  static func cardHeight(for cityCount: Int) -> CGFloat {
    availableHeight(for: cityCount) + cardVerticalPadding
  }
}

enum MeetingFinderLayout {
  static let cardWidth: CGFloat = 540
  static let headerHeight: CGFloat = 52
  static let footerHeight: CGFloat = 52
  static let panelPadding: CGFloat = 16

  static func cardSize(for cityCount: Int) -> CGSize {
    CGSize(
      width: cardWidth,
      height: headerHeight + TimelineMetrics.cardHeight(for: cityCount) + footerHeight
    )
  }

  static func panelSize(for cityCount: Int) -> CGSize {
    let cardSize = cardSize(for: cityCount)
    return CGSize(
      width: cardSize.width + (panelPadding * 2),
      height: cardSize.height + (panelPadding * 2)
    )
  }

  static func panelFrame(preservingTopOf currentFrame: CGRect, for cityCount: Int) -> CGRect {
    let size = panelSize(for: cityCount)
    return CGRect(
      x: currentFrame.minX,
      y: currentFrame.maxY - size.height,
      width: size.width,
      height: size.height
    )
  }
}

struct MeetingFinderView: View {
  @ObservedObject var model: MeetingViewModel
  @State private var isShowingTimeZonePicker: Bool
  @State private var reorderSession: TimeZoneReorderSession?

  init(model: MeetingViewModel) {
    self.model = model
    _isShowingTimeZonePicker = State(initialValue: false)
  }

  var body: some View {
    let cityCount = model.state.cities.count
    let cardSize = MeetingFinderLayout.cardSize(for: cityCount)

    VStack(spacing: 0) {
      header
        .frame(height: MeetingFinderLayout.headerHeight)

      timelineCard
        .padding(.horizontal, 12)

      footer
        .frame(height: MeetingFinderLayout.footerHeight)
    }
    .frame(width: cardSize.width, height: cardSize.height)
    .background(Color(red: 0.935, green: 0.935, blue: 0.94))
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .strokeBorder(Color.black.opacity(0.032), lineWidth: 0.5)
    }
    .shadow(color: Color.black.opacity(0.035), radius: 2, x: 0, y: 1)
    .shadow(color: Color.black.opacity(0.085), radius: 16, x: 0, y: 8)
    .animation(.easeInOut(duration: 0.2), value: cityCount)
    .environment(\.colorScheme, .light)
    .onReceive(NotificationCenter.default.publisher(for: .showTimeZonePicker)) { _ in
      isShowingTimeZonePicker = true
    }
    .onReceive(NotificationCenter.default.publisher(for: .hideTimeZonePicker)) { _ in
      isShowingTimeZonePicker = false
    }
  }

  private var header: some View {
    HStack {
      Text("Zonely")
        .font(.system(size: 17, weight: .semibold, design: .rounded))
        .foregroundStyle(Color(red: 0.07, green: 0.07, blue: 0.08))

      Button {
        isShowingTimeZonePicker.toggle()
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(Color.black.opacity(0.62))
          .frame(width: 23, height: 23)
          .background(Color.white.opacity(0.72), in: Circle())
      }
      .buttonStyle(.plain)
      .help("Add or remove time zones")
      .accessibilityLabel("Manage time zones")
      .popover(isPresented: $isShowingTimeZonePicker, arrowEdge: .bottom) {
        TimeZonePickerView(model: model)
      }

      Spacer()

      Text(String(format: "%02d:00 UTC", model.state.selectedUTCHour))
        .font(.system(size: 12.5, weight: .regular, design: .monospaced))
        .foregroundStyle(Color(red: 0.27, green: 0.27, blue: 0.31))
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Color.black.opacity(0.045), in: Capsule())
        .contentTransition(.numericText())
    }
    .padding(.horizontal, 24)
    .padding(.top, 2)
  }

  private var timelineCard: some View {
    let availableHeight = TimelineMetrics.availableHeight(for: model.state.cities.count)

    return HStack(alignment: .top, spacing: 0) {
      cityLabels
        .frame(width: 124, alignment: .leading)

      TimelineGrid(model: model, reorderSession: reorderSession)
        .frame(width: 300, height: availableHeight)
        .padding(.trailing, TimelineMetrics.timeLabelGap)

      selectedTimeLabels
        .frame(width: 64, height: availableHeight, alignment: .topLeading)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 14)
    .frame(height: TimelineMetrics.cardHeight(for: model.state.cities.count))
    .background(Color.white.opacity(0.96))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private var cityLabels: some View {
    VStack(alignment: .leading, spacing: 0) {
      Color.clear.frame(height: 24)

      ForEach(Array(model.state.cities.enumerated()), id: \.element.id) { index, city in
        DraggableCityLabelRow(
          city: city,
          cityIndex: index,
          rowHeight: cityRowHeight,
          model: model,
          reorderSession: $reorderSession
        )
      }
    }
  }

  private var selectedTimeLabels: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("UTC")
        .font(.system(size: 10.5, weight: .regular, design: .monospaced))
        .foregroundStyle(Color.black.opacity(0.42))
        .frame(height: 24, alignment: .topLeading)

      ForEach(Array(model.state.cities.enumerated()), id: \.element.id) { index, city in
        let time = city.localTime(
          at: model.state.selectedUTCHour,
          on: model.state.referenceDate
        )
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(time.label)
            .font(.system(size: 12.5, weight: .regular, design: .monospaced))
            .foregroundStyle(time.isWorkingHour ? city.color : Color.black.opacity(0.46))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .contentTransition(.numericText())
          if let dayLabel = time.dayLabel {
            Text(dayLabel)
              .font(.system(size: 9, weight: .regular, design: .monospaced))
              .foregroundStyle(Color.black.opacity(0.36))
              .lineLimit(1)
              .fixedSize(horizontal: true, vertical: false)
          }
        }
        .frame(height: cityRowHeight, alignment: .topLeading)
        .offset(y: reorderOffset(for: city, at: index))
        .zIndex(reorderSession?.cityID == city.id ? 10 : 0)
        .animation(
          reorderSession?.cityID == city.id ? nil : .easeInOut(duration: 0.16),
          value: reorderDestinationIndex
        )
      }
    }
  }

  private var cityRowHeight: CGFloat {
    TimelineMetrics.rowHeight(for: model.state.cities.count)
  }

  private var reorderDestinationIndex: Int? {
    reorderSession?.destinationIndex(
      rowHeight: cityRowHeight,
      itemCount: model.state.cities.count
    )
  }

  private func reorderOffset(for city: City, at index: Int) -> CGFloat {
    reorderSession?.offset(
      for: city.id,
      at: index,
      rowHeight: cityRowHeight,
      itemCount: model.state.cities.count
    ) ?? 0
  }

  private var footer: some View {
    HStack(spacing: 0) {
      HStack(spacing: 8) {
        Circle()
          .fill(
            model.state.worksForEveryone
              ? Color(red: 0.18, green: 0.79, blue: 0.49) : Color.black.opacity(0.14)
          )
          .frame(width: 7, height: 7)

        Text(model.state.summary)
          .font(.system(size: 12.5, weight: .medium, design: .rounded))
          .foregroundStyle(
            model.state.worksForEveryone
              ? Color(red: 0.02, green: 0.52, blue: 0.30) : Color.black.opacity(0.57)
          )
          .contentTransition(.numericText())
      }
      .padding(.horizontal, model.state.worksForEveryone ? 10 : 0)
      .frame(height: 30)
      .background {
        if model.state.worksForEveryone {
          Capsule().fill(Color(red: 0.91, green: 1.0, blue: 0.95))
        }
      }

      Spacer(minLength: 8)

      Button {
        withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
          model.findBestTime()
        }
      } label: {
        HStack(spacing: 7) {
          Image(systemName: "clock")
            .font(.system(size: 11, weight: .semibold))
          Text("Find best time")
            .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 13)
        .frame(height: 30)
        .background(Color(red: 0.06, green: 0.06, blue: 0.07), in: Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityHint("Selects the time that is within working hours in every city")
    }
    .padding(.horizontal, 24)
    .padding(.top, 1)
  }
}

extension Notification.Name {
  static let showTimeZonePicker = Notification.Name("Zonely.showTimeZonePicker")
  static let hideTimeZonePicker = Notification.Name("Zonely.hideTimeZonePicker")
}

private struct TimelineGrid: View {
  @ObservedObject var model: MeetingViewModel
  let reorderSession: TimeZoneReorderSession?
  @State private var dragPositionX: CGFloat?
  @State private var isPointerInsideGrid = false

  private let labelHeight = TimelineMetrics.labelHeight
  private let cellGap = TimelineMetrics.hourGap
  private let rowGap = TimelineMetrics.rowGap
  private let gridWidth: CGFloat = 300

  private var cellWidth: CGFloat {
    (gridWidth - (23 * cellGap)) / 24
  }

  private var cellHeight: CGFloat {
    TimelineMetrics.cellHeight(for: model.state.cities.count)
  }

  private var rowHeight: CGFloat {
    TimelineMetrics.rowHeight(for: model.state.cities.count)
  }

  var body: some View {
    GeometryReader { _ in
      ZStack(alignment: .topLeading) {
        hourLabels

        VStack(spacing: rowGap) {
          ForEach(Array(model.state.cities.enumerated()), id: \.element.id) { index, city in
            HStack(spacing: cellGap) {
              ForEach(0..<24, id: \.self) { hour in
                RoundedRectangle(cornerRadius: 3.2, style: .continuous)
                  .fill(cellColor(city: city, hour: hour))
                  .frame(width: cellWidth, height: cellHeight)
              }
            }
            .offset(y: reorderOffset(for: city, at: index))
            .zIndex(reorderSession?.cityID == city.id ? 10 : 0)
            .animation(
              reorderSession?.cityID == city.id ? nil : .easeInOut(duration: 0.16),
              value: reorderDestinationIndex
            )
          }
        }
        .offset(y: labelHeight)

        selectionIndicator
          .offset(x: selectionX, y: 0)
      }
      .contentShape(Rectangle())
      .coordinateSpace(name: "timelineGrid")
      .highPriorityGesture(dragGesture)
      .onContinuousHover { phase in
        switch phase {
        case .active:
          isPointerInsideGrid = true
          NSCursor.resizeLeftRight.set()
        case .ended:
          isPointerInsideGrid = false
          NSCursor.arrow.set()
        }
      }
      .onDisappear {
        NSCursor.arrow.set()
      }
    }
  }

  private var hourLabels: some View {
    ZStack(alignment: .topLeading) {
      ForEach([0, 6, 12, 18], id: \.self) { hour in
        Text(String(format: "%02d", hour))
          .font(.system(size: 10.5, weight: .regular, design: .monospaced))
          .foregroundStyle(Color.black.opacity(0.42))
          .position(x: xCenter(for: hour), y: 6)
      }
    }
    .frame(width: gridWidth, height: labelHeight)
  }

  private var selectionIndicator: some View {
    let indicatorHeight = CGFloat(model.state.cities.count) * rowHeight
    return ZStack(alignment: .top) {
      selectorGlassSurface(height: indicatorHeight)
        .offset(y: 20)

      Capsule()
        .fill(handleColor)
        .frame(width: 18, height: 4.5)
        .shadow(color: handleColor.opacity(0.22), radius: 2, y: 1)
    }
    .frame(
      width: cellWidth + 7,
      height: TimelineMetrics.availableHeight(for: model.state.cities.count),
      alignment: .top
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Selected UTC time")
    .accessibilityValue(String(format: "%02d:00", model.state.selectedUTCHour))
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: model.select(hour: min(23, model.state.selectedUTCHour + 1))
      case .decrement: model.select(hour: max(0, model.state.selectedUTCHour - 1))
      @unknown default: break
      }
    }
  }

  private var selectionX: CGFloat {
    selectionCenterX - ((cellWidth + 7) / 2)
  }

  private var selectionCenterX: CGFloat {
    dragPositionX ?? xCenter(for: model.state.selectedUTCHour)
  }

  private func xCenter(for hour: Int) -> CGFloat {
    (CGFloat(hour) * (cellWidth + cellGap)) + (cellWidth / 2)
  }

  private func cellColor(city: City, hour: Int) -> Color {
    let isElapsedSuccessHour = model.state.worksForEveryone && hour < model.state.selectedUTCHour

    switch model.state.availability(for: city, utcHour: hour) {
    case .off:
      return Color.black.opacity(0.055)
    case .edge:
      return city.color.opacity(isElapsedSuccessHour ? 0.18 : 0.30)
    case .working:
      return city.color.opacity(isElapsedSuccessHour ? 0.52 : 1)
    }
  }

  private var reorderDestinationIndex: Int? {
    reorderSession?.destinationIndex(
      rowHeight: rowHeight,
      itemCount: model.state.cities.count
    )
  }

  private func reorderOffset(for city: City, at index: Int) -> CGFloat {
    reorderSession?.offset(
      for: city.id,
      at: index,
      rowHeight: rowHeight,
      itemCount: model.state.cities.count
    ) ?? 0
  }

  @ViewBuilder
  private func selectorGlassSurface(height: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: 7.5, style: .continuous)

    if #available(macOS 26.0, *) {
      ZStack {
        shape.fill(Color.white.opacity(0.018))
        shape.fill(indicatorGradient).opacity(0.025)
        shape.fill(
          LinearGradient(
            colors: [
              Color.white.opacity(0.065), Color.white.opacity(0.012), Color.black.opacity(0.006),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
      }
      .glassEffect(.clear.interactive(), in: shape)
      .overlay(shape.stroke(indicatorGradient.opacity(0.72), lineWidth: 1.25))
      .overlay(shape.inset(by: 1.1).stroke(Color.white.opacity(0.36), lineWidth: 0.45))
      .frame(width: cellWidth + 7, height: height)
    } else {
      ZStack {
        shape.fill(Color.white.opacity(0.018))
        shape.fill(indicatorGradient).opacity(0.025)
        shape.fill(
          LinearGradient(
            colors: [
              Color.white.opacity(0.065), Color.white.opacity(0.012), Color.black.opacity(0.006),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
      }
      .overlay(shape.stroke(indicatorGradient.opacity(0.72), lineWidth: 1.25))
      .overlay(shape.inset(by: 1.1).stroke(Color.white.opacity(0.36), lineWidth: 0.45))
      .frame(width: cellWidth + 7, height: height)
    }
  }

  private var indicatorGradient: LinearGradient {
    LinearGradient(
      colors: indicatorColors,
      startPoint: .top,
      endPoint: .bottom
    )
  }

  private var indicatorColors: [Color] {
    if model.state.worksForEveryone {
      let green = Color(red: 0.10, green: 0.74, blue: 0.46)
      return [green, green]
    }

    let colors = previewCities.map { city -> Color in
      switch model.state.availability(for: city, utcHour: model.state.selectedUTCHour) {
      case .working:
        return city.color
      case .edge:
        return city.color.opacity(0.48)
      case .off:
        return Color(red: 0.10, green: 0.10, blue: 0.11).opacity(0.62)
      }
    }
    return colors.isEmpty ? [Color.black, Color.black] : colors
  }

  private var handleColor: Color {
    if model.state.worksForEveryone {
      return Color(red: 0.05, green: 0.58, blue: 0.34)
    }
    return previewCities.first { city in
      if case .working = model.state.availability(for: city, utcHour: model.state.selectedUTCHour) {
        return true
      }
      return false
    }?.color ?? Color(red: 0.08, green: 0.08, blue: 0.09)
  }

  private var previewCities: [City] {
    reorderSession?.reordered(model.state.cities, rowHeight: rowHeight) ?? model.state.cities
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named("timelineGrid"))
      .onChanged { value in
        let step = cellWidth + cellGap
        let clampedX = min(max(value.location.x, cellWidth / 2), gridWidth - (cellWidth / 2))
        let hour = Int(((clampedX - (cellWidth / 2)) / step).rounded())
        dragPositionX = clampedX
        NSCursor.resizeLeftRight.set()
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
          model.select(hour: hour)
        }
      }
      .onEnded { _ in
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
          dragPositionX = nil
        }
        if isPointerInsideGrid {
          NSCursor.resizeLeftRight.set()
        } else {
          NSCursor.arrow.set()
        }
      }
  }
}
