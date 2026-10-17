// lib/screens/notes_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../state/notes_provider.dart';
import '../repositories/notes_repository.dart';

// ✅ ใช้ Header แบบเดียวกับหน้าอื่น
import '../widgets/more_menu.dart';
import '../widgets/list_empty_state.dart';
import '../widgets/add_fab.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/header_row.dart';
import '../widgets/error_state.dart';
import '../widgets/page_loading.dart';
import '../widgets/toast.dart';
import '../widgets/refresh.dart';
import '../l10n/friendly_error.dart';
import '../l10n/l10n.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  static const _query = NotesQuery(limit: 50, offset: 0);

  final _q = TextEditingController();
  final _scroll = ScrollController();

  // ฟิลเตอร์ทั้งหมด (อยู่ในแผงเดียว)
  bool _filtersOpen = false; // เปิด/ปิดทั้งแผง
  _StatusTab _status = _StatusTab.all;
  String? _category; // bills | chores | appointment | general | null
  bool? _pinned; // true | false | null
  String _tag = 'all';

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pull() =>
      pullRefresh(() => ref.refresh(notesProvider(_query).future));

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider(_query));
    const accent = Color(0xFF1F4E9E);

    final reloading = watchReloading(ref, 'notes');
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          centerTitle: false,
        ),
        visualDensity: VisualDensity.compact,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: TopNavBar(
          title: 'Important Notes',
          actions: [
            RefreshButton(
              busy: reloading || notes.isReloadingData,
              onPressed: () => runReload(
                ref,
                'notes',
                () => ref.refresh(notesProvider(_query).future),
              ),
            ),
            IconButton(
              tooltip: context.l10n.commonClearFilters,
              onPressed: _clearAll,
              icon: const Icon(Icons.filter_alt_off),
            ),
          ],
        ),
        floatingActionButton: AddFab(
          color: accent,
          tooltip: context.l10n.notesNew,
          onPressed: () => _openEditor(context, ref),
        ),
        body: ReloadOverlay(
          active: reloading,
          child: Column(
            children: [
              // ✅ Header เดียวกับหน้าอื่น: Search ทางซ้าย + ปุ่ม Filters ทางขวา
              HeaderRow(
                left: _SearchField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(() {}),
                ),
                right: _FilterButton(
                  isOpen: _filtersOpen,
                  activeCount: _activeFilterCount(),
                  onTap: () => setState(() => _filtersOpen = !_filtersOpen),
                ),
              ),

              // ✅ แผง Filters (กาง/หุบ) — เนื้อหาเหมือนเดิม
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 160),
                crossFadeState: _filtersOpen
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(context.l10n.commonStatus),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              _statusChip(
                                context.l10n.commonAll,
                                _StatusTab.all,
                              ),
                              _statusChip(
                                context.l10n.notesStatusActive,
                                _StatusTab.active,
                              ),
                              _statusChip(
                                context.l10n.notesStatusDone,
                                _StatusTab.done,
                              ),
                              _statusChip(
                                context.l10n.notesStatusOverdue,
                                _StatusTab.overdue,
                              ),
                              _statusChip(
                                context.l10n.notesPinned,
                                _StatusTab.pinned,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          _SectionLabel(context.l10n.notesCategory),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              _categoryChip(context.l10n.commonAll, null),
                              _categoryChip(
                                context.l10n.notesCatBills,
                                'bills',
                              ),
                              _categoryChip(
                                context.l10n.notesCatChores,
                                'chores',
                              ),
                              _categoryChip(
                                context.l10n.notesCatAppointment,
                                'appointment',
                              ),
                              _categoryChip(
                                context.l10n.notesCatGeneral,
                                'general',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          _SectionLabel(context.l10n.notesPinned),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              _pinnedChip(context.l10n.commonAll, null),
                              _pinnedChip(context.l10n.notesPinned, true),
                              _pinnedChip(context.l10n.notesUnpinned, false),
                            ],
                          ),
                          const SizedBox(height: 10),

                          _SectionLabel(context.l10n.notesTag),
                          const SizedBox(height: 6),
                          notes.maybeWhen(
                            data: (items) {
                              final set = <String>{};
                              for (final n in items) {
                                set.addAll(n.tags);
                              }
                              final list = set.toList()..sort();
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _tagChip(context.l10n.commonAll, 'all'),
                                    const SizedBox(width: 6),
                                    for (final t in list) ...[
                                      _tagChip('#$t', t),
                                      const SizedBox(width: 6),
                                    ],
                                  ],
                                ),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 12),
                          Row(
                            children: {
                              TextButton.icon(
                                onPressed: _clearAll,
                                icon: const Icon(Icons.clear_all, size: 18),
                                label: Text(context.l10n.commonClear),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                ),
                                onPressed: () {
                                  setState(() => _filtersOpen = false);
                                  _scroll.animateTo(
                                    0,
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeOut,
                                  );
                                },
                                icon: const Icon(Icons.check),
                                label: Text(context.l10n.commonApply),
                              ),
                            }.toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),

              // ✅ เนื้อหาหลัก (List/Refresh) — เหมือนเดิม
              Expanded(child: _buildBody(notes, accent)),
            ],
          ),
        ),
      ),
    );
  }

  // ==== Chips builders ====
  Widget _statusChip(String label, _StatusTab tab) => ChoiceChip(
    label: Text(label),
    selected: _status == tab,
    onSelected: (_) => setState(() => _status = tab),
  );

  Widget _categoryChip(String label, String? v) => ChoiceChip(
    label: Text(label),
    selected: (v == null && (_category == null || _category!.isEmpty))
        ? true
        : _category == v,
    onSelected: (_) => setState(() => _category = v),
  );

  Widget _pinnedChip(String label, bool? v) => ChoiceChip(
    label: Text(label),
    selected: _pinned == v,
    onSelected: (_) => setState(() => _pinned = v),
  );

  Widget _tagChip(String label, String v) => ChoiceChip(
    label: Text(label),
    selected: _tag == v,
    onSelected: (_) => setState(() => _tag = v),
  );

  // ==== Body ====
  Widget _buildBody(AsyncValue<List<Note>> notes, Color accent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: notes.when(
        loading: () => const PageLoading(),
        error: (e, _) => RefreshableFill(
          onRefresh: _pull,
          child: ErrorState(
            title: context.l10n.commonLoadFailed,
            error: e,
            icon: Icons.error_outline,
            retryLabel: context.l10n.commonTryAgain,
            onRetry: () => ref.refresh(notesProvider(_query)),
          ),
        ),
        data: (items) {
          final filtered = _applyFilters(
            items,
            q: _q.text,
            tag: _tag,
            category: _category,
            pinned: _pinned,
          );
          final byStatus = filtered.where((n) {
            switch (_status) {
              case _StatusTab.all:
                return true;
              case _StatusTab.active:
                return !n.isDone && !n.isOverdue;
              case _StatusTab.done:
                return n.isDone;
              case _StatusTab.overdue:
                return n.isOverdue;
              case _StatusTab.pinned:
                return n.pinned == true;
            }
          }).toList();

          if (byStatus.isEmpty) {
            // No notes at all is not the same as none matching the filters.
            final none = items.isEmpty;
            return RefreshableFill(
              onRefresh: _pull,
              child: ListEmptyState(
                centered: true,
                icon: none
                    ? Icons.event_note_outlined
                    : Icons.search_off_rounded,
                title: none
                    ? context.l10n.notesEmptyTitle
                    : context.l10n.notesNoMatch,
                subtitle: none
                    ? context.l10n.notesEmptyHint
                    : context.l10n.notesNoMatchHint,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _pull,
            child: ListView.separated(
              controller: _scroll,
              // A controller makes the list non-primary, so without this a
              // short list can't be pulled down to refresh.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: byStatus.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _NoteCard(
                note: byStatus[i],
                accent: accent,
                onEdit: () => _openEditor(context, ref, note: byStatus[i]),
                onDelete: () => _confirmDelete(context, ref, byStatus[i]),
                onTogglePin: () => _togglePin(ref, byStatus[i]),
                onToggleDone: () => _toggleDone(ref, byStatus[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==== Logic ====
  void _clearAll() {
    setState(() {
      _q.clear();
      _status = _StatusTab.all;
      _category = null;
      _pinned = null;
      _tag = 'all';
      _filtersOpen = false;
    });
  }

  int _activeFilterCount() {
    var c = 0;
    if (_category != null && _category!.isNotEmpty) c++;
    if (_pinned != null) c++;
    if (_tag != 'all') c++;
    if (_q.text.trim().isNotEmpty) c++;
    if (_status != _StatusTab.all) c++; // นับสถานะด้วย
    return c;
  }

  List<Note> _applyFilters(
    List<Note> items, {
    required String q,
    required String tag,
    required String? category,
    required bool? pinned,
  }) {
    Iterable<Note> res = items;

    if (tag != 'all') res = res.where((n) => n.tags.contains(tag));
    if (category != null && category.isNotEmpty) {
      res = res.where((n) => (n.category ?? '').toLowerCase() == category);
    }
    if (pinned != null) res = res.where((n) => (n.pinned ?? false) == pinned);
    if (q.trim().isNotEmpty) {
      final k = q.toLowerCase();
      res = res.where(
        (n) =>
            n.title.toLowerCase().contains(k) ||
            n.body.toLowerCase().contains(k) ||
            n.tags.any((t) => t.toLowerCase().contains(k)),
      );
    }
    return res.toList();
  }

  Future<void> _toggleDone(WidgetRef ref, Note note) async {
    final repo = ref.read(notesRepositoryProvider);
    final isDone = note.doneAt != null;
    try {
      final updated = isDone
          ? await repo.unsetDone(note.id)
          : await repo.setDone(note.id);
      if (!mounted) return;
      AppToast.success(
        updated.doneAt != null
            ? context.l10n.notesMarkedDone
            : context.l10n.notesMarkedUndone,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      AppToast.error(_shortError(e, fallback: context.l10n.notesErrDone));
    } finally {
      ref.invalidate(notesProvider(_query));
    }
  }

  Future<void> _togglePin(WidgetRef ref, Note note) async {
    final repo = ref.read(notesRepositoryProvider);
    try {
      final toggled = await repo.setPinned(note.id, !(note.pinned ?? false));
      if (mounted) {
        AppToast.success(
          toggled.pinned == true
              ? context.l10n.notesPinned
              : context.l10n.notesUnpinned,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      AppToast.error(_shortError(e, fallback: context.l10n.notesErrPin));
    } finally {
      ref.invalidate(notesProvider(_query));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.notesDeleteTitle),
        content: Text(context.l10n.notesDeleteBody(note.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(notesRepositoryProvider).delete(note.id);
      if (context.mounted) {
        AppToast.success(context.l10n.notesDeleted);
      }
    } on DioException catch (e) {
      if (!context.mounted) return;
      AppToast.error(_shortError(e, fallback: context.l10n.notesErrDelete));
    } finally {
      ref.invalidate(notesProvider(_query));
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Note? note,
  }) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EditorSheet(note: note, accent: const Color(0xFF1F4E9E)),
    );
    if (result == null) return;

    final repo = ref.read(notesRepositoryProvider);
    final cancel = CancelToken();

    try {
      if (note == null) {
        await repo.create(
          title: result.title,
          content: result.body.isEmpty ? null : result.body,
          category: result.category,
          pinned: result.pinned,
          cancelToken: cancel,
        );
        if (context.mounted) {
          AppToast.success(context.l10n.notesAdded);
        }
      } else {
        await repo.update(
          id: note.id,
          title: result.title,
          content: result.body,
          category: result.category,
          pinned: result.pinned,
          cancelToken: cancel,
        );
        if (context.mounted) {
          AppToast.success(context.l10n.notesEdited);
        }
      }
    } on DioException catch (e) {
      if (!context.mounted) return;
      AppToast.error(_shortError(e, fallback: context.l10n.notesErrSave));
    } finally {
      ref.invalidate(notesProvider(_query));
    }
  }

  String _shortError(DioException e, {String? fallback}) {
    final what = fallback ?? context.l10n.commonError;
    final sc = e.response?.statusCode;
    if (sc == 401) return context.l10n.notesErr401(what);
    if (sc == 404) return context.l10n.notesErr404(what);
    return '$what: ${friendlyError(context.l10n, e)}';
  }
}

/* ===== Helpers ===== */

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: const Color(0xFF374151),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

enum _StatusTab { all, active, done, overdue, pinned }

extension _NoteComputed on Note {
  bool get isDone => doneAt != null;
  bool get isOverdue =>
      !isDone && dueAt != null && dueAt!.isBefore(DateTime.now());
  bool get isEdited => updatedAt != null && updatedAt!.isAfter(createdAt);
}

/* ===== Search, Card, Editor, Error ===== */

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
  }

  void _listener() => setState(() {});
  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: context.l10n.notesSearchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: context.l10n.commonClear,
                icon: const Icon(Icons.close),
                onPressed: () {
                  widget.controller.clear();
                  widget.onClear();
                },
              ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}

// ปุ่ม Filters ทางขวาใน HeaderRow (แจ้งจำนวน Active + toggle เปิด/ปิด)
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.isOpen,
    required this.activeCount,
    required this.onTap,
  });
  final bool isOpen;
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.tune, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.commonFilters),
          if (hasActive) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(width: 2),
          Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 18),
        ],
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.note,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
    required this.onToggleDone,
  });

  final Note note;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleDone;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> with TickerProviderStateMixin {
  bool _expanded = false;

  static const _previewChars = 140;
  static const _previewLines = 3;

  /// There is more to show than the preview does (the same limits the preview
  /// itself uses), so the card can unfold.
  bool get _canExpand {
    final body = widget.note.body;
    return body.length > _previewChars ||
        '\n'.allMatches(body.trim()).length >= _previewLines;
  }

  String _previewBody(String body, {int limit = 140}) {
    if (_expanded) return body;
    if (body.length <= limit) return body;
    return '${body.substring(0, limit).trimRight()} …';
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final editedSuffix = n.isEdited ? ' (edited)' : '';

    final statusPill = n.isDone
        ? _Pill(
            text: context.l10n.notesStatusDone,
            color: Color(0xFFE8FFF1),
            textColor: Color(0xFF16A34A),
          )
        : (n.isOverdue
              ? _Pill(
                  text: context.l10n.notesStatusOverdue,
                  color: Color(0xFFFFEEF0),
                  textColor: Color(0xFFDC2626),
                )
              : _Pill(
                  text: context.l10n.notesStatusActive,
                  color: Color(0xFFEFF6FF),
                  textColor: Color(0xFF2563EB),
                ));

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Only a note with more to show reacts to a tap.
        onTap: _canExpand ? () => setState(() => _expanded = !_expanded) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${n.title}$editedSuffix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    df.format(n.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // This card unfolds in place (it does not open another page),
                  // so it shows an arrow that turns, not a ">", and only when
                  // there is something more to read.
                  if (_canExpand) ...[
                    const SizedBox(width: 2),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: const Color(0xFF6B7280),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // Pills
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  statusPill,
                  const _Pill(
                    text: 'general',
                    color: Color(0xFFF3F4F6),
                    textColor: Color(0xFF374151),
                  ),
                  if (n.tags.isNotEmpty)
                    _Pill(
                      text: '#${n.tags.first}',
                      color: const Color(0xFFEFF6FF),
                      textColor: const Color(0xFF2563EB),
                    ),
                  if (n.pinned == true)
                    _Pill(
                      text: context.l10n.notesPinned,
                      color: Color(0xFFEFF4FF),
                      textColor: Color(0xFF2563EB),
                    ),
                ],
              ),

              if (n.body.trim().isNotEmpty) const SizedBox(height: 8),
              if (n.body.trim().isNotEmpty)
                AnimatedSize(
                  duration: const Duration(milliseconds: 140),
                  child: Text(
                    _previewBody(n.body, limit: 140),
                    maxLines: _expanded ? 8 : 3,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.25,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),

              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.notesCopy,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: '${n.title}\n\n${n.body}'.trim()),
                      );
                      if (context.mounted) {
                        AppToast.success(context.l10n.notesCopied);
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  IconButton(
                    tooltip: n.isDone
                        ? context.l10n.notesMarkUndone
                        : context.l10n.notesMarkDone,
                    onPressed: widget.onToggleDone,
                    icon: Icon(
                      n.isDone ? Icons.undo : Icons.check_circle_outline,
                    ),
                  ),
                  const Spacer(),
                  // "⋯": the same place and look as on every detail page.
                  MoreMenuButton(
                    items: [
                      MoreMenuItem(
                        label: (n.pinned == true)
                            ? context.l10n.notesUnpin
                            : context.l10n.notesPin,
                        icon: (n.pinned == true)
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        onSelected: widget.onTogglePin,
                      ),
                      MoreMenuItem(
                        label: context.l10n.commonEdit,
                        icon: Icons.edit_outlined,
                        onSelected: widget.onEdit,
                      ),
                      MoreMenuItem(
                        label: context.l10n.commonDelete,
                        icon: Icons.delete_outline,
                        destructive: true,
                        onSelected: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    required this.textColor,
  });
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EditResult {
  _EditResult({
    required this.title,
    required this.body,
    required this.category,
    required this.pinned,
  });
  final String title;
  final String body;
  final String category;
  final bool pinned;
}

/* ===== Editor bottom sheet (เดิม) ===== */

class _EditorSheet extends StatefulWidget {
  const _EditorSheet({this.note, required this.accent});
  final Note? note;
  final Color accent;
  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _category;
  late bool _pinned;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
    _category = (widget.note?.category ?? 'general').toLowerCase();
    _pinned = widget.note?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              isEdit ? context.l10n.notesEditTitle : context.l10n.notesNew,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: context.l10n.notesFieldTitle,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                DropdownMenuItem(
                  value: 'general',
                  child: Text(context.l10n.notesCatGeneral),
                ),
                DropdownMenuItem(
                  value: 'bills',
                  child: Text(context.l10n.notesCatBills),
                ),
                DropdownMenuItem(
                  value: 'chores',
                  child: Text(context.l10n.notesCatChores),
                ),
                DropdownMenuItem(
                  value: 'appointment',
                  child: Text(context.l10n.notesCatAppointment),
                ),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'general'),
              decoration: InputDecoration(
                labelText: context.l10n.notesCategory,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
              title: Text(context.l10n.notesPinned),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: widget.accent,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: context.l10n.notesFieldContent,
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: Text(context.l10n.commonCancel),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: widget.accent),
                  onPressed: () {
                    final title = _title.text.trim();
                    if (title.isEmpty) {
                      AppToast.error(context.l10n.notesTitleRequired);
                      return;
                    }
                    Navigator.pop(
                      context,
                      _EditResult(
                        title: title,
                        body: _body.text,
                        category: _category,
                        pinned: _pinned,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: Text(
                    isEdit ? context.l10n.commonSave : context.l10n.notesCreate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
