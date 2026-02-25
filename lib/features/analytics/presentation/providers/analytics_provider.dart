import 'package:flutter/foundation.dart';
import '../../domain/entities/analytics_entity.dart';
import '../../domain/usecases/get_analytics_usecase.dart';

class AnalyticsProvider extends ChangeNotifier {
  final GetAnalyticsUseCase getAnalyticsUseCase;

  AnalyticsEntity? _analytics;
  bool _isLoading = false;
  String? _errorMessage;

  AnalyticsProvider({required this.getAnalyticsUseCase});

  AnalyticsEntity? get analytics => _analytics;
  bool get isLoading => _isLoading;
  String? get error => _errorMessage;

  Future<void> fetchAnalytics({int? month, int? year}) async {
    _setLoading(true);
    try {
      _analytics = await getAnalyticsUseCase(month: month, year: year);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to fetch analytics: \$e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
