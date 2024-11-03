import 'package:flutter/material.dart';
import '../models/route_info.dart';
import '../models/place.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/places_service.dart';
import '../screens/navigation_screen.dart';
import '../widgets/place_detail_dialog.dart';

class RouteSelectionBottomSheet extends StatefulWidget {
  final List<RouteInfo> routes;
  final Function(RouteInfo) onRouteSelected;
  final GoogleMapController? mapController;
  final Function(Set<Marker>)? onMarkersUpdate;

  const RouteSelectionBottomSheet({
    Key? key,
    required this.routes,
    required this.onRouteSelected,
    this.mapController,
    this.onMarkersUpdate,
  }) : super(key: key);

  @override
  State<RouteSelectionBottomSheet> createState() => _RouteSelectionBottomSheetState();
}

class _RouteSelectionBottomSheetState extends State<RouteSelectionBottomSheet> with SingleTickerProviderStateMixin {
  final PlacesService _placesService = PlacesService();
  List<Place> _startAreaPlaces = [];
  List<Place> _endAreaPlaces = [];
  bool _isLoadingPlaces = false;
  RouteInfo? _selectedRoute;
  late TabController _tabController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3개의 탭으로 변경
    if (widget.routes.isNotEmpty) {
      _selectedRoute = widget.routes.first;
      _searchPlaces(_selectedRoute!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Marker _createPlaceMarker(Place place) {
    return Marker(
      markerId: MarkerId(place.id),
      position: place.location,
      infoWindow: InfoWindow(
        title: place.name,
        snippet: '${place.category} • ${(place.distance / 1000).toStringAsFixed(1)}km',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }

  Future<void> _searchPlaces(RouteInfo route) async {
    setState(() {
      _isLoadingPlaces = true;
      _startAreaPlaces = [];
      _endAreaPlaces = [];
    });

    try {
      final places = await _placesService.searchNearbyPlaces(route.points);

      setState(() {
        // 출발지와 도착지 근처의 장소 분리
        _startAreaPlaces = places.where((p) => p.distance <= 1000).toList();
        _endAreaPlaces = places.where((p) => p.distance > 1000).toList();
        _isLoadingPlaces = false;

        _markers = places.map((place) => _createPlaceMarker(place)).toSet();
        widget.onMarkersUpdate?.call(_markers);
      });
    } catch (e) {
      setState(() {
        _isLoadingPlaces = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추천 장소를 가져오는데 실패했습니다: $e')),
        );
      }
    }
  }

  void _moveToPlace(Place place) {
    widget.mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        place.location,
        16,
      ),
    );

    setState(() {
      _markers = {_createPlaceMarker(place)};
      widget.onMarkersUpdate?.call(_markers);
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: '추천 경로'),
                    Tab(text: '출발지 주변'),
                    Tab(text: '도착지 주변'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRoutesTab(scrollController),
                      _buildStartAreaTab(scrollController),
                      _buildEndAreaTab(scrollController),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoutesTab(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        ...widget.routes.map((route) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              setState(() => _selectedRoute = route);
              _searchPlaces(route);
              widget.onRouteSelected(route);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '소요 시간: ${route.duration}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '거리: ${route.distance}',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NavigationScreen(
                            route: route,
                            origin: route.points.first,
                            destination: route.points.last,
                            recommendedPlaces: _startAreaPlaces + _endAreaPlaces,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('길안내'),
                  ),
                ],
              ),
            ),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildPlaceList(List<Place> places, ScrollController scrollController) {
    if (_isLoadingPlaces) {
      return const Center(child: CircularProgressIndicator());
    }

    if (places.isEmpty) {
      return const Center(
        child: Text('추천할만한 장소가 없습니다.'),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => PlaceDetailDialog(
                  place: place,
                  onShowOnMap: () => _moveToPlace(place),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: const Icon(Icons.place, color: Colors.blue),
            ),
            title: Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '거리: ${(place.distance / 1000).toStringAsFixed(1)}km',
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (place.rating > 0) ...[
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    place.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStartAreaTab(ScrollController scrollController) {
    return _buildPlaceList(_startAreaPlaces, scrollController);
  }

  Widget _buildEndAreaTab(ScrollController scrollController) {
    return _buildPlaceList(_endAreaPlaces, scrollController);
  }
}