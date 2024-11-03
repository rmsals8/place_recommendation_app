import 'package:flutter/material.dart';
import '../models/place.dart';
import '../models/route_info.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/place_detail_dialog.dart';

class PlaceBottomSheet extends StatelessWidget {
  final RouteInfo route;
  final List<Place> places;
  final Function(Place) onPlaceSelected;
  final GoogleMapController? mapController;

  const PlaceBottomSheet({
    Key? key,
    required this.route,
    required this.places,
    required this.onPlaceSelected,
    this.mapController,
  }) : super(key: key);

  void _moveToPlace(BuildContext context, Place place) {
    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        place.location,
        16,
      ),
    );
    Navigator.pop(context);
    onPlaceSelected(place);
  }

  @override
  Widget build(BuildContext context) {
    // 500m 단위로 장소들을 그룹화
    Map<int, List<Place>> placeGroups = {};
    for (var place in places) {
      final groupIndex = (place.distance / 500).floor();
      placeGroups.putIfAbsent(groupIndex, () => []).add(place);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '경로 주변 추천 장소',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '총 거리: ${route.distance} • 예상 시간: ${route.duration}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: places.isEmpty
                    ? const Center(
                  child: Text('경로 주변에 추천할만한 장소가 없습니다.'),
                )
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: placeGroups.length,
                  itemBuilder: (context, index) {
                    final groupDistance = index * 500;
                    final nextGroupDistance = (index + 1) * 500;
                    final groupPlaces = placeGroups[index] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '출발지로부터 ${groupDistance}m ~ ${nextGroupDistance}m',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...groupPlaces.map((place) => Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => PlaceDetailDialog(
                                  place: place,
                                  onShowOnMap: () => _moveToPlace(context, place),
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
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    place.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                        const Divider(height: 32),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}