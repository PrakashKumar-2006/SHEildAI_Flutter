import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage_service.dart';

class ShakeSettingsService {
  final StorageService _storageService = StorageService();

  Future<bool> isShakeTriggerEnabled() async {
    await _storageService.init();
    // Default to true as per requirements
    return _storageService.getBool(AppConstants.keyShakeTriggerEnabled) ?? true;
  }

  Future<void> setShakeTriggerEnabled(bool enabled) async {
    await _storageService.setBool(AppConstants.keyShakeTriggerEnabled, enabled);
  }
}
