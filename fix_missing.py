import re

file_path = '/Users/muhammedirshadnp/Documents/xloop_invoice/lib/screens/public/registration_screen.dart'

with open(file_path, 'r') as f:
    text = f.read()

vars_to_replace = ['_isLoading', '_isSubmitting', '_company', '_errorMessage', '_registrationSuccess', '_countryCode', '_previewCaseCodes', '_isArabic', '_isMobileFormOpen']

for v in vars_to_replace:
    # We want to replace all occurrences of `v` with `v.value`
    # BUT we must NOT replace if it's already followed by `.value`, `.dispose`, or is in the declaration.
    # The safest way is to replace everything, then fix the specific known exceptions.
    text = re.sub(fr'\b{v}\b(?!\.value)(?!\.dispose)', f'{v}.value', text)

# Now fix the declarations
text = text.replace('final ValueNotifier<bool> _isLoading.value = ValueNotifier', 'final ValueNotifier<bool> _isLoading = ValueNotifier')
text = text.replace('final ValueNotifier<bool> _isSubmitting.value = ValueNotifier', 'final ValueNotifier<bool> _isSubmitting = ValueNotifier')
text = text.replace('final ValueNotifier<CompanyEntity?> _company.value = ValueNotifier', 'final ValueNotifier<CompanyEntity?> _company = ValueNotifier')
text = text.replace('final ValueNotifier<String?> _errorMessage.value = ValueNotifier', 'final ValueNotifier<String?> _errorMessage = ValueNotifier')
text = text.replace('final ValueNotifier<bool> _registrationSuccess.value = ValueNotifier', 'final ValueNotifier<bool> _registrationSuccess = ValueNotifier')
text = text.replace("final ValueNotifier<String> _countryCode.value = ValueNotifier", "final ValueNotifier<String> _countryCode = ValueNotifier")
text = text.replace('final ValueNotifier<List<String>> _previewCaseCodes.value = ValueNotifier', 'final ValueNotifier<List<String>> _previewCaseCodes = ValueNotifier')
text = text.replace('final ValueNotifier<bool> _isArabic.value = ValueNotifier', 'final ValueNotifier<bool> _isArabic = ValueNotifier')
text = text.replace('final ValueNotifier<bool> _isMobileFormOpen.value = ValueNotifier', 'final ValueNotifier<bool> _isMobileFormOpen = ValueNotifier')

# Fix Listenable.merge usages
text = text.replace('_isLoading.value,\n        _isSubmitting.value,\n        _company.value,\n        _errorMessage.value,\n        _registrationSuccess.value,\n        _countryCode.value,\n        _previewCaseCodes.value,\n        _isArabic.value,\n        _isMobileFormOpen.value,',
'_isLoading,\n        _isSubmitting,\n        _company,\n        _errorMessage,\n        _registrationSuccess,\n        _countryCode,\n        _previewCaseCodes,\n        _isArabic,\n        _isMobileFormOpen,')

# Wait, the Listenable.merge might have been written in different spacing. Let's use regex for Listenable.merge
merge_pattern = r'Listenable\.merge\(\[\s*_isLoading\.value,\s*_isSubmitting\.value,\s*_company\.value,\s*_errorMessage\.value,\s*_registrationSuccess\.value,\s*_countryCode\.value,\s*_previewCaseCodes\.value,\s*_isArabic\.value,\s*_isMobileFormOpen\.value,\s*\]\)'
merge_replacement = r'''Listenable.merge([
        _isLoading,
        _isSubmitting,
        _company,
        _errorMessage,
        _registrationSuccess,
        _countryCode,
        _previewCaseCodes,
        _isArabic,
        _isMobileFormOpen,
      ])'''
text = re.sub(merge_pattern, merge_replacement, text, flags=re.MULTILINE)

with open(file_path, 'w') as f:
    f.write(text)

print("Fixes applied")
