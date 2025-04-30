import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:futapedia/firebase_services.dart/get_semester.dart';
import 'package:futapedia/test.dart/test_page.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

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
    return  PopScope(
      canPop: true,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(40.h), 
          child: AppBar(
            leading: IconButton(
              icon: Icon(Icons.chevron_left, size: 30.sp,color: Colors.white,),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'SUBJECTS', 
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.indigo.shade700,
            actions: [
              IconButton(
                icon: Icon(Icons.search, color: Colors.white, size: 28.sp),
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
        ),

        body: isLoading
          ? Center(child: LoadingAnimationWidget.staggeredDotsWave(color: Colors.indigo.shade700, size: 50.sp,))
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
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                    color: Colors.indigo.shade700,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level: ${widget.level}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          'Semester: ${semester ?? "Loading..."}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(18.r),
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
                          return Center(child: LoadingAnimationWidget.staggeredDotsWave(color: Colors.indigo.shade700, size: 50.sp,));
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 50.sp, color: Colors.red),
                                SizedBox(height: 14.h),
                                Text('Error: ${snapshot.error}'),
                                SizedBox(height: 14.h),
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
                                SizedBox(height: 16.h),
                                Text(
                                  'No subjects available yet',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  'Check back later or contact your department',
                                  style: TextStyle(color: Colors.grey, fontSize:18.sp),
                                ),
                              ],
                            ),
                          );
                        }

                        List<DocumentSnapshot> subjects = snapshot.data!.docs;

                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: GridView.builder(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 148.w,
                              crossAxisSpacing: 17.w,
                              mainAxisSpacing: 17.h,
                              childAspectRatio: .9,
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
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(16.r),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          baseColor.withOpacity(0.7),
                                          baseColor,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _getSubjectIcon(subjectName),
                                          color: Colors.white,
                                          size: 28.sp,
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          subjectName,
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (subjectCode.isNotEmpty) 
                                          Padding(
                                            padding: EdgeInsets.only(top: 6.h),
                                            child: Text(
                                              subjectCode,
                                              style: TextStyle(
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.bold,
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
        child: Text('Enter a subject name to search', style: TextStyle(fontSize:12.sp)),
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
          return Center(child: LoadingAnimationWidget.staggeredDotsWave(color: Colors.indigo.shade700,size: 50.sp,));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No subjects found', style: TextStyle(fontSize: 12.5.sp)));
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