/// One condition on a single NHTSA field. Comparison is case-insensitive
///  and ignores leading/trailing whitespace.
/// 
/// A condition with an empty [value] never matches. Otherwise a missing
/// field (read as an empty string - "") would match Equals (field, '') and
/// every field matches Contains (field, '')


enum MatchType { equals, contains }

/// One condition on a single NHTSA field. Comparison is case-insensitive
/// and ignores leading/trailing whitespace.
///
/// A condition with an empty [value] never matches.
/// NhtsaConditions are ALWAYS constants
class NhtsaCondition {
  final String field;
  final String value;
  final MatchType type;

  /// CONSTRUCTORS - 
  /// ------------------------------------------------------------------------------
  /// NHTSA [field] must equal [value] exactly (case-insensitive).
  const NhtsaCondition.equals(this.field, this.value) : type = MatchType.equals;

  /// NHTSA [field] must contain [value] anywhere in it (case-insensitive).
  /// Use for free-text fields such as OtherTrailerInfo.
  const NhtsaCondition.contains(this.field, this.value) : type = MatchType.contains;
  /// ------------------------------------------------------------------------------
  
  // run the check based on matchtype 
  // receives the NHTSA key and value
  bool test(Map<String, dynamic> info) {
    final String expected = value.trim().toLowerCase();
    if (expected.isEmpty) return false;
    final String actual = ((info[field] as String?) ?? '').trim().toLowerCase(); // the NHTSA value

    switch (type) {
      case MatchType.equals:
        return actual == expected;
      case MatchType.contains:
        return actual.contains(expected);
    }
  }

  @override
  String toString() => "NhtsaCondition.${type.name}('$field', '$value')";
}

/// A single NHTSA -> Model_n_Fuel rule.
/// Used to define how we convert data from the NHTSA lookup into local model data.
/// See nhtsa_rules.dart for usage.
class NhtsaRule<T> {
  /// If set, the rule only applies when the vehicle's vehType is in this set.
  final Set<int>? onlyForVehTypes;

  /// ALL conditions must match for the rule to match.
  /// A rule with an empty list never matches.
  final List<NhtsaCondition> when;

  /// Value written to Model_n_Fuel when this rule matches.
  final T result;

  const NhtsaRule({
    this.onlyForVehTypes,
    required this.when,
    required this.result,
  });

  /// check if this rule applies to the passed vehType
  bool appliesTo(int vehType) =>
      onlyForVehTypes == null || onlyForVehTypes!.contains(vehType);

  bool matches(Map<String, dynamic> info) =>
      when.isNotEmpty && when.every((condition) => condition.test(info));

  @override
  String toString() =>
      'NhtsaRule(onlyForVehTypes: $onlyForVehTypes, when: $when, result: $result)';
}

class NhtsaRuleEngine {
  NhtsaRuleEngine._();

  static const double feetPerMeter = 3.281;
  static const int minVehClass = 0;
  static const int maxVehClass = 10; // VehClass default is 0
  static const Set<String> _emptyValues = {'', 'not applicable', 'n/a', 'null', '0'};  /// NHTSA values that count as "no value".
  static const Set<String> _companyWords = { // words to be ignored when comparing a model to manufacturer name
    'inc', 'co', 'corp', 'corporation', 'company', 'llc', 'ltd', 'mfg',
    'manufacturing', 'manufacturer', 'industries', 'trailer', 'trailers',
  };

  static String _normalizeName(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .split(' ')
      .where((word) => word.isNotEmpty && !_companyWords.contains(word))
      .join(' ');

  /// Returns the result of the FIRST matching rule, or 0 if none match.
  /// rules = the specific list of rules to address, determines which column we're looking at (vehType, vehBody, etc...).
  /// info = decoded NHTSA response.
  /// vehType = vehicle's already resolved vehType, which only matters for rules set for onlyForVehTypes.
  static T? resolve<T>(List<NhtsaRule<T>> rules, Map<String, dynamic> info, {int vehType = 0}) {
    for (final NhtsaRule rule in rules) {
      if (!rule.appliesTo(vehType)) continue; 
      if (rule.matches(info)) return rule.result;
    }
    return null;
  }

  /// True if any rule could apply to [vehType]. Used to skip the NHTSA call.
  static bool hasRulesFor(List<NhtsaRule<Object>> rules, int vehType) =>
      rules.any((rule) => rule.appliesTo(vehType));

  /// Lists the NHTSA values the rules looked at, for logging unmatched vehicles.
  static String describeInputs(List<NhtsaRule<Object>> rules, Map<String, dynamic> info, {int vehType = 0}) {
    final Set<String> fields = {
      for (final NhtsaRule rule in rules.where((r) => r.appliesTo(vehType)))
        for (final NhtsaCondition condition in rule.when) condition.field,
    };
    return fields.map((f) => '$f="${info[f] ?? ''}"').join(', ');
  }

  /// Model name methods
  
  /// True if model name is just one of the makes (case insensitive)
  static bool isRedundantModel(String model, List<String> makes){
    final String m = _normalizeName(model);
    if (m.isEmpty) return true;
    for (final String make in makes){
      final String n = _normalizeName(make);
      if (n.isEmpty) continue;
      if (n == m || n.startsWith('$m ') || m.startsWith('$n ')){
        // model name from NHTSA is the same as the manufacturer so it's redundant
        return true;
      }
    }
    return false;
  }

  /// True for NHTSA "no value" placeholders such as "" or "Not Applicable".
  static bool isEmptyValue(String value) =>
      _emptyValues.contains(value.trim().toLowerCase());

  /// Formats a length given in FEET for a model name.
  /// Imperial: whole feet ("53 Ft"). Metric: meters to 1 decimal ("16.2 M").
  static String formatLength(double feet, {required bool metric}) {
    if (metric) return '${(feet / feetPerMeter).toStringAsFixed(1)} M';
    return '${feet.round()} Ft';
  }

  /// Convert feet to meters, truncated (not rounded) to 2 decimal places.
  /// The epsilon guards against binary float error (e.g. 16.15 -> 16.149999...).
  static double feetToMeters(double feet) {
    final double meters = feet / feetPerMeter;
    return ((meters * 100) + 1e-9).floorToDouble() / 100;
  }

  /// GVWR - Gross Vehicle Weight Rating
  ///  Pulls first number out of data returned by the NHTSA
  /// "Class 4: 14,001 - 16,000 lb (6,350 - 7,258 kg)" -> 4
  /// "Class 2E: 6,001 - 7,000 lb (2,722 - 3,175 kg)"  -> 2
  /// Returns 0 if not found or outside [minVehClass]..[maxVehClass].
  static int parseGvwrClass(String gvwr) {
    final RegExpMatch? match =
        RegExp(r'class\s*(\d+)', caseSensitive: false).firstMatch(gvwr);
    if (match == null) return 0;
    final int vehClass = int.parse(match.group(1)!);
    return (vehClass >= minVehClass && vehClass <= maxVehClass) ? vehClass : 0;
  }

}
