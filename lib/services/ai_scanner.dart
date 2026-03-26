import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AiScanner {
  final String apiKey;

  AiScanner({required this.apiKey});

  Future<Map<String, dynamic>> scanDashboard(File imageFile) async {
    final base64Image = base64Encode(await imageFile.readAsBytes());
    final mimeType = imageFile.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    return await _callApi(
      base64Image,
      mimeType,
      'Analysiere dieses Foto eines Auto-Armaturenbretts. '
      'Extrahiere folgende Werte und gib sie als JSON zurück:\n'
      '- consumption: Verbrauch in l/100km (Zahl)\n'
      '- total_km: Gesamtkilometerstand (Ganzzahl)\n'
      '- trip_km: Tageskilometer/Trip (Zahl)\n\n'
      'Antworte NUR mit einem JSON-Objekt, keine Erklärung. '
      'Wenn ein Wert nicht erkennbar ist, setze null.',
    );
  }

  Future<Map<String, dynamic>> scanReceipt(File imageFile) async {
    final base64Image = base64Encode(await imageFile.readAsBytes());
    final mimeType = imageFile.path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    return await _callApi(
      base64Image,
      mimeType,
      'Analysiere dieses Foto einer Tankquittung/Kassenbon. '
      'Extrahiere folgende Werte und gib sie als JSON zurück:\n'
      '- price_per_liter: Preis pro Liter in EUR (Zahl)\n'
      '- total_cost: Gesamtbetrag in EUR (Zahl)\n'
      '- liters: Getankte Liter (Zahl)\n'
      '- date: Datum im Format YYYY-MM-DD (String)\n\n'
      'Antworte NUR mit einem JSON-Objekt, keine Erklärung. '
      'Wenn ein Wert nicht erkennbar ist, setze null.',
    );
  }

  Future<Map<String, dynamic>> _callApi(
    String base64Image,
    String mimeType,
    String prompt,
  ) async {
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'google/gemini-3.1-flash-preview',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$base64Image',
                },
              },
              {
                'type': 'text',
                'text': prompt,
              },
            ],
          },
        ],
        'max_tokens': 500,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API-Fehler: ${response.statusCode} - ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final content = responseData['choices'][0]['message']['content'] as String;

    // Extract JSON from response (handle markdown code blocks)
    var jsonStr = content.trim();
    if (jsonStr.contains('```')) {
      final match = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
      if (match != null) {
        jsonStr = match.group(1)!.trim();
      }
    }

    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
