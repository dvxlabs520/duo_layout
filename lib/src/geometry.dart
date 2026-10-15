import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// `UIHinge.Status` on iOS; mapped from the fold posture on Android.
enum HingeStatus { unknown, closed, partiallyOpen, fullyOpen }

/// Hinge status and, on iOS, angle in degrees.
@immutable
class Hinge {
  const Hinge(this.status, {this.angle});

  final HingeStatus status;
  final double? angle;

  bool get partiallyOpen => status == HingeStatus.partiallyOpen;

  @override
  bool operator ==(Object other) =>
      other is Hinge && other.status == status && other.angle == angle;

  @override
  int get hashCode => Object.hash(status, angle);

  @override
  String toString() =>
      'Hinge(${status.name}${angle == null ? '' : ', $angle°'})';
}

/// A `UIView.ReservedRegion`; [frame] includes [margins].
@immutable
class ReservedRegion {
  const ReservedRegion(
    this.frame, {
    this.margins = EdgeInsets.zero,
    this.active = true,
  });

  final Rect frame;
  final EdgeInsets margins;
  final bool active;

  /// [frame] without [margins].
  Rect get rect => margins.deflateRect(frame);

  @override
  bool operator ==(Object other) =>
      other is ReservedRegion &&
      other.frame == frame &&
      other.margins == margins &&
      other.active == active;

  @override
  int get hashCode => Object.hash(frame, margins, active);

  @override
  String toString() => 'ReservedRegion($frame${active ? '' : ', inactive'})';
}

/// A fold or hinge across the window.
@immutable
class Fold {
  const Fold(this.bounds, {required this.status, required this.obstructs});

  final Rect bounds;
  final HingeStatus status;

  /// Content should stay out of [bounds].
  final bool obstructs;

  bool get vertical => bounds.height > bounds.width;

  bool get halfOpened => status == HingeStatus.partiallyOpen;

  /// Half-open, fold horizontal.
  bool get isTabletop => halfOpened && !vertical;

  /// Half-open, fold vertical.
  bool get isBook => halfOpened && vertical;

  @override
  bool operator ==(Object other) =>
      other is Fold &&
      other.bounds == bounds &&
      other.status == status &&
      other.obstructs == obstructs;

  @override
  int get hashCode => Object.hash(bounds, status, obstructs);

  @override
  String toString() =>
      'Fold($bounds, ${status.name}${obstructs ? ', obstructs' : ''})';
}

/// Which side edge a [SideStrip] runs along.
enum StripSide { left, right }

/// The column iPhone Duo keeps for its camera and status bar.
@immutable
class SideStrip {
  const SideStrip(
    this.side, {
    required this.width,
    required this.top,
    required this.reserved,
    this.padding = EdgeInsets.zero,
  });

  final StripSide side;

  final double width;

  /// Where free space starts, below the reserved area.
  final double top;

  final ReservedRegion reserved;

  /// Centers content on the status bar's axis.
  final EdgeInsets padding;

  @override
  bool operator ==(Object other) =>
      other is SideStrip &&
      other.side == side &&
      other.width == width &&
      other.top == top &&
      other.padding == padding;

  @override
  int get hashCode => Object.hash(side, width, top, padding);
}

/// What the platform says about the shape of the device.
@immutable
class DeviceGeometry {
  const DeviceGeometry({
    this.supported,
    this.sideBars = const {},
    this.occlusions = const [],
    this.divisions = const [],
    this.hinge,
    this.displayFeatures = const [],
  });

  /// iOS: whether UIKit's regions are available (iOS 27.1 SDK and runtime).
  final bool? supported;

  /// iOS: `UIView.LayoutRegion.bar(onEdge:)` for each side edge.
  final Map<StripSide, Rect> sideBars;

  /// iOS: `reservedRegions(kind: .occlusion)`.
  final List<ReservedRegion> occlusions;

  /// iOS: `reservedRegions(kind: .division)`.
  final List<ReservedRegion> divisions;

  /// iOS: `UIHingeInteraction`; Android: from the fold posture.
  final Hinge? hinge;

  /// Android: `MediaQueryData.displayFeatures` (Jetpack WindowManager).
  final List<DisplayFeature> displayFeatures;

  static const none = DeviceGeometry();

  /// Parses an event from the iOS plugin.
  factory DeviceGeometry.fromPlatform(Map<Object?, Object?> event) {
    List<ReservedRegion> regions(Object? list) => [
      for (final r in (list as List?) ?? const [])
        if (r is Map) _region(r),
    ];
    final h = event['hinge'];
    return DeviceGeometry(
      supported: event['supported'] as bool?,
      sideBars: {
        for (final side in StripSide.values)
          if ((event['bars'] as Map?)?[side.name] case final Map bar)
            side: _region(bar).frame,
      },
      occlusions: regions(event['occlusions']),
      divisions: regions(event['divisions']),
      hinge: h is Map
          ? Hinge(
              HingeStatus.values.firstWhere(
                (s) => s.name == h['status'],
                orElse: () => HingeStatus.unknown,
              ),
              angle: (h['angle'] as num?)?.toDouble(),
            )
          : null,
    );
  }

  /// From Android's display features.
  factory DeviceGeometry.fromDisplayFeatures(List<DisplayFeature> features) {
    final fold = features
        .where((f) => f.type != DisplayFeatureType.cutout)
        .firstOrNull;
    return DeviceGeometry(
      displayFeatures: features,
      hinge: fold == null
          ? null
          : Hinge(switch (fold.state) {
              DisplayFeatureState.postureHalfOpened =>
                HingeStatus.partiallyOpen,
              DisplayFeatureState.postureFlat => HingeStatus.fullyOpen,
              _ => HingeStatus.unknown,
            }),
    );
  }

  static ReservedRegion _region(Map r) {
    double d(String k) => (r[k] as num?)?.toDouble() ?? 0;
    return ReservedRegion(
      Rect.fromLTWH(d('x'), d('y'), d('width'), d('height')),
      margins: EdgeInsets.fromLTRB(
        d('marginLeft'),
        d('marginTop'),
        d('marginRight'),
        d('marginBottom'),
      ),
      active: r['active'] != false,
    );
  }

  /// Fills empty fields from [other].
  DeviceGeometry merge(DeviceGeometry other) => DeviceGeometry(
    supported: supported ?? other.supported,
    sideBars: sideBars.isNotEmpty ? sideBars : other.sideBars,
    occlusions: occlusions.isNotEmpty ? occlusions : other.occlusions,
    divisions: divisions.isNotEmpty ? divisions : other.divisions,
    hinge: hinge ?? other.hinge,
    displayFeatures: displayFeatures.isNotEmpty
        ? displayFeatures
        : other.displayFeatures,
  );

  /// The active fold or hinge, if any.
  Fold? get fold {
    final division = divisions.where((d) => d.active).firstOrNull;
    if (division != null) {
      return Fold(
        division.frame,
        status: hinge?.status ?? HingeStatus.unknown,
        obstructs: division.frame.shortestSide > 0,
      );
    }
    final feature = displayFeatures
        .where((f) => f.type != DisplayFeatureType.cutout)
        .firstOrNull;
    if (feature != null) {
      return Fold(
        feature.bounds,
        status: hinge?.status ?? HingeStatus.unknown,
        obstructs:
            feature.type == DisplayFeatureType.hinge ||
            feature.bounds.shortestSide > 0,
      );
    }
    return null;
  }

  /// The side column in a window of [size], if any.
  SideStrip? sideStrip(Size size) {
    for (final r in occlusions) {
      if (!r.active || r.frame.height < r.frame.width) continue;
      final StripSide side;
      final double left, right;
      if (r.frame.right >= size.width - 0.5) {
        (side, left, right) = (StripSide.right, r.frame.left, size.width);
      } else if (r.frame.left <= 0.5) {
        (side, left, right) = (StripSide.left, 0, r.frame.right);
      } else {
        continue;
      }
      ReservedRegion? camera;
      for (final o in occlusions) {
        final inside =
            o != r &&
            o.active &&
            o.frame.left >= left - 0.5 &&
            o.frame.right <= right + 0.5;
        if (inside &&
            (camera == null ||
                o.frame.width * o.frame.height <
                    camera.frame.width * camera.frame.height)) {
          camera = o;
        }
      }
      // Axis: UIKit's bar region, else a camera in the column, else the region.
      final bar = sideBars[side];
      final axis = bar?.center.dx ?? (camera?.rect ?? r.rect).center.dx;
      final shift = 2 * (axis - (left + right) / 2);
      return SideStrip(
        side,
        width: right - left,
        top: bar?.top ?? r.frame.bottom,
        reserved: r,
        padding: shift >= 0
            ? EdgeInsets.only(left: shift)
            : EdgeInsets.only(right: -shift),
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DeviceGeometry &&
      other.supported == supported &&
      mapEquals(other.sideBars, sideBars) &&
      listEquals(other.occlusions, occlusions) &&
      listEquals(other.divisions, divisions) &&
      other.hinge == hinge &&
      listEquals(other.displayFeatures, displayFeatures);

  @override
  int get hashCode => Object.hash(
    supported,
    Object.hashAll(sideBars.entries.map((e) => Object.hash(e.key, e.value))),
    Object.hashAll(occlusions),
    Object.hashAll(divisions),
    hinge,
    Object.hashAll(displayFeatures),
  );

  @override
  String toString() =>
      'DeviceGeometry(occlusions: $occlusions, divisions: $divisions, hinge: $hinge, '
      'displayFeatures: $displayFeatures)';
}
