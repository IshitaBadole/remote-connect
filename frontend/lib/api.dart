import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String baseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://localhost:8000',
);

class ElementField {
  final String type;
  final String label;
  final bool required;
  final bool hasImage;
  final List<String>? options;

  ElementField({
    required this.type,
    required this.label,
    required this.required,
    this.hasImage = false,
    this.options,
  });

  factory ElementField.fromJson(Map<String, dynamic> json) => ElementField(
    type: json['type'] as String,
    label: json['label'] as String,
    required: json['required'] as bool,
    hasImage: (json['has_image'] as bool?) ?? false,
    options: (json['options'] as List<dynamic>?)?.cast<String>(),
  );
}

class TemplateMetadata {
  final String id;
  final String displayName;
  final String description;
  final String senderRole; // "caregiver" | "older_adult" | "both"
  final List<ElementField> fields;
  final List<Map<String, dynamic>> defaultElements;

  TemplateMetadata({
    required this.id,
    required this.displayName,
    required this.description,
    required this.senderRole,
    required this.fields,
    required this.defaultElements,
  });

  factory TemplateMetadata.fromJson(Map<String, dynamic> json) =>
      TemplateMetadata(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        description: json['description'] as String,
        senderRole: (json['sender_role'] as String?) ?? 'both',
        fields: (json['fields'] as List<dynamic>)
            .map((f) => ElementField.fromJson(f as Map<String, dynamic>))
            .toList(),
        defaultElements: (json['default_elements'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList(),
      );
}

// ── Profile helpers (direct Supabase client, no backend needed) ───────────────

Future<Map<String, dynamic>?> fetchProfile() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  return await Supabase.instance.client
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();
}

Future<void> upsertProfile({required String name, required String role}) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  await Supabase.instance.client.from('profiles').upsert({
    'id': userId,
    'name': name,
    'role': role,
  });
}

// GET /api/templates
Future<List<TemplateMetadata>> fetchTemplates() async {
  final response = await http.get(Uri.parse('$baseUrl/api/templates'));
  if (response.statusCode == 200) {
    return (jsonDecode(response.body) as List<dynamic>)
        .map((t) => TemplateMetadata.fromJson(t as Map<String, dynamic>))
        .toList();
  }
  throw Exception('Failed to load templates: ${response.statusCode}');
}

// GET /api/icons
Future<List<String>> fetchIcons() async {
  final response = await http.get(Uri.parse('$baseUrl/api/icons'));
  if (response.statusCode == 200) {
    return (jsonDecode(response.body) as List<dynamic>).cast<String>();
  }
  throw Exception('Failed to load icons: ${response.statusCode}');
}

// POST /api/generate-print
Future<void> generatePrint({
  required String template,
  required List<Map<String, dynamic>> elements,
  Map<String, XFile> images = const {},
  String toName = '',
  String fromName = '',
}) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/api/generate-print'),
  );

  request.fields['template'] = template;
  request.fields['elements'] = jsonEncode(elements);
  request.fields['to_name'] = toName;
  request.fields['from_name'] = fromName;
  request.fields['save_image'] = 'true';
  request.fields['do_print'] = 'true';

  final token = Supabase.instance.client.auth.currentSession?.accessToken ?? '';
  if (token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';

  for (final entry in images.entries) {
    final bytes = await entry.value.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        entry.key,
        bytes,
        filename: entry.value.name,
      ),
    );
  }

  final response = await http.Response.fromStream(await request.send());
  if (response.statusCode != 200) {
    throw Exception('Print failed: ${response.statusCode} ${response.body}');
  }
}

// POST /api/preview — returns rendered PNG bytes
Future<Uint8List> fetchPreview({
  required String template,
  required List<Map<String, dynamic>> elements,
  Map<String, XFile> images = const {},
  String toName = '',
  String fromName = '',
}) async {
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/api/preview'),
  );
  request.fields['template'] = template;
  request.fields['elements'] = jsonEncode(elements);
  request.fields['to_name'] = toName;
  request.fields['from_name'] = fromName;

  for (final entry in images.entries) {
    final bytes = await entry.value.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        entry.key,
        bytes,
        filename: entry.value.name,
      ),
    );
  }

  final streamed = await request.send();
  final bytes = await streamed.stream.toBytes();
  if (streamed.statusCode != 200) {
    throw Exception('Preview failed: ${streamed.statusCode}');
  }
  return bytes;
}
