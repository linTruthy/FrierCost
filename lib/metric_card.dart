import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? accentColor;
  final bool isPositive;
  final bool showTrendIndicator;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.accentColor,
    this.isPositive = true,
    this.showTrendIndicator = false,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use provided accent color or derive from theme
    final Color effectiveAccentColor =
        widget.accentColor ??
        (widget.isPositive ? colorScheme.primary : Colors.redAccent);

    // Create gradient based on accent color
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        effectiveAccentColor.withValues(alpha:  0.05),
        effectiveAccentColor.withValues(alpha:  0.15),
      ],
    );

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovering = true;
          _controller.forward();
        });
      },
      onExit: (_) {
        setState(() {
          _isHovering = false;
          _controller.reverse();
        });
      },
      cursor: SystemMouseCursors.click,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: 200,
          child: Card(
                elevation: _isHovering ? 8 : 2,
                shadowColor: effectiveAccentColor.withValues(alpha:  0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: effectiveAccentColor.withValues( alpha: 
                      _isHovering ? 0.5 : 0.2,
                    ),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: gradient,
                  ),
                  child: Semantics(
                    label: '${widget.title} metric card',
                    value: widget.value,
                    hint:
                        'Shows the ${widget.title} metric with value ${widget.value}',
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  color: effectiveAccentColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 
                                      0.8,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                      widget.value,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    )
                                    .animate(
                                      onPlay:
                                          (controller) => controller.repeat(),
                                    )
                                    .shimmer(
                                      duration: 2.seconds,
                                      color: effectiveAccentColor.withValues(alpha: 
                                        0.3,
                                      ),
                                    ),
                              ),
                              if (widget.showTrendIndicator)
                                Icon(
                                  widget.isPositive
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  color:
                                      widget.isPositive
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                  size: 24,
                                ).animate().scaleXY(
                                  curve: Curves.easeOut,
                                  duration: 600.ms,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(
                begin: 0.2,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutQuad,
              )
              .then()
              .shimmer(delay: 200.ms, duration: 1200.ms)
              .then()
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(
                begin: 1,
                end: 1.02,
                duration: 3.seconds,
                curve: Curves.easeInOut,
              ),
        ),
      ),
    );
  }
}
