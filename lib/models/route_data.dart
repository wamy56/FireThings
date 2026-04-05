import 'package:latlong2/latlong.dart';
import 'dispatched_job.dart';

/// A segment connecting two job locations.
/// [points] is a straight line for now; swap in OSRM polyline later.
class RouteSegment {
  final LatLng from;
  final LatLng to;
  final List<LatLng> points;

  RouteSegment({required this.from, required this.to})
      : points = [from, to];

  /// Factory for when OSRM or another routing provider supplies the polyline.
  RouteSegment.withPolyline({
    required this.from,
    required this.to,
    required this.points,
  });
}

/// A computed route for one engineer on one day.
class EngineerRoute {
  final String engineerId;
  final String engineerName;
  final DateTime date;
  final List<DispatchedJob> orderedJobs;
  final List<RouteSegment> segments;

  EngineerRoute({
    required this.engineerId,
    required this.engineerName,
    required this.date,
    required this.orderedJobs,
    required this.segments,
  });

  /// All points in the route as a flat list (for polyline rendering).
  List<LatLng> get allPoints {
    if (segments.isEmpty) return [];
    final result = <LatLng>[segments.first.from];
    for (final seg in segments) {
      // Skip the first point of each segment (it's the same as the last of the previous)
      result.addAll(seg.points.skip(1));
    }
    return result;
  }
}
