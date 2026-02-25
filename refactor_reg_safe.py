import re

file_path = '/Users/muhammedirshadnp/Documents/xloop_invoice/lib/screens/public/registration_screen.dart'
with open(file_path, 'r') as f:
    text = f.read()

# 1. Variable Declarations
declarations = {
    'bool _isLoading = true;': 'final ValueNotifier<bool> _isLoading = ValueNotifier(true);',
    'bool _isSubmitting = false;': 'final ValueNotifier<bool> _isSubmitting = ValueNotifier(false);',
    'CompanyEntity? _company;': 'final ValueNotifier<CompanyEntity?> _company = ValueNotifier(null);',
    'String? _errorMessage;': 'final ValueNotifier<String?> _errorMessage = ValueNotifier(null);',
    'bool _registrationSuccess = false;': 'final ValueNotifier<bool> _registrationSuccess = ValueNotifier(false);',
    "String _countryCode = '+966'; // Default to KSA": "final ValueNotifier<String> _countryCode = ValueNotifier('+966'); // Default to KSA",
    'List<String> _previewCaseCodes = [];': 'final ValueNotifier<List<String>> _previewCaseCodes = ValueNotifier([]);',
    'bool _isArabic = false;': 'final ValueNotifier<bool> _isArabic = ValueNotifier(false);',
    'bool _isMobileFormOpen = false;': 'final ValueNotifier<bool> _isMobileFormOpen = ValueNotifier(false);'
}

for old, new in declarations.items():
    text = text.replace(old, new)


# 2. Variable Usage
variables = ['_isLoading', '_isSubmitting', '_company', '_errorMessage', '_registrationSuccess', '_countryCode', '_previewCaseCodes', '_isArabic', '_isMobileFormOpen']

for var in variables:
    # We want to replace all occurrences of var with var.value
    # BUT EXCLUDE:
    # - The declaration itself which has "final ValueNotifier<...>"
    # - If it already has .value or .dispose
    # Instead of regex lookbehinds which are tricky, let's just do:
    pattern = r'\b' + var + r'\b(?!\.value|\.dispose)'
    text = re.sub(pattern, f'{var}.value', text)

# Now fix the declarations back because they got matched by the above var replacement:
for var in variables:
    # Revert `final ValueNotifier<...> var.value = ValueNotifier` back to `var =`
    text = re.sub(rf'(final ValueNotifier<[^>]+>\s+){var}\.value(\s*=\s*ValueNotifier)', rf'\1{var}\2', text)
    # Revert Listenable.merge items and dispose items if any got messed up (actually we didn't add dispose yet)

# 3. Dispose Method
dispose_start = '  void dispose() {'
dispose_items = "\n".join([f"    {var}.dispose();" for var in variables])
text = text.replace('  void dispose() {', '  void dispose() {\n' + dispose_items)

# 4. Remove setState wrappers
# We need to remove `setState(() { ... });` but KEEP the `...`
# Easiest way in python:
def remove_setstate(match):
    inner_block = match.group(1).strip()
    return inner_block + ';' if not inner_block.endswith(';') and not inner_block.endswith('}') else inner_block

# Simple single-line setStates: setState(() => _isSubmitting.value = ...)
text = re.sub(r'setState\(\s*\(\)\s*=>\s*([^;]+)\s*\);', r'\1;', text)
text = re.sub(r'setState\(\s*\(\)\s*\{\s*([^}]+)\s*\}\s*\);', remove_setstate, text)

# 5. Wrap build method
build_start = r'Widget build\(BuildContext context\) \{'
build_replacement = """Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([""" + ",\n        ".join(variables) + """
      ]),
      builder: (context, _) {"""
text = re.sub(build_start, build_replacement, text)

# We must close the AnimatedBuilder by replacing the last brace of the `build` method.
# In registration_screen.dart, the method right after `build` is `Widget _buildSuccessScreen() {`
# So we can look for `  Widget _buildSuccessScreen() {` and replace the space above it.
# Original structure:
#     return Scaffold(...);\n  }\n\n  Widget _buildSuccessScreen() {
text = text.replace(
    '    );\n  }\n\n  Widget _buildSuccessScreen() {',
    '    );\n      },\n    );\n  }\n\n  Widget _buildSuccessScreen() {'
)

with open(file_path, 'w') as f:
    f.write(text)

print("Safe refactor applied")
