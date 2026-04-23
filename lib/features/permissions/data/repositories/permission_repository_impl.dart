import 'package:dartz/dartz.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../../../../core/error/failures.dart';
import '../../domain/models/permission_model.dart';
import '../../domain/repositories/permission_repository.dart';

class PermissionRepositoryImpl implements PermissionRepository {
  @override
  Future<Either<Failure, List<PermissionModel>>> checkAllPermissions() async {
    try {
      final permissions = <PermissionModel>[];
      
      // Location Permission
      final locationStatus = await ph.Permission.location.status;
      permissions.add(PermissionModel(
        name: 'location',
        description: 'Required for location tracking and safety features',
        isGranted: locationStatus.isGranted || locationStatus.isLimited,
        isPermanentlyDenied: locationStatus.isPermanentlyDenied,
      ));
      
      // Camera Permission
      final cameraStatus = await ph.Permission.camera.status;
      permissions.add(PermissionModel(
        name: 'camera',
        description: 'Required for video recording during emergencies',
        isGranted: cameraStatus.isGranted,
        isPermanentlyDenied: cameraStatus.isPermanentlyDenied,
      ));
      
      // Microphone Permission
      final micStatus = await ph.Permission.microphone.status;
      permissions.add(PermissionModel(
        name: 'microphone',
        description: 'Required for voice detection and SOS activation',
        isGranted: micStatus.isGranted,
        isPermanentlyDenied: micStatus.isPermanentlyDenied,
      ));
      
      // Notification Permission
      final notificationStatus = await ph.Permission.notification.status;
      permissions.add(PermissionModel(
        name: 'notification',
        description: 'Required for emergency alerts and updates',
        isGranted: notificationStatus.isGranted,
        isPermanentlyDenied: notificationStatus.isPermanentlyDenied,
      ));
      
      return Right(permissions);
    } catch (e) {
      return Left(PermissionFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> requestPermission(String permissionName) async {
    try {
      ph.Permission permission;
      
      switch (permissionName.toLowerCase()) {
        case 'location':
          permission = ph.Permission.location;
          break;
        case 'camera':
          permission = ph.Permission.camera;
          break;
        case 'microphone':
          permission = ph.Permission.microphone;
          break;
        case 'notification':
          permission = ph.Permission.notification;
          break;
        default:
          return const Left(PermissionFailure('Unknown permission'));
      }
      
      final status = await permission.request();
      return Right(status.isGranted);
    } catch (e) {
      return Left(PermissionFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> openAppSettings() async {
    try {
      final result = await ph.openAppSettings();
      return Right(result);
    } catch (e) {
      return Left(PermissionFailure(e.toString()));
    }
  }
}
