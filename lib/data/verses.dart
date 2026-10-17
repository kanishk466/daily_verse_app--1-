class Verse {
  final int id;
  final String religion;
  final String original;
  final String transliteration;
  final String hindi;
  final String english;
  final String source;
  final String category;

  const Verse({
    required this.id,
    required this.religion,
    required this.original,
    required this.transliteration,
    required this.hindi,
    required this.english,
    required this.source,
    required this.category,
  });

  factory Verse.fromJson(Map<String, dynamic> json, String religion) {
    return Verse(
      id: json['id'] as int? ?? 0,
      religion: religion,
      original: json['original'] as String? ?? '',
      transliteration: json['transliteration'] as String? ?? '',
      hindi: json['hindi'] as String? ?? '',
      english: json['english'] as String? ?? '',
      source: json['source'] as String? ?? '',
      category: json['category'] as String? ?? 'all',
    );
  }
}
