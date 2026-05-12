void main() {
  final videoUrl = 'https://www.youtube.com/watch?v=gXp5l_P-RkE';
  final uri = Uri.tryParse(videoUrl);
  print('Host: ${uri?.host}');
  print('Path: ${uri?.path}');
  print('Query Params: ${uri?.queryParameters}');
  print('V: ${uri?.queryParameters['v']}');
}
