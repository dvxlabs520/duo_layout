import 'package:flutter/material.dart';

import 'geometry.dart';
import 'widgets.dart';

/// A destination in an [AdaptiveNavigationScaffold].
@immutable
class AdaptiveDestination {
  const AdaptiveDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge = 0,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  /// Badge count; 0 hides it.
  final int badge;
}

/// Tabs in iPhone Duo's side column, a rail on wide windows, or a bottom bar.
class AdaptiveNavigationScaffold extends StatelessWidget {
  const AdaptiveNavigationScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.railBreakpoint = 840,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  /// Minimum width for the rail.
  final double railBreakpoint;

  Widget _icon(BuildContext context, int i) {
    final d = destinations[i];
    final icon = Icon(i == selectedIndex ? d.selectedIcon ?? d.icon : d.icon);
    return d.badge > 0 ? Badge(label: Text('${d.badge}'), child: icon) : icon;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final strip = context.deviceGeometry.sideStrip(size);

    if (strip != null) {
      final onRight = strip.side == StripSide.right;
      final bar = _StripBar(
        strip: strip,
        count: destinations.length,
        selectedIndex: selectedIndex,
        onSelected: onDestinationSelected,
        icon: (i) => _icon(context, i),
        label: (i) => destinations[i].label,
      );
      final content = MediaQuery.removePadding(
        context: context,
        removeRight: onRight,
        removeLeft: !onRight,
        child: body,
      );
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: onRight
              ? [Expanded(child: content), bar]
              : [bar, Expanded(child: content)],
        ),
      );
    }

    if (size.width >= railBreakpoint) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (var i = 0; i < destinations.length; i++)
                    NavigationRailDestination(
                      icon: _icon(context, i),
                      label: Text(destinations[i].label),
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (var i = 0; i < destinations.length; i++)
            NavigationDestination(
              icon: _icon(context, i),
              label: destinations[i].label,
            ),
        ],
      ),
    );
  }
}

/// The destinations stacked down a [SideStrip].
class _StripBar extends StatelessWidget {
  const _StripBar({
    required this.strip,
    required this.count,
    required this.selectedIndex,
    required this.onSelected,
    required this.icon,
    required this.label,
  });

  final SideStrip strip;
  final int count, selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget Function(int) icon;
  final String Function(int) label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelSmall;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return SizedBox(
      width: strip.width,
      child: LayoutBuilder(
        builder: (context, c) {
          final room = c.maxHeight - strip.top - bottom - 16;
          final itemHeight = (room / count).clamp(48.0, 64.0);
          return SingleChildScrollView(
            padding: strip.padding.add(
              EdgeInsets.only(top: strip.top + 8, bottom: bottom + 8),
            ),
            child: Column(
              children: [
                for (var i = 0; i < count; i++)
                  Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    label: label(i),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelected(i),
                      child: SizedBox(
                        width: double.infinity,
                        height: itemHeight,
                        child: IconTheme(
                          data: IconThemeData(
                            color: i == selectedIndex
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            size: 24,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              icon(i),
                              if (itemHeight >= 56) ...[
                                const SizedBox(height: 4),
                                Text(
                                  label(i),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                  style: text?.copyWith(
                                    color: i == selectedIndex
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
