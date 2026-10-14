/// A quantity as people write it: "2", not "2.0"; "1.5" stays "1.5".
String qtyText(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toString();
}
