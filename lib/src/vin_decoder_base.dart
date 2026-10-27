import 'dart:developer';

import 'manufacturers.dart';
import 'nhtsa_model.dart';
import 'nhtsa_rule.dart';
import 'nhtsa_rules.dart';
import 'year_map.dart';
class VIN {
  /// Hashmap containing fuel names and their respective #
  static const Map<String, int> fuelMap = {
    "Diesel": 1,
    "CNG": 6,
    "Gasoline": 4,
    "Battery": 2,
    "Electric":2,
    "BEV":2,
    "LNG": 7,
    "Hydrogen": 8,
    "LPG": 9,
    "E85": 10,
    "E100": 11,
    "M85": 13,
    "M100": 14,
    "FFV": 15,
    "FCEV":18,
    "Fuel Cell": 18
  };

// CASE type statement NHTSA parameter  vehicletype =
//   "TRAILER" then assign value to model_n_fuel\vehType = 6  AND
//                 assign model_n_fuel\vehBody where NHTSA parameter trailerbodytype =
//                     "Intermodal Container Chassis or Trailer": 109,
//                     "Tank Trailer": 138,
//                      Default:0   
//                  assign value to models n fuels\vehLength where NHTSA parameter trailerlength > 0
//                     trailerlength/3.281  Note this converts feet to meters  truncate results to 2 decimal places.   


  /// The VIN that the class was instantiated with.
  final String number;

  /// The World Manufacturer Identifier (WMI) code for the specified [number].
  final String wmi;

  /// The Vehicle Descriptor Section (VDS) code for the specified [number].
  final String vds;

  /// The Vehicle Identifier Section (VIS) code for the specified [number].
  final String vis;

  /// Try to obtain extended information for the VIN from the NHTSA database.
  final bool extended;
  Map<String, dynamic> _vehicleInfo = {};

  /// Private named constructor. Creates a new VIN. 
  /// 
  /// [wmi], [vds], and [vis] are populated based on [number]. 
  VIN._({required this.number, required this.extended}) : 
  // check for 6 digit WMIs, otherwise return 3 digit
    wmi = number[2] != '9' ? number.substring(0, 3) : number.substring(0, 3) + number.substring(11, 14),
    vds = number.substring(3, 9),
    vis = number.substring(9, 17);

  /// Creates a new VIN. 
  /// 
  /// This factory constructor makes sure the string is normallyed 
  factory VIN({required String vin, bool extended = false}){
    return VIN._(number: normalize(vin), extended: extended);
  }

  /// Carry out VIN validation. A valid [number] must be 17 characters long
  /// and contain only valid alphanumeric characters.
  /// 
  /// If a number is provided, validates that number. Otherwise, it validates the number this object was initialized with.
  bool valid([String? number]) {
    final String value = normalize(number ?? this.number);
    return RegExp(r"^[a-zA-Z0-9]+$").hasMatch(value) && value.length == 17;
  }

  /// Provide a normalized VIN string, regardless of the input format.
  static String normalize(String number) =>
      number.toUpperCase().replaceAll('-', '');

  /// Obtain the encoded manufacturing year in YYYY format.
  int getYear() {
    return yearMap[modelYear()] ?? 2001;
  }

  /// Obtain the 2-character region code for the manufacturing region.
  String getRegion() {
    if (RegExp("[A-H]", caseSensitive: false).hasMatch(number[0])) {
      return "AF";
    }
    if (RegExp("[J-R]", caseSensitive: false).hasMatch(number[0])) {
      return "AS";
    }
    if (RegExp("[S-Z]", caseSensitive: false).hasMatch(number[0])) {
      return "EU";
    }
    if (RegExp("[1-5]", caseSensitive: false).hasMatch(number[0])) {
      return "NA";
    }
    if (RegExp("[6-7]", caseSensitive: false).hasMatch(number[0])) {
      return "OC";
    }
    if (RegExp("[8-9]", caseSensitive: false).hasMatch(number[0])) {
      return "SA";
    }
    return "Unknown";
  }

  /// Get the full name of the vehicle manufacturer as defined by the [wmi].
  /// 
  /// If the full name cannot be found, returns null.
  String? getManufacturer() {
    // Check for the standard case - a 3 character WMI
    if (manufacturers.containsKey(wmi)) {
      return manufacturers[wmi];
    } else {
      // Some manufacturers only use the first 2 characters for manufacturer
      // identification, and the third for the class of vehicle.
      var id = wmi.substring(0, 2);
      if (manufacturers.containsKey(id)) {
        return manufacturers[id];
      } else {
        return null;
      }
    }
  }

  /// Returns the checksum for the VIN. Note that in the case of the EU region
  /// checksums are not implemented, so this becomes a no-op. More information
  /// is provided in ISO 3779:2009.
  /// 
  /// If the region is EU, returns null
  String? getChecksum() {
    return (getRegion() != "EU") ? number[8] : null;
  }

  /// Extract the single-character model year from the [number].
  String modelYear() => number[9];

  /// Extract the single-character assembly plant designator from the [number].
  String assemblyPlant() => number[10];

  /// Extract the serial number from the [number].
  String serialNumber() => number.substring(12, 17);

  /// True if NHTSA returned data for this VIN. False if the fetch failed or never ran.
  bool get hasExtendedInfo => _vehicleInfo.isNotEmpty;

  /// Assigns the NHTSA values to the vehicle based off VIN
  Future<void> _fetchExtendedVehicleInfo() async {
    if (_vehicleInfo.isEmpty && extended == true) {
      _vehicleInfo = await NHTSA.decodeVinValues(number) ?? {};
    }
  }

  /// Get the fuel type of the vehicle from the NHTSA database if [extended] mode
  /// is enabled.
  Future<int> getFuelTypeAsync() async {
    await _fetchExtendedVehicleInfo();
    final String? fuelType = _vehicleInfo['FuelTypePrimary'] as String?;
    if (fuelType == null) return 0;
    
    final String fuelLower = fuelType.toLowerCase();
    for (final String fuelKey in fuelMap.keys) {
      if (fuelLower.contains(fuelKey.toLowerCase())) {
        return fuelMap[fuelKey]!;
      }
    }
    return 0;
  }

  /// Get the Make of the vehicle from the NHTSA database if [extended] mode
  /// is enabled.
  Future<String> getMakeAsync() async {
    await _fetchExtendedVehicleInfo();
    return _vehicleInfo['Make'] as String? ?? "";
  }

  /// Get the Make ID of a vehicle from the NHTSA database if the [extended] mode is enabled
  Future<int> getMakeIdAsync() async {
    await _fetchExtendedVehicleInfo();
    return _vehicleInfo.keys.contains("MakeID") ? int.parse(_vehicleInfo["MakeID"]): 0;
  }

  /// Get the Model of the vehicle from the NHTSA database if [extended] mode is enabled.
  Future<String> getModelAsync() async {
    await _fetchExtendedVehicleInfo();
    return (_vehicleInfo.keys.contains("Model") ? _vehicleInfo['Model'] as String? ?? "Unknown": "Unknown");
  }

  /// The NHTSA Model, or a generated "<descriptor> <noun> <length>" name if the
  /// Model repeats the Make and [vehType] is listed in [NhtsaRules.modelNameNoun].
  Future<String> getModelNameAsync(int vehType, {required bool metric}) async {
    final String model = await getModelAsync();
    if (model == 'Unknown' || model.trim().isEmpty) return model;

    final String? noun = NhtsaRules.modelNameNoun[vehType];
    if (noun == null) return model;

    if (!NhtsaRuleEngine.isRedundantModel(model, [_info('Make'), _info('Manufacturer')])) {
      return model;
    }

    final String descriptor = NhtsaRuleEngine.resolve(
            NhtsaRules.modelNameDescriptorRules, _vehicleInfo, vehType: vehType) ?? '';

    String length = '';
    final String? lengthField = NhtsaRules.vehLengthFeetField[vehType];
    if (lengthField != null) {
      final double? feet = double.tryParse(_info(lengthField).replaceAll(',', ''));
      if (feet != null && feet > 0) {
        length = NhtsaRuleEngine.formatLength(feet, metric: metric);
      }
    }

    if (descriptor.isEmpty && length.isEmpty) {
      log('Model "$model" repeats make for $number (vehType $vehType); '
          'no descriptor or length to build a name.', name: 'nhtsa_rules');
      return model;
    }

    // Format. For "Trailer Reefer 53 Ft" instead, use [noun, descriptor, length].
    return [descriptor, noun, length].where((part) => part.isNotEmpty).join(' ');
  }

  Future<String> getModelIdAsync() async {
    await _fetchExtendedVehicleInfo();
    return (_vehicleInfo.keys.contains("ModelID") ? _vehicleInfo['ModelID'] as String? ?? "Unknown": "Unknown");
  }

  /// Get the Vehicle Type from the NHTSA database if [extended] mode is enabled.
  Future<String> getVehicleTypeAsync() async {
    await _fetchExtendedVehicleInfo();
    return (_vehicleInfo.keys.contains("VehicleType") ? _vehicleInfo['VehicleType'] as String? ?? "0": "0");
  }

  /// Raw trimmed NHTSA value for [key], or "" if missing.
  String _info(String key) =>
      ((_vehicleInfo[key] as String?) ?? '').trim();

  /// Resolve Model_n_Fuel.vehType from NHTSA using [NhtsaRules.vehTypeRules].
  /// Returns 0 if no rule matches or NHTSA data is unavailable.
  Future<int> getVehTypeNoAsync() async {
    await _fetchExtendedVehicleInfo();
    if (_vehicleInfo.isEmpty) return 0;

    final int result = NhtsaRuleEngine.resolve(NhtsaRules.vehTypeRules, _vehicleInfo) ?? 0;
    if (result == 0) {
      log('No vehType rule matched for $number: '
          '${NhtsaRuleEngine.describeInputs(NhtsaRules.vehTypeRules, _vehicleInfo)}',
          name: 'nhtsa_rules');
    }
    return result;
  }

  /// Resolve Model_n_Fuel.vehBody using [NhtsaRules.vehBodyRules].
  /// Returns 0 if no rule matches or NHTSA data is unavailable.
  Future<int> getVehBodyAsync(int vehType) async {
    if (!NhtsaRuleEngine.hasRulesFor(NhtsaRules.vehBodyRules, vehType)) return 0;

    await _fetchExtendedVehicleInfo();
    if (_vehicleInfo.isEmpty) return 0;

    final int result = NhtsaRuleEngine.resolve(NhtsaRules.vehBodyRules, _vehicleInfo, vehType: vehType) ?? 0;
    if (result == 0) {
      log('No vehBody rule matched for $number (vehType $vehType): '
          '${NhtsaRuleEngine.describeInputs(NhtsaRules.vehBodyRules, _vehicleInfo, vehType: vehType)}',
          name: 'nhtsa_rules');
    }
    return result;
  }

  /// Resolve Model_n_Fuel.vehLength (meters, truncated to 2 decimals).
  /// Returns 0 if not applicable or not > 0.
  Future<double> getVehLengthMetersAsync(int vehType) async {
    final String? field = NhtsaRules.vehLengthFeetField[vehType];
    if (field == null) return 0;

    await _fetchExtendedVehicleInfo();

    final double? feet = double.tryParse(_info(field).replaceAll(',', ''));
    if (feet == null || feet <= 0) return 0;

    return NhtsaRuleEngine.feetToMeters(feet);
  }

  /// Resolve Model_n_Fuel.vehClass from GVWR.
  /// Returns 0 if not applicable or unparseable.
  Future<int> getVehClassAsync(int vehType) async {
    if (!NhtsaRules.vehClassFromGvwr.contains(vehType)) return 0;

    await _fetchExtendedVehicleInfo();

    return NhtsaRuleEngine.parseGvwrClass(_info('GVWR'));
  }
  @override
  String toString() => wmi + vds + vis;
}
