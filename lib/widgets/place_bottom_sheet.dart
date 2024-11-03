// lib/widgets/route_selection_bottom_sheet.dart
import 'package:flutter/material.dart';
import '../services/directions_service.dart';

class RouteSelectionBottomSheet extends StatelessWidget {
  final List<RouteInfo> routes;
  final Function(RouteInfo) onRouteSelected;

  const RouteSelectionBottomSheet({
    Key? key,
    required this.routes,
    required this.onRouteSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '경로 선택',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 16),
          ...routes.map((route) => _RouteOption(
            route: route,
            onTap: () {
              onRouteSelected(route);
              Navigator.pop(context);
            },
          )).toList(),
        ],
      ),
    );
  }
}

class _RouteOption extends StatelessWidget {
  final RouteInfo route;
  final VoidCallback onTap;

  const _RouteOption({
    Key? key,
    required this.route,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text('소요 시간: ${route.duration}'),
        subtitle: Text('거리: ${route.distance}'),
        trailing: Icon(Icons.arrow_forward_ios),
      ),
    );
  }
}