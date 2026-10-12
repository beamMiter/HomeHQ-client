import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/home_camera.dart';
import '../../shared/app_colors.dart';
import '../../state/cameras_provider.dart';

/// A row of small pictures to jump to another camera without going back.
class CameraStrip extends ConsumerWidget {
  const CameraStrip({
    super.key,
    required this.cameras,
    required this.currentId,
    required this.onSelect,
  });

  final List<HomeCamera> cameras;
  final String currentId;
  final void Function(HomeCamera camera) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cameras.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cameras[i];
          final selected = c.id == currentId;
          return GestureDetector(
            key: ValueKey('strip-${c.id}'),
            onTap: () => onSelect(c),
            child: SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.softBlue
                            : AppColors.cardBorder,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: c.online
                          ? _Thumb(id: c.id)
                          : const ColoredBox(
                              color: Color(0xFFE5E9F2),
                              child: Center(
                                child: Icon(
                                  Icons.videocam_off_rounded,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.softBlue : AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(cameraSnapshotProvider(id)).value;
    if (bytes == null) {
      return const ColoredBox(
        color: AppColors.bgSoft,
        child: Center(
          child: Icon(Icons.videocam_outlined, color: AppColors.textMuted),
        ),
      );
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    );
  }
}
