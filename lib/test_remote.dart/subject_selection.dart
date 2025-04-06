import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:futapedia/firebase_services.dart/get_semester.dart';
import 'package:futapedia/test_remote.dart/test_page.dart';

class SubjectSelectionPage extends StatefulWidget {
  final String level;

  const SubjectSelectionPage({Key? key, required this.level}) : super(key: key);

  @override
  State<SubjectSelectionPage> createState() => _SubjectSelectionPageState();
}

class _SubjectSelectionPageState extends State<SubjectSelectionPage> {
  String? semester;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSemester();
  }

  void _loadSemester() async {
    Semester semesterInstance = Semester();
    String? result = await semesterInstance.checkSemester();
    setState(() {
      semester = result;
      isLoading = false;
    });
  }

  // Custom color generator based on subject name
  Color getSubjectColor(String subjectName) {
    // Create a simple hash of the subject name to get consistent colors
    int hash = subjectName.hashCode;
    
    // List of student-friendly colors (avoid harsh colors)
    final colors = [
      Color(0xFF4285F4), // Google Blue
      Color(0xFF0F9D58), // Google Green
      Color(0xFFDB4437), // Google Red
      Color(0xFF4285F4), // Google Blue
      Color(0xFFFFBB00), // Amber
      Color(0xFF673AB7), // Deep Purple
      Color(0xFF009688), // Teal
      Color(0xFF3F51B5), // Indigo
    ];
    
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false; // Return false to prevent the default back button behavior
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'SUBJECTS', 
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.indigo.shade700,
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: Colors.white),
              onPressed: () {
                // Implement search functionality
                showSearch(
                  context: context,
                  delegate: SubjectSearchDelegate(semester: semester, level: widget.level),
                );
              },
            ),
          ],
        ),

        body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.indigo.shade100, Colors.white],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    color: Colors.indigo.shade700,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level: ${widget.level}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Semester: ${semester ?? "Loading..."}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Semester')
                          .doc(semester)
                          .collection('Tests')
                          .doc('CBT')
                          .collection(widget.level)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: Colors.red),
                                SizedBox(height: 16),
                                Text('Error: ${snapshot.error}'),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      // Refresh the page
                                    });
                                  },
                                  child: Text('Retry'),
                                ),
                              ],
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: 16),
                                Text(
                                  'No subjects available yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Check back later or contact your department',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        List<DocumentSnapshot> subjects = snapshot.data!.docs;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1,
                            ),
                            itemCount: subjects.length,
                            itemBuilder: (context, index) {
                              Map<String, dynamic> subject = subjects[index].data() as Map<String, dynamic>;
                              String subjectName = subject['name'] ?? 'Coming soon';
                              String subjectCode = subject['code'] ?? '';
                              
                              Color baseColor = getSubjectColor(subjectName);

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TestPage(subjectId: subjects[index].id),
                                    ),
                                  );
                                },
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          baseColor.withOpacity(0.7),
                                          baseColor,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _getSubjectIcon(subjectName),
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          subjectName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (subjectCode.isNotEmpty) 
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              subjectCode,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
    
  }
  
  // Helper method to choose appropriate icons based on subject name
  IconData _getSubjectIcon(String subjectName) {
    final name = subjectName.toLowerCase();
    
    if (name.contains('math') || name.contains('calculus') || name.contains('algebra')) {
      return Icons.calculate;
    } else if (name.contains('physics') || name.contains('mechanics')) {
      return Icons.science;
    } else if (name.contains('chem')) {
      return Icons.biotech;
    } else if (name.contains('computer') || name.contains('programming')) {
      return Icons.computer;
    } else if (name.contains('eng') || name.contains('mech')) {
      return Icons.build;
    } else if (name.contains('bio') || name.contains('zoo')) {
      return Icons.healing;
    } else if (name.contains('eco') || name.contains('account')) {
      return Icons.account_balance;
    } else if (name.contains('language') || name.contains('english')) {
      return Icons.language;
    } else if (name.contains('hist')) {
      return Icons.history_edu;
    } else if (name.contains('art') || name.contains('music')) {
      return Icons.palette;
    } else {
      return Icons.book;
    }
  }
}

// Add search functionality
class SubjectSearchDelegate extends SearchDelegate {
  final String? semester;
  final String level;

  SubjectSearchDelegate({required this.semester, required this.level});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildSearchResults();
  }

  Widget buildSearchResults() {
    if (semester == null || query.trim().isEmpty) {
      return Center(
        child: Text('Enter a subject name to search'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Semester')
          .doc(semester)
          .collection('Tests')
          .doc('CBT')
          .collection(level)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No subjects found'));
        }

        // Filter subjects based on search query
        List<DocumentSnapshot> filteredSubjects = snapshot.data!.docs.where((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String name = data['name'] ?? '';
          String code = data['code'] ?? '';
          return name.toLowerCase().contains(query.toLowerCase()) || 
                 code.toLowerCase().contains(query.toLowerCase());
        }).toList();

        if (filteredSubjects.isEmpty) {
          return Center(child: Text('No matching subjects found'));
        }

        return ListView.builder(
          itemCount: filteredSubjects.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> subject = filteredSubjects[index].data() as Map<String, dynamic>;
            String name = subject['name'] ?? 'Unnamed Subject';
            String code = subject['code'] ?? '';
            
            return ListTile(
              leading: Icon(Icons.book),
              title: Text(name),
              subtitle: code.isNotEmpty ? Text(code) : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TestPage(subjectId: filteredSubjects[index].id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}