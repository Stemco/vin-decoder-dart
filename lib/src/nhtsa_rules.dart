// ===================================================================================
// NHTSA -> Model_n_Fuel RULES
// ===================================================================================
// This file contains ONLY data. To change how NHTSA values map to
// Model_n_Fuel columns, edit the lists below. No other file needs to change.
//
// RULE FORMAT
//   NhtsaRule(
//     onlyForVehTypes: {VehTypeCode.vehicleTypeName},               // optional: rules for just these vehTypes
//     when: [                                                       // ALL conditions must match (logical ANDS)
//       NhtsaCondition.equals('TrailerBodyType', 'Tank Trailer'),   // field must EQUAL value
//       NhtsaCondition.contains('OtherTrailerInfo', 'Reefer'),      // field must CONTAIN value
//       // ...add as many conditions as needed
//     ],
//     result: 138,                                   // value written to Model_n_Fuel
//   ),
// NOTE: 
//  when = the conditions for this rule
//  NhstaCondition.equals(nhstaFieldName, value)
//  VehTypeCode.vehicleTypeName => represents the vehType number, but in a more human-readable way
//
// All comparisons are case-insensitive!!
// Use Equals for fixed NHTSA values (BodyClass, VehicleType, TrailerBodyType)
// Use Contains for fields with more varying text (OtherTrailerInfo, OtherBusInfo)
//
// OR LOGIC: for "A OR B", write two separate rules with the same result.
// AND LOGIC: for "A AND B", add multiple conditions to one rule. 

// ORDER MATTERS: rules are checked top to bottom and the FIRST match wins.
// Put specific rules ABOVE the general rule they refine.
//
// HOW TO FIND NHTSA FIELD NAMES AND VALUES - 
//   Decode a sample VIN in a browser:
//   https://vpic.nhtsa.dot.gov/api/ 
//   - use the "Decode VIN (flat format) in a Batch (max 50 VINs per batch)" option
//
// ===================================================================================
// RELATED FILES
// ===================================================================================
// lib\package\vin-decoder-dart\lib\src\nhtsa_rule.dart 
//     - Class for each rule object
//     - Defines methods that apply to these rules such as feet to meters conversion
// lib\package\vin-decoder-dart\lib\src\vin_decoder_base.dart
//     - The main vin_decoder class
//     - Handles calls to the NHTSA API to then compare against the rules listed here
// ===================================================================================



import 'nhtsa_rule.dart';

/// Model_n_Fuel.vehType codes- Add new codes here, then use them by name.
class VehTypeCode {
  VehTypeCode._();
  static const int passengerCar = 2;
  static const int bus = 5;
  static const int trailer = 6;
  static const int incomplete = 10;
}

class NhtsaRules {
  NhtsaRules._();

  // ---------------------------------------------------------------------------
  // vehType
  // ---------------------------------------------------------------------------
  static const List<NhtsaRule<int>> vehTypeRules = [
    NhtsaRule(when: [NhtsaCondition.equals('BodyClass', 'Trailer')],              result: VehTypeCode.trailer),
    NhtsaRule(when: [NhtsaCondition.equals('VehicleType', 'Trailer')],            result: VehTypeCode.trailer),
    NhtsaRule(when: [NhtsaCondition.equals('BodyClass', 'Bus')],                  result: VehTypeCode.bus),
    NhtsaRule(when: [NhtsaCondition.equals('VehicleType', 'Bus')],                result: VehTypeCode.bus),
    NhtsaRule(when: [NhtsaCondition.equals('BodyClass', 'Incomplete - Cutaway')], result: VehTypeCode.incomplete),
    NhtsaRule(when: [NhtsaCondition.equals('VehicleType', 'Incomplete Vehicle')], result: VehTypeCode.incomplete),
    NhtsaRule(when: [NhtsaCondition.equals('VehicleType', 'Passenger Car')],      result: VehTypeCode.passengerCar),
  ];

  // ---------------------------------------------------------------------------
  // vehBody
  // ---------------------------------------------------------------------------
  static const List<NhtsaRule<int>> vehBodyRules = [
    // Trailers
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.equals('TrailerBodyType', 'Box or Van Enclosed Trailer'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Reefer'),
    ], result: 143),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.equals('TrailerBodyType', 'Box or Van Enclosed Trailer'),
    ], result: 186),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.equals('TrailerBodyType', 'Tank Trailer'),
    ], result: 138),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.equals('TrailerBodyType', 'Flatbed or Platform Trailer'),
    ], result: 6),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.equals('TrailerBodyType', 'Intermodal Container Chassis or Trailer'),
    ], result: 109),

    // Buses
    NhtsaRule(onlyForVehTypes: {VehTypeCode.bus, VehTypeCode.incomplete}, when: [
      NhtsaCondition.equals('BusType', 'Transit Bus'),
    ], result: 5),

    // Passenger cars
    NhtsaRule(onlyForVehTypes: {VehTypeCode.passengerCar}, when: [
      NhtsaCondition.equals('BodyClass', 'Sedan/Saloon'),
    ], result: 13),
  ];

  // ---------------------------------------------------------------------------
  // Generated model names
  // Used ONLY when the NHTSA Model just repeats the Make/Manufacturer.
  // Format: "<descriptor> <noun> <length>", e.g. "Reefer Trailer 53 Ft".
  //   <noun>:       modelNameNoun for the vehType. vehTypes not listed keep the NHTSA Model.
  //   <descriptor>: description from the FIRST matching rule in modelNameDescriptorRules.
  //                 Left out if no rule matches ("Trailer 53 Ft").
  //   <length>:     from vehLengthFeetField, in the user's UOM (Ft or M).
  // Stored names are truncated to 50 characters.
  // ---------------------------------------------------------------------------
  static const Map<int, String> modelNameNoun = {
    VehTypeCode.trailer: 'Trailer',
    // VehTypeCode.bus: 'Bus',
  };

 static const List<NhtsaRule<String>> modelNameDescriptorRules = [
    // Reefers (a reefer is also a Box/Van trailer, so this goes above Van)
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer},
        when: [NhtsaCondition.contains('OtherTrailerInfo', 'Reefer')], result: 'Reefer'),

    // Tankers by cargo (above the general Tanker rule)
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Asphalt'),
    ], result: 'Asphalt Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Propane'),
    ], result: 'Propane Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'LPG'),
    ], result: 'Propane Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Ammonia'),
    ], result: 'Ammonia Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Crude'),
    ], result: 'Crude Oil Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Petroleum'),
    ], result: 'Fuel Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Gasoline'),
    ], result: 'Fuel Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Fuel'),
    ], result: 'Fuel Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Flammable'),
    ], result: 'Flammable Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Chemical'),
    ], result: 'Chemical Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Acid'),
    ], result: 'Acid Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Cryogenic'),
    ], result: 'Cryogenic Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Milk'),
    ], result: 'Milk Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Food Grade'),
    ], result: 'Food Grade Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Water'),
    ], result: 'Water Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Cement'),
    ], result: 'Cement Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Pneumatic'),
    ], result: 'Dry Bulk Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Dry Bulk'),
    ], result: 'Dry Bulk Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer}, when: [
      NhtsaCondition.contains('TrailerBodyType', 'Tank'),
      NhtsaCondition.contains('OtherTrailerInfo', 'Vacuum'),
    ], result: 'Vacuum Tanker'),

    // General body types
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer},
        when: [NhtsaCondition.contains('TrailerBodyType', 'Tank')], result: 'Tanker'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer},
        when: [NhtsaCondition.contains('TrailerBodyType', 'Flatbed')], result: 'Flatbed'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer},
        when: [NhtsaCondition.contains('TrailerBodyType', 'Container')], result: 'Chassis'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer},
        when: [NhtsaCondition.contains('TrailerBodyType', 'Van')], result: 'Van'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer},
        when: [NhtsaCondition.contains('TrailerBodyType', 'Dump')], result: 'Dump'),
    NhtsaRule(onlyForVehTypes: {VehTypeCode.trailer},
        when: [NhtsaCondition.contains('TrailerBodyType', 'Lowboy')], result: 'Lowboy'),
  ];


  // ---------------------------------------------------------------------------
  // vehLength: vehType -> NHTSA field holding length in FEET.
  // Stored in meters, truncated to 2 decimals.
  // ---------------------------------------------------------------------------
  static const Map<int, String> vehLengthFeetField = {
    VehTypeCode.trailer: 'TrailerLength',
    VehTypeCode.bus: 'BusLength',
    VehTypeCode.incomplete: 'BusLength',
  };

  // ---------------------------------------------------------------------------
  // vehClass: vehTypes whose class is parsed from the NHTSA "GVWR" field.
  // ---------------------------------------------------------------------------
  static const Set<int> vehClassFromGvwr = {
    VehTypeCode.bus,
    VehTypeCode.incomplete,
  };
}
