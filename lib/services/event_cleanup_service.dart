class EventCleanupService {
  /// Historical events are product data: Club Profile history, student RSVP
  /// records, and check-in attendance all reference the original event row.
  ///
  /// Kept as a no-op compatibility hook because existing startup/load paths
  /// still call it. Event deletion is now an explicit club-admin action only.
  Future<void> cleanupExpiredEvents() async {
    return;
  }
}

final eventCleanupService = EventCleanupService();
