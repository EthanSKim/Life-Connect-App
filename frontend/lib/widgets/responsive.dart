import 'package:flutter/material.dart';

/// Single breakpoint used across every admin screen so "desktop" means the
/// same thing everywhere instead of each screen picking its own number.
const double kDesktopBreakpoint = 900;

bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= kDesktopBreakpoint;

/// Wraps a screen's scrollable content so it's edge-to-edge on mobile but
/// constrained to a centered, readable column on desktop/web - the same
/// pattern used by most responsive admin dashboards, and much simpler than
/// maintaining two separate layouts per screen.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Lays out variable-height cards in two columns on desktop (single column
/// on mobile), WITHOUT forcing every card to the same height the way
/// GridView.count's fixed aspectRatio does. That fixed-height approach is
/// wrong here: a household card with 4 members needs more vertical space
/// than one with 2, and forcing them to match causes the taller card's
/// content to overflow past its own border instead of the card just being
/// taller. Splitting into two independent Columns avoids the problem
/// entirely since each column sizes to its own content naturally.
class TwoColumnList extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const TwoColumnList({super.key, required this.children, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    if (!isDesktop(context)) {
      return Column(children: children);
    }
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      (i.isEven ? left : right).add(children[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        SizedBox(width: spacing),
        Expanded(child: Column(children: right)),
      ],
    );
  }
}

/// A field row that stacks vertically on mobile but sits side-by-side on
/// desktop, since cramming two fields into a narrow phone width looks
/// worse than just stacking them, while stacking on a wide desktop form
/// wastes horizontal space.
class ResponsiveFieldRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ResponsiveFieldRow({super.key, required this.children, this.spacing = 12});

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      final spaced = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        spaced.add(Expanded(child: children[i]));
        if (i != children.length - 1) spaced.add(SizedBox(width: spacing));
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: spaced);
    }
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) spaced.add(SizedBox(height: spacing));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: spaced);
  }
}
