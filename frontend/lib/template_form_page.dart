
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:frontend/api.dart';
import 'package:image_picker/image_picker.dart';

class TemplateFormPage extends StatefulWidget {
  final TemplateMetadata template;
  final List<String> icons;

  const TemplateFormPage({
    super.key,
    required this.template,
    required this.icons,
  });

  @override
  State<TemplateFormPage> createState() => _TemplateFormPageState();
}

class _TemplateFormPageState extends State<TemplateFormPage> {
  // stores the current value for field at index
  final Map<int, dynamic> _values = {};
  final Map<int, TextEditingController> _controllers = {};
  final Map<String, XFile> _xfiles = {};  // used for both preview and upload
  bool _isSending = false;
  bool _isPreviewing = false;

  final _toController = TextEditingController();
  final _fromController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // iterate over fields in the template
    for (int i = 0; i < widget.template.fields.length; i++){
      final field = widget.template.fields[i];

      // create text editing controller for a text input field type
      // if field is icon type, pre-populate its values with the default options
      switch (field.type) {
        case 'text':
        case 'mood':
        case 'yesno':
        case 'checklist':
          _controllers[i] = TextEditingController();
        case 'icons':
          _values[i] = List<String>.from(field.options ?? []);
        case 'datetime':
          _values[i] = <String, String>{'date': '', 'time': ''};
        case 'location':
          _values[i] = <String, TextEditingController>{
            'name': TextEditingController(),
            'address': TextEditingController(),
          };
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    for (final v in _values.values) {
      if (v is Map<String, TextEditingController>) {
        for (final c in v.values) { c.dispose(); }
      }
    }
    _toController.dispose();
    _fromController.dispose();
    super.dispose();
  }

  // Returns which image key ("image_0", "image_1") to use for the nth image field
  String _imageKeyForField(int fieldIndex) {
    int imageCount = 0;
    for (int i = 0; i < widget.template.fields.length; i++) {
      if (widget.template.fields[i].type == 'image') {
        if (i == fieldIndex) return 'image_$imageCount';
        imageCount++;
      }
    }
    return 'image_0';
  }
  
  Future<void> _pickImage(int fieldIndex, ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;
    final key = _imageKeyForField(fieldIndex);
    setState(() => _xfiles[key] = picked);
  }

  void _showImagePicker(BuildContext context, int fieldIndex) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
          child: Wrap(children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(fieldIndex, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(fieldIndex, ImageSource.camera);
                },
              ),
            ]),
          ),
    );
  }

  // ─── Field builders ───────────────────────────────────────────────────────

  Widget _buildTextField(int index, String label, {int maxLines = 3}) {
    return TextField(
      controller: _controllers[index],
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildImageField(int index, String label) {
    final key = _imageKeyForField(index);
    final xfile = _xfiles[key];
    return GestureDetector(
      onTap: () => _showImagePicker(context, index),
      child: Center(
        child: Container(
          height: 200,
          width: 220,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey),
          ),
          child: xfile == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ])
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(xfile.path, fit: BoxFit.contain)
                      : Image.file(File(xfile.path), fit: BoxFit.contain),
                ),
        ),
      ),
    );
  }

  Widget _buildIconPicker(int index) {
    final selected = (_values[index] as List<String>?) ?? [];
    return SizedBox(
      height: 220,
      child: SingleChildScrollView(
        child: Column(
          children: widget.icons.map((iconName) {
            final isSelected = selected.contains(iconName);
            return CheckboxListTile(
              secondary: Image.network(
                '$baseUrl/static/icons/$iconName.png',
                width: 32,
                height: 32,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 32),
              ),
              title: Text(iconName.replaceAll('_', ' ')),
              value: isSelected,
              onChanged: (checked) {
                setState(() {
                  final updated = List<String>.from(selected);
                  if (checked == true) {
                    updated.add(iconName);
                  } else {
                    updated.remove(iconName);
                  }
                  _values[index] = updated;
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLocationField(int index) {
    final controllers = _values[index] as Map<String, TextEditingController>;
    return Column(
      children: [
        TextField(
          controller: controllers['name'],
          decoration: const InputDecoration(
            labelText: 'Place name',
            prefixIcon: Icon(Icons.place),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controllers['address'],
          decoration: const InputDecoration(
            labelText: 'Address (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildDateTimeField(int index) {
    final val = (_values[index] as Map<String, String>?) ?? {'date': '', 'time': ''};
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(val['date']!.isEmpty ? 'Pick date' : val['date']!),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked == null) return;
              final formatted =
                  '${_weekday(picked.weekday)}, ${_month(picked.month)} ${picked.day}';
              setState(() => (_values[index] as Map)['date'] = formatted);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text(val['time']!.isEmpty ? 'Pick time' : val['time']!),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked == null || !mounted) return;
              setState(() =>
                  (_values[index] as Map)['time'] = picked.format(context));
            },
          ),
        ),
      ],
    );
  }

  // Returns a Widget based on field.type
  Widget _buildField(ElementField field, int index) {
    switch (field.type) {
      case 'text':
        return _buildTextField(index, field.label);
      case 'mood':
        return _buildTextField(index, field.label, maxLines: 1);
      case 'yesno':
        return _buildTextField(index, field.label);
      case 'checklist':
        return _buildTextField(index, '${field.label} (one per line)');
      case 'image':
        return _buildImageField(index, field.label);
      case 'icons':
        return _buildIconPicker(index);
      case 'datetime':
        return _buildDateTimeField(index);
      case 'location':
        return _buildLocationField(index);
      case 'weekly_tracker':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Weekly tracker will be printed',
              style: TextStyle(color: Colors.grey)),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<Map<String, dynamic>> _buildElements() {
    final elements = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.template.fields.length; i++) {
      final field = widget.template.fields[i];
      switch (field.type) {
        case 'text':
          elements.add({'type': 'text', 'value': _controllers[i]!.text});
        case 'mood':
          elements.add({'type': 'mood', 'name': _controllers[i]!.text});
        case 'yesno':
          elements.add({'type': 'yesno', 'question': _controllers[i]!.text});
        case 'checklist':
          final tasks = _controllers[i]!.text
              .split('\n')
              .where((s) => s.trim().isNotEmpty)
              .toList();
          elements.add({'type': 'checklist', 'tasks': tasks});
        case 'image':
          final key = _imageKeyForField(i);
          elements.add({
            'type': 'image',
            'image_key': key,
            'style': widget.template.id == 'note_with_picture' ? 'polaroid' : 'full_width',
          });
        case 'icons':
          elements.add({'type': 'icons', 'names': _values[i] ?? []});
        case 'datetime':
          final val = _values[i] as Map<String, String>;
          elements.add({'type': 'datetime', 'date': val['date']!, 'time': val['time']!});
        case 'weekly_tracker':
          elements.add({'type': 'weekly_tracker'});
        case 'location':
          final controllers = _values[i] as Map<String, TextEditingController>;
          elements.add({
            'type': 'location',
            'name': controllers['name']!.text,
            'address': controllers['address']!.text,
          });
      }
    }
    return elements;
  }

  Future<void> _preview() async {
    setState(() => _isPreviewing = true);
    try {
      final bytes = await fetchPreview(
        template: widget.template.id,
        elements: _buildElements(),
        images: _xfiles,
        toName: _toController.text.trim(),
        fromName: _fromController.text.trim(),
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: InteractiveViewer(
                  child: SingleChildScrollView(
                    child: Image.memory(bytes),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(dialogContext); _send(); },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Print & Send',
                      style: TextStyle(fontSize: 20, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Preview failed: $e')));
    } finally {
      if (mounted) setState(() => _isPreviewing = false);
    }
  }

  Future<void> _send() async {
    // Validate required fields
    for (int i = 0; i < widget.template.fields.length; i++) {
      final field = widget.template.fields[i];
      if (!field.required) continue;
      bool empty = false;
      if (['text', 'mood', 'yesno', 'checklist'].contains(field.type)) {
        empty = _controllers[i]!.text.trim().isEmpty;
      } else if (field.type == 'image') {
        empty = !_xfiles.containsKey(_imageKeyForField(i));
      } else if (field.type == 'datetime') {
        final val = _values[i] as Map<String, String>;
        empty = val['date']!.isEmpty || val['time']!.isEmpty;
      } else if (field.type == 'location') {
        final controllers = _values[i] as Map<String, TextEditingController>;
        empty = controllers['name']!.text.trim().isEmpty;
      }
      if (empty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${field.label} is required')),
        );
        return;
      }
    }

    setState(() => _isSending = true);
    try {
      await generatePrint(
        template: widget.template.id,
        elements: _buildElements(),
        images: _xfiles,
        toName: _toController.text.trim(),
        fromName: _fromController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sent!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.template.fields;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.displayName,
            style: const TextStyle(fontSize: 22)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _toController,
              decoration: const InputDecoration(
                labelText: 'To',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fromController,
              decoration: const InputDecoration(
                labelText: 'From',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(thickness: 1),
            ),
            ...List.generate(fields.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fields[i].label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildField(fields[i], i),
                ],
              ),
            )),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isPreviewing ? null : _preview,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 70)),
                  child: _isPreviewing
                      ? const CircularProgressIndicator()
                      : const Text('Preview',
                          style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSending ? null : _send,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 70),
                      backgroundColor: Colors.green),
                  child: _isSending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Print & Send',
                          style: TextStyle(fontSize: 20, color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ─── Date formatting helpers ───────────────────────────────────────────────

  String _weekday(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];

  String _month(int m) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}
