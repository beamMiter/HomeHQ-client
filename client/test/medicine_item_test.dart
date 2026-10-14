import 'package:flutter_test/flutter_test.dart';

import 'package:homeservice/models/medicine_item.dart';

// The list rows as the server sends them: the item nested, the totals beside it.
void main() {
  Map<String, dynamic> row({Object? next}) => {
    'item': {
      'id': 'm1',
      'name': 'Cetirizine',
      'form': 'tablet',
      'unit': 'tab',
      'category': 'antihistamine',
    },
    'total_qty': 10,
    'low_stock': false,
    'expiring': false,
    'next_expiry_date': next,
  };

  test('a row with no expiry date reads fine', () {
    final m = MedicineItem.fromItemSummaryJson(row());
    expect(m.name, 'Cetirizine');
    expect(m.stockQty, 10);
    expect(m.nextExpiryDate, isNull);
    expect(m.status?.expired, isFalse);
  });

  test('the expiry date is read from next_expiry_date', () {
    final m = MedicineItem.fromItemSummaryJson(
      row(next: '2031-05-01T00:00:00Z'),
    );
    expect(m.nextExpiryDate?.year, 2031);
    expect(m.status?.expired, isFalse);
  });

  test('a past date is expired', () {
    final m = MedicineItem.fromItemSummaryJson(
      row(next: '2020-01-01T00:00:00Z'),
    );
    expect(m.status?.expired, isTrue);
  });
}
