import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/models/Location.dart';
import 'package:scenickazatva_app/widgets/DynamicIcon.dart';
import 'package:scenickazatva_app/widgets/DeepLinkButton.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';

class LocationDetailPage extends StatelessWidget {
  final String locationId;
  const LocationDetailPage({super.key, required this.locationId});

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final location = eventsProvider.getLocationById(locationId);

    if (location == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.go('/events'),
          ),
          title: const Text("Lokalita"),
        ),
        body: const Center(
          child: Text("Lokalita sa nenašla.", style: TextStyle(fontStyle: FontStyle.italic)),
        ),
      );
    }

    final color = _parseColor(location.color);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/events'),
        ),
        title: Text(location.displayName),
        actions: [
          const DeepLinkButton(),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Header with icon and color
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _buildIcon(location, color),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  location.displayName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Details card
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (location.description.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(location.description),
                  ),
                if (location.address.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(location.address),
                  ),
                if (location.city.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.location_city),
                    title: Text(location.city),
                  ),
                if (location.latitude.isNotEmpty && location.longitude.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.map_outlined),
                    title: Text("${location.latitude}, ${location.longitude}"),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () {
                      final lat = double.tryParse(location.latitude);
                      final lng = double.tryParse(location.longitude);
                      if (lat != null && lng != null) {
                        SystemServices().launchURL(
                            'https://www.google.com/maps?q=$lat,$lng');
                      }
                    },
                  ),
                if (location.description.isEmpty &&
                    location.address.isEmpty &&
                    location.city.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      "Žiadne detaily.",
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          // Events at this location
          _buildEventsAtLocation(context, eventsProvider, locationId),
        ],
      ),
      floatingActionButton: context.watch<UserProvider>().canEdit
          ? FloatingActionButton(
              onPressed: () => context.go('/locations/$locationId/edit'),
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  Widget _buildEventsAtLocation(
      BuildContext context, EventsProvider provider, String locationId) {
    final events = provider.events.where((e) => e.location == locationId).toList();
    if (events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Podujatia (${events.length})",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final event in events)
            Card(
              child: ListTile(
                title: Text(event.title),
                subtitle: Text(event.artist.isNotEmpty ? event.artist : ""),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/events/${event.id}'),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildIcon(Location location, Color color) {
    try {
      return DynamicIcon(
        codePoint: int.parse(location.icon),
        size: 40,
        color: color,
      );
    } catch (_) {
      return Icon(Icons.location_on, size: 40, color: color);
    }
  }

  Color _parseColor(String colorString) {
    if (colorString.isEmpty) return Colors.black;
    try {
      return Color(int.parse(colorString, radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }
}
