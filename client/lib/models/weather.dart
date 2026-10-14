class WeatherNow {
  final double temperature;
  final double windSpeed;
  final int weatherCode;
  final DateTime time;

  const WeatherNow({
    required this.temperature,
    required this.windSpeed,
    required this.weatherCode,
    required this.time,
  });

  /// WMO weather code grouped into what the UI distinguishes. The wording is
  /// the UI's job (it depends on the language).
  WeatherCondition get condition {
    final w = weatherCode;
    if ([0].contains(w)) return WeatherCondition.clear;
    if ([1, 2, 3].contains(w)) return WeatherCondition.partlyCloudy;
    if ([45, 48].contains(w)) return WeatherCondition.fog;
    if ([51, 53, 55, 56, 57].contains(w)) return WeatherCondition.drizzle;
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(w)) {
      return WeatherCondition.rain;
    }
    if ([71, 73, 75, 77, 85, 86].contains(w)) return WeatherCondition.snow;
    if ([95, 96, 99].contains(w)) return WeatherCondition.thunderstorm;
    return WeatherCondition.unknown;
  }
}

enum WeatherCondition {
  clear,
  partlyCloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunderstorm,
  unknown,
}
