## 0.1.0

- `DeviceGeometry`: occlusion and division regions, UIKit's side bar regions, hinge status and angle (degrees), fold and side strip, `supported`.
- iOS: `UIView.reservedRegions(kind:)`, `UIView.LayoutRegion.bar(onEdge:extent:)` and `UIHingeInteraction` (iOS 27.1 SDK), streamed live and re-read once the window settles.
- Android: display features (Jetpack WindowManager) through `MediaQuery`.
- `AdaptiveNavigationScaffold`: tabs in the iPhone Duo's status bar column, a rail on wide windows, a bottom bar on phones.
- `DeviceGeometryScope`, `context.deviceGeometry` and `TabletopSplit`.
