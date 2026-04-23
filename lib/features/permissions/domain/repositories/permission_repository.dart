import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/permission_model.dart';

abstract class PermissionRepository {
  Future<Either<Failure, List<PermissionModel>>> checkAllPermissions();
  
  Future<Either<Failure, bool>> requestPermission(String permissionName);
  
  Future<Either<Failure, bool>> openAppSettings();
}
