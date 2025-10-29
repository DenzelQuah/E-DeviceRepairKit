import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ai_service.dart';
import 'services/findshop_service.dart';
import 'services/location_service.dart';
import 'services/impl/mock_ai_service.dart';
import 'services/impl/mock_location_service.dart';
import 'services/impl/mock_shop_finder_service.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'view/chatView.dart'; // We will create this next

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // --- Services ---
        // We bind the INTERFACE to the MOCK implementation
        Provider<AIService>(
          create: (_) => MockAIService(),
        ),
        Provider<LocationService>(
          create: (_) => MockLocationService(),
        ),
        Provider<ShopFinderService>(
          create: (_) => MockShopFinderService(),
        ),

        // --- ViewModel ---
        // It reads the services above to create itself
        ChangeNotifierProvider(
          create: (context) => ChatViewModel(
            aiService: context.read<AIService>(),
            locationService: context.read<LocationService>(),
            shopFinderService: context.read<ShopFinderService>(),
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