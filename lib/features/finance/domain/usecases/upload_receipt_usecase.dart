import 'package:image_picker/image_picker.dart';
import '../repositories/finance_repository.dart';

/// Uploads a receipt file to Firebase Storage and returns the download URL.
class UploadReceiptUseCase {
  final FinanceRepository repository;

  UploadReceiptUseCase(this.repository);

  Future<String> call(XFile file, String expenseId) async {
    return await repository.uploadReceipt(file, expenseId);
  }
}
