import 'package:e_repairkit/firebase_options.dart';
import 'package:e_repairkit/services/impl/gemini_ai_Service.dart';
import 'package:e_repairkit/services/impl/google_location_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/ai_service.dart';
import 'services/findshop_service.dart';
import 'services/location_service.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'view/chatview.dart';
import 'services/chat_service.dart';
import 'services/impl/firestore_chat_service.dart';
import 'services/impl/google_shop_finder_service.dart';




// FINAL VERSION WITH DOTENV AND FIREBASE INITIALIZATION
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load your API key
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --- SERVICES ---
        Provider<ChatService>(
          create: (_) => FirestoreChatService(),
        ),

        Provider<AIService>(
          create: (_) => GeminiAIService(),
        ),
        
        Provider<LocationService>(
          create: (_) => GoogleLocationService(),
        ),

        Provider<ShopFinderService>(
          create: (_) => GoogleShopFinderService(),
        ),

        // --- ViewModel ---
        // It reads the services above to create itself
        ChangeNotifierProvider(
          create: (context) => ChatViewModel(
            aiService: context.read<AIService>(),
            locationService: context.read<LocationService>(),
            shopFinderService: context.read<ShopFinderService>(),
            chatService: context.read<ChatService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'E-RepairKit',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: ChatView(), // Set ChatView as the home screen
      ),
    );
  }
}