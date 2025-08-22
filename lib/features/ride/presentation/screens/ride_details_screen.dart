import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_extra_mile_new/features/ride/domain/entities/ride_entity.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_extra_mile_new/common/widgets/circular_image.dart';
import 'package:go_extra_mile_new/core/constants/app_constants.dart';
import 'package:go_extra_mile_new/features/ride/presentation/widgets/save_ride_section.dart';
import 'package:go_extra_mile_new/features/ride/presentation/widgets/save_ride_info_row.dart';
import 'package:go_extra_mile_new/core/service/location_service.dart' as location_service;

class RideDetailsScreen extends StatefulWidget {
  final RideEntity ride;
  const RideDetailsScreen({super.key, required this.ride});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final location_service.LocationService _locationService = location_service.LocationService();
  List<LatLng> _routePoints = [];
  String? _startAddress;
  String? _endAddress;
  bool _isLoadingAddresses = false;

  Set<Marker> get _markers {
    if (_routePoints.isEmpty) return {};
    return {
      Marker(
        markerId: const MarkerId('start'),
        position: _routePoints.first,
        infoWindow: const InfoWindow(title: 'Start'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: _routePoints.last,
        infoWindow: const InfoWindow(title: 'End'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  Set<Polyline> get _polylines => {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          width: 5,
          geodesic: true,
        ),
      };

  CameraPosition get _initialCameraPosition => CameraPosition(
        target: _routePoints.isNotEmpty
            ? _routePoints.first
            : const LatLng(12.9716, 77.5946), // fallback: Bangalore
        zoom: 12,
      );

  Future<void> _fitToRoute() async {
    if (_routePoints.length < 2) return;
    final controller = await _mapController.future;
    final bounds = _computeBounds(_routePoints);
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  static LatLngBounds _computeBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      if (minLat == null) {
        minLat = maxLat = p.latitude;
        minLng = maxLng = p.longitude;
      } else {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat!) maxLat = p.latitude;
        if (p.longitude < minLng!) minLng = p.longitude;
        if (p.longitude > maxLng!) maxLng = p.longitude;
      }
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoadingAddresses = true;
    });

    try {
      // Load start address
      final startAddress = await _locationService.getFormattedAddressFromCoordinates(
        widget.ride.startCoordinates.latitude,
        widget.ride.startCoordinates.longitude,
      );

      // Load end address if available
      String? endAddress;
      if (widget.ride.endCoordinates != null) {
        endAddress = await _locationService.getFormattedAddressFromCoordinates(
          widget.ride.endCoordinates!.latitude,
          widget.ride.endCoordinates!.longitude,
        );
      }

      if (mounted) {
        setState(() {
          _startAddress = startAddress;
          _endAddress = endAddress;
          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.ride.routePoints != null) {
      _routePoints = widget.ride.routePoints!
          .map((geoPoint) => LatLng(geoPoint.latitude, geoPoint.longitude))
          .toList();
    }
    _loadAddresses();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            CircularImage(imageUrl: vechileBrandImage1, height: 45, width: 45),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ride.vehicleId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  widget.ride.vehicleId,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.share, color: Colors.black),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ride Title & Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(screenPadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.ride.rideTitle ?? "Untitled Ride",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800)),
                  const SizedBox(height: 16),
                  Text(widget.ride.rideDescription ?? "No description",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey.shade700,
                          height: 1.4)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Google Map
            if (_routePoints.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 400,
                  child: GoogleMap(
                    initialCameraPosition: _initialCameraPosition,
                    onMapCreated: (controller) async {
                      _mapController.complete(controller);
                      await Future.delayed(const Duration(milliseconds: 300));
                      await _fitToRoute();
                    },
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    zoomGesturesEnabled: false,
                    scrollGesturesEnabled: false,
                    mapType: MapType.normal,
                    myLocationButtonEnabled: false, // Remove current location button
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Route Section
            SaveRideSection(
              title: "Route",
              gradient: [Colors.white, Colors.grey.shade50],
              children: [
                SaveRideInfoRow(
                  icon: Icons.location_on_outlined,
                  label: "Start",
                  value: _isLoadingAddresses 
                      ? "Loading..." 
                      : (_startAddress ?? widget.ride.startCoordinates.toString()),
                  theme: theme,
                ),
                SaveRideInfoRow(
                  icon: Icons.flag_outlined,
                  label: "End",
                  value: _isLoadingAddresses 
                      ? "Loading..." 
                      : (_endAddress ?? (widget.ride.endCoordinates?.toString() ?? "Ongoing")),
                  theme: theme,
                ),
                SaveRideInfoRow(
                  icon: Icons.route,
                  label: "Route Points",
                  value: "${widget.ride.routePoints?.length ?? 0} points",
                  theme: theme,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Performance Section
            SaveRideSection(
              title: "Performance",
              gradient: [Colors.white, Colors.grey.shade50],
              children: [
                SaveRideInfoRow(
                  icon: Icons.route_outlined,
                  label: "Distance",
                  value:
                      "${widget.ride.totalDistance?.toStringAsFixed(2) ?? '0.00'} km",
                  theme: theme,
                ),
                SaveRideInfoRow(
                  icon: Icons.access_time,
                  label: "Duration",
                  value:
                      "${widget.ride.totalTime?.toStringAsFixed(2) ?? '0.00'} min",
                  theme: theme,
                ),
                SaveRideInfoRow(
                  icon: Icons.speed,
                  label: "Top Speed",
                  value:
                      "${widget.ride.topSpeed?.toStringAsFixed(1) ?? '0.0'} km/h",
                  theme: theme,
                ),
                SaveRideInfoRow(
                  icon: Icons.directions_bike_outlined,
                  label: "Average Speed",
                  value:
                      "${widget.ride.averageSpeed?.toStringAsFixed(1) ?? '0.0'} km/h",
                  theme: theme,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Ride Memories Section
            if (widget.ride.rideMemories != null &&
                widget.ride.rideMemories!.isNotEmpty)
              SaveRideSection(
                title: "Ride Memories",
                gradient: [Colors.white, Colors.grey.shade50],
                  children: [
                  RideMemoryRoad(
                    rideMemory: widget.ride.rideMemories!
                        .map((m) => {
                              'imageUrl': m.imageUrl,
                              'title': m.title,
                            })
                        .toList(),
                    startAddress: _isLoadingAddresses 
                        ? "Loading..." 
                        : (_startAddress ?? widget.ride.startCoordinates.toString()),
                    endAddress: _isLoadingAddresses 
                        ? "Loading..." 
                        : (_endAddress ?? (widget.ride.endCoordinates?.toString() ?? "Destination")),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // GEM Coins
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.amber.shade100, Colors.orange.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.amber.shade200, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icons/gem_coin.png',
                      width: 32, height: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My GEM Coins Earning',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade800)),
                      Text(
                        "${widget.ride.totalGEMCoins?.toStringAsFixed(0) ?? (widget.ride.totalDistance?.floor() ?? 0)} GEM Coins",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// RideMemoryRoad widget (same as your implementation)
class RideMemoryRoad extends StatefulWidget {
  final String startAddress;
  final String? endAddress;
  final List<Map<String, dynamic>> rideMemory;

  const RideMemoryRoad({
    super.key,
    required this.rideMemory,
    required this.startAddress,
    this.endAddress,
  });

  @override
  State<RideMemoryRoad> createState() => _RideMemoryRoadState();
}

class _RideMemoryRoadState extends State<RideMemoryRoad> {
  final ScrollController _controller = ScrollController();
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateProgress);
  }

  void _updateProgress() {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions)
      return;

    final maxScroll = _controller.position.maxScrollExtent;
    final currentScroll = _controller.offset;
    setState(() {
      _progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 24),
                  _buildMilestone(widget.startAddress),
                  for (int i = 0; i < widget.rideMemory.length; i++) ...[
                    _roadSegment(),
                    _memoryPoint(widget.rideMemory[i], i),
                  ],
                  _roadSegment(),
                  _buildMilestone(widget.endAddress ?? "Destination"),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _fadeEdge(Alignment.centerLeft),
                    _fadeEdge(Alignment.centerRight),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 4,
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _fadeEdge(Alignment alignment) {
    return Container(
      width: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: alignment,
          end: alignment == Alignment.centerLeft
              ? Alignment.centerRight
              : Alignment.centerLeft,
          colors: [Colors.white, Colors.white.withOpacity(0.0)],
        ),
      ),
    );
  }

  Widget _buildMilestone(String label) {
    return Column(
      children: [
        Image.asset('assets/icons/road_milestone.png', width: 60, height: 60),
        Text(label),
      ],
    );
  }

  Widget _memoryPoint(Map<String, dynamic> memory, int index) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              memory['imageUrl'],
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 70,
                  height: 70,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        Text(memory['title']),
      ],
    );
  }

  Widget _roadSegment() {
    return SizedBox(
      width: 140,
      height: 100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CustomPaint(painter: DottedRoadPainter()),
      ),
    );
  }
}

class DottedRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 6;
    const double dashSpace = 4;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..cubicTo(
        size.width * 0.25,
        -size.height * 0.8,
        size.width * 0.75,
        size.height * 1.3,
        size.width,
        size.height * 0.5,
      );

    PathMetrics pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final segment = metric.extractPath(
          distance,
          distance + dashWidth,
          startWithMoveTo: true,
        );
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashSpace;
      }

      final startPos = metric.getTangentForOffset(0)?.position;
      if (startPos != null) {
        canvas.drawCircle(startPos, 5, Paint()..color = Colors.black);
      }

      final endPos = metric.getTangentForOffset(metric.length)?.position;
      if (endPos != null) {
        canvas.drawCircle(endPos, 5, Paint()..color = Colors.black);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}