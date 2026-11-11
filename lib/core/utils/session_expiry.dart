/// Hour of the day (device local time) at which every login session ends,
/// so users start each day with a fresh login and a freshly loaded app.
const int sessionCutoffHour = 4;

/// The most recent cutoff at or before [now].
DateTime lastSessionCutoff(DateTime now) {
  final todayCutoff = DateTime(now.year, now.month, now.day, sessionCutoffHour);
  return now.isBefore(todayCutoff)
      ? todayCutoff.subtract(const Duration(days: 1))
      : todayCutoff;
}

/// True when the login at [signedInAt] happened before the latest cutoff.
/// An unknown sign-in time is treated as expired.
bool loginPredatesCutoff(DateTime? signedInAt, {DateTime? now}) {
  if (signedInAt == null) return true;
  return signedInAt.isBefore(lastSessionCutoff(now ?? DateTime.now()));
}
