import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duo_layout/duo_layout.dart';

void main() {
  // iPhone Duo, flat and upright: strip on the right, no division.
  final duoOpen = <Object?, Object?>{
    'width': 466.0,
    'height': 678.0,
    'occlusions': [
      {
        'x': 382.0,
        'y': 0.0,
        'width': 84.0,
        'height': 160.0,
        'marginTop': 0.0,
        'marginLeft': 8.0,
        'marginBottom': 8.0,
        'marginRight': 0.0,
        'active': true,
      },
    ],
    'divisions': <Object?>[],
    'hinge': {'status': 'fullyOpen', 'angle': 180.0},
  };

  group('iOS events', () {
    test('parse regions, margins and hinge', () {
      final g = DeviceGeometry.fromPlatform(duoOpen);
      expect(g.occlusions.single.frame, const Rect.fromLTWH(382, 0, 84, 160));
      expect(g.occlusions.single.rect, const Rect.fromLTRB(390, 0, 466, 152));
      expect(g.hinge, const Hinge(HingeStatus.fullyOpen, angle: 180));
      expect(g.fold, isNull);
    });

    test('a vertical occlusion on an edge becomes a side strip', () {
      final strip = DeviceGeometry.fromPlatform(duoOpen)
          .sideStrip(const Size(466, 678))!;
      expect(strip.side, StripSide.right);
      expect(strip.width, 84);
      expect(strip.top, 160);
      expect(strip.padding, const EdgeInsets.only(left: 8));
    });

    test('content lines up with the camera inside the strip', () {
      // iPhone Duo outer display: the strip, and the camera within it.
      final g = DeviceGeometry.fromPlatform({
        'occlusions': [
          {'x': 399.7, 'y': 29.3, 'width': 37.0, 'height': 37.0},
          {'x': 382.0, 'y': 0.0, 'width': 84.0, 'height': 170.0},
        ],
      });
      final strip = g.sideStrip(const Size(466, 678))!;
      expect(strip.top, 170);
      final axis =
          382 + strip.padding.left + (84 - strip.padding.horizontal) / 2;
      expect(axis, closeTo(418.2, 0.01));
    });

    test("UIKit's bar region sets the column's top and axis", () {
      // iPhone Duo inner display, landscape: no camera in the column.
      final g = DeviceGeometry.fromPlatform({
        'occlusions': [
          {'x': 867.0, 'y': 0.0, 'width': 84.0, 'height': 120.0},
        ],
        'bars': {
          'right': {'x': 873.0, 'y': 120.0, 'width': 60.0, 'height': 515.0},
        },
      });
      final strip = g.sideStrip(const Size(951, 669))!;
      expect(strip.top, 120);
      final axis =
          867 + strip.padding.left + (84 - strip.padding.horizontal) / 2;
      expect(axis, 903);
    });

    test('a camera island at the top is not a side strip', () {
      final g = DeviceGeometry.fromPlatform({
        'occlusions': [
          {'x': 140.0, 'y': 0.0, 'width': 120.0, 'height': 37.0},
        ],
      });
      expect(g.sideStrip(const Size(402, 874)), isNull);
    });

    test('a horizontal division while partially open is tabletop', () {
      final g = DeviceGeometry.fromPlatform({
        'divisions': [
          {'x': 0.0, 'y': 330.0, 'width': 678.0, 'height': 12.0},
        ],
        'hinge': {'status': 'partiallyOpen', 'angle': 95.0},
      });
      final fold = g.fold!;
      expect(fold.vertical, isFalse);
      expect(fold.isTabletop, isTrue);
      expect(fold.obstructs, isTrue);
    });

    test('inactive divisions are ignored', () {
      final g = DeviceGeometry.fromPlatform({
        'divisions': [
          {
            'x': 300.0,
            'y': 0.0,
            'width': 0.0,
            'height': 600.0,
            'active': false,
          },
        ],
      });
      expect(g.fold, isNull);
    });
  });

  group('Android display features', () {
    test('a half-opened vertical fold is book posture', () {
      final g = DeviceGeometry.fromDisplayFeatures(const [
        DisplayFeature(
          bounds: Rect.fromLTWH(426, 0, 0, 880),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ]);
      expect(g.hinge?.status, HingeStatus.partiallyOpen);
      expect(g.fold!.isBook, isTrue);
      expect(g.fold!.obstructs, isFalse);
    });

    test('a hinge between two screens obstructs', () {
      final g = DeviceGeometry.fromDisplayFeatures(const [
        DisplayFeature(
          bounds: Rect.fromLTWH(540, 0, 34, 720),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ]);
      expect(g.fold!.obstructs, isTrue);
      expect(g.fold!.halfOpened, isFalse);
    });

    test('cutouts are not folds', () {
      final g = DeviceGeometry.fromDisplayFeatures(const [
        DisplayFeature(
          bounds: Rect.fromLTWH(180, 0, 40, 30),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ]);
      expect(g.fold, isNull);
    });
  });

  testWidgets('the scope delivers iOS events as they arrive', (tester) async {
    final events = StreamController<Map<Object?, Object?>>();
    DeviceGeometry? seen;
    await tester.pumpWidget(
      DeviceGeometryScope(
        events: events.stream,
        child: Builder(
          builder: (context) {
            seen = context.deviceGeometry;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen!.occlusions, isEmpty);
    events.add(duoOpen);
    await tester.pump(); // delivers the event
    await tester.pump(); // rebuilds with it
    expect(seen!.occlusions, hasLength(1));
    await events.close();
  });

  testWidgets('TabletopSplit puts the top half above the fold', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 800),
          displayFeatures: [
            DisplayFeature(
              bounds: Rect.fromLTWH(0, 390, 800, 20),
              type: DisplayFeatureType.hinge,
              state: DisplayFeatureState.postureHalfOpened,
            ),
          ],
        ),
        child: DeviceGeometryScope(
          child: TabletopSplit(
            top: Container(key: const Key('top')),
            bottom: const SizedBox(key: Key('bottom'), height: 60),
          ),
        ),
      ),
    );
    await tester.pump(); // the split measures itself after the first frame
    expect(tester.getSize(find.byKey(const Key('top'))).height, 390);
    expect(tester.getTopLeft(find.byKey(const Key('bottom'))).dy, 410);
  });
}
