import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride_model.dart';
import '../models/ride_memory_model.dart';
import '../../domain/entities/ride_memory_entity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideLocalDatasource {
  /// 🔹 Get cache key for a specific user
  String _getCacheKey(String userId) => "ride_cache_$userId";

  /// 🔹 Save single ride for a specific user
  Future<void> saveRide(RideModel ride) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _getCacheKey(ride.userId);
    await prefs.setString(cacheKey, jsonEncode(ride.toJson()));
    
    // Notify listeners about the update
    _notifyRideUpdate(ride.userId, ride);
  }

  /// 🔹 Get cached ride for a specific user (or null if not exists)
  Future<RideModel?> getRide(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _getCacheKey(userId);
    final rideJsonString = prefs.getString(cacheKey);

    if (rideJsonString == null) return null;

    final Map<String, dynamic> json = jsonDecode(rideJsonString);
    return RideModel.fromJson(json);
  }

  /// 🔹 Clear cached ride for a specific user
  Future<void> clearRide(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _getCacheKey(userId);
    await prefs.remove(cacheKey);
    
    // Notify listeners that ride was cleared
    _notifyRideUpdate(userId, null);
  }

  /// 🔹 Stream current ride data for a specific user
  Stream<RideModel?> watchCurrentRide(String userId) {
    // Create a stream controller for this specific user
    final controller = StreamController<RideModel?>.broadcast();
    
    // Get initial value and emit it
    getRide(userId).then((ride) {
      controller.add(ride);
    });
    
    // Store the controller for this user
    _userControllers[userId] = controller;
    
    return controller.stream;
  }

  /// 🔹 Store stream controllers for each user
  final Map<String, StreamController<RideModel?>> _userControllers = {};
  
  /// 🔹 Notify listeners about ride updates for a specific user
  void _notifyRideUpdate(String userId, RideModel? ride) {
    final controller = _userControllers[userId];
    if (controller != null && !controller.isClosed) {
      controller.add(ride);
    }
  }
  
  /// 🔹 Dispose stream controller for a specific user
  void disposeUserStream(String userId) {
    final controller = _userControllers[userId];
    if (controller != null) {
      controller.close();
      _userControllers.remove(userId);
    }
  }

  /// 🔹 Update specific fields of the current ride
  Future<void> updateRideFields(String userId, Map<String, dynamic> fields) async {
    final currentRide = await getRide(userId);
    if (currentRide != null) {
      // Handle rideMemories conversion if present
      List<RideMemoryEntity>? updatedRideMemories;
      if (fields['rideMemories'] != null) {
        if (fields['rideMemories'] is List<Map<String, dynamic>>) {
          // Convert from Firestore format to RideMemoryEntity
          updatedRideMemories = (fields['rideMemories'] as List<Map<String, dynamic>>)
              .map((memoryMap) => RideMemoryModel.fromFirestore(memoryMap))
              .toList();
        } else if (fields['rideMemories'] is List<RideMemoryEntity>) {
          // Already in correct format
          updatedRideMemories = fields['rideMemories'] as List<RideMemoryEntity>;
        }
      }

      // Handle routePoints conversion if present
      List<GeoPoint>? updatedRoutePoints;
      if (fields['routePoints'] != null) {
        if (fields['routePoints'] is List<Map<String, dynamic>>) {
          // Convert from JSON format to GeoPoint
          updatedRoutePoints = (fields['routePoints'] as List<Map<String, dynamic>>)
              .map((pointMap) => GeoPoint(
                (pointMap['latitude'] as num).toDouble(),
                (pointMap['longitude'] as num).toDouble(),
              ))
              .toList();
        } else if (fields['routePoints'] is List<GeoPoint>) {
          // Already in correct format
          updatedRoutePoints = fields['routePoints'] as List<GeoPoint>;
        }
      }

      // Create a new ride model with updated fields
      final updatedRide = RideModel(
        id: currentRide.id,
        userId: currentRide.userId,
        vehicleId: currentRide.vehicleId,
        status: fields['status'] ?? currentRide.status,
        startedAt: currentRide.startedAt,
        startCoordinates: currentRide.startCoordinates,
        endCoordinates: fields['endCoordinates'] ?? currentRide.endCoordinates,
        endedAt: fields['endedAt'] ?? currentRide.endedAt,
        totalDistance: fields['totalDistance'] ?? currentRide.totalDistance,
        totalTime: fields['totalTime'] ?? currentRide.totalTime,
        totalGEMCoins: fields['totalGEMCoins'] ?? currentRide.totalGEMCoins,
        rideMemories: updatedRideMemories ?? currentRide.rideMemories,
        rideTitle: fields['rideTitle'] ?? currentRide.rideTitle,
        rideDescription: fields['rideDescription'] ?? currentRide.rideDescription,
        topSpeed: fields['topSpeed'] ?? currentRide.topSpeed,
        averageSpeed: fields['averageSpeed'] ?? currentRide.averageSpeed,
        routePoints: updatedRoutePoints ?? currentRide.routePoints,
      );
      await saveRide(updatedRide);
    }
  }
}
