part of '../health.dart';

/// Custom Exception for the plugin. Used when a Health Data Type is requested,
/// but not available on the current platform.
class HealthException implements Exception {
  /// Data Type that was requested.
  dynamic dataType;

  /// Cause of the exception.
  String cause;

  HealthException(this.dataType, this.cause);

  @override
  String toString() =>
      "Error requesting health data type '$dataType' - cause: $cause";
}

/// The status of Google Health Connect.
///
/// **NOTE** - The enum order is arbitrary. If you need the native value,
/// use [nativeValue] and not the index.
///
/// Reference:
/// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#constants_1
enum HealthConnectSdkStatus {
  /// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#SDK_UNAVAILABLE()
  sdkUnavailable(1),

  /// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED()
  sdkUnavailableProviderUpdateRequired(2),

  /// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#SDK_AVAILABLE()
  sdkAvailable(3);

  const HealthConnectSdkStatus(this.nativeValue);

  /// The native value that matches the value in the Android SDK.
  final int nativeValue;

  factory HealthConnectSdkStatus.fromNativeValue(int value) {
    return HealthConnectSdkStatus.values.firstWhere(
        (e) => e.nativeValue == value,
        orElse: () => HealthConnectSdkStatus.sdkUnavailable);
  }
}


/// Return a list of [HealthDataPoint] based on [points] with no duplicates.
  List<HealthDataPoint> removeDuplicates(List<HealthDataPoint> points) =>
      LinkedHashSet.of(points).toList();

  /// Aggregates step data points from the same day into a single data point.
  /// Returns a list of [HealthDataPoint] where steps from the same day are combined.
  /// Original step points are removed from the returned list.
  List<HealthDataPoint> aggregateStepsByDay(List<HealthDataPoint> points) {
    if (points.isEmpty) return [];

    // Keep non-step points
    final List<HealthDataPoint> resultPoints = points.where((point) => point.type != HealthDataType.STEPS).toList();

    // Group step points by day
    final Map<String, List<HealthDataPoint>> dayGroups = {};
    
    for (var point in points) {
      if (point.type != HealthDataType.STEPS) continue;
      
      // Create a key for the day (YYYY-MM-DD)
      final dayKey = "${point.dateFrom.year}-${point.dateFrom.month.toString().padLeft(2, '0')}-${point.dateFrom.day.toString().padLeft(2, '0')}";
      dayGroups[dayKey] ??= [];
      dayGroups[dayKey]!.add(point);
    }

    for (var entry in dayGroups.entries) {
      final points = entry.value;
      if (points.isEmpty) continue;

      num totalSteps = 0;
      for (var point in points) {
        if (point.value is NumericHealthValue) {
          totalSteps += (point.value as NumericHealthValue).numericValue;
        }
      }

      final firstPoint = points.first;
      final lastPoint = points.last;
      final startOfDay = DateTime(firstPoint.dateFrom.year, firstPoint.dateFrom.month, firstPoint.dateFrom.day);
      final endOfDay = DateTime(lastPoint.dateFrom.year, lastPoint.dateFrom.month, lastPoint.dateFrom.day, 23, 59, 59);

      final aggregatedPoint = HealthDataPoint(
        uuid: Health.generateUuid(),
        value: NumericHealthValue(numericValue: totalSteps),
        type: HealthDataType.STEPS,
        unit: HealthDataUnit.COUNT,
        dateFrom: startOfDay,
        dateTo: endOfDay,
        sourcePlatform: firstPoint.sourcePlatform,
        sourceDeviceId: firstPoint.sourceDeviceId,
        sourceId: firstPoint.sourceId,
        sourceName: firstPoint.sourceName,
        recordingMethod: firstPoint.recordingMethod,
        metadata: {
          'aggregated': true,
          'number_of_records': points.length,
        },
      );

      resultPoints.add(aggregatedPoint);
    }

    return resultPoints;
  }

  /// Aggregates heart rate data points from the same day into a single data point with average value.
  /// Returns a list of [HealthDataPoint] where heart rates from the same day are combined.
  /// Original heart rate points are removed from the returned list.
  /// Metadata includes max, min values and total measurements count.
  List<HealthDataPoint> aggregateHeartRateByDay(List<HealthDataPoint> points) {
    if (points.isEmpty) return [];

    // Keep non-heart-rate points
    final List<HealthDataPoint> resultPoints = points.where((point) => point.type != HealthDataType.HEART_RATE).toList();
    final Map<String, List<HealthDataPoint>> dayGroups = {};
    
    for (var point in points) {
      if (point.type != HealthDataType.HEART_RATE) continue;
      
      final dayKey = "${point.dateFrom.year}-${point.dateFrom.month.toString().padLeft(2, '0')}-${point.dateFrom.day.toString().padLeft(2, '0')}";
      dayGroups[dayKey] ??= [];
      dayGroups[dayKey]!.add(point);
    }

    for (var entry in dayGroups.entries) {
      final points = entry.value;
      if (points.isEmpty) continue;

      num totalHeartRate = 0;
      num maxHeartRate = double.negativeInfinity;
      num minHeartRate = double.infinity;
      int validMeasurements = 0;

      for (var point in points) {
        if (point.value is NumericHealthValue) {
          final heartRate = (point.value as NumericHealthValue).numericValue;
          totalHeartRate += heartRate;
          maxHeartRate = max(maxHeartRate, heartRate);
          minHeartRate = min(minHeartRate, heartRate);
          validMeasurements++;
        }
      }

      if (validMeasurements == 0) continue;

      final averageHeartRate = totalHeartRate / validMeasurements;
      final firstPoint = points.first;
      final lastPoint = points.last;
      final startOfDay = DateTime(firstPoint.dateFrom.year, firstPoint.dateFrom.month, firstPoint.dateFrom.day);
      final endOfDay = DateTime(lastPoint.dateFrom.year, lastPoint.dateFrom.month, lastPoint.dateFrom.day, 23, 59, 59);

      final aggregatedPoint = HealthDataPoint(
        uuid: Health.generateUuid(),
        value: NumericHealthValue(numericValue: averageHeartRate),
        type: HealthDataType.HEART_RATE,
        unit: HealthDataUnit.BEATS_PER_MINUTE,
        dateFrom: startOfDay,
        dateTo: endOfDay,
        sourcePlatform: firstPoint.sourcePlatform,
        sourceDeviceId: firstPoint.sourceDeviceId,
        sourceId: firstPoint.sourceId,
        sourceName: firstPoint.sourceName,
        recordingMethod: firstPoint.recordingMethod,
        metadata: {
          'aggregated': true,
          'number_of_records': validMeasurements,
          'max_heart_rate': maxHeartRate,
          'min_heart_rate': minHeartRate,
          'original_records': points.map((p) => p.uuid).toList(),
        },
      );

      resultPoints.add(aggregatedPoint);
    }
    return resultPoints;
  }