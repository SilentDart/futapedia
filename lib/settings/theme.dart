import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'theme_provider.dart';

// Class to handle theme color preferences
class ThemeColorManager {
  static const String colorKey = 'selectedColorName';
  static MaterialColor _cachedColor = Colors.brown;
  static MaterialColor get cachedColor => _cachedColor;

  static Future<void> initCachedColor() async {
    _cachedColor = await getSavedColor();
  }

  static Future<void> saveColor(String colorName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(colorKey, colorName);
    
    if (colorOptions.containsKey(colorName)) {
      _cachedColor = colorOptions[colorName]!;
    }
  }
  
  static final Map<String, MaterialColor> colorOptions = {
    'Brown': Colors.brown,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Grey': Colors.grey,
    'Orange': Colors.orange,
    'Yellow': Colors.yellow,
    'Cyan': Colors.cyan,
    'Teal': Colors.teal,
  };
  
  static Future<MaterialColor> getSavedColor() async {
    final prefs = await SharedPreferences.getInstance();
    final savedColorName = prefs.getString(colorKey);
    
    if (savedColorName != null && colorOptions.containsKey(savedColorName)) {
      return colorOptions[savedColorName]!;
    } else {
      return Colors.brown; // Default to brown
    }
  }
  
  static Future<String> getSavedColorName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(colorKey) ?? 'Brown'; // Default to brown
  }
  
  static Future<Color> getSavedColorWithShade([int shade = 500]) async {
    final MaterialColor materialColor = await getSavedColor();
    return materialColor[shade] ?? materialColor[500]!;
  }
  
  static List<Map<String, dynamic>> getColorOptionsList() {
    return colorOptions.entries.map((entry) => {
      "name": entry.key,
      "color": entry.value,
    }).toList();
  }
}


// The actual widget for selecting colors
class ThemeSelector extends StatefulWidget {
  const ThemeSelector({super.key});

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  MaterialColor selectedColor = Colors.brown;
  String selectedColorName = 'Brown';
  MaterialColor originalColor = Colors.brown;
  String originalColorName = 'Brown';
  bool hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadSavedColor();
  }

  // Load the saved color when widget initializes
  void _loadSavedColor() async {
    MaterialColor savedColor = await ThemeColorManager.getSavedColor();
    String savedColorName = await ThemeColorManager.getSavedColorName();
    
    setState(() {
      selectedColor = savedColor;
      selectedColorName = savedColorName;
      originalColor = savedColor;
      originalColorName = savedColorName;
    });
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    if (!hasChanges) {
      return true;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Discard changes?'),
        content: Text('You have unsaved theme changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Discard'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // Get the ThemeProvider but don't listen to it (we'll update it manually)
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.chevron_left, size: 35,),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Pick Your Theme Color'),
          backgroundColor: selectedColor[500],
          
        ),
        body: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.palette, size: 32, color: selectedColor),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Choose your favorite color for the app theme:',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              Expanded(
                child: ListView.builder(
                  itemCount: ThemeColorManager.colorOptions.length,
                  itemBuilder: (context, index) {
                    final String name = ThemeColorManager.colorOptions.keys.elementAt(index);
                    final MaterialColor color = ThemeColorManager.colorOptions.values.elementAt(index);
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: selectedColorName == name ? 4 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selectedColorName == name ? Colors.black : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            selectedColor = color;
                            selectedColorName = name;
                            hasChanges = selectedColorName != originalColorName;
                          });
                          
                          // Update the provider immediately to see a preview
                          // This updates the UI in real-time without saving to preferences yet
                          themeProvider.setThemeColor(color);
                        },
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: selectedColorName == name ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Spacer(),
                              if (selectedColorName == name)
                                Icon(Icons.check_circle, color: Colors.green, size: 28),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16),
              child: ElevatedButton(
                onPressed: hasChanges 
                    ? () async {
                        // Save to preferences
                        await ThemeColorManager.saveColor(selectedColorName);
                        
                        // Update the provider (even though we already updated on tap)
                        // This ensures consistent state
                        themeProvider.setThemeColor(selectedColor);
                        
                        setState(() {
                          originalColor = selectedColor;
                          originalColorName = selectedColorName;
                          hasChanges = false;
                        });
                      } 
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Save My Theme Color',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}


class ThemeChangeNotifier {
  // Singleton pattern
  static final ThemeChangeNotifier _instance = ThemeChangeNotifier._internal();
  factory ThemeChangeNotifier() => _instance;
  ThemeChangeNotifier._internal();

  // StreamController to broadcast theme change events
  final _controller = StreamController<MaterialColor>.broadcast();
  
  // Stream getter that widgets can listen to
  Stream<MaterialColor> get themeStream => _controller.stream;
  
  // Method to notify all listeners about theme changes
  void notifyThemeChanged(MaterialColor newColor) {
    _controller.add(newColor);
  }
  
  // Clean up resources
  void dispose() {
    _controller.close();
  }
}