import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Result of analysing one photo.
class CarResult {
  final bool isCar;
  final String make;
  final String model;
  final String colour;
  final String bodyType;
  final String yearRange;
  final String confidence; // high | medium | low
  final String notes;

  const CarResult({
    required this.isCar,
    required this.make,
    required this.model,
    required this.colour,
    required this.bodyType,
    required this.yearRange,
    required this.confidence,
    required this.notes,
  });

  factory CarResult.fromJson(Map<String, dynamic> j) => CarResult(
        isCar: j['is_car'] == true,
        make: (j['make'] ?? 'Unknown').toString(),
        model: (j['model'] ?? 'Unknown').toString(),
        colour: (j['colour'] ?? 'Unknown').toString(),
        bodyType: (j['body_type'] ?? 'Unknown').toString(),
        yearRange: (j['year_range'] ?? 'Unknown').toString(),
        confidence: (j['confidence'] ?? 'low').toString(),
        notes: (j['notes'] ?? '').toString(),
      );
}

class CarDetectionException implements Exception {
  final String message;
  CarDetectionException(this.message);
  @override
  String toString() => message;
}

/// Sends the image to a vision-capable AI model and parses the JSON reply.
///
/// PROTOTYPE SETUP: pass the key at build time:
///   flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
///
/// PRODUCTION: never ship an API key inside the app. Point [_endpoint] at your
/// own backend that holds the key and forwards the request.
class CarService {
  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const _endpoint = String.fromEnvironment(
    'API_ENDPOINT',
    defaultValue: 'https://api.anthropic.com/v1/messages',
  );
  static const _model = 'claude-sonnet-5-5';

  static const _prompt = '''
You are a car identification expert. Look at the image and identify the main car.
Reply with ONLY a JSON object, no markdown, using exactly these keys:
{
  "is_car": true or false,
  "make": "manufacturer, e.g. Toyota",
  "model": "model name, e.g. Innova Crysta",
  "colour": "main body colour in plain words, e.g. Pearl White",
  "body_type": "hatchback, sedan, SUV, MUV, coupe, pickup, van, etc.",
  "year_range": "approximate generation years, e.g. 2016-2020",
  "confidence": "high, medium or low",
  "notes": "one short sentence on what you based this on, or why you are unsure"
}
If there is no car in the image set is_car to false and use "Unknown" elsewhere.
If you cannot tell the exact model, give your best guess and lower the confidence.
Many cars in India are sold under regional model names; mention alternatives in notes.
''';

  Future<CarResult> identify(File imageFile) async {
    if (_apiKey.isEmpty && _endpoint.contains('anthropic.com')) {
      throw CarDetectionException(
          'No API key set. Run with --dart-define=ANTHROPIC_API_KEY=your_key');
    }

    final bytes = await imageFile.readAsBytes();
    final mime = _mimeFor(imageFile.path);

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 600,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mime,
                'data': base64Encode(bytes),
              },
            },
            {'type': 'text', 'text': _prompt},
          ],
        }
      ],
    });

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));
    } on SocketException {
      throw CarDetectionException('No internet connection.');
    } on HttpException {
      throw CarDetectionException('Network error. Please try again.');
    }

    if (res.statusCode != 200) {
      throw CarDetectionException(
          'AI service error (${res.statusCode}). Check your API key and try again.');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final blocks = (decoded['content'] as List?) ?? const [];
    final text = blocks
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'].toString())
        .join();

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) {
      throw CarDetectionException('Could not read the AI response.');
    }
    try {
      return CarResult.fromJson(
          jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>);
    } on FormatException {
      throw CarDetectionException('Could not read the AI response.');
    }
  }

  String _mimeFor(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
