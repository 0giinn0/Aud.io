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
/// screen) and up to 3 inactive sections occupy successively smaller golden
/// rectangles spiraling into the corner. When there are more than 4 sections
/// the visible set slides: tapping the smallest panel cycles to the next
/// hidden section, so all sections stay within 1–3 taps.
///
/// Page state is preserved: every page stays mounted (Offstage while its
/// section is inactive).
class GoldenSpiralNav extends StatelessWidget {
  final List<GoldenSection> sections;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  // Maximum panels shown in the spiral at once (1 active + N-1 inactive).
  static const int _maxVisible = 4;

  const GoldenSpiralNav({
    super.key,
    required this.sections,
    required this.activeIndex,
    required this.onChanged,
  });

  /// Returns the indices of sections shown in the spiral, in spiral order
  /// (active first, then the next [_maxVisible-1] sections circularly).
  List<int> _visibleIndices() {
    final count = sections.length.clamp(0, _maxVisible);
    return List<int>.generate(count, (i) => (activeIndex + i) % sections.length);
  }

  /// Splits [bounds] into one rect per visible section.
  List<Rect> _spiralRects(Rect bounds, int visibleCount) {
    final rects = List<Rect>.filled(visibleCount, Rect.zero);
    var remaining = bounds;
    for (var k = 0; k < visibleCount; k++) {
      if (k == visibleCount - 1) {
        rects[k] = remaining;
        break;
      }
      final landscape = remaining.width >= remaining.height;
      if (landscape) {
        final w = remaining.width * AudIoTheme.golden;
        rects[k] = Rect.fromLTWH(remaining.left, remaining.top, w, remaining.height);
        remaining = Rect.fromLTWH(remaining.left + w, remaining.top,
            remaining.width - w, remaining.height);
      } else {
        final h = remaining.height * AudIoTheme.golden;
        rects[k] = Rect.fromLTWH(remaining.left, remaining.top, remaining.width, h);
        remaining = Rect.fromLTWH(remaining.left, remaining.top + h,
            remaining.width, remaining.height - h);
      }
    }
    return rects;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndices();
    final hasOverflow = sections.length > _maxVisible;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight);
        final rects = _spiralRects(bounds, visible.length);

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
              rect: rects[0], // rects[0] is always the active section
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
            // Preview panels for the inactive visible sections, spiraling inward.
            for (var v = 1; v < visible.length; v++)
              AnimatedPositioned.fromRect(
                key: ValueKey('golden-panel-${visible[v]}'),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeInOutQuart,
                rect: rects[v],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(visible[v]),
                  child: Container(
                    decoration: BoxDecoration(
                      color: sections[visible[v]].panelColor,
                      border: Border.all(color: AudIoTheme.ink, width: 1),
                    ),
                    child: _PanelPreview(
                      section: sections[visible[v]],
                      index: visible[v],
                      // Show overflow indicator on last visible panel when sections overflow
                      showOverflowDot: hasOverflow && v == visible.length - 1,
                    ),
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
  final bool showOverflowDot;

  const _PanelPreview({
    required this.section,
    required this.index,
    this.showOverflowDot = false,
  });

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
            // Overflow indicator: small dot when more sections are hidden
            if (showOverflowDot)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
