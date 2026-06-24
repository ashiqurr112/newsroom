import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/services/feed_service.dart';
import 'data/services/storage_service.dart';
import 'data/repositories/feed_repository.dart';
import 'data/repositories/user_repository.dart';
import 'ui/core/themes.dart';
import 'ui/features/feed/view_models/feed_view_model.dart';
import 'ui/features/profile/view_models/user_view_model.dart';
import 'ui/features/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Setup services
  final storageService = StorageService();
  final feedService = FeedService();
  
  // Setup repositories
  final userRepository = UserRepository(storageService: storageService);
  final feedRepository = FeedRepository(feedService: feedService);
  
  // Initialize repository
  await userRepository.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserViewModel>(
          create: (_) => UserViewModel(userRepository: userRepository),
        ),
        ChangeNotifierProvider<FeedViewModel>(
          create: (_) => FeedViewModel(feedRepository: feedRepository),
        ),
      ],
      child: const NewsroomApp(),
    ),
  );
}

class NewsroomApp extends StatelessWidget {
  const NewsroomApp({super.key});

  @override
  Widget build(BuildContext context) {
    final userVM = Provider.of<UserViewModel>(context);
    
    // Choose active theme
    ThemeData activeTheme;
    if (userVM.themeMode == 'sepia') {
      activeTheme = AppTheme.sepiaTheme;
    } else if (userVM.themeMode == 'dark') {
      activeTheme = AppTheme.darkTheme;
    } else {
      activeTheme = AppTheme.lightTheme;
    }

    return MaterialApp(
      title: 'Newsroom',
      theme: activeTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
