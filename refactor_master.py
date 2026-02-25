import re

file_path = "lib/screens/vehicle_master_screen.dart"

with open(file_path, "r") as f:
    content = f.read()

# Refactor _VehicleMasterScreenState variables
content = re.sub(
    r"List<VehicleMakeEntity> _makes = \[\];",
    r"final ValueNotifier<List<VehicleMakeEntity>> _makes = ValueNotifier([]);",
    content
)
content = re.sub(
    r"bool _isLoading = true;",
    r"final ValueNotifier<bool> _isLoading = ValueNotifier(true);",
    content
)

# Refactor _loadMakes()
load_makes = """  Future<void> _loadMakes() async {
    _isLoading.value = true;
    try {
      if (mounted) {
        await context.read<VehicleProvider>().fetchAllVehicleMakes();
        _makes.value = context.read<VehicleProvider>().vehicleMakes;
        _isLoading.value = false;
      }
    } catch (e) {
      debugPrint('Error loading vehicle makes: $e');
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }"""
content = re.sub(
    r"  Future<void> _loadMakes\(\) async \{.*?\n  \}",
    load_makes,
    content,
    flags=re.DOTALL
)

# Remove unused setStates in _VehicleMasterScreenState if any others exist
# Wait, let's add `dispose` for _makes and _isLoading
dispose_method = """  @override
  void dispose() {
    _makes.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  @override"""
content = content.replace("  @override\n  Widget build(BuildContext context) {", dispose_method + "\n  Widget build(BuildContext context) {")

# Wrap body in AnimatedBuilder
body_original = """      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _makes.isEmpty"""
body_new = """      body: AnimatedBuilder(
        animation: Listenable.merge([_isLoading, _makes]),
        builder: (context, _) {
          return _isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : _makes.value.isEmpty"""
content = content.replace(body_original, body_new)

# Close AnimatedBuilder
# Find floatingActionButton
content = content.replace(
    "                );\n              },\n            ),\n      floatingActionButton:",
    "                );\n              },\n            );\n        },\n      ),\n      floatingActionButton:"
)

# Replace _makes array accesses
content = content.replace("_makes.length", "_makes.value.length")
content = content.replace("final make = _makes[index];", "final make = _makes.value[index];")

# Refactor _AddEditMakeDialogState
content = re.sub(
    r"late List<VehicleModelDetailEntity> _models;",
    r"late final ValueNotifier<List<VehicleModelDetailEntity>> _models;",
    content
)
content = re.sub(
    r"late List<int> _years;",
    r"late final ValueNotifier<List<int>> _years;",
    content
)
content = re.sub(
    r"late List<String> _colors;",
    r"late final ValueNotifier<List<String>> _colors;",
    content
)

init_state_dialog = """    // Deep copy models
    _models = ValueNotifier(
        widget.make?.models
            .map((m) => VehicleModelDetailEntity(name: m.name, type: m.type))
            .toList() ??
        []
    );
    _years = ValueNotifier(List.from(widget.make?.years ?? []));
    _colors = ValueNotifier(List.from(widget.make?.colors ?? []));"""
content = re.sub(
    r"    // Deep copy models.*?\].*?\};\n.*?\};\n.*?\n",
    init_state_dialog + "\n",
    content,
    flags=re.DOTALL
)
content = content.replace(
    "    _models =\n        widget.make?.models\n            .map((m) => VehicleModelDetailEntity(name: m.name, type: m.type))\n            .toList() ??\n        [];\n    _years = List.from(widget.make?.years ?? []);\n    _colors = List.from(widget.make?.colors ?? []);",
    init_state_dialog
)

# dialog dispose
content = content.replace(
    "    _colorController.dispose();\n    super.dispose();",
    "    _colorController.dispose();\n    _models.dispose();\n    _years.dispose();\n    _colors.dispose();\n    super.dispose();"
)

# _addModel
add_model = """  void _addModel() {
    final name = _modelController.text.trim();
    final type = _modelTypeController.text.trim();

    if (name.isNotEmpty) {
      final exists = _models.value.any(
        (m) => m.name.toLowerCase() == name.toLowerCase(),
      );
      if (!exists) {
        final current = List<VehicleModelDetailEntity>.from(_models.value);
        current.add(
          VehicleModelDetailEntity(
            name: name,
            type: type.isNotEmpty ? type : 'Sedan', // Default if empty
          ),
        );
        _models.value = current;
        _modelController.clear();
        _modelTypeController.clear();
      }
    }
  }"""
content = re.sub(
    r"  void _addModel\(\) \{.*?\n  \}",
    add_model,
    content,
    flags=re.DOTALL
)

# _addYear
add_year = """  void _addYear() {
    final val = int.tryParse(_yearController.text.trim());
    if (val != null && !_years.value.contains(val)) {
      final current = List<int>.from(_years.value);
      current.add(val);
      current.sort(); // Keep sorted
      _years.value = current;
      _yearController.clear();
    }
  }"""
content = re.sub(
    r"  void _addYear\(\) \{.*?\n  \}",
    add_year,
    content,
    flags=re.DOTALL
)

# _addColor
add_color = """  void _addColor() {
    final val = _colorController.text.trim();
    if (val.isNotEmpty && !_colors.value.contains(val)) {
      final current = List<String>.from(_colors.value);
      current.add(val);
      _colors.value = current;
      _colorController.clear();
    }
  }"""
content = re.sub(
    r"  void _addColor\(\) \{.*?\n  \}",
    add_color,
    content,
    flags=re.DOTALL
)

# Save dialog
content = content.replace("models: _models,", "models: _models.value,")
content = content.replace("years: _years,", "years: _years.value,")
content = content.replace("colors: _colors,", "colors: _colors.value,")

# Wrap _buildListSection callers ? Not wrap but pass the value when drawing, wait... UI needs to rebuild!
# So we must wrap them in ValueListenableBuilder
content = content.replace(
    "                    Expanded(\n                      flex: 2, // Give more space to models\n                      child: _buildModelSection(),\n                    ),",
    "                    Expanded(\n                      flex: 2, // Give more space to models\n                      child: ValueListenableBuilder<List<VehicleModelDetailEntity>>(\n                        valueListenable: _Models,\n                        builder: (context, models, _) {\n                          return _buildModelSection(models);\n                        },\n                      ),\n                    ),"
)
content = content.replace("_Models", "_models")

content = content.replace(
    "                    Expanded(\n                      child: _buildListSection(\n                        title: 'Years',\n                        controller: _yearController,\n                        items: _years.map((e) => e.toString()).toList(),\n                        onAdd: _addYear,\n                        onRemove: (i) => setState(() => _years.removeAt(i)),\n                        hint: 'Year',\n                        isNumber: true,\n                      ),\n                    ),",
    "                    Expanded(\n                      child: ValueListenableBuilder<List<int>>(\n                        valueListenable: _years,\n                        builder: (context, years, _) {\n                          return _buildListSection(\n                            title: 'Years',\n                            controller: _yearController,\n                            items: years.map((e) => e.toString()).toList(),\n                            onAdd: _addYear,\n                            onRemove: (i) {\n                              final current = List<int>.from(_years.value);\n                              current.removeAt(i);\n                              _years.value = current;\n                            },\n                            hint: 'Year',\n                            isNumber: true,\n                          );\n                        },\n                      ),\n                    ),"
)

content = content.replace(
    "                    Expanded(\n                      child: _buildListSection(\n                        title: 'Colors',\n                        controller: _colorController,\n                        items: _colors,\n                        onAdd: _addColor,\n                        onRemove: (i) => setState(() => _colors.removeAt(i)),\n                        hint: 'Color',\n                      ),\n                    ),",
    "                    Expanded(\n                      child: ValueListenableBuilder<List<String>>(\n                        valueListenable: _colors,\n                        builder: (context, colors, _) {\n                          return _buildListSection(\n                            title: 'Colors',\n                            controller: _colorController,\n                            items: colors,\n                            onAdd: _addColor,\n                            onRemove: (i) {\n                              final current = List<String>.from(_colors.value);\n                              current.removeAt(i);\n                              _colors.value = current;\n                            },\n                            hint: 'Color',\n                          );\n                        },\n                      ),\n                    ),"
)

content = content.replace(
    "  Widget _buildModelSection() {",
    "  Widget _buildModelSection(List<VehicleModelDetailEntity> modelsList) {"
)
content = content.replace("itemCount: _models.length,", "itemCount: modelsList.length,")
content = content.replace("final model = _models[index];", "final model = modelsList[index];")
content = content.replace(
    "onPressed: () => setState(() => _models.removeAt(index)),",
    "onPressed: () {\n                        final current = List<VehicleModelDetailEntity>.from(_models.value);\n                        current.removeAt(index);\n                        _models.value = current;\n                      },"
)

with open(file_path, "w") as f:
    f.write(content)
