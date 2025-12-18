import 'package:flutter/material.dart';

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
    this.breathingIntensity = 0.05, // This value will be added to the base scale, so the max scale will be scale + breathingIntensity
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
  
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);

    // 3. Setup Breathing Animation
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

  // 4. Logic to Start/Stop Breathing
  void _updateBreathing() {
    if (_isHovered || _isFocused) {
      _breathingController.repeat(reverse: true);
    } else {
      _breathingController.animateTo(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isHovered || _isFocused;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      cursor: SystemMouseCursors.click,
      // 5. Layer 1: The Main Zoom (Smooth Enter/Exit)
      child: AnimatedScale(
        scale: isActive ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutBack,
        // 6. Layer 2: The Breathing Pulse (Continuous Loop)
        child: AnimatedBuilder(
          animation: _breathingController,
          builder: (context, child) {
            return Transform.scale(
              // Current Base Scale * (1 + Breathing Amount)
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