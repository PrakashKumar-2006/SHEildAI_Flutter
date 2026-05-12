import 'dart:convert';
import 'dart:io';

class AwarenessVideo {
  final String videoUrl;
  AwarenessVideo(this.videoUrl);

  String? get youtubeId {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    } else if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return null;
  }
}

void main() {
  final file = File('assets/mock/awareness_videos.json');
  final jsonStr = file.readAsStringSync();
  final List<dynamic> data = json.decode(jsonStr);
  
  print('--- Verification Report ---');
  for (var item in data) {
    final video = AwarenessVideo(item['videoUrl']);
    final id = video.youtubeId;
    print('Title: ${item['title']}');
    print('URL: ${item['videoUrl']}');
    print('Extracted ID: $id');
    if (id == null || id.isEmpty) {
      print('FAILED: Could not extract ID!');
    } else {
      print('SUCCESS: ID extracted correctly.');
    }
    print('---');
  }
}
