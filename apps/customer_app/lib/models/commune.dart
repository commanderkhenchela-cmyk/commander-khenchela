/// نموذج بسيط يمثّل بلدية واحدة، مطابق لجدول communes في قاعدة البيانات.
class Commune {
  final int id;
  final String name;

  const Commune({required this.id, required this.name});

  factory Commune.fromMap(Map<String, dynamic> map) {
    return Commune(id: map['id'] as int, name: map['name'] as String);
  }
}
