import 'package:flutter/material.dart';
import 'package:frontend/api.dart';
import 'package:frontend/form_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _nameController = TextEditingController();
  String? _selectedRole;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name and select a role')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await upsertProfile(name: name, role: _selectedRole!);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TemplateGalleryPage(userRole: _selectedRole!, userName: name),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to Care Connect')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What is your name?', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Your name',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 20),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 32),
            const Text('I am a…', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 14),
            _RoleCard(
              title: 'Family member or caregiver',
              subtitle: 'I send notes and updates to someone I care for',
              icon: Icons.favorite_outline,
              selected: _selectedRole == 'caregiver',
              onTap: () => setState(() => _selectedRole = 'caregiver'),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              title: 'Person receiving messages',
              subtitle: 'My family or caregiver sends me notes',
              icon: Icons.elderly_outlined,
              selected: _selectedRole == 'older_adult',
              onTap: () => setState(() => _selectedRole = 'older_adult'),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 70),
                backgroundColor: Colors.green,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Get started',
                      style: TextStyle(fontSize: 22, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.green : Colors.grey.shade300,
            width: selected ? 2.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 40, color: selected ? Colors.green : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.green.shade800 : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
          ],
        ),
      ),
    );
  }
}
