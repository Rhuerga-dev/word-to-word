import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'audio.dart';
import 'auth.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = Api();
  runApp(MultiProvider(
    providers: [
      Provider<Api>.value(value: api),
      ChangeNotifierProvider<Auth>(create: (_) => Auth(api)..restore()),
      Provider<AppAudio>(create: (_) => AppAudio(api), dispose: (_, a) => a.dispose()),
    ],
    child: const WordToWordApp(),
  ));
}

class WordToWordApp extends StatelessWidget {
  const WordToWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word to Word',
      debugShowCheckedModeBanner: false,
      theme: W.theme(),
      home: Consumer<Auth>(
        builder: (context, auth, _) {
          if (auth.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return auth.loggedIn ? const Shell() : const LoginScreen();
        },
      ),
    );
  }
}
