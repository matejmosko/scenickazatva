import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/views/CalendarView.dart'; // We can reuse EventListItem
import 'package:go_router/go_router.dart';

class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final eventsProvider = Provider.of<EventsProvider>(context);
    final festivalProvider = Provider.of<FestivalProvider>(context);
    final festival = festivalProvider.festival;

    final favoriteIds = userProvider.userData.favorites[festival.id] ?? [];
    final favoriteEvents = eventsProvider.events.where((e) => favoriteIds.contains(e.id)).toList();
    
    // Sort favorites by time
    favoriteEvents.sort((a, b) => (a.startTime ?? DateTime(0)).compareTo(b.startTime ?? DateTime(0)));

    return Scaffold(
      appBar: AppBar(
        title: Text("Moje obľúbené"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/'),
        ),
      ),
      body: favoriteEvents.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Zatiaľ nemáte žiadne obľúbené podujatia\npre festival ${festival.title}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: favoriteEvents.length,
              itemBuilder: (context, index) {
                return EventListItem(
                  event: favoriteEvents[index],
                  festival: festival,
                );
              },
            ),
    );
  }
}
