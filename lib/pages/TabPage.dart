import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/InfoProvider.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:scenickazatva_app/providers/UserProvider.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/views/CalendarView.dart';
import 'package:scenickazatva_app/views/InfoView.dart';
import 'package:scenickazatva_app/views/NewsView.dart';
import 'package:scenickazatva_app/views/MagazineView.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';

class TabPage extends StatefulWidget {
  final initialIndex;
  TabPage({required this.initialIndex});
  @override
  _TabPageState createState() => _TabPageState();
}

class _TabPageState extends State<TabPage> {
  static List<Widget> _widgetOptions = <Widget>[
    MagazineView(),
    CalendarView(),
    NewsView(),
    InfoView(),
//    MagazineView(),
  ];
  Festival festival = Festival();
  int _selectedIndex = 0;
  PageController _pageController = PageController();

  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(
      initialPage: widget.initialIndex,
      keepPage: true,
    );
  }

  void _itemTapped(int index, newsProvider, eventsProvider, infoProvider) {
    Analytics().sendEvent("menu: "+index.toString());
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  void pageChanged(
      int index, newsProvider, eventsProvider, infoProvider) async {

    if (index == 2) {
      newsProvider.fetchWpNews();
    } else if (index == 1) {
      // Events are updated automatically via ProxyProvider
    } else if (index == 3) {
      // Info is updated automatically via ProxyProvider
    } else if (index == 0) {
      newsProvider.fetchWpMagazine();
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Widget buildPageView(newsProvider, eventsProvider, infoProvider) {
    return PageView(
        controller: _pageController,
        onPageChanged: (index) {
          pageChanged(index, newsProvider, eventsProvider, infoProvider);
        },
        children: _widgetOptions);
  }

  @override
  Widget build(BuildContext context) {
    final NewsProvider newsProvider = Provider.of<NewsProvider>(context);
    final EventsProvider eventsProvider = Provider.of<EventsProvider>(context);
    final InfoProvider infoProvider = Provider.of<InfoProvider>(context);
    final FestivalProvider festivalProvider = Provider.of<FestivalProvider>(context, listen: false);
    festival = festivalProvider.festival;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? "javisko.sk"
              : _selectedIndex == 1
              ? "Program"
              : _selectedIndex == 2
              ? "Festník"
              : _selectedIndex == 3
              ? "Info"
              : "Festival",
        ),
        actions: <Widget>[
          // --- FESTIVAL SELECTOR DROPDOWN ---
          Consumer<AppSettingsProvider>(
            builder: (context, settings, child) {
              if (settings.allFestivals.isEmpty) return const SizedBox();
              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: Theme.of(context).primaryColor,

                  // Bind the text color of the selected item and items in the menu
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  value: settings.allFestivals.any((f) => f.id == settings.defaultfestival)
                      ? settings.defaultfestival
                      : (settings.allFestivals.isNotEmpty ? settings.allFestivals.first.id : null),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),

                  // This builds the widget inside the AppBar when closed
                  selectedItemBuilder: (context) {
                    return settings.allFestivals.map((f) {
                      return Center(
                        child: Text(
                          // Use the active festival title from the provider if IDs match
                          // This acts as a secondary buffer against empty titles in the list
                          (f.id == settings.defaultfestival && festivalProvider.festival.title.isNotEmpty)
                              ? festivalProvider.festival.title
                              : (f.title.isEmpty ? f.id : f.title),
                          style: const TextStyle(
                              fontFamily: 'Space Grotesk',
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList();
                  },
                  // This builds the list of choices when opened
                  items: settings.allFestivals.map((f) {
                    return DropdownMenuItem<String>(
                      value: f.id,
                      child: Text(
                        (f.title.isEmpty) ? f.id : f.title,
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          fontSize: 14,
                          // Use theme onSurface color for adaptive support
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newId) {
                    if (newId != null) {
                      settings.changeFestival(newId);
                    }
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.favorite, color: Colors.white70),
            onPressed: () {
              Analytics().sendEvent("menu: favorites");
              context.go('/favorites');
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              Analytics().sendEvent("menu: settings");
              context.go('/settings');
            },
          ),
        ],
      ),
      body: Center(
        child: buildPageView(newsProvider, eventsProvider, infoProvider),
      ),
      floatingActionButton: (kIsWeb && (_selectedIndex == 1 || _selectedIndex == 3) && context.watch<UserProvider>().canEdit)
          ? FloatingActionButton(
              onPressed: () {
                if (_selectedIndex == 1) {
                  context.go("/events/new/edit");
                } else if (_selectedIndex == 3) {
                  context.go("/info/new/edit");
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
          destinations: <Widget>[
            NavigationDestination(
              icon: Badge(
                label: Text(newsProvider.unreadMagazineCount.toString()),
                isLabelVisible: newsProvider.unreadMagazineCount > 0,
                child: Icon(Icons.menu_book),
              ),
              label: 'javisko.sk',
            ),
            NavigationDestination(
              icon: Icon(Icons.date_range),
              label: festival.menuTitle,
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications),
              label: 'Novinky',
            ),
            NavigationDestination(
              icon: Icon(Icons.info),
              label: 'Info',
            ),
          ],
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              _itemTapped(index, newsProvider, eventsProvider, infoProvider)),
    );
  }
}
