import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // 1. Ensure Flutter is ready before doing async work
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_DEFAULT_KEY'),
  );

  runApp(const MyApp());
}

// 3. Create a global shortcut to use the Supabase client anywhere
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = false;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // This "listens" for the Magic Link click from the email
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        // SUCCESS! The Intent Filter worked. Move to the Library.
        print("Logged in! Redirecting...");
      }
    });
  }

  Future<void> _sendMagicLink() async {
    setState(() => _isLoading = true);
    try {
      final String redirectUrl = kIsWeb
          ? 'http://localhost:53441/' // Replace with your web port
          : 'io.supabase.remote-connect://login-callback/';
      // 3. This triggers the email to be sent
      await supabase.auth.signInWithOtp(
        email: _emailController.text.trim(),
        emailRedirectTo: redirectUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your email for the magic link!')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Care Connect')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Enter your email to sign in:',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                style: const TextStyle(
                  fontSize: 18,
                ), // Senior-friendly text size
                decoration: const InputDecoration(border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.email,
                ], // Autofills from phone memory
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendMagicLink,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 60),
                ), // Big button
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Send Magic Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
