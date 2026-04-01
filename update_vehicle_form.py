import re

file_path = "lib/screens/vehicle_form_screen.dart"
with open(file_path, 'r') as f:
    content = f.read()

# 1. Add controllers
controllers_addition = """
  // Maintenance Intervals
  final _engineOilIntervalController = TextEditingController();
  final _gearOilIntervalController = TextEditingController();
  final _housingOilIntervalController = TextEditingController();
  final _tyreChangeIntervalController = TextEditingController();
  final _batteryChangeIntervalController = TextEditingController();
  final _brakePadsIntervalController = TextEditingController();
  final _airFilterIntervalController = TextEditingController();
  final _acServiceIntervalController = TextEditingController();
  final _wheelAlignmentIntervalController = TextEditingController();
  final _sparkPlugsIntervalController = TextEditingController();
  final _coolantFlushIntervalController = TextEditingController();
  final _wiperBladesIntervalController = TextEditingController();
  final _timingBeltIntervalController = TextEditingController();
  final _transmissionFluidIntervalController = TextEditingController();
  final _brakeFluidIntervalController = TextEditingController();
  final _fuelFilterIntervalController = TextEditingController();
"""
content = re.sub(r'(// Vehicle Master Data)', controllers_addition + r'\n  \1', content)

# 2. Add dispose
dispose_addition = """
    _engineOilIntervalController.dispose();
    _gearOilIntervalController.dispose();
    _housingOilIntervalController.dispose();
    _tyreChangeIntervalController.dispose();
    _batteryChangeIntervalController.dispose();
    _brakePadsIntervalController.dispose();
    _airFilterIntervalController.dispose();
    _acServiceIntervalController.dispose();
    _wheelAlignmentIntervalController.dispose();
    _sparkPlugsIntervalController.dispose();
    _coolantFlushIntervalController.dispose();
    _wiperBladesIntervalController.dispose();
    _timingBeltIntervalController.dispose();
    _transmissionFluidIntervalController.dispose();
    _brakeFluidIntervalController.dispose();
    _fuelFilterIntervalController.dispose();
"""
content = re.sub(r'(_fuelFilterKmController.dispose\(\);\n)', r'\1' + dispose_addition, content)

# 3. Add populate
populate_chunk = """
    if (v.maintenanceIntervals != null) {
      final i = v.maintenanceIntervals!;
      _engineOilIntervalController.text = i['engineOil']?.toString() ?? '';
      _gearOilIntervalController.text = i['gearOil']?.toString() ?? '';
      _housingOilIntervalController.text = i['housingOil']?.toString() ?? '';
      _tyreChangeIntervalController.text = i['tyreChange']?.toString() ?? '';
      _batteryChangeIntervalController.text = i['batteryChange']?.toString() ?? '';
      _brakePadsIntervalController.text = i['brakePads']?.toString() ?? '';
      _airFilterIntervalController.text = i['airFilter']?.toString() ?? '';
      _acServiceIntervalController.text = i['acService']?.toString() ?? '';
      _wheelAlignmentIntervalController.text = i['wheelAlignment']?.toString() ?? '';
      _sparkPlugsIntervalController.text = i['sparkPlugs']?.toString() ?? '';
      _coolantFlushIntervalController.text = i['coolantFlush']?.toString() ?? '';
      _wiperBladesIntervalController.text = i['wiperBlades']?.toString() ?? '';
      _timingBeltIntervalController.text = i['timingBelt']?.toString() ?? '';
      _transmissionFluidIntervalController.text = i['transmissionFluid']?.toString() ?? '';
      _brakeFluidIntervalController.text = i['brakeFluid']?.toString() ?? '';
      _fuelFilterIntervalController.text = i['fuelFilter']?.toString() ?? '';
    }
"""
content = re.sub(r'(_fuelFilterKmController\.text = m\.fuelFilter\?\.mileage\.toString\(\) \?\? \'\';\n    \})', r'\1\n' + populate_chunk, content)

# 4. Save Vehicle addition
save_addition = """
        maintenanceIntervals: {
          if (_engineOilIntervalController.text.isNotEmpty) 'engineOil': int.parse(_engineOilIntervalController.text),
          if (_gearOilIntervalController.text.isNotEmpty) 'gearOil': int.parse(_gearOilIntervalController.text),
          if (_housingOilIntervalController.text.isNotEmpty) 'housingOil': int.parse(_housingOilIntervalController.text),
          if (_tyreChangeIntervalController.text.isNotEmpty) 'tyreChange': int.parse(_tyreChangeIntervalController.text),
          if (_batteryChangeIntervalController.text.isNotEmpty) 'batteryChange': int.parse(_batteryChangeIntervalController.text),
          if (_brakePadsIntervalController.text.isNotEmpty) 'brakePads': int.parse(_brakePadsIntervalController.text),
          if (_airFilterIntervalController.text.isNotEmpty) 'airFilter': int.parse(_airFilterIntervalController.text),
          if (_acServiceIntervalController.text.isNotEmpty) 'acService': int.parse(_acServiceIntervalController.text),
          if (_wheelAlignmentIntervalController.text.isNotEmpty) 'wheelAlignment': int.parse(_wheelAlignmentIntervalController.text),
          if (_sparkPlugsIntervalController.text.isNotEmpty) 'sparkPlugs': int.parse(_sparkPlugsIntervalController.text),
          if (_coolantFlushIntervalController.text.isNotEmpty) 'coolantFlush': int.parse(_coolantFlushIntervalController.text),
          if (_wiperBladesIntervalController.text.isNotEmpty) 'wiperBlades': int.parse(_wiperBladesIntervalController.text),
          if (_timingBeltIntervalController.text.isNotEmpty) 'timingBelt': int.parse(_timingBeltIntervalController.text),
          if (_transmissionFluidIntervalController.text.isNotEmpty) 'transmissionFluid': int.parse(_transmissionFluidIntervalController.text),
          if (_brakeFluidIntervalController.text.isNotEmpty) 'brakeFluid': int.parse(_brakeFluidIntervalController.text),
          if (_fuelFilterIntervalController.text.isNotEmpty) 'fuelFilter': int.parse(_fuelFilterIntervalController.text),
        },
"""
content = re.sub(r'(status: _status\.value,\n      \);)', save_addition + r'\1', content)

# 5. UI elements - replacing _buildMaintenanceRow definition
new_row_def = """  Widget _buildMaintenanceRow(
    String label,
    ValueNotifier<DateTime?> dateNotifier,
    TextEditingController kmController,
    TextEditingController intervalController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: ValueListenableBuilder<DateTime?>(
                valueListenable: dateNotifier,
                builder: (context, date, _) {
                  return CustomDatePicker(
                    label: 'Last Date',
                    date: date,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2050),
                      );
                      if (picked != null) {
                        dateNotifier.value = picked;
                      }
                    },
                    onClear: () => dateNotifier.value = null,
                  );
                },
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              flex: 3,
              child: _buildTextField('Last Service KM', kmController,
                  isNumber: true, required: false),
            ),
            SizedBox(width: 8.w),
            Expanded(
              flex: 3,
              child: _buildTextField('Interval KM', intervalController,
                  isNumber: true, required: false),
            ),
          ],
        ),
      ],
    );
  }"""
content = re.sub(r'  Widget _buildMaintenanceRow\([\s\S]*?    \];\n  \}', new_row_def, content)

# 6. Update calls to _buildMaintenanceRow
content = content.replace("                          _engineOilChangeKmController,\n                        ),", "                          _engineOilChangeKmController,\n                          _engineOilIntervalController,\n                        ),")
content = content.replace("                          _gearOilChangeKmController,\n                        ),", "                          _gearOilChangeKmController,\n                          _gearOilIntervalController,\n                        ),")
content = content.replace("                          _housingOilChangeKmController,\n                        ),", "                          _housingOilChangeKmController,\n                          _housingOilIntervalController,\n                        ),")
content = content.replace("                          _tyreChangeKmController,\n                        ),", "                          _tyreChangeKmController,\n                          _tyreChangeIntervalController,\n                        ),")
content = content.replace("                          _batteryChangeKmController,\n                        ),", "                          _batteryChangeKmController,\n                          _batteryChangeIntervalController,\n                        ),")
content = content.replace("                          _brakePadsKmController,\n                        ),", "                          _brakePadsKmController,\n                          _brakePadsIntervalController,\n                        ),")
content = content.replace("                          _airFilterKmController,\n                        ),", "                          _airFilterKmController,\n                          _airFilterIntervalController,\n                        ),")
content = content.replace("                          _acServiceKmController,\n                        ),", "                          _acServiceKmController,\n                          _acServiceIntervalController,\n                        ),")
content = content.replace("                          _wheelAlignmentKmController,\n                        ),", "                          _wheelAlignmentKmController,\n                          _wheelAlignmentIntervalController,\n                        ),")
content = content.replace("                          _sparkPlugsKmController,\n                        ),", "                          _sparkPlugsKmController,\n                          _sparkPlugsIntervalController,\n                        ),")
content = content.replace("                          _coolantFlushKmController,\n                        ),", "                          _coolantFlushKmController,\n                          _coolantFlushIntervalController,\n                        ),")
content = content.replace("                          _wiperBladesKmController,\n                        ),", "                          _wiperBladesKmController,\n                          _wiperBladesIntervalController,\n                        ),")
content = content.replace("                          _timingBeltKmController,\n                        ),", "                          _timingBeltKmController,\n                          _timingBeltIntervalController,\n                        ),")
content = content.replace("                          _transmissionFluidKmController,\n                        ),", "                          _transmissionFluidKmController,\n                          _transmissionFluidIntervalController,\n                        ),")
content = content.replace("                          _brakeFluidKmController,\n                        ),", "                          _brakeFluidKmController,\n                          _brakeFluidIntervalController,\n                        ),")
content = content.replace("                          _fuelFilterKmController,\n                        ),", "                          _fuelFilterKmController,\n                          _fuelFilterIntervalController,\n                        ),")

with open(file_path, 'w') as f:
    f.write(content)

