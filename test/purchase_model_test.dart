import 'package:flutter_test/flutter_test.dart';

import 'package:homehq/models/purchase_model.dart';

// The shape the server really sends for a purchase with no items or optional
// fields (what the seed script makes): the keys are simply absent. Parsing it
// used to throw, and the whole Purchases page said "Couldn't load the data".
void main() {
  const bare = <String, dynamic>{
    'id': 'p1',
    'title': 'Cleaning supplies',
    'note': 'mop',
    'amount_estimated': 500,
    'currency': 'THB',
    'status': 'planned',
    'requester_id': 'u1',
    'editable_until': '2026-08-25T01:07:22.403877+07:00',
    'created_at': '2026-08-25T00:57:22.403877+07:00',
    'updated_at': '2026-08-25T00:57:22.403877+07:00',
  };

  test('a purchase with no items key parses, with no items', () {
    final p = Purchase.fromJson(bare);
    expect(p.items, isEmpty);
    expect(p.title, 'Cleaning supplies');
    expect(p.amountEstimated, 500);
    expect(p.category, isNull);
    expect(p.buyerId, isNull);
  });

  test('a null items list parses the same way', () {
    expect(Purchase.fromJson({...bare, 'items': null}).items, isEmpty);
  });

  test('items that are there are kept', () {
    final p = Purchase.fromJson({
      ...bare,
      'items': [
        {'name': 'Mop', 'qty': 2},
      ],
    });
    expect(p.items, hasLength(1));
    expect(p.items.single.name, 'Mop');
  });
}
