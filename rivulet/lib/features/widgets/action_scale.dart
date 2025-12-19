import 'package:flutter/material.dart';
import 'package:rivulet/features/utils/platform_utils.dart';

class ActionScale extends StatefulWidget {
  final Widget Function(BuildContext context, FocusNode node) builder;
  final double scale;
  final double breathingIntensity;
  final Duration duration;
  final FocusNode? focusNode;

  const ActionScale({
    super.key,
    required this.builder,
    this.scale = 1.1,
    this.breathingIntensity =
        0.05, // This value will be added to the base scale, so the max scale will be scale + breathingIntensity
    this.duration = const Duration(milliseconds: 200),
    this.focusNode,
  });

  @override
  State<ActionScale> createState() => _ActionScaleState();
}

class _ActionScaleState extends State<ActionScale>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _breathingController;

  bool get isActive => _isHovered || (PlatformUtils.isTv ? _isFocused : false);

  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.0,
      upperBound: widget.breathingIntensity,
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _breathingController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
        _updateBreathing();
      });
    }
  }

  void _onHover(bool hovering) {
    if (_isHovered != hovering) {
      setState(() {
        _isHovered = hovering;
        _updateBreathing();
      });
    }
  }

  void _updateBreathing() {
    if (isActive) {
      _breathingController.repeat(reverse: true);
    } else {
      _breathingController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedScale(
        scale: isActive ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutBack,
        child: AnimatedBuilder(
          animation: _breathingController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + _breathingController.value,
              child: child,
            );
          },
          child: widget.builder(context, _focusNode),
        ),
      ),
    );
  }
}
