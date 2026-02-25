import os
import re

file_path = '/Users/muhammedirshadnp/Documents/xloop_invoice/lib/screens/public/registration_screen.dart'

with open(file_path, 'r') as f:
    text = f.read()

# 1. Variable Definitions
text = re.sub(r'bool _isLoading = true;', r'final ValueNotifier<bool> _isLoading = ValueNotifier(true);', text)
text = re.sub(r'bool _isSubmitting = false;', r'final ValueNotifier<bool> _isSubmitting = ValueNotifier(false);', text)
text = re.sub(r'CompanyEntity\? _company;', r'final ValueNotifier<CompanyEntity?> _company = ValueNotifier(null);', text)
text = re.sub(r'String\? _errorMessage;', r'final ValueNotifier<String?> _errorMessage = ValueNotifier(null);', text)
text = re.sub(r'bool _registrationSuccess = false;', r'final ValueNotifier<bool> _registrationSuccess = ValueNotifier(false);', text)
text = re.sub(r"String _countryCode = '\+966';", r"final ValueNotifier<String> _countryCode = ValueNotifier('+966');", text)
text = re.sub(r'List<String> _previewCaseCodes = \[\];', r'final ValueNotifier<List<String>> _previewCaseCodes = ValueNotifier([]);', text)
text = re.sub(r'bool _isArabic = false;', r'final ValueNotifier<bool> _isArabic = ValueNotifier(false);', text)
text = re.sub(r'bool _isMobileFormOpen = false;', r'final ValueNotifier<bool> _isMobileFormOpen = ValueNotifier(false);', text)

# 2. Add dispose method part
dispose_code = r'''
  @override
  void dispose() {
    _mobileFormController.dispose();
    _waveController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _caseCodeController.dispose();
    _companyNameController.dispose();

    _isLoading.dispose();
    _isSubmitting.dispose();
    _company.dispose();
    _errorMessage.dispose();
    _registrationSuccess.dispose();
    _countryCode.dispose();
    _previewCaseCodes.dispose();
    _isArabic.dispose();
    _isMobileFormOpen.dispose();

    super.dispose();
  }
'''
text = re.sub(r'  @override\s+void dispose\(\) \{.*?(?=  @override|  Widget build)', dispose_code, text, flags=re.DOTALL)

# 3. Replace setState blocks
text = re.sub(r'setState\(\(\) \{\s*_previewCaseCodes\.add\((.*?)\);\s*_caseCodeController\.clear\(\);\s*\}\);', r'_previewCaseCodes.value = List.from(_previewCaseCodes.value)..add(\1);\n      _caseCodeController.clear();', text)
text = re.sub(r'setState\(\(\) \{\s*_previewCaseCodes\.remove\((.*?)\);\s*\}\);', r'_previewCaseCodes.value = List.from(_previewCaseCodes.value)..remove(\1);', text)

text = re.sub(r"setState\(\(\) \{\s*_isLoading\.value = false;\s*_errorMessage\.value = '([^\']+)';\s*\}\);", r"      _isLoading.value = false;\n        _errorMessage.value = '\1';", text)
# Oops, the previous lines were already replacing `_isLoading`? Actually we should just run a basic text replace. Let's do a more robust approach.

# Let's replace usages of variables:
vars_to_replace = ['_isLoading', '_isSubmitting', '_company', '_errorMessage', '_registrationSuccess', '_countryCode', '_previewCaseCodes', '_isArabic', '_isMobileFormOpen']

for v in vars_to_replace:
    # `v = ` -> `v.value = `
    text = re.sub(fr'\b{v}\s*=', f'{v}.value =', text)
    # `v ==` -> `v.value ==`
    text = re.sub(fr'\b{v}\s*==', f'{v}.value ==', text)
    # `v !=` -> `v.value !=`
    text = re.sub(fr'\b{v}\s*!=', f'{v}.value !=', text)
    # `if (v)` -> `if (v.value)`
    text = re.sub(fr'if\s*\(\s*{v}\s*\)', f'if ({v}.value)', text)
    # `!v` -> `!v.value`
    text = re.sub(fr'!{v}\b', f'!{v}.value', text)
    # `v!` -> `v.value!`  (This regex handles variables with exclamation marks)
    text = re.sub(fr'\b{v}!', f'{v}.value!', text)
    text = re.sub(fr'\b{v}\?', f'{v}.value?', text)

    # `v.` -> `v.value.` (except `.value`)
    text = re.sub(fr'\b{v}\.(?!value)', f'{v}.value.', text)

# For _isMobileFormOpen used in string interpolation? Not likely.
# For _countryCode used in string or as parameter:
text = text.replace('Text(_countryCode,', 'Text(_countryCode.value,')
text = text.replace('Text(_countryCode)', 'Text(_countryCode.value)')
text = text.replace('Text(\n                                        _countryCode,', 'Text(\n                                        _countryCode.value,')

# Now strip empty setStates
text = re.sub(r'setState\(\(\) \{(.*?)\}\);', r'\1', text, flags=re.DOTALL)
text = re.sub(r'setState\(\(\) => (.*?)\);', r'\1;', text)

# Finally, wrap `build` body in AnimatedBuilder
build_start = text.find('Widget build(BuildContext context) {')
# find first brace `{`
first_brace = text.find('{', build_start)
body_start = first_brace + 1

# Extract the rest of the text to find the end brace of `build` method
import textwrap

# We will just inject the `AnimatedBuilder` right after `Widget build(BuildContext context) {`
new_build_return_start = """
    return AnimatedBuilder(
      animation: Listenable.merge([
        _isLoading,
        _isSubmitting,
        _company,
        _errorMessage,
        _registrationSuccess,
        _countryCode,
        _previewCaseCodes,
        _isArabic,
        _isMobileFormOpen,
      ]),
      builder: (context, _) {
"""

# To close it, we need to find the `Widget _buildDesktopInput` and add the closing braces before it.
desktop_input_idx = text.find('Widget _buildDesktopInput')
if desktop_input_idx != -1:
    # The end of `build` is right before this line
    # Find the last `}` before `Widget _buildDesktopInput`
    last_brace_idx = text.rfind('}', 0, desktop_input_idx)
    text = text[:last_brace_idx] + "      }\n    );\n  }\n\n  " + text[desktop_input_idx:]
    text = text[:first_brace+1] + new_build_return_start + text[first_brace+1:last_brace_idx] + text[last_brace_idx:]

with open(file_path, 'w') as f:
    f.write(text)

print("Done")
