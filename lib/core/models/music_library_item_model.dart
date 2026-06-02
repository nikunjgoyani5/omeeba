/// Single track from GET `zeals/music`.
class MusicLibraryItem {
  MusicLibraryItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.coverImage,
  });

  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? coverImage;

  factory MusicLibraryItem.fromJson(Map<String, dynamic> json) {
    return MusicLibraryItem(
      id: json['_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      coverImage: json['coverImage'] as String?,
    );
  }
}

/// UI model for a selectable track in the music bottom sheet.
class MusicTrack {
  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumArtUrl,
    required this.audioUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String albumArtUrl;
  final String audioUrl;

  factory MusicTrack.fromLibraryItem(MusicLibraryItem item) {
    return MusicTrack(
      id: item.id,
      title: item.title,
      artist: item.artist,
      albumArtUrl: (item.coverImage != null && item.coverImage!.isNotEmpty) ? item.coverImage! : '',
      audioUrl: item.audioUrl,
    );
  }
}
