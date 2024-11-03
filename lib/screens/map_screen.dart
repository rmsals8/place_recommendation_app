import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import '../services/location_service.dart';
import '../services/directions_service.dart';
import '../widgets/address_search_dialog.dart'; // 추가
import '../widgets/route_selection_bottom_sheet.dart'; // 추가
import 'dart:math';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _locationService = LocationService();
  final DirectionsService _directionsService = DirectionsService();

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  LatLng? _originLocation;
  LatLng? _destinationLocation;
  bool _isSearchingOrigin = true; // 출발지/도착지 검색 상태 관리

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 검색'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _useCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(37.5666103, 126.9783882), // 서울시청
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _originController,
                      decoration: InputDecoration(
                        labelText: '출발지',
                        prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchAddress(true),
                        ),
                      ),
                      onTap: () => _searchAddress(true),
                      readOnly: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        labelText: '도착지',
                        prefixIcon: const Icon(Icons.location_on),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => _searchAddress(false),
                        ),
                      ),
                      onTap: () => _searchAddress(false),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _originLocation != null && _destinationLocation != null
                            ? _searchRoute
                            : null,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('경로 검색'),
                        ),
                      ),
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

  Future<void> _searchAddress(bool isOrigin) async {
    try {
      // 주소 검색 다이얼로그 표시
      final address = await showDialog<String>(
        context: context,
        builder: (context) => AddressSearchDialog(
          initialValue: isOrigin ? _originController.text : _destinationController.text,
        ),
      );

      if (address == null || address.isEmpty) return;

      try {
        final locations = await geocoding.locationFromAddress(address);
        if (locations.isEmpty) return;

        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);

        setState(() {
          if (isOrigin) {
            _originLocation = latLng;
            _originController.text = address;
          } else {
            _destinationLocation = latLng;
            _destinationController.text = address;
          }
          _updateMarkers();
        });
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('주소를 찾을 수 없습니다: $e')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('주소 검색 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      final latLng = LatLng(position.latitude, position.longitude);

      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: 'ko_KR',
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = '${place.street ?? ''} ${place.thoroughfare ?? ''}'.trim();

        setState(() {
          _originLocation = latLng;
          _originController.text = address;
          _updateMarkers();
        });

        _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('현재 위치를 가져오는데 실패했습니다: $e')),
      );
    }
  }

  void _updateMarkers() {
    _markers.clear();
    _polylines.clear();

    if (_originLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('origin'),
        position: _originLocation!,
        infoWindow: InfoWindow(title: '출발지', snippet: _originController.text),
      ));
    }

    if (_destinationLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLocation!,
        infoWindow: InfoWindow(title: '도착지', snippet: _destinationController.text),
      ));
    }

    if (_originLocation != null && _destinationLocation != null) {
      _fitBounds();
    } else if (_originLocation != null || _destinationLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_originLocation ?? _destinationLocation!),
      );
    }
  }

  void _fitBounds() {
    if (_originLocation == null || _destinationLocation == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        min(_originLocation!.latitude, _destinationLocation!.latitude),
        min(_originLocation!.longitude, _destinationLocation!.longitude),
      ),
      northeast: LatLng(
        max(_originLocation!.latitude, _destinationLocation!.latitude),
        max(_originLocation!.longitude, _destinationLocation!.longitude),
      ),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  Future<void> _searchRoute() async {
    if (_originLocation == null || _destinationLocation == null) return;

    try {
      final routes = await _directionsService.getRoutes(
        _originLocation!,
        _destinationLocation!,
      );

      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            points: routes.first.points,
            color: Colors.blue,
            width: 5,
          ),
        );
      });

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        builder: (context) => RouteSelectionBottomSheet(
          routes: routes,
          onRouteSelected: (route) {
            setState(() {
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: route.points,
                  color: Colors.blue,
                  width: 5,
                ),
              );
            });
            Navigator.pop(context);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('경로 검색 중 오류가 발생했습니다: $e')),
      );
    }
  }
  @override
  void dispose() {
    _mapController?.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}