import 'package:flutter/material.dart';
import 'dart:math';
import '../../data/models/feed_models.dart';
import '../../data/services/feed_service.dart';

class FeedProvider extends ChangeNotifier {
  final FeedService _feedService = FeedService();

  List<StaticSafetyAlert> _alerts = [];
  List<SafetyTip> _tips = [];
  List<AwarenessVideo> _videos = [];
  List<SafetyCampaign> _campaigns = [];

  bool _isLoading = false;

  List<StaticSafetyAlert> get alerts => _alerts;
  List<SafetyTip> get tips => _tips;
  List<AwarenessVideo> get videos => _videos;
  List<SafetyCampaign> get campaigns => _campaigns;
  bool get isLoading => _isLoading;

  FeedProvider() {
    _loadAllFeedData();
  }

  Future<void> _loadAllFeedData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _feedService.fetchSafetyAlerts(),
        _feedService.fetchSafetyTips(),
        _feedService.fetchAwarenessVideos(),
        _feedService.fetchCampaigns(),
      ]);

      // Make Alerts dynamically nearby
      _alerts = (results[0] as List<StaticSafetyAlert>).map<StaticSafetyAlert>((a) => StaticSafetyAlert(
        id: a.id,
        title: a.title,
        description: a.description,
        location: 'Nearby Area (~${DateTime.now().second % 4 + 1} km away)',
        severity: a.severity,
        timestamp: DateTime.now(),
      )).toList();

      _tips = results[1] as List<SafetyTip>;

      // Randomize videos daily and pick all 8
      var allVideos = results[2] as List<AwarenessVideo>;
      allVideos.shuffle(Random(DateTime.now().day));
      _videos = allVideos.take(8).toList();

      // Make campaigns fresh
      _campaigns = (results[3] as List<SafetyCampaign>).map<SafetyCampaign>((c) {
        final isToday = c.id.hashCode % 2 == 0;
        return SafetyCampaign(
          id: c.id,
          title: c.title,
          description: c.description,
          date: isToday ? 'Today, 5:00 PM' : 'Tomorrow, 10:00 AM',
          venue: 'Local Community Hub, Nearby',
          distance: '${Random().nextInt(5) + 1} km',
        );
      }).toList();
    } catch (e) {
      debugPrint('[FeedProvider] Error loading feed data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFeed() async {
    await _loadAllFeedData();
  }
}
