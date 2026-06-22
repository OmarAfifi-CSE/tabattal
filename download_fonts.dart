import 'dart:io';

void main() async {
  final client = HttpClient();
  
  final fonts = {
    'Amiri-Regular.ttf': 'https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Regular.ttf',
    'Amiri-Bold.ttf': 'https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Bold.ttf',
    'AmiriQuran-Regular.ttf': 'https://raw.githubusercontent.com/google/fonts/main/ofl/amiriquran/AmiriQuran-Regular.ttf',
  };

  for (var entry in fonts.entries) {
    try {
      final request = await client.getUrl(Uri.parse(entry.value));
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final file = File('assets/fonts/${entry.key}');
        await response.pipe(file.openWrite());
        print('Downloaded ${entry.key}');
      } else {
        print('Failed to download ${entry.key}: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading ${entry.key}: $e');
    }
  }
}
