import 'package:flutter/material.dart';
import 'package:frontend/api.dart';
import 'package:frontend/template_form_page.dart';

class TemplateGalleryPage extends StatefulWidget {
  final String userRole;
  final String userName;

  const TemplateGalleryPage({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  State<TemplateGalleryPage> createState() => _TemplateGalleryPageState();
}

class _TemplateGalleryPageState extends State<TemplateGalleryPage> {
  bool isLoading = true;
  List<TemplateMetadata> _templates = [];
  List<String> _icons = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final results = await Future.wait([fetchTemplates(), fetchIcons()]);
      if (!mounted) return;
      setState(() {
        final all = results[0] as List<TemplateMetadata>;
        _templates = all
            .where((t) =>
                t.senderRole == 'both' || t.senderRole == widget.userRole)
            .toList();
        _icons = results[1] as List<String>;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        isLoading = false;
      });
    }
  }

  IconData _iconForTemplate(String id) {
    switch (id) {
      case 'simple_note':
        return Icons.edit_note;
      case 'note_with_picture':
        return Icons.add_photo_alternate_outlined;
      case 'weekly_mood_tracker':
        return Icons.mood;
      case 'meal_delivery':
        return Icons.restaurant;
      case 'health_update':
        return Icons.favorite_outline;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a Template', style: TextStyle(fontSize: 24)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Could not connect to server'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  _error = null;
                  _templates = [];
                  _icons = [];
                });
                _initData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
        children: _templates
            .map(
              (t) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TemplateFormPage(template: t, icons: _icons),
                  ),
                ),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_iconForTemplate(t.id), size: 40, color: Colors.green),
                        const SizedBox(height: 12),
                        Text(
                          t.displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
