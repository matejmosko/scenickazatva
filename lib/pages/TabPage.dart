import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/EventsProvider.dart';
import 'package:scenickazatva_app/providers/InfoProvider.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:scenickazatva_app/providers/FestivalProvider.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/views/CalendarView.dart';
import 'package:scenickazatva_app/views/InfoView.dart';
import 'package:scenickazatva_app/views/NewsView.dart';
import 'package:scenickazatva_app/views/MagazineView.dart';
import 'package:provider/provider.dart';
import 'package:scenickazatva_app/requests/api.dart';

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
      newsProvider.fetchWpNews("news_src");
    } else if (index == 1) {
      await eventsProvider.fetchAllEvents();
      await eventsProvider.fetchLocations();
    } else if (index == 3) {
      await infoProvider.fetchInfo();
    } else if (index == 0) {
      newsProvider.fetchWpMagazine("magazine_src");
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
    festivalProvider.fetchFestival();
    festival = festivalProvider.festival;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0 ? "javisko.sk" : _selectedIndex == 1 ? "Program "+festival.title : _selectedIndex == 2 ? "Festník "+festival.title : _selectedIndex == 3 ? "Info "+festival.title : festival.title,
        ),
        actions: <Widget>[
          kIsWeb == true
              ? IconButton(
                  icon: Icon(
                    Icons.settings,
                  ),
                  onPressed: () {
                    Analytics().sendEvent("menu: settings");
                    context.go('/settings');
                  },
                )
              : SizedBox(),
          kIsWeb == true
              ? IconButton(
                  icon: Icon(
                    Icons.person,
                  ),
                  onPressed: () {
                    // TODO Pridať možnosť prihlásiť sa na webe.
                    context.go('/settings');
                  },
                )
              : SizedBox(),
        ],
      ),
      body: Center(
        child: buildPageView(newsProvider, eventsProvider, infoProvider),
      ),
      bottomNavigationBar: NavigationBar(
          destinations: <Widget>[
            NavigationDestination(
              icon: Icon(Icons.menu_book),
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
