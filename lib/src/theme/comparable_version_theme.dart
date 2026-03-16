// Copyright 2026 comparable_version_sync authors. All rights reserved.

import 'package:flutter/material.dart';

/// Visual configuration for [ComparableVersionWidget] and all its sub-widgets.
///
/// Every hardcoded dimension, colour, duration, and curve has been lifted into
/// this class so that host applications can tailor the look and feel without
/// forking the package source.
///
/// All fields have sensible defaults and the class is `const`-constructable,
/// meaning you can define a single shared instance at compile time:
///
/// ```dart
/// const myTheme = ComparableVersionTheme(
///   initialSplitRatio: 0.4,
///   localHighlightColor: Color(0x2200BCD4),
///   incomingHighlightColor: Color(0x22FF5722),
/// );
///
/// ComparableVersionWidget.diffView(
///   theme: myTheme,
///   ...
/// )
/// ```
///
/// Use [copyWith] to derive a variant from the default theme:
///
/// ```dart
/// const myTheme = ComparableVersionTheme().copyWith(
///   responsiveBreakpoint: 720,
///   monoFontSize: 14,
/// );
/// ```
@immutable
class ComparableVersionTheme {
  // ── DiffDetailScreen — split panel ─────────────────────────────────────────

  /// Initial ratio [0.0, 1.0] allocated to the left (local) panel.
  ///
  /// `0.5` means each panel starts at 50 % of the available width.
  final double initialSplitRatio;

  /// Minimum allowed split ratio after dragging. Default: `0.1`.
  final double minSplitRatio;

  /// Maximum allowed split ratio after dragging. Default: `0.9`.
  final double maxSplitRatio;

  /// Width in logical pixels of the draggable vertical divider between panels.
  /// Default: `6.0`.
  final double dividerWidth;

  // ── DiffDetailScreen — code lines ─────────────────────────────────────────

  /// Fixed pixel height allocated to each line of code in [DiffDetailScreen].
  /// Default: `20.0`.
  ///
  /// Increase this for larger fonts or extra leading.
  final double lineHeight;

  /// Horizontal padding applied inside each code-line cell. Default: `8.0`.
  final double linePadding;

  /// Logical-pixel width of the virtual canvas used for horizontal scrolling.
  /// Default: `2000.0`.
  ///
  /// The canvas must be wide enough to prevent deep-indented JSON from being
  /// clipped. Increase if your content regularly exceeds this width.
  final double codeCanvasWidth;

  // ── DiffDetailScreen — horizontal pan bar ─────────────────────────────────

  /// Pixel height of the drag bar at the bottom of [DiffDetailScreen] that
  /// pans both panels horizontally in sync. Default: `24.0`.
  final double panBarHeight;

  /// Width of the indicator pill drawn inside the pan bar. Default: `48.0`.
  final double panBarHandleWidth;

  /// Height of the indicator pill drawn inside the pan bar. Default: `4.0`.
  final double panBarHandleHeight;

  // ── DiffDetailScreen — highlights ─────────────────────────────────────────

  /// Background colour applied to highlighted lines in the **local** (file 1)
  /// panel. Default: semi-transparent green — `Color(0x334CAF50)`.
  final Color localHighlightColor;

  /// Background colour applied to highlighted lines in the **incoming** (file 2)
  /// panel. Default: semi-transparent amber — `Color(0x33FFC107)`.
  final Color incomingHighlightColor;

  // ── DiffDetailScreen — scroll animation ───────────────────────────────────

  /// Duration of the animated scroll triggered when the user taps a line.
  /// Default: `Duration(milliseconds: 300)`.
  final Duration scrollAnimationDuration;

  /// Curve of the animated scroll triggered when the user taps a line.
  /// Default: `Curves.easeOut`.
  final Curve scrollAnimationCurve;

  // ── RawViewPanel ──────────────────────────────────────────────────────────

  /// Minimum panel width (dp) at which [RawViewPanel] switches from a tabbed
  /// single-column layout to a side-by-side two-column layout.
  /// Default: `600.0`.
  final double responsiveBreakpoint;

  // ── Cards (MergeOverlay, DiffViewPanel) ───────────────────────────────────

  /// Corner radius for choice cards in [MergeOverlay]. Default: `12.0`.
  final double cardBorderRadius;

  /// Border width drawn around the **selected** card. Default: `2.0`.
  final double selectedBorderWidth;

  /// Border width drawn around **unselected** cards. Default: `1.0`.
  final double unselectedBorderWidth;

  /// Inner padding of choice / manual-edit cards. Default: `12.0`.
  final double cardPadding;

  /// Duration of the [AnimatedContainer] colour transition when a card is
  /// selected or deselected. Default: `Duration(milliseconds: 150)`.
  final Duration cardAnimationDuration;

  // ── Icons ─────────────────────────────────────────────────────────────────

  /// Size of standard action icons (radio button, resolved check).
  /// Default: `20.0`.
  final double iconSize;

  /// Size of small secondary icons (chip avatar, warning badges).
  /// Default: `18.0`.
  final double smallIconSize;

  // ── Text ──────────────────────────────────────────────────────────────────

  /// Font size used for monospace content (values, JSON, SQL). Default: `13.0`.
  final double monoFontSize;

  /// Font size used for index numbers and small labels. Default: `11.0`.
  final double smallLabelFontSize;

  /// Corner radius of the manual-edit [TextField] in [MergeOverlay].
  /// Default: `8.0`.
  final double textFieldBorderRadius;

  // ── Layout offsets ────────────────────────────────────────────────────────

  /// Distance from the **bottom** edge of the viewport for the raw-view FAB
  /// ("Accept File 1"). Default: `16.0`.
  final double fabBottomOffset;

  /// Distance from the **right** edge of the viewport for the raw-view FAB.
  /// Default: `16.0`.
  final double fabRightOffset;

  /// Distance from the **bottom** edge of the viewport for the diff-view
  /// "Finalize" FAB. Default: `72.0`.
  ///
  /// The larger default keeps the FAB above the navigation bar at the bottom
  /// of [DiffViewPanel].
  final double diffFabBottomOffset;

  /// Distance from the **right** edge of the viewport for the diff-view FAB.
  /// Default: `16.0`.
  final double diffFabRightOffset;

  /// Bottom padding added to the diff-tile [ListView] so the last item is not
  /// obscured by the FAB. Default: `80.0`.
  final double listBottomPadding;

  /// Bottom padding added to the [MergeOverlay] scroll body so the last card
  /// is not obscured by the "Confirm" FAB. Default: `100.0`.
  final double overlayBodyBottomPadding;

  /// Creates a [ComparableVersionTheme] with the given overrides.
  ///
  /// Every field is optional — omitting a field keeps its documented default.
  const ComparableVersionTheme({
    this.initialSplitRatio = 0.5,
    this.minSplitRatio = 0.1,
    this.maxSplitRatio = 0.9,
    this.dividerWidth = 6.0,
    this.lineHeight = 20.0,
    this.linePadding = 8.0,
    this.codeCanvasWidth = 2000.0,
    this.panBarHeight = 24.0,
    this.panBarHandleWidth = 48.0,
    this.panBarHandleHeight = 4.0,
    this.localHighlightColor = const Color(0x334CAF50),
    this.incomingHighlightColor = const Color(0x33FFC107),
    this.scrollAnimationDuration = const Duration(milliseconds: 300),
    this.scrollAnimationCurve = Curves.easeOut,
    this.responsiveBreakpoint = 600.0,
    this.cardBorderRadius = 12.0,
    this.selectedBorderWidth = 2.0,
    this.unselectedBorderWidth = 1.0,
    this.cardPadding = 12.0,
    this.cardAnimationDuration = const Duration(milliseconds: 150),
    this.iconSize = 20.0,
    this.smallIconSize = 18.0,
    this.monoFontSize = 13.0,
    this.smallLabelFontSize = 11.0,
    this.textFieldBorderRadius = 8.0,
    this.fabBottomOffset = 16.0,
    this.fabRightOffset = 16.0,
    this.diffFabBottomOffset = 72.0,
    this.diffFabRightOffset = 16.0,
    this.listBottomPadding = 80.0,
    this.overlayBodyBottomPadding = 100.0,
  });

  /// Returns a copy of this theme with the specified fields replaced.
  ///
  /// ```dart
  /// final compact = const ComparableVersionTheme().copyWith(
  ///   lineHeight: 16,
  ///   panBarHeight: 18,
  /// );
  /// ```
  ComparableVersionTheme copyWith({
    double? initialSplitRatio,
    double? minSplitRatio,
    double? maxSplitRatio,
    double? dividerWidth,
    double? lineHeight,
    double? linePadding,
    double? codeCanvasWidth,
    double? panBarHeight,
    double? panBarHandleWidth,
    double? panBarHandleHeight,
    Color? localHighlightColor,
    Color? incomingHighlightColor,
    Duration? scrollAnimationDuration,
    Curve? scrollAnimationCurve,
    double? responsiveBreakpoint,
    double? cardBorderRadius,
    double? selectedBorderWidth,
    double? unselectedBorderWidth,
    double? cardPadding,
    Duration? cardAnimationDuration,
    double? iconSize,
    double? smallIconSize,
    double? monoFontSize,
    double? smallLabelFontSize,
    double? textFieldBorderRadius,
    double? fabBottomOffset,
    double? fabRightOffset,
    double? diffFabBottomOffset,
    double? diffFabRightOffset,
    double? listBottomPadding,
    double? overlayBodyBottomPadding,
  }) {
    return ComparableVersionTheme(
      initialSplitRatio: initialSplitRatio ?? this.initialSplitRatio,
      minSplitRatio: minSplitRatio ?? this.minSplitRatio,
      maxSplitRatio: maxSplitRatio ?? this.maxSplitRatio,
      dividerWidth: dividerWidth ?? this.dividerWidth,
      lineHeight: lineHeight ?? this.lineHeight,
      linePadding: linePadding ?? this.linePadding,
      codeCanvasWidth: codeCanvasWidth ?? this.codeCanvasWidth,
      panBarHeight: panBarHeight ?? this.panBarHeight,
      panBarHandleWidth: panBarHandleWidth ?? this.panBarHandleWidth,
      panBarHandleHeight: panBarHandleHeight ?? this.panBarHandleHeight,
      localHighlightColor: localHighlightColor ?? this.localHighlightColor,
      incomingHighlightColor:
          incomingHighlightColor ?? this.incomingHighlightColor,
      scrollAnimationDuration:
          scrollAnimationDuration ?? this.scrollAnimationDuration,
      scrollAnimationCurve: scrollAnimationCurve ?? this.scrollAnimationCurve,
      responsiveBreakpoint: responsiveBreakpoint ?? this.responsiveBreakpoint,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      selectedBorderWidth: selectedBorderWidth ?? this.selectedBorderWidth,
      unselectedBorderWidth:
          unselectedBorderWidth ?? this.unselectedBorderWidth,
      cardPadding: cardPadding ?? this.cardPadding,
      cardAnimationDuration:
          cardAnimationDuration ?? this.cardAnimationDuration,
      iconSize: iconSize ?? this.iconSize,
      smallIconSize: smallIconSize ?? this.smallIconSize,
      monoFontSize: monoFontSize ?? this.monoFontSize,
      smallLabelFontSize: smallLabelFontSize ?? this.smallLabelFontSize,
      textFieldBorderRadius:
          textFieldBorderRadius ?? this.textFieldBorderRadius,
      fabBottomOffset: fabBottomOffset ?? this.fabBottomOffset,
      fabRightOffset: fabRightOffset ?? this.fabRightOffset,
      diffFabBottomOffset: diffFabBottomOffset ?? this.diffFabBottomOffset,
      diffFabRightOffset: diffFabRightOffset ?? this.diffFabRightOffset,
      listBottomPadding: listBottomPadding ?? this.listBottomPadding,
      overlayBodyBottomPadding:
          overlayBodyBottomPadding ?? this.overlayBodyBottomPadding,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ComparableVersionTheme &&
        other.initialSplitRatio == initialSplitRatio &&
        other.minSplitRatio == minSplitRatio &&
        other.maxSplitRatio == maxSplitRatio &&
        other.dividerWidth == dividerWidth &&
        other.lineHeight == lineHeight &&
        other.linePadding == linePadding &&
        other.codeCanvasWidth == codeCanvasWidth &&
        other.panBarHeight == panBarHeight &&
        other.panBarHandleWidth == panBarHandleWidth &&
        other.panBarHandleHeight == panBarHandleHeight &&
        other.localHighlightColor == localHighlightColor &&
        other.incomingHighlightColor == incomingHighlightColor &&
        other.scrollAnimationDuration == scrollAnimationDuration &&
        other.scrollAnimationCurve == scrollAnimationCurve &&
        other.responsiveBreakpoint == responsiveBreakpoint &&
        other.cardBorderRadius == cardBorderRadius &&
        other.selectedBorderWidth == selectedBorderWidth &&
        other.unselectedBorderWidth == unselectedBorderWidth &&
        other.cardPadding == cardPadding &&
        other.cardAnimationDuration == cardAnimationDuration &&
        other.iconSize == iconSize &&
        other.smallIconSize == smallIconSize &&
        other.monoFontSize == monoFontSize &&
        other.smallLabelFontSize == smallLabelFontSize &&
        other.textFieldBorderRadius == textFieldBorderRadius &&
        other.fabBottomOffset == fabBottomOffset &&
        other.fabRightOffset == fabRightOffset &&
        other.diffFabBottomOffset == diffFabBottomOffset &&
        other.diffFabRightOffset == diffFabRightOffset &&
        other.listBottomPadding == listBottomPadding &&
        other.overlayBodyBottomPadding == overlayBodyBottomPadding;
  }

  @override
  int get hashCode => Object.hashAll([
        initialSplitRatio,
        minSplitRatio,
        maxSplitRatio,
        dividerWidth,
        lineHeight,
        linePadding,
        codeCanvasWidth,
        panBarHeight,
        panBarHandleWidth,
        panBarHandleHeight,
        localHighlightColor,
        incomingHighlightColor,
        scrollAnimationDuration,
        scrollAnimationCurve,
        responsiveBreakpoint,
        cardBorderRadius,
        selectedBorderWidth,
        unselectedBorderWidth,
        cardPadding,
        cardAnimationDuration,
        iconSize,
        smallIconSize,
        monoFontSize,
        smallLabelFontSize,
        textFieldBorderRadius,
        fabBottomOffset,
        fabRightOffset,
        diffFabBottomOffset,
        diffFabRightOffset,
        listBottomPadding,
        overlayBodyBottomPadding,
      ]);
}
