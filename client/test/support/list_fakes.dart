import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'package:homeservice/models/bill.dart';
import 'package:homeservice/models/medicine_item.dart';
import 'package:homeservice/models/note.dart';
import 'package:homeservice/models/purchase_model.dart';
import 'package:homeservice/repositories/bill_repository.dart';
import 'package:homeservice/repositories/medicine_repository.dart';
import 'package:homeservice/repositories/notes_repository.dart';
import 'package:homeservice/repositories/purchase_repository.dart';
import 'package:homeservice/screens/bills_screen.dart';
import 'package:homeservice/screens/medicine_screen.dart';
import 'package:homeservice/screens/notes_screen.dart';
import 'package:homeservice/screens/purchase_screen.dart';
import 'package:homeservice/state/bills_provider.dart';
import 'package:homeservice/state/medicine_provider.dart';
import 'package:homeservice/state/purchase_providers.dart';

// Shared by the list-screen tests: the four list screens (Bills, Purchases,
// Medicine, Notes) wired to repositories that count their fetches.

/// What a list repository answers, and how often it was asked.
class ListFetch<T> {
  ListFetch(this.items);
  final List<T> items;
  int calls = 0;

  /// While set, the next fetch stays pending until it is completed.
  Completer<List<T>>? hold;

  /// While true, fetches fail.
  bool failing = false;

  Future<List<T>> next() {
    calls++;
    if (failing) return Future.error(Exception('boom'));
    return hold?.future ?? Future.value(items);
  }
}

// `noSuchMethod` keeps the stand-ins independent of each repository's full
// surface: only `list` is ever called by these screens.
class CountingBills implements BillRepository {
  CountingBills(this.f);
  final ListFetch<Bill> f;
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.memberName == #list ? f.next() : super.noSuchMethod(i);
}

class CountingPurchases implements PurchaseRepository {
  CountingPurchases(this.f);
  final ListFetch<Purchase> f;
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.memberName == #list ? f.next() : super.noSuchMethod(i);
}

class CountingMedicines implements MedicineRepository {
  CountingMedicines(this.f);
  final ListFetch<MedicineItem> f;
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.memberName == #list ? f.next() : super.noSuchMethod(i);
}

class CountingNotes implements NotesRepository {
  CountingNotes(this.f);
  final ListFetch<Note> f;
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.memberName == #list ? f.next() : super.noSuchMethod(i);
}

final sampleBills = [
  for (var n = 1; n <= 2; n++)
    Bill.fromJson({
      'id': 'b$n',
      'type': 'electric',
      'title': 'Electric bill $n',
      'amount': 100.0 * n,
      'due_date': '2026-11-0${n}T00:00:00Z',
      'status': 'unpaid',
      'created_by': 'u',
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-01T00:00:00Z',
    }),
];

final samplePurchases = [
  for (var n = 1; n <= 2; n++)
    Purchase(
      id: 'p$n',
      title: 'Supplies $n',
      items: const [],
      status: PurchaseStatus.planned,
      requesterId: 'u',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    ),
];

final sampleMedicines = [
  MedicineItem(id: 'm1', name: 'Paracetamol', stockQty: 10),
  MedicineItem(id: 'm2', name: 'Antihistamine', stockQty: 4),
];

final sampleNotes = [
  for (var n = 1; n <= 2; n++)
    Note.fromJson({
      'id': 'n$n',
      'title': 'Note $n',
      'content': '',
      'created_at': '2026-10-01T00:00:00Z',
    }),
];

/// A list screen wired to a counting repository.
class BuiltScreen {
  BuiltScreen({
    required this.screen,
    required this.overrides,
    required this.calls,
    required this.setFailing,
    required this.hold,
    required this.release,
  });

  final Widget screen;
  final List<Override> overrides;
  final int Function() calls;
  final void Function(bool) setFailing;

  /// Makes the next fetch stay in flight until [release].
  final void Function() hold;
  final void Function() release;
}

BuiltScreen buildScreen<T>({
  required Widget screen,
  required List<T> items,
  required List<Override> Function(ListFetch<T>) overrides,
}) {
  final f = ListFetch<T>(items);
  return BuiltScreen(
    screen: screen,
    overrides: overrides(f),
    calls: () => f.calls,
    setFailing: (v) => f.failing = v,
    hold: () => f.hold = Completer<List<T>>(),
    release: () {
      final h = f.hold!;
      f.hold = null;
      h.complete(f.items);
    },
  );
}

typedef MakeScreen = BuiltScreen Function({required bool filled});

final Map<String, MakeScreen> listScreens = {
  'Bills': ({required filled}) => buildScreen<Bill>(
    screen: const BillsScreen(),
    items: filled ? sampleBills : [],
    overrides: (f) => [
      billRepositoryProvider.overrideWithValue(CountingBills(f)),
    ],
  ),
  'Purchases': ({required filled}) => buildScreen<Purchase>(
    screen: const PurchaseScreen(),
    items: filled ? samplePurchases : [],
    overrides: (f) => [
      purchaseRepoProvider.overrideWithValue(CountingPurchases(f)),
    ],
  ),
  'Medicine': ({required filled}) => buildScreen<MedicineItem>(
    screen: const MedicineScreen(),
    items: filled ? sampleMedicines : [],
    overrides: (f) => [
      medicineRepoProvider.overrideWithValue(CountingMedicines(f)),
    ],
  ),
  'Notes': ({required filled}) => buildScreen<Note>(
    screen: const NotesScreen(),
    items: filled ? sampleNotes : [],
    overrides: (f) => [
      notesRepositoryProvider.overrideWithValue(CountingNotes(f)),
    ],
  ),
};
