import 'package:aigetai/provider/theme_changer.dart';
import 'package:aigetai/screens/home_screen_page_body.dart';
import 'package:aigetai/screens/pd%20code/bing_ai/bing_ai_page.dart';
import 'package:aigetai/screens/pd%20code/scr/file_screen.dart';
import 'package:aigetai/screens/pd%20code/scr/login_signup/pages/login_screen.dart';
import 'package:aigetai/screens/pd%20code/scr/login_signup/pages/otp_verify_screen.dart';
import 'package:aigetai/screens/pd%20code/scr/login_signup/pages/set_password_screen.dart';
import 'package:aigetai/screens/pd%20code/scr/login_signup/services/login_api_service.dart';
import 'package:aigetai/screens/MusicPlayerScreen.dart'; //videoplayer package
import 'package:aigetai/screens/videoplayer.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:aigetai/screens/pd code/scr/Screen/file/downloads_list_screen.dart';
import 'package:aigetai/providers/download_manager.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  send?.send([id, status, progress]);
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

  // Load previously persisted downloads into DownloadManager
  await DownloadManager().loadAll();

  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initSettings = const InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload == 'open_downloads') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const DownloadsListScreen()),
        );
      }
    },
  );

  // Enable hybrid composition for Android WebView
  WebViewPlatform.instance = AndroidWebViewPlatform();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // video player and audio player initialization

   String? videoPath;
  String? audioPath;
  try {
    final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialMedia.isNotEmpty) {
      final file = initialMedia.first;
      final path = file.path;
      final mimeType = file.mimeType ?? '';
 
      if (path != null && path.isNotEmpty) {
        if (mimeType.startsWith('audio/')) {
          audioPath = path;
        } else if (mimeType.startsWith('video/')) {
          videoPath = path;
        } else {
         
          final ext = path.split('.').last.toLowerCase();
          const audioExts = ['mp3', 'aac', 'flac', 'wav', 'm4a', 'ogg', 'opus', 'wma'];
          const videoExts = ['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv', '3gp', 'ts', 'wmv'];
          if (audioExts.contains(ext)) {
            audioPath = path;
          } else if (videoExts.contains(ext)) {
            videoPath = path;
          }
        }
      }
    }
  } catch (_) {}

  runApp(
    ProviderScope(
      child: MyApp(initialVideoPath: videoPath, initialAudioPath: audioPath),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final String? initialVideoPath;
  final String? initialAudioPath;
  MyApp({super.key, this.initialVideoPath, this.initialAudioPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

   return MaterialApp(
  navigatorKey: navigatorKey,
navigatorObservers: [videoRouteObserver],
  debugShowCheckedModeBanner: false,
  title: 'Browser App',
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
        home: initialVideoPath != null
          ? VideoPlayerScreen(initialVideoPath: initialVideoPath)
          : initialAudioPath != null
              ? MusicPlayerScreen(initialAudioPath: initialAudioPath)
              : const SplashScreen(),  
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  // Future<void> _initializeServices() async {
  //   try {
  //     final token = await ApiService.getAccessToken();
  //     if (!mounted) return;
  //
  //     if (token == null) {
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (_) => LoginPage()),
  //       );
  //     } else {
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(builder: (_) => LoginPage()),
  //       );
  //       // Navigator.pushReplacement(
  //       //   context,
  //       //   MaterialPageRoute(builder: (_) => HomePage()), // your main page
  //       // );
  //     }
  //   } catch (e) {
  //     debugPrint("Failed to initialize: $e");
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error: $e')),
  //       );
  //     }
  //   }
  // }
  Future<void> _initializeServices() async {
    try {
      final refresh = await ApiService.getrefreshToken();
      if (!mounted) return;

      if (refresh == null) {
        // No refresh token at all → force login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
        );
        return;
      }

      // Try to refresh access token
      try {
        final newAccess = await ApiService.refreshToken();
        debugPrint("New Access Token: $newAccess");

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } catch (e) {
        // Refresh failed → go back to login
        debugPrint("Token refresh failed: $e");
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
        );
      }
    } catch (e) {
      debugPrint("Init error: $e");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   void _navigateToLogin() {
//     if (!mounted) return;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => LoginPage()),
//     );
//   }
//
//   Future<void> _initializeServices() async {
//     try {
//       final token = await ApiService.getAccessToken();
//       if (token == null) {
//         _navigateToLogin();
//         return;
//       }
//     } catch (e) {
//       _showError('Failed to initialize: ${e.toString()}');
//     }
//   }
//
//   // Enable hybrid composition for Android
//   WebViewPlatform.instance = AndroidWebViewPlatform();
//
//   SystemChrome.setSystemUIOverlayStyle(
//     const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ),
//   );
//   runApp(const ProviderScope(child: MyApp()));
// }
//
// class MyApp extends ConsumerWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final themeMode = ref.watch(themeProvider);
//
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Browser App',
//       themeMode: themeMode,
//       theme: ThemeData.light(),
//       darkTheme: ThemeData.dark(),
//       // themeMode:
//       //     themeProvider.isDarkMode
//       //         ? ThemeMode.dark
//       //         : ThemeMode.light, // This is KEY
//       // home: DiscoverPage(),
//      // home: NewsHomePage(),
//        home: LoginPage(),
//        // FilesHomePage(), // work remaining
//       //home: PublisherDetailPage(),
//     );
//   }
// }




// void main() {
//   runApp(
//     ChangeNotifierProvider(
//       create: (_) => ThemeProvider(),
//       child: const MyApp(),
//     ),
//   );
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     final isDarkMode = themeProvider.isDarkMode;

//     return MaterialApp(
//       title: 'Phoenix Browser',
//       theme: ThemeData(
//         brightness: Brightness.light,
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.blue,
//           brightness: Brightness.light,
//         ),
//         useMaterial3: true,
//       ),
//       darkTheme: ThemeData(
//         brightness: Brightness.dark,
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.blue,
//           brightness: Brightness.dark,
//         ),
//         useMaterial3: true,
//       ),
//       themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
//       home: const PhoenixHomePage(),
//       // debugShowCheckedModeBanner: false,
//     );
//   }
// }


// class PhoenixHomePage extends StatefulWidget {
//   const PhoenixHomePage({super.key});

//   @override
//   State<PhoenixHomePage> createState() => _PhoenixHomePageState();
// }

// class _PhoenixHomePageState extends State<PhoenixHomePage> {
//   int _selectedIndex = 0;
  
//   final List<Widget> _screens = [
//      VpnScreen(),
//      // HomeScreen(),
//     FilesHomePage(),
//      SportsDashboard(),
//      AppScreens(),
//      ProfileScreen(),
//     //FilesHomePage(),
//   ];
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _screens[_selectedIndex],
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _selectedIndex,
//         onTap: (index) {
//           setState(() {
//             _selectedIndex = index;
//           });
//         },
//         type: BottomNavigationBarType.fixed, // Correct enum type
//         items: [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.vpn_key),
//             label: 'VPN',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.home),
//             label: 'Home',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.sports_soccer),
//             label: 'Sports',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.article),
//             label: 'News',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.person),
//             label: 'Me',
//           ),


//         ],
//       ),

//     );
//   }
// }
