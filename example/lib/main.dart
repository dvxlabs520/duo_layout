import 'package:flutter/material.dart';
import 'package:duo_layout/duo_layout.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'duo_layout',
    theme: ThemeData(colorSchemeSeed: Colors.teal),
    builder: (context, child) => DeviceGeometryScope(child: child!),
    home: const Home(),
  );
}

/// The three things a foldable-aware app usually needs, one per tab, under
/// an [AdaptiveNavigationScaffold]: on iPhone Duo the tabs sit in the status
/// bar's column, on wide windows in a rail, on phones at the bottom.
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => AdaptiveNavigationScaffold(
    selectedIndex: _tab,
    onDestinationSelected: (i) => setState(() => _tab = i),
    destinations: const [
      AdaptiveDestination(
        icon: Icons.straighten_outlined,
        selectedIcon: Icons.straighten,
        label: 'Geometry',
      ),
      AdaptiveDestination(
        icon: Icons.vertical_split_outlined,
        selectedIcon: Icons.vertical_split,
        label: 'Split',
        badge: 2,
      ),
      AdaptiveDestination(
        icon: Icons.laptop_outlined,
        selectedIcon: Icons.laptop,
        label: 'Tabletop',
      ),
    ],
    body: switch (_tab) {
      0 => const GeometryPage(),
      1 => const SplitPage(),
      _ => const TabletopPage(),
    },
  );
}

/// Everything the device reports.
class GeometryPage extends StatelessWidget {
  const GeometryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.deviceGeometry;
    final size = MediaQuery.sizeOf(context);
    final strip = g.sideStrip(size);
    final fold = g.fold;
    Widget line(String label, Object? value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$label: ${value ?? 'none'}'),
    );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Window ${size.width.round()} × ${size.height.round()}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          line('UIKit regions', g.supported),
          line('Hinge', g.hinge),
          line('Fold', fold),
          if (fold != null)
            line(
              'Posture',
              fold.isTabletop ? 'tabletop' : (fold.isBook ? 'book' : 'flat'),
            ),
          line(
            'Side strip',
            strip == null
                ? null
                : '${strip.side.name}, ${strip.width} wide from y=${strip.top}, padding ${strip.padding}',
          ),
          line('Safe area', MediaQuery.paddingOf(context)),
          const Divider(height: 32),
          for (final r in g.occlusions)
            line('Occlusion${r.active ? '' : ' (inactive)'}', r.frame),
          for (final e in g.sideBars.entries)
            line('Bar region ${e.key.name}', e.value),
          for (final r in g.divisions)
            line('Division${r.active ? '' : ' (inactive)'}', r.frame),
          for (final f in g.displayFeatures)
            line('Display feature ${f.type.name} ${f.state.name}', f.bounds),
        ],
      ),
    );
  }
}

/// A list and its detail, divided on the fold when there is one.
class SplitPage extends StatefulWidget {
  const SplitPage({super.key});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final fold = context.deviceGeometry.fold;
    return LayoutBuilder(
      builder: (context, c) {
        final box = context.findRenderObject() as RenderBox?;
        final originX = box != null && box.hasSize
            ? box.localToGlobal(Offset.zero).dx
            : 0.0;
        // The fold's position in this page's coordinates, or 40% of the width.
        final split = fold != null && fold.vertical
            ? fold.bounds.left - originX
            : c.maxWidth * 0.4;
        final gap = fold != null && fold.vertical && fold.obstructs
            ? fold.bounds.width
            : 0.0;
        final list = ListView.builder(
          itemCount: 20,
          itemBuilder: (_, i) => ListTile(
            selected: i == _selected,
            title: Text('Item ${i + 1}'),
            onTap: () => setState(() => _selected = i),
          ),
        );
        final detail = Center(
          child: Text(
            'Item ${_selected + 1}',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        );
        if (c.maxWidth < 600) return SafeArea(child: list);
        return SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: split.clamp(200.0, c.maxWidth - 200),
                child: list,
              ),
              SizedBox(width: gap),
              Expanded(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: detail,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Content above the fold, controls below it when the device stands
/// half-open.
class TabletopPage extends StatelessWidget {
  const TabletopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: TabletopSplit(
        top: ColoredBox(
          color: scheme.primaryContainer,
          child: const Center(
            child: Text('Content: a video, a terminal, a game'),
          ),
        ),
        bottom: Container(
          height: 140,
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Text('Controls: below the fold in tabletop posture'),
        ),
      ),
    );
  }
}
