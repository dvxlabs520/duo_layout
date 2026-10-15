import 'package:flutter/widgets.dart';

import 'geometry.dart';
import 'scope.dart';

/// [top] above the fold and [bottom] below it in tabletop posture.
class TabletopSplit extends StatefulWidget {
  const TabletopSplit({
    super.key,
    required this.top,
    required this.bottom,
    this.minHeight = 120,
  });

  final Widget top, bottom;

  /// Minimum height of each half for the split.
  final double minHeight;

  @override
  State<TabletopSplit> createState() => _TabletopSplitState();
}

class _TabletopSplitState extends State<TabletopSplit> {
  double? _originY;

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) return;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y != _originY) setState(() => _originY = y);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fold = DeviceGeometryScope.of(context).fold;
    final tabletop = fold != null && fold.isTabletop;
    if (tabletop) _measure();
    return LayoutBuilder(
      builder: (context, constraints) {
        final origin = _originY;
        final plain = Column(
          children: [
            Expanded(child: widget.top),
            widget.bottom,
          ],
        );
        if (!tabletop || origin == null) return plain;
        final above = fold.bounds.top - origin;
        final below = constraints.maxHeight - above - fold.bounds.height;
        if (above < widget.minHeight || below < widget.minHeight) return plain;
        return Column(
          children: [
            SizedBox(height: above, child: widget.top),
            SizedBox(height: fold.bounds.height),
            Expanded(child: SingleChildScrollView(child: widget.bottom)),
          ],
        );
      },
    );
  }
}

/// Reads the device's geometry from the nearest [DeviceGeometryScope].
extension DeviceGeometryContext on BuildContext {
  DeviceGeometry get deviceGeometry => DeviceGeometryScope.of(this);
}
