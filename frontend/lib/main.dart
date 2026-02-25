import 'package:flutter/material.dart';
import 'package:frontend/form_page.dart';
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
  final _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // This "listens" for the Magic Link click from the email
    supabase.auth.onAuthStateChange.listen((data) {
      if(!mounted) return;

      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      // 1. Only transition if we have a session AND it's a 'Login' or 'Initial' event
      if (session != null &&
          (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.initialSession)) {
        // 2. Use pushReplacement so they can't 'Go Back' to the login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UploadPage()),
        );
      } else if (event == AuthChangeEvent.signedOut) {
        // 3. If they log out, wipe the screen and go back to Login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const MyHomePage(title: 'Flutter Demo Home Page'),
          ),
          (route) => false,
        );
      }
    });
  }

  // 1. Add a boolean to track if the code was sent
  bool _codeSent = false;

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    try {
      if (!_codeSent) {
        // STEP 1: SEND THE CODE
        await supabase.auth.signInWithOtp(email: _emailController.text.trim());
        setState(() => _codeSent = true); // Now show the OTP input field
      } else {
        // STEP 2: VERIFY THE CODE typed by the user
        await supabase.auth.verifyOTP(
          email: _emailController.text.trim(),
          token: _otpController.text.trim(),
          type: OtpType.magiclink, // Use 'magiclink' even for codes
        );
        // The 'onAuthStateChange' listener you wrote earlier will
        // automatically catch the success and redirect to the dummy page!
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
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
              if (!_codeSent) ...[
                const Text("Enter your email:", style: TextStyle(fontSize: 22)),
                TextField(
                  controller: _emailController,
                  style: TextStyle(fontSize: 20),
                ),
              ] else ...[
                const Text(
                  "Enter the 6-digit code from your email:",
                  style: TextStyle(fontSize: 22),
                ),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 30,
                    letterSpacing: 10,
                  ), // Big numbers!
                  decoration: InputDecoration(hintText: "000000"),
                ),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleAuth,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 70),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _codeSent ? 'Verify Code' : 'Send Code',
                        style: TextStyle(fontSize: 22),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
