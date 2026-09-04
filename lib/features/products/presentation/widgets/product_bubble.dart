import 'dart:async';

import 'package:flutter/material.dart';

enum ProductAdd { active, frequent }

class ProductBubble extends StatefulWidget {
  const ProductBubble({
    super.key,
    required this.label,
    required this.amount,
    this.onTap,
    this.onLongPress,
    this.longPressDuration = const Duration(milliseconds: 400),
    required this.productAdd,
    this.animateOnEntry = false,
  });

  final String label;
  final int amount;
  final ProductAdd productAdd;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Duration longPressDuration;
  final bool animateOnEntry;

  @override
  State<ProductBubble> createState() => _ProductBubbleState();
}

class _ProductBubbleState extends State<ProductBubble> {
  Timer? _longPressTimer;
  bool _longPressTriggered = false;

  void _startLongPressTimer() {
    _longPressTriggered = false;
    _longPressTimer?.cancel();
    if (widget.onLongPress == null) return;

    _longPressTimer = Timer(widget.longPressDuration, () {
      _longPressTriggered = true;
      widget.onLongPress?.call();
    });
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _handleTap() {
    if (_longPressTriggered) {
      _longPressTriggered = false;
      return;
    }
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _cancelLongPressTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: widget.productAdd == ProductAdd.active
                  ? Colors.orange
                      : widget.productAdd == ProductAdd.frequent
                  ? Colors.green
                  : Colors.grey,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black, spreadRadius: 1)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Center(
                child: Stack(
                  children: [
                    Text(
                      widget.amount > 1 ? "${widget.label}\n(${widget.amount})"
                      : widget.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      widget.amount > 1 ? "${widget.label}\n(${widget.amount})"
                      : widget.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final interactiveBubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startLongPressTimer(),
      onTapUp: (_) => _cancelLongPressTimer(),
      onTapCancel: _cancelLongPressTimer,
      child: bubble,
    );

    if (!widget.animateOnEntry) return interactiveBubble;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
      builder: (context, opacity, child) => Opacity(
        opacity: opacity,
        child: child,
      ),
      child: interactiveBubble,
    );
  }
}
