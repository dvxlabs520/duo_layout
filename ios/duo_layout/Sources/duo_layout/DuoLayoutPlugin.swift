import Flutter
import UIKit

/// Streams to Dart, on the event channel "duo_layout/events", what UIKit
/// knows about the shape of the device:
///
///   - `UIView.reservedRegions(kind: .occlusion)`: areas covered by hardware or
///     system UI, like the iPhone Duo's camera and vertical status bar.
///   - `UIView.reservedRegions(kind: .division)`: where content should divide
///     into two regions, like a fold.
///   - `UIHingeInteraction`: the hinge's status (closed, partially open, fully
///     open) and angle.
///
///   - `UIView.LayoutRegion.bar(onEdge:extent:)`: where UIKit places a
///     bar along the left and right edges.
///
/// Frames are in the Flutter view's points, which are Flutter's logical
/// pixels. The APIs ship with the iOS 27.1 SDK: built with an older SDK, or
/// running on an older iOS, the stream reports no regions and no hinge.
public class DuoLayoutPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private weak var registrar: FlutterPluginRegistrar?
  private var sink: FlutterEventSink?
  private var probe: ProbeView?
  private var hinge: [String: Any]?
  private var last: NSDictionary?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = DuoLayoutPlugin()
    instance.registrar = registrar
    FlutterEventChannel(name: "duo_layout/events", binaryMessenger: registrar.messenger())
      .setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    last = nil
    attach()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  /// Puts an invisible view over the Flutter view: it is told about every
  /// size and safe-area change, and it is where the hinge interaction lives.
  private func attach() {
    if probe != nil {
      publish()
      return
    }
    guard let host = registrar?.viewController?.view else {
      // The Flutter view may not be in place yet when Dart starts listening.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
        if self?.sink != nil { self?.attach() }
      }
      return
    }
    let view = ProbeView(frame: host.bounds)
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    view.onChange = { [weak self] in self?.publish() }
    host.addSubview(view)
    probe = view

    #if canImport(UIKit, _version: 9127.0.85)
    if #available(iOS 27.1, *) {
      view.addInteraction(UIHingeInteraction { [weak self] _, update in
        if let h = update.hinge {
          // UIHinge.angle is in radians; Dart gets degrees.
          self?.hinge = ["status": DuoLayoutPlugin.name(h.status), "angle": Double(h.angle) * 180 / .pi]
        } else {
          self?.hinge = nil
        }
        self?.publish()
        self?.settle()
      })
    }
    #endif
    publish()
    settle()
    NotificationCenter.default.addObserver(
      self, selector: #selector(settle), name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  /// UIKit can settle the reserved regions after the view's last layout
  /// pass, with nothing telling the view: ask again once the window is in
  /// place.
  @objc private func settle() {
    for delay in [0.15, 0.5, 1.0, 2.0] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.publish() }
    }
  }

  /// Sends the current geometry when it differs from the last one sent.
  private func publish() {
    guard let sink, let view = probe else { return }
    var state: [String: Any] = [
      "occlusions": [Any](),
      "divisions": [Any](),
      "width": Double(view.bounds.width),
      "height": Double(view.bounds.height),
      "supported": false,
    ]
    #if canImport(UIKit, _version: 9127.0.85)
    if #available(iOS 27.1, *) {
      state["supported"] = true
      state["occlusions"] = view.reservedRegions(kind: .occlusion).map(DuoLayoutPlugin.encode)
      state["divisions"] = view.reservedRegions(kind: .division).map(DuoLayoutPlugin.encode)
      // Where UIKit places a bar along each side edge
      // (`UIView.LayoutRegion.bar(onEdge:extent:)`): on iPhone Duo, under the
      // status bar and on its axis. The extent only sets the width.
      var bars: [String: Any] = [:]
      for (name, edge) in [("left", UIRectEdge.left), ("right", UIRectEdge.right)] {
        let rect = view.bounds.inset(by: view.edgeInsets(for: .bar(onEdge: edge, extent: 60)))
        if rect.width > 0, rect.height > 0 {
          bars[name] = ["x": Double(rect.minX), "y": Double(rect.minY), "width": Double(rect.width), "height": Double(rect.height)]
        }
      }
      state["bars"] = bars
    }
    #endif
    if let hinge { state["hinge"] = hinge }
    let dict = state as NSDictionary
    if let last, last.isEqual(dict) { return }
    last = dict
    sink(state)
  }

  #if canImport(UIKit, _version: 9127.0.85)
  @available(iOS 27.1, *)
  private static func encode(_ region: UIView.ReservedRegion) -> [String: Any] {
    [
      "x": Double(region.frame.minX), "y": Double(region.frame.minY),
      "width": Double(region.frame.width), "height": Double(region.frame.height),
      "marginTop": Double(region.margins.top), "marginLeft": Double(region.margins.left),
      "marginBottom": Double(region.margins.bottom), "marginRight": Double(region.margins.right),
      "active": region.isActive,
    ]
  }

  @available(iOS 27.1, *)
  private static func name(_ status: UIHinge.Status) -> String {
    switch status {
    case .closed: return "closed"
    case .partiallyOpen: return "partiallyOpen"
    case .fullyOpen: return "fullyOpen"
    case .unknown: return "unknown"
    @unknown default: return "unknown"
    }
  }
  #endif
}

/// A transparent view the size of the Flutter view that reports changes.
final class ProbeView: UIView {
  var onChange: (() -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    onChange?()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onChange?()
  }

  // Never takes touches meant for Flutter.
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}
