import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_repairkit/firebase_options.dart';
import 'package:e_repairkit/models/appuser.dart';
import 'package:e_repairkit/models/push_service.dart';
import 'package:e_repairkit/services/auth_service.dart';
import 'package:e_repairkit/services/forum_service.dart';
import 'package:e_repairkit/services/impl/feedback_service.dart';
import 'package:e_repairkit/services/impl/firebase_auth_service.dart';
import 'package:e_repairkit/services/impl/firestore_forum_service.dart';
import 'package:e_repairkit/services/impl/gemini_ai_Service.dart';
import 'package:e_repairkit/services/impl/google_location_service.dart';
import 'package:e_repairkit/services/impl/hms_push_service.dart';
import 'package:e_repairkit/services/offline_search_service.dart';
import 'package:e_repairkit/view/splash.dart';
import 'package:e_repairkit/widget/auth_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';


import 'services/ai_service.dart';
import 'services/cache_service.dart';
import 'services/chat_service.dart';
import 'services/feedback_service.dart';
import 'services/findshop_service.dart';
import 'services/impl/firestore_chat_service.dart';
import 'services/impl/google_shop_finder_service.dart';
import 'services/location_service.dart';
import 'viewmodels/chat_viewmodel.dart';

// --- 1. DEFINE YOUR APP'S COLOR PALETTE ---
const Color kPrimaryColor = Color(0xFF0571ab); // Your deep blue
const Color kSecondaryColor = Color(0xFFF39C12); // The wrench's gold/orange
const Color kTertiaryColor = Color(0xFF3498DB); // The hammer's light blue

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- 2. RUN YOUR APP WITH PROVIDERS ---
  runApp(
    MultiProvider(
      providers: [
        // --- SERVICES ---
        Provider<AuthService>(create: (_) => FirebaseAuthService()), // <-- 5. Add AuthService
        Provider<ChatService>(create: (_) => FirestoreChatService()),
        Provider<AIService>(create: (_) => GeminiAIService()),
        Provider<LocationService>(create: (_) => GoogleLocationService()),
        Provider<ShopFinderService>(create: (_) => GoogleShopFinderService()),
        Provider<FeedbackService>(create: (_) => FirestoreFeedbackService()),
        Provider<LocalCacheService>(create: (_) => LocalCacheService()),
        Provider<OfflineSearchService>(create: (_) => OfflineSearchService()),
        Provider<ForumService>(create: (_) => FirestoreForumService()),
        Provider<FirebaseAuth>(create: (_) => FirebaseAuth.instance), // Provides the SDK instance
        Provider<FirebaseFirestore>(create: (_) => FirebaseFirestore.instance),
        
        // --- 6. ADD THE STREAMPROVIDER (THIS FIXES YOUR ERROR) ---
        // This listens to auth state and provides AppUser? to the app
        StreamProvider<AppUser?>(
          create: (context) => context.read<AuthService>().onAuthStateChanged,
          initialData: null,
        ),


            Provider<PushService>(
  create: (context) => HmsPushService(
    auth: context.read<FirebaseAuth>(),
    firestore: context.read<FirebaseFirestore>(),
  ),
),


        // --- ViewModel ---
        ChangeNotifierProvider(
          create: (context) => ChatViewModel(
            aiService: context.read<AIService>(),
            locationService: context.read<LocationService>(),
            shopFinderService: context.read<ShopFinderService>(),
            chatService: context.read<ChatService>(),
            feedbackService: context.read<FeedbackService>(),
            cacheService: context.read<LocalCacheService>(),
            offlineSearch: context.read<OfflineSearchService>(),
            forumService: context.read<ForumService>(),
            pushService: context.read<PushService>(),
            
          ),
        ),

      ],


      
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-RepairKit',
      debugShowCheckedModeBanner: false,



      // --- THEME DATA (FROM YOUR ICON) ---
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          brightness: Brightness.light,
        ).copyWith(
          secondary: kSecondaryColor,
          onSecondary: Colors.black, // Text on gold buttons
          tertiary: kTertiaryColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 1.0,
        ),
        cardTheme: CardThemeData(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          brightness: Brightness.dark,
        ).copyWith(
          secondary: kSecondaryColor,
          onSecondary: Colors.black,
          tertiary: kTertiaryColor,
        ),
        cardTheme: CardThemeData(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
      themeMode: ThemeMode.system,

      // --- 7. SET HOME TO THE AUTH WRAPPER ---
      home: NeonSplashScreen(
  duration: const Duration(milliseconds: 2600),
  onFinish: () {
    // Navigate AFTER splash finishes
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
    );
  },
),
    );
  }
}

