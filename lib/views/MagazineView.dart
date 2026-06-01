import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scenickazatva_app/providers/NewsProvider.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scenickazatva_app/requests/SystemServices.dart';
import 'package:scenickazatva_app/models/PostExtension.dart';
import 'package:scenickazatva_app/utils/StringUtils.dart';
import 'package:scenickazatva_app/providers/AppSettingsProvider.dart';
import 'package:scenickazatva_app/models/Event.dart';
import 'package:scenickazatva_app/models/Ad.dart';
import 'package:scenickazatva_app/models/Festival.dart';
import 'package:scenickazatva_app/requests/ImagePrecacheService.dart';
import 'package:firebase_cached_image/firebase_cached_image.dart';

class MagazineView extends StatefulWidget {
  @override
  _MagazineViewState createState() => _MagazineViewState();
}

class _MagazineViewState extends State<MagazineView> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showLiveEvents = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.offset > 50 && _showLiveEvents) {
      setState(() {
        _showLiveEvents = false;
      });
    } else if (_scrollController.offset <= 50 && !_showLiveEvents) {
      setState(() {
        _showLiveEvents = true;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final NewsProvider newsProvider = Provider.of<NewsProvider>(context);
    final appSettings = Provider.of<AppSettingsProvider>(context);

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _showLiveEvents
              ? (appSettings.currentlyPlayingEvents.isNotEmpty
                  ? _buildCurrentlyPlaying(context, appSettings)
                  : _buildAds(context, appSettings))
              : const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Hľadať...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              newsProvider.setMagazineSearchQuery(null);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                  onSubmitted: (value) {
                    newsProvider.setMagazineSearchQuery(value.isEmpty ? null : value);
                  },
                ),
              ),
              if (newsProvider.magazineCategories.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildCategoryDropdown(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              if (newsProvider.articlesLoading && newsProvider.wparticles.isEmpty)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (!newsProvider.articlesLoading && newsProvider.wparticles.isEmpty)
                const Center(
                  child: Text("Nenašli sa žiadne články"),
                ),
              Column(
                children: [
                  if (newsProvider.unreadMagazineCount > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${newsProvider.unreadMagazineCount} neprečítaných",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          TextButton(
                            onPressed: () => newsProvider.markAllMagazineAsRead(),
                            child: Text(
                              "Označiť všetky ako prečítané",
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: LazyLoadScrollView(
                      onEndOfPage: () => newsProvider.fetchWpMagazine(fetchMore: true),
                      isLoading: newsProvider.articlesLoading,
                      scrollOffset: 50,
                      child: RefreshIndicator(
                        onRefresh: () => newsProvider.fetchWpMagazine(refresh: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: newsProvider.wparticles.length,
                          itemBuilder: (BuildContext context, int index) {
                            final item = newsProvider.wparticles[index];
                            return Card(
                              child: GestureDetector(
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Expanded(
                                          child: ListTile(
                                            title: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (!newsProvider.isRead(item.id))
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 6.0, right: 8.0),
                                                    child: Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context).colorScheme.primary,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ),
                                                Expanded(
                                                  child: Text(
                                                    item.title?.rendered?.replaceAll('&amp;', '&') ?? "",
                                                    style: Theme.of(context).textTheme.titleMedium,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            isThreeLine: true,
                                            subtitle: Builder(
                                              builder: (context) {
                                                final stripped = StringUtils.stripHtml(item.excerpt?.rendered ?? "");
                                                return Text(
                                                  stripped.length > 100
                                                      ? "${stripped.substring(0, 100)}..."
                                                      : stripped,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14.0),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 120.0,
                                          height: 120.0,
                                          child: CachedNetworkImage(
                                            imageUrl: item.featuredImageSourceUrl(),
                                            fit: BoxFit.cover,
                                            height: double.infinity,
                                            width: double.infinity,
                                            placeholder: (context, url) => Image.asset('assets/images/icon512.png'),
                                            errorWidget: (context, url, error) => Image.asset('assets/images/icon512.png'),
                                          ),
                                        ),
                                      ]),
                                  onTap: () {
                                    newsProvider.markAsRead(item.id);
                                    Analytics().sendEvent(item.title!.rendered);
                                    Analytics().sendEvent("festník article opened");
                                    context.go("/magazine/" + item.id.toString());
                                  }),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (newsProvider.articlesLoading && newsProvider.wparticles.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    final newsProvider = Provider.of<NewsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonHideUnderline(
      child: DropdownButton<int?>(
        value: newsProvider.selectedMagazineCategoryId,
        isExpanded: true,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black,
          fontSize: 14,
          fontFamily: 'Space Grotesk',
        ),
        hint: const Text("Kategórie"),
        items: [
          const DropdownMenuItem<int?>(
            value: null,
            child: Text("Všetky kategórie"),
          ),
          ...newsProvider.magazineCategories.map((category) {
            return DropdownMenuItem<int?>(
              value: category.id,
              child: Text(category.name ?? ""),
            );
          }).toList(),
        ],
        onChanged: (int? value) {
          newsProvider.setMagazineCategory(value);
        },
      ),
    );
  }

  Widget _buildCurrentlyPlaying(BuildContext context, AppSettingsProvider appSettings) {
    final liveEvents = appSettings.currentlyPlayingEvents;

    if (liveEvents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            "Práve prebiehajúce podujatia",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: liveEvents.length,
            itemBuilder: (context, index) {
              final Festival fest = liveEvents[index].key;
              final Event event = liveEvents[index].value;

              return GestureDetector(
                onTap: () {
                  appSettings.changeFestival(fest.id);
                  context.go("/events/${event.id}");
                },
                child: Container(
                  width: 280,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FutureBuilder<bool>(
                            future: event.image.isNotEmpty
                                ? ImagePrecacheService().doesImageExist(event.image)
                                : Future.value(false),
                            builder: (context, snapshot) {
                              final bool exists =
                                  snapshot.data ?? (ImagePrecacheService().checkCache(event.image) ?? false);
                              final String effectiveUrl = exists ? event.image : fest.logo;

                              if (effectiveUrl.isEmpty) {
                                return Image.asset('assets/images/icon512.png', fit: BoxFit.cover);
                              }

                              return Image(
                                image: FirebaseImageProvider(FirebaseUrl(effectiveUrl)),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Image.asset('assets/images/icon512.png', fit: BoxFit.cover),
                              );
                            },
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                fest.title,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildAds(BuildContext context, AppSettingsProvider appSettings) {
    final ads = appSettings.activeAds;

    if (ads.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];

              return GestureDetector(
                onTap: () {
                  if (ad.link.isNotEmpty) {
                    SystemServices().launchURL(ad.link);
                  }
                },
                child: Container(
                  width: ads.length == 1
                      ? MediaQuery.of(context).size.width - 24
                      : MediaQuery.of(context).size.width - 48,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FutureBuilder<bool>(
                            future: ad.image.isNotEmpty
                                ? ImagePrecacheService().doesImageExist(ad.image)
                                : Future.value(false),
                            builder: (context, snapshot) {
                              final bool exists = snapshot.data ??
                                  (ImagePrecacheService().checkCache(ad.image) ?? false);
                              if (!exists || ad.image.isEmpty) {
                                return Container(color: Theme.of(context).colorScheme.primaryContainer);
                              }

                              return Image(
                                image: FirebaseImageProvider(FirebaseUrl(ad.image)),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: Theme.of(context).colorScheme.primaryContainer),
                              );
                            },
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ad.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20 * appSettings.settings.fontSizeFactor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (ad.description.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    ad.description,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              const Spacer(),
                              if (ad.cta.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    ad.cta,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(),
      ],
    );
  }
}
