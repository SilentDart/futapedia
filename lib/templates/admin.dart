import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:futapedia/firebase_services.dart/get_semester.dart';

void main()async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  runApp(const MaterialApp(
    home: AdminCourseManager(),
  ));
}

class AdminCourseManager extends StatefulWidget {
  final String initialLevel;
  final String initialCourse;

  const AdminCourseManager({
    Key? key, 
    this.initialLevel = '300L',
    this.initialCourse = 'MTS303',
  }) : super(key: key);

  @override
  State<AdminCourseManager> createState() => _AdminCourseManagerState();
}

class _AdminCourseManagerState extends State<AdminCourseManager> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedLevel;
  final TextEditingController _courseNameController = TextEditingController();
  final List<TopicEntry> _topicEntries = [];
  bool _isLoading = false;
  String? _currentSemester;
  
  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.initialLevel;
    _courseNameController.text = widget.initialCourse;
    _loadCurrentSemester();
    
    // Add a default empty topic entry
    _addTopicEntry();
  }
  
  Future<void> _loadCurrentSemester() async {
    try {
      Semester semesterInstance = Semester();
      _currentSemester = await semesterInstance.checkSemester();
      setState(() {});
    } catch (e) {
      _showErrorSnackBar('Failed to load current semester: ${e.toString()}');
    }
  }
  
  void _addTopicEntry() {
    setState(() {
      _topicEntries.add(TopicEntry(
        lessonController: TextEditingController(),
        linkController: TextEditingController(),
        lessonNumber: _topicEntries.length + 1,
        onDelete: () => _removeTopicEntry(_topicEntries.length),
      ));
    });
  }
  
  void _removeTopicEntry(int index) {
    if (_topicEntries.length <= 1) {
      _showErrorSnackBar('Cannot remove the last entry');
      return;
    }
    
    setState(() {
      // Save controllers to dispose them properly
      final toRemove = _topicEntries.removeAt(index);
      toRemove.lessonController.dispose();
      toRemove.linkController.dispose();
      
      // Update lesson numbers for subsequent entries
      for (int i = index; i < _topicEntries.length; i++) {
        _topicEntries[i].lessonNumber = i + 1;
      }
    });
  }
  
  Future<void> _submitCourseData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_topicEntries.isEmpty) {
      _showErrorSnackBar('Please add at least one topic');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final List<Map<String, dynamic>> topicData = _topicEntries.map((entry) {
        return {
          'Lesson ${entry.lessonNumber}': entry.lessonController.text.trim(),
          'Link ${entry.lessonNumber}': entry.linkController.text.trim(),
        };
      }).toList();
      
      await CourseDataWriter.writeTopicData(
        level: _selectedLevel,
        courseName: _courseNameController.text.trim(),
        // context: context,
        topicData: topicData,
      );
      
      _showSuccessDialog();
    } catch (e) {
      _showErrorSnackBar('Error saving course data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Text('Course ${_courseNameController.text} updated successfully'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetForm();
            },
            child: const Text('Add Another Course'),
          ),
        ],
      ),
    );
  }
  
  void _resetForm() {
    setState(() {
      _courseNameController.clear();
      
      // Clear and dispose all controllers
      for (var entry in _topicEntries) {
        entry.lessonController.dispose();
        entry.linkController.dispose();
      }
      
      _topicEntries.clear();
      _addTopicEntry(); // Add a fresh empty entry
    });
  }
  
  void _showErrorSnackBar(String message) {
  // Check if the widget is still mounted
  if (!mounted) return;
  
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 60),
      ),
    );
  } catch (e) {
    print("Could not show error snackbar: $e");
  }
}
  void _uploadPredefinedTopics() {
  // Create a local variable to store the mounted state
  final BuildContext currentContext = context;
  
  showDialog(
    context: currentContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Upload Predefined Content'),
      content: const Text('This will upload predefined topics for MTS 102 to the 300L collection. Continue?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            // Close the dialog first
            Navigator.of(dialogContext).pop();
            
            // Check if widget is still mounted before changing state
            if (!mounted) return;
            
            setState(() => _isLoading = true);
            
            try {
              // Call the updateCourseData method
              await updateCourseData(
                level: '300L',
                courseName: 'MTS303',
              );
              
              // Check if widget is still mounted before accessing context
              if (!mounted) return;
              
              setState(() => _isLoading = false);
              
              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(
                  content: Text('Predefined topics uploaded successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (error) {
              // Make sure widget is still mounted before updating UI
              if (!mounted) return;
              
              setState(() => _isLoading = false);
              
              // Use a try-catch here as well in case the context is no longer valid
              try {
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  SnackBar(
                    content: Text('Error uploading topics: ${error.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                print("Could not show error snackbar: $e");
              }
            }
          },
          child: const Text('Upload'),
        ),
      ],
    ),
  );
}
  @override
void dispose() {
  _courseNameController.dispose();
  
  // Dispose all text controllers
  for (var entry in _topicEntries) {
    entry.lessonController.dispose();
    entry.linkController.dispose();
  }
  
  // Don't call any methods that might access context or other widgets here
  
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Course Content Manager'),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.cloud_upload),
          tooltip: 'Upload Predefined Topics',
          onPressed: () {
            _uploadPredefinedTopics();
          },
        ),
      ],
    ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Semester: ${_currentSemester ?? 'Loading...'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Level',
                                  border: OutlineInputBorder(),
                                ),
                                value: _selectedLevel,
                                items: ['100L', '200L', '300L', '400L', '500L']
                                    .map((level) => DropdownMenuItem(
                                          value: level,
                                          child: Text(level),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _selectedLevel = value);
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a level';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _courseNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Course Code',
                                  hintText: 'e.g., MTS 102',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a course code';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Course Topics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(
                          _topicEntries.length,
                          (index) => _buildTopicEntryCard(_topicEntries[index]),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _addTopicEntry,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Topic'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resetForm,
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _submitCourseData,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Save Course Content'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTopicEntryCard(TopicEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lesson ${entry.lessonNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: entry.onDelete,
                  tooltip: 'Remove this lesson',
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: entry.lessonController,
              decoration: const InputDecoration(
                labelText: 'Lesson Title',
                hintText: 'e.g., Introduction to Functions',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a lesson title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: entry.linkController,
              decoration: const InputDecoration(
                labelText: 'Video Link',
                hintText: 'e.g., https://www.youtube.com/watch?v=...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a video link';
                }
                if (!value.contains('youtube.com') && !value.contains('youtu.be')) {
                  return 'Please enter a valid YouTube link';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper class to manage topic entry data
class TopicEntry {
  final TextEditingController lessonController;
  final TextEditingController linkController;
  int lessonNumber;
  final VoidCallback onDelete;

  TopicEntry({
    required this.lessonController,
    required this.linkController,
    required this.lessonNumber,
    required this.onDelete,
  });
}

/// Utility class for writing course data to Firestore
class CourseDataWriter {
  /// Writes topic data to Firestore for a specific course
  static Future<void> writeTopicData({
    required String level,
    required String courseName,
    // required BuildContext context,
    required List<Map<String, dynamic>> topicData,
  }) async {
    try {
      // Get current semester
      Semester semesterInstance = Semester();
      String? currentSemester = await semesterInstance.checkSemester();
      
      if (currentSemester == null) {
        throw Exception("Couldn't determine current semester");
      }
      
      // Prepare the course document data
      final Map<String, dynamic> courseData = {
        'Topic': topicData,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Get reference to the course document
      final DocumentReference courseDocRef = FirebaseFirestore.instance
          .collection('Semester')
          .doc(currentSemester)
          .collection(level)
          .doc(courseName.toLowerCase());
      
      // Update or create the document
      await courseDocRef.set(courseData, SetOptions(merge: true));
      
      // Clear any cache for immediate visibility of changes
      _clearCourseCache(courseName);
      
    } catch (e) {
      // print("Error updating course data: $e");
      rethrow;
    }
  }
  
  /// Helper method to clear course cache if it exists
  static void _clearCourseCache(String courseName) {
    // This is a placeholder - you'll need to integrate with your actual caching logic
    // If your CourseDetailsPage._courseCache is accessible, you could do:
    // CourseDetailsPage._courseCache.remove(courseName);
    
    // If the cache is not directly accessible, consider implementing a cache
    // clearing mechanism in CourseDetailsPage as a static method
    // print("Cache for course $courseName should be cleared");
  }
}

/// Example usage method as you provided
Future<void> updateCourseData({
  // required BuildContext context,
  required String level,
  required String courseName,
}) async{
  // Create topic data in the format expected by your _fetchCourseData method
 try{ List<Map<String, dynamic>> topicData = 
  [
  {
    "Lesson 1": "Proving Sets || IQ Initiative",
    "Link 1": "http://www.youtube.com/watch?v=dYEQvKD_CpY",
    "imagePath": "jsons/mathematics.json"
  },
  {
    "Lesson 2": "How to prove Cartesian Product of Sets || IQ Initiative",
    "Link 2": "http://www.youtube.com/watch?v=t0GleyxCdFU"
  },
  {
    "Lesson 3": "Product of Sets - Proof | Set Theory || IQ Initiative",
    "Link 3": "http://www.youtube.com/watch?v=8diLbGIaxSU"
  },
  {
    "Lesson 4": "RELATIONS - DISCRETE MATHEMATICS || TrevTutor",
    "Link 4": "http://www.youtube.com/watch?v=FI6j5QZNVx0"
  },
  {
    "Lesson 5": "Introduction to Relations || Neso Academy",
    "Link 5": "http://www.youtube.com/watch?v=4Caxyh0zt_o"
  },
  {
    "Lesson 6": "Types of Relations (Part 1) || Neso Academy",
    "Link 6": "http://www.youtube.com/watch?v=GvNGf9Gki7o"
  },
  {
    "Lesson 7": "Reflexive, Symmetric, and Transitive Relations on a Set || Dr. Trefor Bazett",
    "Link 7": "http://www.youtube.com/watch?v=q0xN_N7l_Kw"
  },
  {
    "Lesson 8": "Relations and Functions | Algebra || The Organic Chemistry Tutor",
    "Link 8": "http://www.youtube.com/watch?v=wbBY2tTqXDA"
  },
  {
    "Lesson 9": "Learn Functions – Understand In 7 Minutes || TabletClass Math",
    "Link 9": "http://www.youtube.com/watch?v=lGfsp2CWjok"
  },
  {
    "Lesson 10": "INJECTIVE, SURJECTIVE, and BIJECTIVE FUNCTIONS - DISCRETE MATHEMATICS || TrevTutor",
    "Link 10": "http://www.youtube.com/watch?v=bZred_Ksz2k"
  },
  {
    "Lesson 11": "[Discrete Mathematics] Inverse Function Examples || TrevTutor",
    "Link 11": "http://www.youtube.com/watch?v=1cvQhfZGF7Q"
  },
  {
    "Lesson 12": "[Discrete Mathematics] Inverses Examples 2 || TrevTutor",
    "Link 12": "http://www.youtube.com/watch?v=kEUVTLpdG0k"
  },
  {
    "Lesson 13": "Binary Operations || SolMathSolutions",
    "Link 13": "http://www.youtube.com/watch?v=vuiQ0fJRD8I"
  },
  {
    "Lesson 14": "SHS 1 Core Mathematics | Binary Operations Real || Adesua Online",
    "Link 14": "http://www.youtube.com/watch?v=CzI6VVk-0c8"
  },
  {
    "Lesson 15": "Binary Operations Complete Review || Transcended Institute",
    "Link 15": "http://www.youtube.com/watch?v=1_UWikW7gTs"
  },
  {
    "Lesson 16": "Group Definition (expanded) - Abstract Algebra || Socratica",
    "Link 16": "http://www.youtube.com/watch?v=g7L_r6zw4-c"
  },
  {
    "Lesson 17": "Abstract Algebra: Group or Not Group? (Integer edition) || Socratica",
    "Link 17": "http://www.youtube.com/watch?v=qvx9TnK85bw"
  },
  {
    "Lesson 18": "Group and Abelian Group || Neso Academy",
    "Link 18": "http://www.youtube.com/watch?v=8TjYHK804mU"
  },
  {
    "Lesson 19": "Group Multiplication Tables | Cayley Tables  (Abstract Algebra) || Socratica",
    "Link 19": "http://www.youtube.com/watch?v=BwHspSCXFNM"
  },
  {
    "Lesson 20": "Abstract Algebra: The definition of a Subgroup || Socratica",
    "Link 20": "http://www.youtube.com/watch?v=TJAQNlGvfjE"
  },
  {
    "Lesson 21": "Cyclic Groups  (Abstract Algebra) || Socratica",
    "Link 21": "http://www.youtube.com/watch?v=8A84sA1YuPw"
  },
  {
    "Lesson 22": "Cyclic Group || Neso Academy",
    "Link 22": "http://www.youtube.com/watch?v=OGCRccWi4OE"
  },
  {
    "Lesson 23": "The Order of an Element  (Abstract Algebra) || Socratica",
    "Link 23": "http://www.youtube.com/watch?v=OWTKYLAEYvY"
  },
  {
    "Lesson 24": "Symmetric Groups (Abstract Algebra) || Socratica",
    "Link 24": "http://www.youtube.com/watch?v=3aNeCWRjh8I"
  },
  {
    "Lesson 25": "Dihedral Group  (Abstract Algebra) || Socratica",
    "Link 25": "http://www.youtube.com/watch?v=rPh7EQPSaO4"
  },
  {
    "Lesson 26": "Symmetry Groups of Triangles  (Abstract Algebra) || Socratica",
    "Link 26": "http://www.youtube.com/watch?v=DeCcqioogLY"
  },
  {
    "Lesson 27": "Homomorphisms  (Abstract Algebra) || Socratica",
    "Link 27": "http://www.youtube.com/watch?v=cYzp5IWqCsg"
  },
  {
    "Lesson 28": "Group Homomorphisms - Abstract Algebra || Socratica",
    "Link 28": "http://www.youtube.com/watch?v=XPF5fe1WdKY"
  },
  {
    "Lesson 29": "Isomorphisms  (Abstract Algebra) || Socratica",
    "Link 29": "http://www.youtube.com/watch?v=BAmWgVjSosY"
  },
  {
    "Lesson 30": "The Kernel of a Group Homomorphism – Abstract Algebra || Socratica",
    "Link 30": "http://www.youtube.com/watch?v=TngePpJ_x-I"
  }
];
  
  // Call the method with explicit level and courseName
  await CourseDataWriter.writeTopicData(
    level: "300L",  // Explicitly pass the level parameter
    courseName: "MTS303",  // Explicitly pass the courseName parameter
    // context: context,
    topicData: topicData,
  );}catch (e) {
    // print("Error in updateCourseData: $e");
    rethrow; // Rethrow to be caught by the caller
  }
}