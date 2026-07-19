import 'package:image_picker/image_picker.dart';
import '../repositories/finance_repository.dart';

/// Uploads a petty cash closing sheet (PDF/image) to Firebase Storage.
class UploadClosingSheetUseCase {
  final FinanceRepository repository;

  UploadClosingSheetUseCase(this.repository);

  Future<String> call(XFile file, String sessionId) async {
    return await repository.uploadClosingSheet(file, sessionId);
  }
}
