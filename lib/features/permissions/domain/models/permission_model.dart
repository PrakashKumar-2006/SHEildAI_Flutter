class PermissionModel {
  final String name;
  final String description;
  final bool isGranted;
  final bool isPermanentlyDenied;

  PermissionModel({
    required this.name,
    required this.description,
    required this.isGranted,
    this.isPermanentlyDenied = false,
  });

  PermissionModel copyWith({
    String? name,
    String? description,
    bool? isGranted,
    bool? isPermanentlyDenied,
  }) {
    return PermissionModel(
      name: name ?? this.name,
      description: description ?? this.description,
      isGranted: isGranted ?? this.isGranted,
      isPermanentlyDenied: isPermanentlyDenied ?? this.isPermanentlyDenied,
    );
  }
}
