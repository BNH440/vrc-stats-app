import 'dart:developer';

import 'package:hive/hive.dart';
import 'package:vrc_ranks_app/Hive/Team.dart';
import 'package:vrc_ranks_app/Request.dart';
import 'package:vrc_ranks_app/globals.dart' as globals;
import '../Schema/Events.dart' show Location;
import '../Schema/Events.dart' as schema;
import '../Schema/Division.dart' as divschema;
import '../Schema/Rankings.dart' as rankschema;

part 'Event.g.dart';

@HiveType(typeId: 4)
class Event extends HiveObject {
  Event.eventInfo(
      {required this.id,
      required this.sku,
      required this.name,
      required this.start,
      required this.end,
      required this.location,
      required this.level,
      required this.ongoing,
      required this.awardsFinalized,
      required this.seasonName,
      required this.isLocal,
      required this.distance,
      required this.seasonId,
      required this.schemaVersion});

  Event({
    required this.id,
    required this.sku,
    required this.name,
    required this.start,
    required this.end,
    required this.location,
    required this.divisions,
    required this.teams,
    required this.level,
    required this.ongoing,
    required this.awardsFinalized,
    required this.seasonName,
    required this.isLocal,
    required this.distance,
    required this.seasonId,
    required this.schemaVersion,
  });

  Event.empty({
    this.id = -1,
    this.sku = "",
    this.name = "",
    this.seasonId = "",
    this.schemaVersion = "",
  });

  @HiveField(0)
  int id;

  @HiveField(1)
  String sku;

  @HiveField(2)
  String name;

  @HiveField(3)
  String? start;

  @HiveField(4)
  String? end;

  @HiveField(5)
  Location? location;

  @HiveField(6)
  List<Division>? divisions;

  @HiveField(7)
  HiveList<Team>? teams;

  @HiveField(8)
  String? level;

  @HiveField(9)
  bool? ongoing;

  @HiveField(10)
  bool? awardsFinalized;

  @HiveField(11)
  String? seasonName;

  @HiveField(40)
  bool isLocal = false;

  @HiveField(41)
  double distance = double.maxFinite;

  @HiveField(42)
  String seasonId;

  @HiveField(43)
  String schemaVersion;

  @HiveField(44)
  DateTime lastUpdated = DateTime.now();

  bool isValid() {
    var currentSeason = seasonId == globals.seasonId;
    var currentSchema = schemaVersion == globals.eventSchemaVersion;
    if (currentSeason == false || currentSchema == false) {
      delete();
      return false;
    }
    return true;
  }

  Event copyWith({
    String? name,
    String? start,
    String? end,
    Location? location,
    List<Division>? divisions,
    HiveList<Team>? teams,
    String? level,
    bool? ongoing,
    bool? awardsFinalized,
    String? seasonName,
  }) =>
      Event(
        id: this.id,
        sku: this.sku,
        name: name ?? this.name,
        start: start ?? this.start,
        end: end ?? this.end,
        location: location ?? this.location,
        divisions: divisions ?? this.divisions,
        teams: teams ?? this.teams,
        level: level ?? this.level,
        ongoing: ongoing ?? this.ongoing,
        awardsFinalized: awardsFinalized ?? this.awardsFinalized,
        seasonName: seasonName ?? this.seasonName,
        isLocal: this.isLocal,
        distance: this.distance,
        seasonId: this.seasonId,
        schemaVersion: this.schemaVersion,
      );
}

Future<Event> eventToHiveEvent(schema.Event event) async {
  var hiveEvent = Event(
      id: event.id!,
      sku: event.sku!,
      name: event.name!,
      start: event.start,
      end: event.end,
      location: event.location,
      divisions: null,
      teams: null,
      level: event.level,
      ongoing: event.ongoing,
      awardsFinalized: event.awardsFinalized,
      isLocal: event.isLocal,
      distance: event.distance,
      seasonId: globals.seasonId,
      schemaVersion: globals.eventSchemaVersion,
      seasonName: event.season?.name);

  // TODO  left off here: Implementing rank as a rankings object so there's a rank list per division
  if (event.teams?.data?.isNotEmpty ?? false) {
    hiveEvent.teams = HiveList<Team>(Hive.box<Team>('teams'));

    if (event.teams != null) {
      for (var team in event.teams!.data!) {
        // if (teamExists(team.id!.toString())) {
        //   var hiveTeam = await getTeam(team.id!.toString());
        //   hiveEvent.teams?.add(hiveTeam);
        //   continue;
        // }

        Hive.box<Team>("teams").put(
            team.id!.toString(),
            Team(
              id: team.id!,
              number: team.number!,
              teamName: team.teamName!,
              organization: team.organization!,
              grade: team.grade!,
              location: team.location!,
              seasonId: globals.seasonId,
              schemaVersion: globals.teamSchemaVersion,
            ));

        hiveEvent.teams?.add(await getTeam(team.id!.toString()));
      }
    }
  }

  if (event.divisions?.isNotEmpty ?? false) {
    hiveEvent.divisions = <Division>[];
    for (var div in event.divisions ?? []) {
      hiveEvent.divisions?.add(await divisionToHiveDivision(div, hiveEvent));
    }
  }

  return hiveEvent;
}

Future<Division> divisionToHiveDivision(schema.Divisions division, Event e) async {
  var hiveDivision = Division(
      id: division.id!,
      name: division.name,
      order: division.order,
      matches: await matchesToHiveMatches(division.data?.data ?? [], e),
      rankings: await rankingsToHiveRankings(division.rankings?.data!, e));
  return hiveDivision;
}

Future<List<Match>> matchesToHiveMatches(List<divschema.Match> matches, Event e) async {
  var hiveMatches = <Match>[];
  for (var match in matches) {
    hiveMatches.add(await matchToHiveMatch(match, e));
  }
  return hiveMatches;
}

Future<Match> matchToHiveMatch(divschema.Match match, Event e) async {
  var hiveMatch = Match(
      id: match.id!,
      round: match.round!,
      instance: match.instance!,
      matchnum: match.matchnum!,
      scheduled: match.scheduled,
      started: match.started,
      field: match.field,
      scored: match.scored,
      name: match.name!,
      redAlliance: await allianceToHiveAlliance(match.alliances![1], AllianceColor.red, e),
      blueAlliance: await allianceToHiveAlliance(match.alliances![0], AllianceColor.blue, e),
      divisionId: match.division!.id!);
  return hiveMatch;
}

Future<Alliance> allianceToHiveAlliance(
    divschema.Alliances alliance, AllianceColor color, Event e) async {
  HiveList<Team> teams = HiveList(Hive.box<Team>('teams'));

  // log(teams.length.toString());

  for (var team in alliance.teams!) {
    // var hiveTeam = await getTeam(team.team!.id.toString());
    var hiveTeam;

    try {
      hiveTeam = e.teams!.firstWhere((element) => element.id == team.team!.id);
    } catch (e) {
      hiveTeam = null;
    }

    if (hiveTeam != null) {
      teams.add(hiveTeam);
    }
  }

  var hiveAlliance = Alliance(
    color: color,
    score: alliance.score,
    teams: teams,
  );
  return hiveAlliance;
}

Future<List<Rank>?> rankingsToHiveRankings(List<rankschema.Data>? rankings, Event e) async {
  if (rankings == null) return null;
  var hiveRankings = <Rank>[];
  for (var rank in rankings) {
    hiveRankings.add(await rankToHiveRank(rank, e));
  }
  return hiveRankings;
}

Future<Rank> rankToHiveRank(rankschema.Data rank, Event e) async {
  HiveList<Team> teamList = HiveList(Hive.box<Team>('teams'));

  // var hiveTeam = await getTeam(rank.team!.id.toString());
  var hiveTeam = e.teams!.firstWhere((element) => element.id == rank.team!.id);
  teamList.add(hiveTeam);

  var hiveRank = Rank(
    id: rank.id!,
    rank: rank.rank,
    team: teamList,
    wins: rank.wins,
    losses: rank.losses,
    ties: rank.ties,
    wp: rank.wp,
    ap: rank.ap,
    sp: rank.sp,
    highScore: rank.highScore,
    averagePoints: rank.averagePoints,
    totalPoints: rank.totalPoints,
  );
  return hiveRank;
}

schema.Event hiveEventToEvent(Event event) {
  return schema.Event(
      id: event.id,
      sku: event.sku,
      name: event.name,
      start: event.start,
      end: event.end,
      location: event.location,
      // divisions: event.divisions,
      // teams: null,
      level: event.level,
      ongoing: event.ongoing,
      awardsFinalized: event.awardsFinalized,
      isLocal: event.isLocal,
      distance: event.distance,
      season: schema.Season(name: event.seasonName));
}

@HiveType(typeId: 6)
class Match extends HiveObject {
  Match(
      {required this.id,
      required this.round,
      required this.instance,
      required this.matchnum,
      this.scheduled,
      this.started,
      this.field,
      this.scored,
      required this.name,
      required this.redAlliance,
      required this.blueAlliance,
      required this.divisionId});

  @HiveField(0)
  int id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int round;

  @HiveField(3)
  int instance;

  @HiveField(4)
  int matchnum;

  @HiveField(5)
  String? scheduled;

  @HiveField(6)
  String? started;

  @HiveField(7)
  String? field;

  @HiveField(8)
  bool? scored;

  @HiveField(9)
  Alliance redAlliance;

  @HiveField(10)
  Alliance blueAlliance;

  @HiveField(11)
  int divisionId;

  @HiveField(44)
  DateTime lastUpdated = DateTime.now();
}

@HiveType(typeId: 7)
class Division extends HiveObject {
  Division({
    required this.id,
    this.name,
    this.order,
    this.matches,
    this.rankings,
  });

  @HiveField(0)
  int id;

  @HiveField(1)
  String? name;

  @HiveField(2)
  int? order;

  @HiveField(3)
  List<Match>? matches;

  @HiveField(4)
  List<Rank>? rankings;

  @HiveField(44)
  DateTime lastUpdated = DateTime.now();
}

@HiveType(typeId: 9)
enum AllianceColor {
  @HiveField(0)
  red,
  @HiveField(1)
  blue
}

@HiveType(typeId: 8)
class Alliance extends HiveObject {
  Alliance({
    required this.color,
    this.score,
    required this.teams,
  });

  @HiveField(0)
  AllianceColor color;

  @HiveField(1)
  int? score;

  @HiveField(2)
  HiveList<Team> teams;

  @HiveField(44)
  DateTime lastUpdated = DateTime.now();
}

@HiveType(typeId: 10)
class Rank extends HiveObject {
  Rank({
    this.id,
    this.rank,
    required this.team,
    this.wins,
    this.losses,
    this.ties,
    this.wp,
    this.ap,
    this.sp,
    this.highScore,
    this.averagePoints,
    this.totalPoints,
  });

  @HiveField(0)
  int? id;

  @HiveField(1)
  int? rank;

  @HiveField(2)
  HiveList<Team> team;

  @HiveField(3)
  int? wins;

  @HiveField(4)
  int? losses;

  @HiveField(5)
  int? ties;

  @HiveField(6)
  int? wp;

  @HiveField(7)
  int? ap;

  @HiveField(8)
  int? sp;

  @HiveField(9)
  int? highScore;

  @HiveField(10)
  num? averagePoints;

  @HiveField(11)
  int? totalPoints;
}
