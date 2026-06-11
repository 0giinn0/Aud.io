import 'package:flutter/material.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';

/// One section of the golden-spiral navigation.
class GoldenSection {
  final String label;
  final IconData icon;
  final Widget page;
  final Color panelColor;
  final Color panelForeground;

  const GoldenSection({
    required this.label,
    required this.icon,
    required this.page,
    required this.panelColor,
    required this.panelForeground,
  });
}

/// Golden-ratio spiral navigation, after narrowdesign.com:
/// the active section fills the major golden rectangle (~61.8% of the
/// screen) and every other section occupies a successively smaller golden
/// rectangle spiraling into the corner. Tapping a panel animates all
/// panels into their new spiral positions.
///
/// Page state is preserved: every page stays mounted (Offstage while its
/// section is inactive).
class GoldenSpiralNav extends StatelessWidget {
  final List<GoldenSection> sections;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const GoldenSpiralNav({
    super.key,
    required this.sections,
    required this.activeIndex,
    required this.onChanged,
  });

  /// Splits [bounds] into one rect per section: the active section takes
  /// the major share of each remaining rectangle's long side, the rest
  /// spiral inward (the classic nested golden-rectangle construction).
  List<Rect> _spiralRects(Rect bounds) {
    final rects = List<Rect>.filled(sections.length, Rect.zero);
    // Visit sections starting at the active one, wrapping around, so the
    // active section always owns the largest rectangle.
    final order = List<int>.generate(
        sections.length, (i) => (activeIndex + i) % sections.length);

    var remaining = bounds;
    for (var k = 0; k < order.length; k++) {
      if (k == order.length - 1) {
        rects[order[k]] = remaining;
        break;
      }
      final landscape = remaining.width >= remaining.height;
      if (landscape) {
        final w = remaining.width * AudIoTheme.golden;
        rects[order[k]] = Rect.fromLTWH(
            remaining.left, remaining.top, w, remaining.height);
        remaining = Rect.fromLTWH(remaining.left + w, remaining.top,
            remaining.width - w, remaining.height);
      } else {
        final h = remaining.height * AudIoTheme.golden;
        rects[order[k]] = Rect.fromLTWH(
            remaining.left, remaining.top, remaining.width, h);
        remaining = Rect.fromLTWH(remaining.left, remaining.top + h,
            remaining.width, remaining.height - h);
      }
    }
    return rects;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight);
        final rects = _spiralRects(bounds);

        return Stack(
          children: [
            // Pages layer: always occupies the active (major) rectangle.
            // Every page stays mounted here so its state survives section
            // switches, and inactive pages are never laid out inside the
            // small spiral panels.
            AnimatedPositioned.fromRect(
              key: const ValueKey('golden-pages-layer'),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeInOutQuart,
              rect: rects[activeIndex],
              child: Container(
                decoration: BoxDecoration(
                  color: AudIoTheme.bg,
                  border: Border.all(color: AudIoTheme.ink, width: 1),
                ),
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      for (var i = 0; i < sections.length; i++)
                        Offstage(
                          offstage: i != activeIndex,
                          child: TickerMode(
                            enabled: i == activeIndex,
                            child: sections[i].page,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Preview panels for the inactive sections, spiraling inward.
            for (var i = 0; i < sections.length; i++)
              if (i != activeIndex)
                AnimatedPositioned.fromRect(
                  key: ValueKey('golden-panel-$i'),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeInOutQuart,
                  rect: rects[i],
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sections[i].panelColor,
                        border: Border.all(color: AudIoTheme.ink, width: 1),
                      ),
                      child: _PanelPreview(section: sections[i], index: i),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

/// Bauhaus preview tile: giant index numeral, small uppercase label, and a
/// circle motif — scaled to whatever golden rectangle it lands in.
class _PanelPreview extends StatelessWidget {
  final GoldenSection section;
  final int index;

  const _PanelPreview({required this.section, required this.index});

  @override
  Widget build(BuildContext context) {
    final fg = section.panelForeground;

    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 90 || c.maxHeight < 90;
        final shortest = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;

        return Stack(
          children: [
            // Circle motif tucked into the corner, echoing the reference art.
            Positioned(
              right: -shortest * 0.21,
              bottom: -shortest * 0.21,
              child: Container(
                width: shortest * AudIoTheme.golden,
                height: shortest * AudIoTheme.golden,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg.withValues(alpha: 0.14),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? AudIoTheme.s2 : AudIoTheme.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '0${index + 1}',
                          style: TextStyle(
                            fontSize: compact ? 21 : 55,
                            fontWeight: FontWeight.w800,
                            height: 0.9,
                            letterSpacing: -2,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    Icon(section.icon, size: 13, color: fg),
                    const SizedBox(height: AudIoTheme.s1),
                  ],
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      section.label,
                      style: TextStyle(
                        fontSize: compact ? 8 : 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
