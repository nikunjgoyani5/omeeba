import 'dart:async';

import 'package:flutter/material.dart';

/// Minimum time the "pressed" scale is shown so quick taps still show animation.
const _kMinPressVisibleDuration = Duration(milliseconds: 100);

/// Wraps [child] with Instagram-style press animation: scale down on tap,
/// scale back on release. Use for icon buttons, nav items, and any tappable
/// control that should feel "pressed". Fast taps still show the press effect
/// by keeping the scaled state for a minimum duration.
class PressScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDownTo;
  final Duration duration;
  final Curve curve;
  final Duration minPressVisibleDuration;

  const PressScaleButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDownTo = 0.82,
    this.duration = const Duration(milliseconds: 80),
    this.curve = Curves.easeOut,
    this.minPressVisibleDuration = _kMinPressVisibleDuration,
  });

  @override
  State<PressScaleButton> createState() => _PressScaleButtonState();
}

class _PressScaleButtonState extends State<PressScaleButton> {
  bool _pressed = false;
  DateTime? _pressStartedAt;
  Timer? _releaseTimer;

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  void _onTapDown(_) {
    _releaseTimer?.cancel();
    _pressStartedAt = DateTime.now();
    setState(() => _pressed = true);
  }

  void _onTapUp(_) {
    _scheduleRelease();
  }

  void _onTapCancel() {
    _scheduleRelease();
  }

  void _scheduleRelease() {
    _releaseTimer?.cancel();
    final started = _pressStartedAt;
    if (started == null) {
      setState(() => _pressed = false);
      return;
    }
    final elapsed = DateTime.now().difference(started);
    final remaining = widget.minPressVisibleDuration - elapsed;
    if (remaining <= Duration.zero) {
      setState(() => _pressed = false);
      return;
    }
    _releaseTimer = Timer(remaining, () {
      if (mounted) setState(() => _pressed = false);
    });
  }

  void _onTap() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDownTo : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}
