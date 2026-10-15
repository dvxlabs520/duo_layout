# duo_layout

Adapt your Flutter app to **iPhone Duo** the way Apple asks, from UIKit's own APIs. Flutter does not expose any of them on iOS; this plugin reads them natively and streams them to Dart:

| UIKit (iOS 27.1 SDK) | What you get |
| --- | --- |
| `UIView.reservedRegions(kind: .occlusion)` | Areas covered by hardware or system UI: the camera and the vertical status bar column |
| `UIView.reservedRegions(kind: .division)` | Where content should divide in two: the fold |
| `UIView.LayoutRegion.bar(onEdge:extent:)` | Where UIKit places a bar along each side edge: under the status bar, on its axis |
| `UIHingeInteraction` / `UIHinge` | Hinge status (closed, partially open, fully open) and angle |

On top of them, `AdaptiveNavigationScaffold` puts your tabs in the status bar's column, as Apple places tab bars on iPhone Duo, instead of leaving that column empty.

**Android foldables work too** (Pixel Fold, Galaxy Fold, Surface Duo): their fold and posture come from Flutter's `MediaQuery.displayFeatures` (Jetpack WindowManager), with no native code. Both platforms arrive as one `DeviceGeometry`, updated live when the device folds, unfolds or rotates.

## Use

```dart
MaterialApp(
  builder: (context, child) => DeviceGeometryScope(child: child!),
  home: const Home(),
);
```

### Navigation where each device expects it

```dart
AdaptiveNavigationScaffold(
  selectedIndex: tab,
  onDestinationSelected: (i) => setState(() => tab = i),
  destinations: const [
    AdaptiveDestination(icon: Icons.inbox_outlined, selectedIcon: Icons.inbox, label: 'Inbox', badge: 3),
    AdaptiveDestination(icon: Icons.settings_outlined, label: 'Settings'),
  ],
  body: pages[tab],
);
```

- **iPhone Duo:** the tabs go vertically in the status bar's column, under it and on its axis, as Apple places tab bars.
- **Wide windows** (840 and up): a `NavigationRail`.
- **Phones:** a `NavigationBar`.

To build your own bar, read `context.deviceGeometry.sideStrip(size)`: it gives the side, the width, where free space starts (`top`) and the `padding` that centers content on the system's axis.

### The geometry itself

```dart
final g = context.deviceGeometry;
g.fold;                    // Fold? — bounds, vertical, isBook, isTabletop, obstructs
g.hinge;                   // Hinge? — status, angle in degrees (iOS)
g.sideStrip(size);         // SideStrip? — the iPhone Duo's status bar column
g.occlusions;              // [ReservedRegion] — frame, margins, active
g.divisions;               // [ReservedRegion]
g.sideBars;                // {StripSide: Rect} — UIKit's bar regions
g.supported;               // iOS: are UIKit's regions available?
```

`TabletopSplit(top:, bottom:)` puts `top` above the fold and `bottom` below it while the device stands half-open.

## iPhone Duo: what Apple asks

- Build with **Xcode 27.1** (iOS 27.1 SDK). The app then extends over the whole inner display. With older SDKs iOS letterboxes it with a black band by the status bar, and `supported` is false.
- Build the layout from the window's size, not from the device, its orientation or `UIScreen.main`.
- Tab bars and toolbars go **vertically below the status bar**, in the side column (see `AdaptiveNavigationScaffold`).
- Split content at `fold.bounds` when there is a division, and keep interactive content out of a region's `margins`.

**If `occlusions` stays empty on iPhone Duo** although `supported` is true: the system may be running that bundle identifier in compatibility mode, because a build made with an older SDK ran on the device first. Erase the simulator (*Device → Erase All Content and Settings*) or try another bundle identifier.

## Android foldables

- Put the split of a list and its detail on the fold, and leave a hinge's width empty (`fold.obstructs`).
- Use tabletop posture (`fold.isTabletop`) for content on top and controls below.
- Declare `android:resizeableActivity="true"` and handle `screenSize|smallestScreenSize|screenLayout|orientation` in `configChanges`, so folding does not restart the activity.

## Platforms

iOS 15+ and Android. UIKit's regions, bar regions and hinge need the iOS 27.1 SDK at build time and iOS 27.1 at run time; otherwise they are empty. On other platforms the geometry is empty, and `AdaptiveNavigationScaffold` falls back to a rail or a bottom bar.

## Example

`example/` is a three-tab app on `AdaptiveNavigationScaffold`:

- **Geometry:** everything the device reports.
- **Split:** a list and its detail divided on the fold.
- **Tabletop:** content above the fold and controls below.

Run it on the iPhone Duo simulator (Xcode 27.1) and on an Android foldable emulator.
