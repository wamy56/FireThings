import 'package:latlong2/latlong.dart';
import '../../../models/dispatched_job.dart';
import '../../../models/route_data.dart';
import 'day_view.dart' show parseScheduledTime;

/// Builds an [EngineerRoute] for a given engineer on a given day.
/// Filters, sorts by scheduled time, and creates straight-line segments.
EngineerRoute? buildEngineerRoute({
  required String engineerId,
  required String engineerName,
  required DateTime date,
  required List<DispatchedJob> allJobs,
}) {
  // Filter: this engineer, this date, has coordinates
  final jobs = allJobs.where((j) {
    if (j.assignedTo != engineerId) return false;
    if (j.scheduledDate == null) {
      return false;
    }
    if (j.scheduledDate!.year != date.year ||
        j.scheduledDate!.month != date.month ||
        j.scheduledDate!.day != date.day) {
      return false;
    }
    if (j.latitude == null || j.longitude == null) {
      return false;
    }
    return true;
  }).toList();

  if (jobs.isEmpty) return null;

  // Sort by scheduled time (jobs without time go at end)
  jobs.sort((a, b) {
    final ta = parseScheduledTime(a.scheduledTime);
    final tb = parseScheduledTime(b.scheduledTime);
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return (ta.hour * 60 + ta.minute).compareTo(tb.hour * 60 + tb.minute);
  });

  // Build straight-line segments between consecutive jobs
  final segments = <RouteSegment>[];
  for (var i = 0; i < jobs.length - 1; i++) {
    segments.add(RouteSegment(
      from: LatLng(jobs[i].latitude!, jobs[i].longitude!),
      to: LatLng(jobs[i + 1].latitude!, jobs[i + 1].longitude!),
    ));
  }

  return EngineerRoute(
    engineerId: engineerId,
    engineerName: engineerName,
    date: date,
    orderedJobs: jobs,
    segments: segments,
  );
}
