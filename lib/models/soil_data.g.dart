import 'package:hive/hive.dart';
import 'soil_data.dart';

@HiveType(typeId: 0)
class SoilDataAdapter extends TypeAdapter<SoilData> {
  @override
  final int typeId = 0;

  @override
  SoilData read(BinaryReader reader) {
    try {
      final numOfFields = reader.readByte();
      final fields = <int, dynamic>{};

      for (int i = 0; i < numOfFields; i++) {
        final key = reader.readByte();
        final value = reader.read();
        fields[key] = value;
      }

      // Extract latitude and longitude from location string
      double latitude = 0.0;
      double longitude = 0.0;

      final location = fields[5] as String? ?? '';
      if (location.isNotEmpty) {
        try {
          final latMatch = RegExp(r'Lat:\s*([-\d.]+)').firstMatch(location);
          final lngMatch = RegExp(r'Lng:\s*([-\d.]+)').firstMatch(location);

          if (latMatch != null) {
            latitude = double.tryParse(latMatch.group(1)!) ?? 0.0;
          }
          if (lngMatch != null) {
            longitude = double.tryParse(lngMatch.group(1)!) ?? 0.0;
          }
        } catch (e) {
          // Use default values if parsing fails
        }
      }

      return SoilData(
        date: fields[0] as DateTime,
        latitude: latitude,
        longitude: longitude,
        location: location,

        // Soil properties
        soilType: fields[14] as String?,

        // Nutrients
        pH: fields[6] as double?,
        nitrogen: fields[8] as double?,
        phosphorus: fields[9] as double?,
        potassium: fields[10] as double?,
        calcium: fields[11] as double?,
        magnesium: fields[7] as double?,
        organicMatter: fields[12] as double?,

        // Physical properties
        soilMoisture: fields[1] as double?,
        soilTemperature: fields[2] as double?,
        salinity: fields[13] as double?,

        // Weather data
        airTemperature: null, // Not stored in your adapter
        precipitation: fields[4] as double?,
        humidity: null, // Not stored in your adapter
        solarRadiation: fields[3] as double?,
        windSpeed: null, // Not stored in your adapter

        // Metadata
        source: 'Hive Storage',
        notes: fields[15] as String?,
        accuracy: null,
        rawData: null,
      );
    } catch (e) {
      print('❌ Error reading SoilData from Hive: $e');
      rethrow;
    }
  }

  @override
  void write(BinaryWriter writer, SoilData obj) {
    try {
      writer
        ..writeByte(16) // Number of fields
        ..writeByte(0)
        ..write(obj.date)
        ..writeByte(1)
        ..write(obj.soilMoisture)
        ..writeByte(2)
        ..write(obj.soilTemperature)
        ..writeByte(3)
        ..write(obj.solarRadiation)
        ..writeByte(4)
        ..write(obj.precipitation)
        ..writeByte(5)
        ..write(obj.location)
        ..writeByte(6)
        ..write(obj.pH)
        ..writeByte(7)
        ..write(obj.magnesium)
        ..writeByte(8)
        ..write(obj.nitrogen)
        ..writeByte(9)
        ..write(obj.phosphorus)
        ..writeByte(10)
        ..write(obj.potassium)
        ..writeByte(11)
        ..write(obj.calcium)
        ..writeByte(12)
        ..write(obj.organicMatter)
        ..writeByte(13)
        ..write(obj.salinity)
        ..writeByte(14)
        ..write(obj.soilType)
        ..writeByte(15)
        ..write(obj.notes);
    } catch (e) {
      print('❌ Error writing SoilData to Hive: $e');
      rethrow;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SoilDataAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}