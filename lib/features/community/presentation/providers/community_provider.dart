import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../domain/models/community_report_model.dart';
import '../../../../core/services/socket_service.dart';

class CommunityProvider extends ChangeNotifier {
  final CommunityRepositoryImpl _communityRepository;
  final SocketService _socketService;

  List<CommunityReportModel> _reports = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _socketSub;

  CommunityProvider({
    required CommunityRepositoryImpl communityRepository,
    required SocketService socketService,
  })  : _communityRepository = communityRepository,
        _socketService = socketService {
    _listenToSocket();
  }

  List<CommunityReportModel> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _listenToSocket() {
    _socketSub?.cancel();
    _socketSub = _socketService.messageStream.listen((data) {
      if (data['event'] == 'new_community_report') {
        _handleRealtimeReport(data);
      }
    });
  }

  void _handleRealtimeReport(Map<String, dynamic> data) {
    try {
      final report = CommunityReportModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        incidentType: data['incidentType'] ?? 'Unknown',
        description: data['description'] ?? '',
        severity: (data['severity'] as num?)?.toInt() ?? 1,
        anonymous: true, // Real-time reports from socket are forced anonymous
        timestamp: DateTime.now(),
      );

      _reports.insert(0, report);
      if (_reports.length > 100) _reports.removeLast();
      notifyListeners();
    } catch (e) {
      debugPrint('[CommunityProvider] Error handling realtime report: $e');
    }
  }

  Future<bool> submitReport({
    required String phone,
    required double latitude,
    required double longitude,
    required String incidentType,
    required String description,
    required int severity,
    bool anonymous = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _communityRepository.submitReport(
        phone: phone,
        latitude: latitude,
        longitude: longitude,
        incidentType: incidentType,
        description: description,
        severity: severity,
        anonymous: anonymous,
      );

      return result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
          return false;
        },
        (report) {
          // Local addition (the socket listener will also pick up its own but we can filter or let it be)
          // To avoid duplicates, we can check if ID exists or just rely on socket for others
          _isLoading = false;
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _communityRepository.getNearbyReports(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );

      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (reports) {
          // Filter: Only show reports from the last 2 hours to keep feed fresh
          final now = DateTime.now();
          _reports = reports.where((r) {
            return now.difference(r.timestamp).inHours < 2;
          }).toList();
          
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }
}
