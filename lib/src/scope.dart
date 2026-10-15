import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'geometry.dart';

const _channel = EventChannel('duo_layout/events');

/// Provides [DeviceGeometry] to the widgets below it. Put it above your pages,
/// for example in `MaterialApp.builder`:
///
/// ```dart
/// MaterialApp(builder: (context, child) => DeviceGeometryScope(child: child!))
/// ```
///
/// On iOS it listens to the plugin (UIKit's reserved regions and hinge); on
/// Android it reads `MediaQuery.displayFeatures`. Both update live as the
/// device folds, unfolds or rotates.
class DeviceGeometryScope extends StatefulWidget {
  const DeviceGeometryScope({super.key, required this.child, this.events});

  final Widget child;

  /// Overrides the platform stream, for tests and previews.
  final Stream<Map<Object?, Object?>>? events;

  /// The geometry from the nearest scope. Without a scope, only what
  /// `MediaQuery` knows (Android's display features).
  static DeviceGeometry of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_GeometryInherited>();
    return scope?.geometry ??
        DeviceGeometry.fromDisplayFeatures(
          MediaQuery.displayFeaturesOf(context),
        );
  }

  @override
  State<DeviceGeometryScope> createState() => _DeviceGeometryScopeState();
}

class _DeviceGeometryScopeState extends State<DeviceGeometryScope> {
  StreamSubscription<Map<Object?, Object?>>? _sub;
  DeviceGeometry _platform = DeviceGeometry.none;

  @override
  void initState() {
    super.initState();
    final stream =
        widget.events ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? _channel.receiveBroadcastStream().map(
                (e) => (e as Map).cast<Object?, Object?>(),
              )
            : null);
    _sub = stream?.listen((event) {
      final next = DeviceGeometry.fromPlatform(event);
      if (next != _platform) setState(() => _platform = next);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final android = DeviceGeometry.fromDisplayFeatures(
      MediaQuery.displayFeaturesOf(context),
    );
    return _GeometryInherited(
      geometry: _platform.merge(android),
      child: widget.child,
    );
  }
}

class _GeometryInherited extends InheritedWidget {
  const _GeometryInherited({required this.geometry, required super.child});
  final DeviceGeometry geometry;

  @override
  bool updateShouldNotify(_GeometryInherited old) => old.geometry != geometry;
}
