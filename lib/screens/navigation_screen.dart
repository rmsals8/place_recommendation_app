import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import '../services/location_service.dart';
import '../models/route_info.dart';

class NavigationScreen extends StatefulWidget {
  final RouteInfo route;
  final LatLng origin;
  final LatLng destination;

  const NavigationScreen({
    Key? key,
    required this.route,
    required this.origin,
    required this.destination,
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  Timer? _locationTimer;
  int _currentStep = 0;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _startNavigation();
  }

  void _startNavigation() {
    setState(() {
      _isNavigating = true;
    });
    _locationTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _updateCurrentLocation(),
    );
  }

  void _pauseNavigation() {
    setState(() {
      _isNavigating = false;
    });
    _locationTimer?.cancel();
  }

  void _resumeNavigation() {
    _startNavigation();
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      if (_isNavigating) {
        _updateCamera();
        _updateNavigationProgress();
      }
    } catch (e) {
      print('위치 업데이트 실패: $e');
    }
  }

  void _updateCamera() {
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: 17,
            tilt: 45,
            bearing: _calculateBearing(),
          ),
        ),
      );
    }
  }

  double _calculateBearing() {
    if (_currentStep + 1 >= widget.route.points.length) return 0;

    final current = widget.route.points[_currentStep];
    final next = widget.route.points[_currentStep + 1];

    final dx = next.longitude - current.longitude;
    final dy = next.latitude - current.latitude;

    return (360 + (atan2(dx, dy) * 180 / pi)) % 360;
  }

  void _updateNavigationProgress() {
    if (_currentLocation == null) return;

    // 현재 위치와 가장 가까운 경로 포인트 찾기
    double minDistance = double.infinity;
    int nearestIndex = _currentStep;

    for (int i = _currentStep; i < widget.route.points.length; i++) {
      final point = widget.route.points[i];
      final distance = _calculateDistance(_currentLocation!, point);

      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    if (nearestIndex != _currentStep) {
      setState(() {
        _currentStep = nearestIndex;
      });
    }

    // 목적지 도착 확인 (50m 이내)
    if (_calculateDistance(_currentLocation!, widget.destination) < 50) {
      _showArrivalDialog();
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const double earthRadius = 6371000; // 미터
    final lat1 = p1.latitude * (pi / 180);
    final lat2 = p2.latitude * (pi / 180);
    final dLat = (p2.latitude - p1.latitude) * (pi / 180);
    final dLng = (p2.longitude - p1.longitude) * (pi / 180);

    final a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) *
            sin(dLng/2) * sin(dLng/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadius * c;
  }

  String _getRemainingDistance() {
    if (_currentLocation == null) return widget.route.distance;

    double totalDistance = 0;
    for (int i = _currentStep; i < widget.route.points.length - 1; i++) {
      totalDistance += _calculateDistance(
        widget.route.points[i],
        widget.route.points[i + 1],
      );
    }

    if (totalDistance < 1000) {
      return '${totalDistance.round()}m';
    } else {
      return '${(totalDistance / 1000).toStringAsFixed(1)}km';
    }
  }

  String _getRemainingTime() {
    if (_currentLocation == null) return widget.route.duration;

    final distance = _getRemainingDistance();
    final km = distance.contains('km')
        ? double.parse(distance.replaceAll('km', ''))
        : double.parse(distance.replaceAll('m', '')) / 1000;

    // 평균 속도를 40km/h로 가정
    final minutes = (km / 40 * 60).round();
    return '$minutes분';
  }

  void _showArrivalDialog() {
    _locationTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('목적지 도착'),
        content: const Text('목적지에 도착했습니다.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              Navigator.of(context).pop(); // 네비게이션 화면 닫기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('실시간 내비게이션'),
        actions: [
          IconButton(
            icon: Icon(_isNavigating ? Icons.pause : Icons.play_arrow),
            onPressed: _isNavigating ? _pauseNavigation : _resumeNavigation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.origin,
              zoom: 17,
              tilt: 45,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              _updateCurrentLocation();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapType: MapType.normal,
            polylines: {
              Polyline(
                polylineId: const PolylineId('navigation_route'),
                points: widget.route.points,
                color: Colors.blue,
                width: 5,
              ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('destination'),
                position: widget.destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: const InfoWindow(title: '목적지'),
              ),
            },
          ),
          // 하단 정보 패널
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '남은 거리: ${_getRemainingDistance()}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '예상 시간: ${_getRemainingTime()}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.my_location),
                              onPressed: _updateCamera,
                            ),
                            IconButton(
                              icon: const Icon(Icons.layers),
                              onPressed: () {
                                // 지도 타입 변경 기능 추가 예정
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}