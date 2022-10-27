import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rate_limiter/rate_limiter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vrc_ranks_app/Schema/Events.dart';
import 'package:vrc_ranks_app/events.dart';
import 'package:vrc_ranks_app/team.dart';
import 'Request.dart' as Request;
import 'match.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import 'package:collection/collection.dart';

class EventPage extends ConsumerStatefulWidget {
  const EventPage({Key? key, required this.title, required this.event_old}) : super(key: key);

  final String title;
  final Event event_old;

  @override
  _EventPageState createState() => _EventPageState();
}

class _EventPageState extends ConsumerState<EventPage> {
  Event _event = Event();
  Event event = Event();

  String convertDate(String date) {
    var humanDate = DateTime.parse(date);

    return DateFormat("MMM dd, yyyy").format(humanDate);
  }

  @override
  void initState() {
    super.initState();
    Request.getEventDetails(widget.event_old.id.toString()).then((value) {
      if (this.mounted) {
        setState(() {
          _event = value;
          event = value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoriteCompsProvider);

    final getEventDetailsThrottled = throttle(
      () async => {
        event = await Request.getEventDetails(widget.event_old.id.toString()),
        if (this.mounted)
          {
            setState(() {
              _event = event;
              event = event;
            }),
          },
      },
      const Duration(seconds: 2),
    );
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                title: Text(widget.title,
                    style: const TextStyle(
                      overflow: TextOverflow.fade,
                    )),
                actions: [
                  IconButton(
                    icon:
                        ref.read(favoriteCompsProvider.notifier).state.contains(event.id.toString())
                            ? const Icon(Icons.star)
                            : const Icon(Icons.star_border_outlined),
                    onPressed: () {
                      List<String> oldState = ref.read(favoriteCompsProvider.notifier).state;
                      if (oldState.contains(event.id.toString())) {
                        oldState.remove(event.id.toString());
                      } else {
                        oldState.add(event.id.toString());
                      }
                      ref.read(favoriteCompsProvider.notifier).update((state) => oldState.toList());

                      SharedPreferences.getInstance()
                          .then((prefs) => prefs.setStringList('favoriteComps', oldState.toList()));
                    },
                  ),
                ],
                pinned: true,
                forceElevated: innerBoxIsScrolled,
              ),
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    (event.divisions?[0].data?.data).toString() == "null"
                        ? const Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Colors.red,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              children: [
                                RefreshIndicator(
                                  child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: Theme.of(context).cardColor,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      margin: const EdgeInsets.all(4),
                                      child: Flex(direction: Axis.vertical, children: [
                                        ListView(
                                            shrinkWrap: true,
                                            padding: const EdgeInsets.all(8),
                                            physics: const NeverScrollableScrollPhysics(),
                                            children: <Widget>[
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 5),
                                                child: Text(
                                                  event.name.toString(),
                                                  style: const TextStyle(fontSize: 20),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 10),
                                                child: Text(
                                                  "${convertDate(event.start.toString())} - ${convertDate(event.end.toString())}",
                                                  style: const TextStyle(fontSize: 15),
                                                ),
                                              ),
                                              Text(
                                                "Ongoing: ${event.ongoing.toString() == "true" ? "Yes" : "No"}",
                                                style: const TextStyle(fontSize: 15),
                                              ),
                                              Text(
                                                "Competition: ${event.season?.name.toString()}",
                                                style: const TextStyle(fontSize: 15),
                                              ),
                                            ]),
                                        Align(
                                            alignment: FractionalOffset.bottomRight,
                                            child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  Column(
                                                    children: [
                                                      InkWell(
                                                        onTap: () {
                                                          if (Platform.isAndroid) {
                                                            launchUrl(
                                                                Uri.parse(
                                                                    "https://maps.google.com/?q=${event.location?.venue.toString()} ${event.location?.address1.toString()}, ${event.location?.city.toString()} ${event.location?.country.toString()}"),
                                                                mode:
                                                                    LaunchMode.externalApplication);
                                                          } else if (Platform.isIOS) {
                                                            launchUrl(
                                                                Uri.parse(
                                                                    "https://maps.apple.com/?q=${event.location?.venue.toString()} ${event.location?.address1.toString()}, ${event.location?.city.toString()} ${event.location?.country.toString()}"),
                                                                mode:
                                                                    LaunchMode.externalApplication);
                                                          }
                                                          log("Redirect to navigation app");
                                                        },
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            borderRadius: BorderRadius.circular(10),
                                                            color:
                                                                Theme.of(context).backgroundColor,
                                                          ),
                                                          padding: const EdgeInsets.all(10),
                                                          margin: const EdgeInsets.symmetric(
                                                              horizontal: 10),
                                                          child: const Icon(
                                                              Icons.navigation_rounded,
                                                              size: 30),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    children: [
                                                      InkWell(
                                                        onTap: () {
                                                          launchUrl(
                                                              Uri.parse(
                                                                  "https://www.robotevents.com/robot-competitions/vex-robotics-competition/${event.sku}.html"),
                                                              mode: LaunchMode.externalApplication);
                                                          log("Redirect to web browser with comp link");
                                                        },
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            borderRadius: BorderRadius.circular(10),
                                                            color:
                                                                Theme.of(context).backgroundColor,
                                                          ),
                                                          padding: const EdgeInsets.all(10),
                                                          child: const Icon(Icons.link, size: 30),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ]))
                                      ])),
                                  onRefresh: () async {
                                    await getEventDetailsThrottled();
                                  },
                                ),
                                TabBar(
                                  indicatorColor: Theme.of(context).colorScheme.secondary,
                                  tabs: const [
                                    Tab(icon: Icon(Icons.schedule), text: "Matches"),
                                    Tab(icon: Icon(Icons.people), text: "Teams"),
                                    Tab(icon: Icon(Icons.bar_chart), text: "Rankings"),
                                  ],
                                ),
                              ],
                            ),
                          )
                  ],
                ),
              )
            ];
          },
          body: TabBarView(
            children: [
              (event.divisions?[0].data?.data).toString() == "null"
                  ? const Text("")
                  : event.divisions?[0].data?.data?.length == 0
                      ? const Center(child: Text("No matches found"))
                      : RefreshIndicator(
                          child: MediaQuery.removePadding(
                            removeTop: true,
                            context: context,
                            child: ListView(children: [
                              for (var i = 0;
                                  i <= (((event.divisions?[0].data?.data?.length ?? 1) - 1));
                                  i++)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                          builder: (context) => MatchPage(
                                              title: (event.divisions?[0].data?.data?[i].name)
                                                  .toString(),
                                              event_old: event,
                                              match_number:
                                                  (event.divisions?[0].data?.data?[i].id ?? 0)
                                                      .toInt())),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Theme.of(context).cardColor,
                                    ),
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(horizontal: 30),
                                    margin: const EdgeInsets.all(4),
                                    child: Center(
                                      child: Text(
                                          (event.divisions?[0].data?.data?[i].name).toString()),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                          onRefresh: () async {
                            await getEventDetailsThrottled();
                          },
                        ),
              (event.teams?.data).toString() == "null"
                  ? const Text("")
                  : event.teams?.data?.length == 0
                      ? const Center(child: Text("No teams found"))
                      : RefreshIndicator(
                          child: MediaQuery.removePadding(
                            removeTop: true,
                            context: context,
                            child: ListView(children: [
                              for (var i = 0; i <= (((_event.teams?.data?.length ?? 1) - 1)); i++)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (context) => TeamPage(
                                            title: (event.teams?.data?[i].number).toString(),
                                            event_old: event,
                                            match_id: event.id.toString(),
                                            team_id: (event.teams?.data?[i].id).toString()),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Theme.of(context).cardColor,
                                    ),
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(horizontal: 30),
                                    margin: const EdgeInsets.all(4),
                                    child: Flex(
                                      direction: Axis.horizontal,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: RichText(
                                            text: TextSpan(
                                              children: [
                                                WidgetSpan(
                                                  alignment: PlaceholderAlignment.middle,
                                                  child: Text(
                                                    (event.teams?.data?[i].number).toString(),
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Spacer(flex: 2),
                                        if (event.teams?.data?[i].teamName != null)
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              width: 160,
                                              child: Text(
                                                (event.teams?.data?[i].teamName).toString(),
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    color: Theme.of(context).colorScheme.tertiary),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                softWrap: false,
                                              ),
                                            ),
                                          ),
                                        const Spacer(flex: 5),
                                        if (event.rankings?[0].data != null)
                                          if ((event.rankings?[0].data?.length ?? 0) > 0)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: RichText(
                                                text: TextSpan(
                                                  children: [
                                                    WidgetSpan(
                                                      alignment: PlaceholderAlignment.middle,
                                                      child: Text(
                                                        "Rank: ${event.rankings?[0].data?[i].rank}      ${event.rankings?[0].data?[i].wins}-${event.rankings?[0].data?[i].losses}-${event.rankings?[0].data?[i].ties}",
                                                        style: TextStyle(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .tertiary,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                          onRefresh: () async {
                            await getEventDetailsThrottled();
                          },
                        ),
              (event.rankings?[0]).toString() == "null"
                  ? const Text("")
                  : event.rankings?[0].data?.length == 0
                      ? const Center(child: Text("No rankings found"))
                      : RefreshIndicator(
                          child: MediaQuery.removePadding(
                            removeTop: true,
                            context: context,
                            child: ListView(children: [
                              for (var i = (((event.rankings?[0].data?.length ?? 1) - 1));
                                  i >= 0;
                                  i--)
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (context) => TeamPage(
                                            title:
                                                (event.rankings?[0].data?[i].team?.name).toString(),
                                            event_old: event,
                                            match_id: event.id.toString(),
                                            team_id:
                                                (event.rankings?[0].data?[i].team?.id).toString()),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Theme.of(context).cardColor,
                                    ),
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(horizontal: 30),
                                    margin: const EdgeInsets.all(4),
                                    child: Flex(
                                      direction: Axis.horizontal,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: RichText(
                                            text: TextSpan(
                                              children: [
                                                WidgetSpan(
                                                    alignment: PlaceholderAlignment.middle,
                                                    child: Text(
                                                      "${event.rankings?[0].data?[i].rank}. ",
                                                      style: TextStyle(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .secondary,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 18),
                                                    )),
                                                WidgetSpan(
                                                  alignment: PlaceholderAlignment.middle,
                                                  child: Text(
                                                    (event.rankings?[0].data?[i].team?.name)
                                                        .toString(),
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: RichText(
                                            text: TextSpan(
                                              children: [
                                                WidgetSpan(
                                                  alignment: PlaceholderAlignment.middle,
                                                  child: Text(
                                                    "WP: ${(event.rankings?[0].data?[i].wp).toString()} AP: ${(event.rankings?[0].data?[i].ap).toString()} SP: ${(event.rankings?[0].data?[i].sp).toString()}      ${event.rankings?[0].data?[i].wins}-${event.rankings?[0].data?[i].losses}-${event.rankings?[0].data?[i].ties}",
                                                    style: TextStyle(
                                                      color: Theme.of(context).colorScheme.tertiary,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                          onRefresh: () async {
                            await getEventDetailsThrottled();
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
