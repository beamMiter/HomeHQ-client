import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../models/home_camera.dart';
import '../repositories/cameras_repository.dart';
import '../shared/app_colors.dart';
import '../state/cameras_provider.dart';
import '../widgets/error_state.dart';
import '../widgets/list_empty_state.dart';
import '../widgets/page_loading.dart';
import '../widgets/refresh.dart';
import '../widgets/toast.dart';
import '../widgets/top_nav_bar.dart';

/// The wording for a camera failure, in the app's language.
String cameraErrorText(AppLocalizations l10n, Object? error) {
  if (error is CameraException) {
    return switch (error.failure) {
      CameraFailure.misconfigured => l10n.camErrMisconfigured,
      CameraFailure.limited => l10n.camErrLimit,
      CameraFailure.offline => l10n.camErrOffline,
      CameraFailure.unsupported => l10n.camNotSupported,
      CameraFailure.disabled => l10n.camDisabledTitle,
      _ => l10n.camErrUnavailable,
    };
  }
  return l10n.camErrUnavailable;
}

/// Home Cameras: a grid of what each camera sees now. Tapping one plays it.
///
/// The video and its recordings stay with the camera vendor; this screen only
/// shows pictures and live streams the server fetched for us.
class CamerasScreen extends ConsumerWidget {
  const CamerasScreen({super.key});

  static const _key = 'cameras';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(camerasStatusProvider);
    final reloading = watchReloading(ref, _key);

    Future<void> reload() async {
      final s = await ref.refresh(camerasStatusProvider.future);
      if (s?.enabled == true) {
        await ref.read(camerasProvider.notifier).reload();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bgSoft,
      appBar: TopNavBar(
        // A feature name: not translated (see the home screen).
        title: 'Home Cameras',
        actions: [
          RefreshButton(
            busy: reloading,
            onPressed: () => runReload(ref, _key, reload),
          ),
        ],
      ),
      body: ReloadOverlay(
        active: reloading,
        child: status.when(
          loading: () => const PageLoading(),
          error: (e, _) => _Message(
            onRefresh: () => pullRefresh(reload),
            child: ErrorState(
              icon: Icons.error_outline,
              title: l10n.camLoadFailed,
              onRetry: () => ref.invalidate(camerasStatusProvider),
            ),
          ),
          data: (s) {
            if (s == null) {
              return _Message(
                onRefresh: () => pullRefresh(reload),
                child: ErrorState(
                  icon: Icons.cloud_off,
                  title: l10n.camLoadFailed,
                  onRetry: () => ref.invalidate(camerasStatusProvider),
                ),
              );
            }
            if (!s.enabled) {
              return _Message(
                onRefresh: () => pullRefresh(reload),
                child: ListEmptyState(
                  centered: true,
                  icon: Icons.videocam_off_outlined,
                  title: l10n.camDisabledTitle,
                  subtitle: l10n.camDisabledHint,
                ),
              );
            }
            return _CameraGrid(onRefresh: () => pullRefresh(reload));
          },
        ),
      ),
    );
  }
}

/// A centred message that can still be pulled down to refresh.
class _Message extends StatelessWidget {
  const _Message({required this.child, required this.onRefresh});
  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) =>
      RefreshableFill(onRefresh: onRefresh, child: child);
}

class _CameraGrid extends ConsumerWidget {
  const _CameraGrid({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cams = ref.watch(camerasProvider);

    return cams.when(
      loading: () => const PageLoading(),
      error: (e, _) => _Message(
        onRefresh: onRefresh,
        child: ErrorState(
          icon: Icons.error_outline,
          title: l10n.camLoadFailed,
          error: cameraErrorText(l10n, e),
          onRetry: () => ref.invalidate(camerasProvider),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return _Message(
            onRefresh: onRefresh,
            child: ListEmptyState(
              centered: true,
              icon: Icons.videocam_outlined,
              title: l10n.camEmptyTitle,
              subtitle: l10n.camEmptyHint,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: LayoutBuilder(
            builder: (context, box) {
              const gap = 12.0, pad = 16.0;
              final tileW = (box.maxWidth - pad * 2 - gap) / 2;
              // 16:10 picture; the name sits on it.
              final tileH = tileW * 10 / 16;
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(pad),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: gap,
                  mainAxisSpacing: gap,
                  mainAxisExtent: tileH,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _CameraTile(camera: items[i]),
              );
            },
          ),
        );
      },
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.camera});
  final HomeCamera camera;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Square corners, on this card only: it is what you tap to open a camera.
    // (Everything else on these screens keeps its usual rounding.)
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (!camera.online) {
            AppToast.info(l10n.camOfflineToast);
            return;
          }
          context.push(
            '/cameras/${Uri.encodeComponent(camera.id)}',
            extra: camera,
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Preview(camera: camera),
            // Darkens the bottom so the name reads on any picture.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 64,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC0B1220)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: camera.online
                          ? const Color(0xFF7DD3FC)
                          : Colors.white54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      camera.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // What this camera can do, at a glance.
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (camera.ptz)
                    const _Capability(icon: Icons.open_with_rounded),
                  if (camera.humanDetect)
                    Tooltip(
                      message: l10n.camHumanDetect,
                      child: const _Capability(icon: Icons.person_rounded),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Capability extends StatelessWidget {
  const _Capability({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black38,
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.camera});
  final HomeCamera camera;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (!camera.online) {
      return ColoredBox(
        color: const Color(0xFFE5E9F2),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.camOffline,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final snap = ref.watch(cameraSnapshotProvider(camera.id));
    // Keep the last picture while a new one loads, so the grid never blanks.
    final Uint8List? bytes = snap.value;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const _PreviewPlaceholder(broken: true),
      );
    }
    return _PreviewPlaceholder(broken: snap.pictureFailed);
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({this.broken = false});
  final bool broken;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgSoft,
      child: Center(
        child: Icon(
          broken ? Icons.videocam_off_rounded : Icons.videocam_outlined,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
