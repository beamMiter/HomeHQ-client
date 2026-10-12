import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/contractor_type.dart';
import '../../shared/app_colors.dart';
import '../../l10n/l10n.dart';

/// A tear-drop map pin coloured and iconed by the contractor's trade.
///
/// Its tip is the bottom-centre of the widget, so place it in a flutter_map
/// `Marker` with `alignment: Alignment.topCenter` and let the child sit at the
/// bottom of the marker box.
class ContractorPin extends StatelessWidget {
  const ContractorPin({super.key, required this.type, this.selected = false});

  final ContractorType type;
  final bool selected;

  static const double width = 40;
  static const double height = 46;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.3 : 1.0,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // A rounded square with one sharp corner, turned 45° so the sharp
            // corner points down: that is the tear-drop.
            Positioned(
              left: 1,
              top: 0,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    // Navy at rest; the brand blue when picked.
                    color: selected ? AppColors.softBlue : AppColors.deepNavy,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(19),
                      topRight: Radius.circular(19),
                      bottomLeft: Radius.circular(19),
                      bottomRight: Radius.circular(3),
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: selected ? 14 : 8,
                        offset: const Offset(0, 3),
                        color:
                            (selected ? AppColors.softBlue : AppColors.deepNavy)
                                .withValues(alpha: selected ? 0.5 : 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 9,
              child: Icon(type.icon, size: 20, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "you are here" dot: a solid blue point with a soft pulse around it.
///
/// The pulse is skipped when the platform asks to reduce motion.
class MyLocationDot extends StatefulWidget {
  const MyLocationDot({
    super.key,
    this.color = AppColors.softBlue,
    this.size = 20,
  });

  final Color color;
  final double size;

  @override
  State<MyLocationDot> createState() => _MyLocationDotState();
}

class _MyLocationDotState extends State<MyLocationDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _ac.stop();
    } else if (!_ac.isAnimating) {
      _ac.repeat();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.size;
    final maxRing = dot * 3.2;
    return SizedBox(
      width: maxRing,
      height: maxRing,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (_, _) {
          final t = Curves.easeOut.transform(_ac.value);
          final ring = dot + (maxRing - dot) * t;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: ring,
                height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.28 * (1 - t)),
                ),
              ),
              Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 6,
                      offset: Offset(0, 2),
                      color: Color(0x40000000),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The small label that floats above [MyLocationDot].
class YouAreHereLabel extends StatelessWidget {
  const YouAreHereLabel({
    super.key,
    this.text,
    this.color = AppColors.softBlue,
  });


  /// Defaults to the translated "You are here".
  final String? text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 3),
            color: Color(0x26000000),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.navigation_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text ?? context.l10n.contYouAreHere,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
