// lib/state/notes_provider.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';

/// พารามิเตอร์ query สำหรับ list (immutable)
class NotesQuery {
  final int limit;
  final int offset;
  const NotesQuery({this.limit = 50, this.offset = 0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotesQuery &&
          runtimeType == other.runtimeType &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(limit, offset);
}

/// Provider หลัก: ดึงโน้ตจาก API จริง (เลิกใช้ mock)
final notesProvider = FutureProvider.autoDispose.family<List<Note>, NotesQuery>(
  (ref, query) async {
    final repo = ref.read(notesRepositoryProvider);

    // ให้ provider อยู่รอดชั่วคราวเวลาเปลี่ยนหน้า/เลื่อน tab
    final link = ref.keepAlive();
    Timer? timer;
    ref.onCancel(() {
      // รอ 30s ก่อนปิดจริง ลดการรีเฟรชถี่ ๆ เวลา user สลับจอ
      timer = Timer(const Duration(seconds: 30), () {
        link.close();
      });
    });
    ref.onResume(() {
      timer?.cancel();
    });

    // ยกเลิก request เมื่อ provider ถูก dispose
    final cancel = CancelToken();
    ref.onDispose(() {
      if (!cancel.isCancelled) cancel.cancel('notesProvider disposed');
    });

    // A failed request goes to the screen as it is; the screen words it
    // (friendlyError), so a server problem reads as one rather than as a
    // paragraph about requests.
    return repo.list(
      limit: query.limit,
      offset: query.offset,
      cancelToken: cancel,
    );
  },
);
