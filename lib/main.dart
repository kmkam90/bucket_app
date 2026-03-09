import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_error.dart';
import 'errors/user_error_message.dart';
import 'state/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/year_list_screen.dart';
import 'screens/overview_calendar_screen.dart';
import 'screens/report_screen.dart';

void main() {
  // Catch synchronous Flutter framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // Replace red screen with friendly fallback in release mode
  if (!kDebugMode) {
    ErrorWidget.builder = (details) => const _ErrorFallbackWidget();
  }

  // Catch async errors that escape the Flutter framework
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(
        ChangeNotifierProvider(
          create: (_) => AppState()..init(),
          child: const BucketApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

/// Friendly fallback widget shown instead of the red error screen in release.
class _ErrorFallbackWidget extends StatelessWidget {
  const _ErrorFallbackWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAFBFD),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFE8A87C)),
          SizedBox(height: 16),
          Text(
            '화면을 표시할 수 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3142),
              decoration: TextDecoration.none,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '다른 탭으로 이동해 주세요.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class BucketApp extends StatelessWidget {
  const BucketApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2D3142);
    const secondary = Color(0xFF4F5D75);
    const accent = Color(0xFF7B8CDE);
    const surface = Color(0xFFFAFBFD);
    const outline = Color(0xFFE5E7EB);
    const muted = Color(0xFF6B7280);

    final colorScheme = const ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE8EAF0),
      onPrimaryContainer: primary,
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE8EAF0),
      onSecondaryContainer: primary,
      tertiary: accent,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE8EAF0),
      onTertiaryContainer: primary,
      error: Color(0xFFDC6B6B),
      onError: Colors.white,
      surface: surface,
      onSurface: primary,
      onSurfaceVariant: muted,
      outline: outline,
      outlineVariant: Color(0xFFF0F1F3),
      shadow: Color(0x0A000000),
    );

    return MaterialApp(
      title: '버킷리스트',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: primary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: outline, width: 0.5),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFE8EAF0),
          elevation: 0,
          height: 72,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary);
            }
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: muted);
          }),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: UnderlineInputBorder(borderSide: BorderSide(color: outline)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent, width: 2)),
          hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
          labelStyle: TextStyle(color: muted),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accent,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const Color(0xFF6BCB8B);
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFF0F1F3), thickness: 1, space: 0),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: primary,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const MainTabScreen(),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _index = 0;
  bool _warningsShown = false;

  /// Cooldown: suppress duplicate errors with the same code within this window.
  static const _errorCooldown = Duration(seconds: 3);
  AppErrorCode? _lastShownErrorCode;
  DateTime? _lastShownErrorTime;

  bool _shouldShowError(AppError error) {
    final now = DateTime.now();
    if (_lastShownErrorCode == error.code &&
        _lastShownErrorTime != null &&
        now.difference(_lastShownErrorTime!) < _errorCooldown) {
      return false;
    }
    _lastShownErrorCode = error.code;
    _lastShownErrorTime = now;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Show init warnings once after loading completes
    if (!state.isLoading && !_warningsShown && state.warnings.isNotEmpty) {
      _warningsShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final warning in state.warnings) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(warning),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: '확인',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      });
    }

    // Show persist errors as SnackBar with cooldown deduplication
    if (state.lastError != null) {
      final error = state.lastError!;
      final retryable = isRetryable(error.code) && state.canRetry;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        state.clearError();
        if (!_shouldShowError(error)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessageFor(error)),
            backgroundColor: const Color(0xFFDC6B6B),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: retryable ? '재시도' : '확인',
              textColor: Colors.white,
              onPressed: retryable ? () => state.retryLastOperation() : () {},
            ),
          ),
        );
      });
    }

    final currentYear = DateTime.now().year;
    final screens = [
      const HomeScreen(),
      const YearListScreen(),
      OverviewCalendarScreen(year: currentYear),
      const ReportScreen(),
    ];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF0F1F3), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag_rounded),
              label: '목표',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: '전체',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: '리포트',
            ),
          ],
        ),
      ),
    );
  }
}
