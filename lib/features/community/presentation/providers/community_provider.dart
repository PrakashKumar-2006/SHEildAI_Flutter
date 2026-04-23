import 'package:flutter/foundation.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../domain/models/community_report_model.dart';

class CommunityProvider extends ChangeNotifier {
  final CommunityRepositoryImpl _communityRepository;

  List<CommunityReportModel> _reports = [];
  bool _isLoading = false;
  String? _errorMessage;

  CommunityProvider({required CommunityRepositoryImpl communityRepository})
      : _communityRepository = communityRepository;

  List<CommunityReportModel> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> submitReport({
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

      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (report) {
          _reports.insert(0, report);
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
          _reports = reports;
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
