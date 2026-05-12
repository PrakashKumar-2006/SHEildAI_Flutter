import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/feed_models.dart';

class FeedService {
  Future<List<StaticSafetyAlert>> fetchSafetyAlerts() async {
    try {
      final String response = await rootBundle.loadString('assets/mock/safety_alerts.json');
      final List<dynamic> data = json.decode(response);
      return data.map((json) => StaticSafetyAlert.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SafetyTip>> fetchSafetyTips() async {
    try {
      final String response = await rootBundle.loadString('assets/mock/safety_tips.json');
      final List<dynamic> data = json.decode(response);
      return data.map((json) => SafetyTip.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<AwarenessVideo>> fetchAwarenessVideos() async {
    try {
      final String response = await rootBundle.loadString('assets/mock/awareness_videos.json');
      final List<dynamic> data = json.decode(response);
      return data.map((json) => AwarenessVideo.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<SafetyCampaign>> fetchCampaigns() async {
    try {
      final String response = await rootBundle.loadString('assets/mock/campaigns.json');
      final List<dynamic> data = json.decode(response);
      return data.map((json) => SafetyCampaign.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }
}
