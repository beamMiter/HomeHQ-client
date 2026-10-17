/// What can be added, in the order it is offered. Air conditioners come first:
/// they are what the app has the most to show for.
///
/// There is no plain fan: nobody buys one to switch on and off. The air cooler
/// is the fan that moves about the house; a fan added before this (the server
/// still knows 'fan') is shown as it always was.
const kApplianceKinds = [
  'aircon',
  'cooler',
  'light',
  'plug',
  'heater',
  'other',
];

/// Air-conditioner makers common in Thailand. Only suggestions: any text goes.
const kAirconBrands = [
  'Daikin',
  'Mitsubishi Electric',
  'Mitsubishi Heavy',
  'Panasonic',
  'LG',
  'Samsung',
  'Haier',
  'Carrier',
  'Midea',
  'Toshiba',
  'Sharp',
  'Hitachi',
  'Saijo Denki',
  'Central Air',
  'TCL',
  'Gree',
];

/// Air-cooler makers common in Thailand. Only suggestions: any text goes.
const kCoolerBrands = [
  'Hatari',
  'Masterkool',
  'Sharp',
  'Clarte',
  'Accord Prevail',
  'Midea',
];

/// How an appliance can be reached.
enum ConnectionMethod {
  /// Simulated by the server: nothing real is controlled.
  demo,

  /// The appliance (or its adapter) talks to its maker's cloud.
  wifi,

  /// A Wi-Fi IR blaster sends the remote's signals.
  ir,

  /// Through a Home Assistant the household already runs.
  homeAssistant;

  /// What the server calls it.
  String get id => switch (this) {
    demo => 'demo',
    wifi => 'wifi',
    ir => 'ir',
    homeAssistant => 'homeassistant',
  };

  /// Whether the server can make this connection today. Only the simulated
  /// one exists; the others show what they will need.
  bool get available => this == demo;
}
