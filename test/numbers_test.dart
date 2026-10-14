import 'package:flutter_test/flutter_test.dart';

import 'package:homehq/utils/numbers.dart';

void main() {
  test('a whole quantity has no ".0"', () {
    expect(qtyText(2), '2');
    expect(qtyText(2.0), '2');
    expect(qtyText(10.0), '10');
    expect(qtyText(0), '0');
  });

  test('a fraction is kept', () {
    expect(qtyText(1.5), '1.5');
    expect(qtyText(0.25), '0.25');
  });
}
