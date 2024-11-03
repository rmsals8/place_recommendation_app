import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_info.dart';
import '../models/place.dart';
import '../services/places_service.dart';
import '../screens/navigation_screen.dart';
import '../widgets/place_detail_dialog.dart';  // 추가

class RouteSelectionBottomSheet extends StatefulWidget {
  final List<RouteInfo> routes;
  final Function(RouteInfo) onRouteSelected;
  final GoogleMapController? mapController;

  const RouteSelectionBottomSheet({
    Key? key,
    required this.routes,
    required this.onRouteSelected,
    this.mapController,
  }) : super(key: key);

  @override
  State<RouteSelectionBottomSheet> createState() => _RouteSelectionBottomSheetState();
}

class _RouteSelectionBottomSheetState extends State<RouteSelectionBottomSheet> with SingleTickerProviderStateMixin {
  final PlacesService _placesService = PlacesService();
  List<Place> _recommendedPlaces = [];
  bool _isLoadingPlaces = false;
  RouteInfo? _selectedRoute;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  Future<void> _searchPlaces(RouteInfo route) async {
    setState(() {
      _isLoadingPlaces = true;
    });

    try {
      final places = await _placesService.searchNearbyPlaces(route.points);
      setState(() {
        _recommendedPlaces = places;
        _isLoadingPlaces = false;
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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
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
                    Tab(text: '추천 장소'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRoutesTab(scrollController),
                      _buildPlacesTab(scrollController),
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
                            recommendedPlaces: _recommendedPlaces,
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

  Widget _buildPlacesTab(ScrollController scrollController) {
    if (_isLoadingPlaces) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recommendedPlaces.isEmpty) {
      return const Center(
        child: Text('경로 주변에 추천할만한 장소가 없습니다.'),
      );
    }

    Map<int, List<Place>> placeGroups = {};
    for (var place in _recommendedPlaces) {
      final groupIndex = (place.distance / 500).floor();
      placeGroups.putIfAbsent(groupIndex, () => []).add(place);
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: placeGroups.length,
      itemBuilder: (context, index) {
        final groupDistance = index * 500;
        final places = placeGroups[index] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '출발지로부터 ${groupDistance}m ~ ${groupDistance + 500}m',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...places.map((place) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
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
              ),
            )).toList(),
            const Divider(height: 32),
          ],
        );
      },
    );
  }
}