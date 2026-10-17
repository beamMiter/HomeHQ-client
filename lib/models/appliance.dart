/// One thing an appliance can be told to do, as the server describes it. The
/// app draws only the capabilities an appliance reports.
class ApplianceCapability {
  const ApplianceCapability({
    required this.key,
    required this.type,
    this.min = 0,
    this.max = 0,
    this.unit,
    this.options = const [],
    this.adminOnly = false,
  });

  /// 'power', 'brightness', 'temperature', 'mode', 'fan_speed', or one the app
  /// doesn't know (shown with its key).
  final String key;

  /// 'bool', 'int' or 'enum'.
  final String type;

  /// The range of an int capability.
  final int min;
  final int max;
  final String? unit;

  /// The values of an enum capability.
  final List<String> options;

  /// Only an admin may use this one. (Everybody may switch power.)
  final bool adminOnly;

  bool get isBool => type == 'bool';
  bool get isInt => type == 'int' && max > min;
  bool get isEnum => type == 'enum' && options.isNotEmpty;

  factory ApplianceCapability.fromJson(Map<String, dynamic> j) =>
      ApplianceCapability(
        key: (j['key'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        min: (j['min'] as num?)?.toInt() ?? 0,
        max: (j['max'] as num?)?.toInt() ?? 0,
        unit: j['unit']?.toString(),
        options: [
          for (final o in (j['options'] as List? ?? const [])) o.toString(),
        ],
        adminOnly: j['admin_only'] == true,
      );
}

/// What an appliance is, in one word, the way smart-home apps put it: on,
/// off, or offline. The thing to read first.
enum ApplianceStatus {
  /// Reachable and on.
  on,

  /// Reachable and off.
  off,

  /// Cannot be reached; its state is the last one known.
  offline;

  /// The server's word for it, or null for one this app doesn't know.
  static ApplianceStatus? parse(Object? v) => switch (v) {
    'on' => ApplianceStatus.on,
    'off' => ApplianceStatus.off,
    'offline' => ApplianceStatus.offline,
    _ => null,
  };

  /// The rule the server follows, for an older server that doesn't say and
  /// for a change the app shows before the server has answered.
  static ApplianceStatus of({required bool online, required bool on}) => !online
      ? ApplianceStatus.offline
      : (on ? ApplianceStatus.on : ApplianceStatus.off);
}

/// One appliance, as the server lists it.
class Appliance {
  const Appliance({
    required this.id,
    required this.name,
    this.kind = 'other',
    this.room,
    this.brand,
    this.model,
    this.connection,
    this.removable = false,
    this.online = false,
    this.capabilities = const [],
    this.state = const {},
    ApplianceStatus? status,
    this.checkedAt,
    this.since,
    this.autoOffAt,
    this.switchingTo,
    this.unconfirmed = false,
  }) : _status = status;

  final String id;
  final String name;

  /// 'light', 'plug', 'fan', 'aircon', 'heater' or 'other'.
  final String kind;
  final String? room;

  /// What the household said when adding it.
  final String? brand;
  final String? model;

  /// How it is reached: 'demo' (simulated by the server), or a vendor or hub.
  final String? connection;

  /// Added by the household itself, so it can be removed again.
  final bool removable;

  /// Whether the vendor can reach the appliance right now.
  final bool online;
  final List<ApplianceCapability> capabilities;

  /// The current value of each capability, by key.
  final Map<String, Object?> state;

  final ApplianceStatus? _status;

  /// When the server read [state] from the appliance.
  final DateTime? checkedAt;

  /// Since when it has been on (or off), when the server knows.
  final DateTime? since;

  /// When the server will switch it off by itself (a heater left on).
  final DateTime? autoOffAt;

  /// While a power command is on its way: what it was asked to be.
  final bool? switchingTo;

  /// The last command went through, but the appliance didn't confirm its
  /// state, so what is shown is what was asked for.
  final bool unconfirmed;

  static const power = 'power';
  static const swing = 'swing';

  /// On, off or offline: what the server said, or, after a change the app
  /// made itself, the same rule applied to what it now shows.
  ApplianceStatus get status =>
      _status ?? ApplianceStatus.of(online: online, on: isOn);

  ApplianceCapability? capability(String key) {
    for (final c in capabilities) {
      if (c.key == key) return c;
    }
    return null;
  }

  bool get hasPower => capability(power)?.isBool ?? false;
  bool get isOn => state[power] == true;

  /// An int state value, or null when it is missing or not a number.
  int? intValue(String key) {
    final v = state[key];
    return v is num ? v.toInt() : null;
  }

  /// The same appliance with a new state. Its status follows the state; a
  /// change of power means the server's "since" no longer applies.
  Appliance withState(Map<String, Object?> next, {bool unconfirmed = false}) {
    final switched = (next[power] == true) != isOn;
    return Appliance(
      id: id,
      name: name,
      kind: kind,
      room: room,
      brand: brand,
      model: model,
      connection: connection,
      removable: removable,
      online: online,
      capabilities: capabilities,
      state: next,
      checkedAt: checkedAt,
      since: switched ? null : since,
      autoOffAt: switched ? null : autoOffAt,
      switchingTo: switchingTo,
      unconfirmed: unconfirmed,
    );
  }

  /// The same appliance, with a power command on its way (or not).
  Appliance switching(bool? to) => Appliance(
    id: id,
    name: name,
    kind: kind,
    room: room,
    brand: brand,
    model: model,
    connection: connection,
    removable: removable,
    online: online,
    capabilities: capabilities,
    state: state,
    status: _status,
    checkedAt: checkedAt,
    since: since,
    autoOffAt: autoOffAt,
    switchingTo: to,
    unconfirmed: unconfirmed,
  );

  factory Appliance.fromJson(Map<String, dynamic> j) {
    final rawState = j['state'];
    String? text(String key) {
      final v = j[key]?.toString().trim();
      return v == null || v.isEmpty ? null : v;
    }

    return Appliance(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      kind: (j['kind'] ?? 'other').toString(),
      room: text('room'),
      brand: text('brand'),
      model: text('model'),
      connection: text('connection'),
      removable: j['removable'] == true,
      online: j['online'] == true,
      capabilities: [
        for (final c in (j['capabilities'] as List? ?? const []))
          if (c is Map) ApplianceCapability.fromJson(c.cast<String, dynamic>()),
      ],
      state: rawState is Map
          ? {for (final e in rawState.entries) e.key.toString(): e.value}
          : const {},
      status: ApplianceStatus.parse(j['status']),
      checkedAt: _time(j['checked_at']),
      since: _time(j['since']),
      autoOffAt: _time(j['auto_off_at']),
    );
  }

  /// A time from the server; Go's zero time means "not known".
  static DateTime? _time(Object? v) {
    final t = v == null ? null : DateTime.tryParse(v.toString());
    return t == null || t.year < 2000 ? null : t;
  }
}

/// One command the server relayed: who sent what, and when.
class ApplianceEvent {
  const ApplianceEvent({
    required this.capability,
    required this.value,
    required this.source,
    required this.at,
    this.userName,
  });

  final String capability;
  final Object? value;

  /// 'user', or 'auto_off' when the server switched it off by itself.
  final String source;
  final DateTime at;
  final String? userName;

  bool get isAutoOff => source == 'auto_off';

  factory ApplianceEvent.fromJson(Map<String, dynamic> j) {
    final name = j['user_name']?.toString().trim();
    return ApplianceEvent(
      capability: (j['capability'] ?? '').toString(),
      value: j['value'],
      source: (j['source'] ?? 'user').toString(),
      at: DateTime.tryParse((j['at'] ?? '').toString()) ?? DateTime.now(),
      userName: name == null || name.isEmpty ? null : name,
    );
  }
}
