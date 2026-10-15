# duo_layout example

A three-tab app on `AdaptiveNavigationScaffold`:

- **Geometry:** everything the device reports: UIKit's reserved regions, side bar regions and hinge on iPhone Duo, display features on Android.
- **Split:** a list and its detail divided on the fold.
- **Tabletop:** content above the fold and controls below.

Run it on the iPhone Duo simulator, built with Xcode 27.1 (iOS 27.1 SDK), and on an Android foldable emulator:

```bash
flutter run
```

On a real iPhone, set your own team under *Signing & Capabilities* in Xcode.
