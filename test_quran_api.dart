import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final response = await dio.get(
      'https://api.quran.com/api/v4/verses/by_page/3',
      queryParameters: {
        'words': true,
        'word_fields': 'text_uthmani,line_number,verse_key,v1_page',
        'fields': 'text_uthmani',
      }
    );
    
    print(jsonEncode(response.data));
  } catch (e) {
    print('Error: $e');
  }
}
