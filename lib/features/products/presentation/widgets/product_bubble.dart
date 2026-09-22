import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum ProductAdd { active, frequent }

class ProductBubble extends StatefulWidget {
  const ProductBubble({
    super.key,
    required this.label,
    required this.amount,
    this.icon,
    this.onTap,
    this.onLongPress,
    this.longPressDuration = const Duration(milliseconds: 400),
    required this.productAdd,
    this.animateOnEntry = false,
  });

  final String label;
  final int amount;
  final String? icon;
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
    final themeProvider = context.watch<ThemeProvider>();
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
              boxShadow: [BoxShadow(color: Colors.black, spreadRadius: 1.5)],
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.amount > 1)
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(8),
                          ),
                        ),

                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${widget.amount}',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight(500)),
                          ),
                        ),
                      ),
                    if (widget.icon != null &&
                        themeProvider.availableIconsSvg.containsKey(
                          widget.icon,
                        )) ...{
                      if (widget.amount < 2) Container(),
                      Container(
                        height: 28,
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: SvgPicture.asset(
                            themeProvider.availableIconsSvg[widget.icon]!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                          // Icon(
                          //   themeProvider.availableIcons[widget.icon],
                          //   size: 35,
                          //   color: Colors.deepPurple,
                          //   shadows: themeProvider.shadowsSoft,
                          // ),
                        ),
                      ),
                    },
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  child: Center(
                    child: Stack(
                      children: [
                        AutoSizeText(
                          widget.label,
                          maxLines: 3,
                          minFontSize: 6,
                          stepGranularity: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 3
                              ..color = Colors.black,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: Offset(0, 0),
                              ),
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: Offset(0, 0),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        AutoSizeText(
                          widget.label,
                          maxLines: 3,
                          minFontSize: 6,
                          stepGranularity: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(),
              ],
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
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: interactiveBubble,
    );
  }
}
