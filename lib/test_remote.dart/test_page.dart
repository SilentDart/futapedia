import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:futapedia/test_remote.dart/result_page.dart';

class TestPage extends StatefulWidget {
  final String subjectId;
  
  TestPage({required this.subjectId});
  
  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _topicsFuture;
  Map<String, List<Question>> topicQuestions = {};
  Map<String, Map<String, String>> userAnswers = {};
  bool _isTabControllerInitialized = false;
  
  // Track progress
  int _totalQuestions = 0;
  int _answeredQuestions = 0;
  
  // Current topic and question tracking
  int _currentTopicIndex = 0;
  
  // Rewarded Ad variables
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;
  bool _isLoadingAd = false;
  bool _userEarnedReward = false;
  final String _rewardedAdUnitId = 'ca-app-pub-2303106437123151/6487175851';
  int _adRetryAttempt = 0;
  final int _maxRetryAttempts = 4;
  final Duration _retryDelay = Duration(seconds: 5);
  
  @override
  void initState() {
    super.initState();
    _topicsFuture = _loadTopics();
    _loadRewardedAd();
  }
  
  // Load rewarded ad
  void _loadRewardedAd() {
    if (_isLoadingAd) return; // Prevent multiple simultaneous loads
    
    setState(() {
      _isLoadingAd = true;
    });
    
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('Rewarded ad loaded successfully');
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
            _isLoadingAd = false;
            _adRetryAttempt = 0; // Reset retry counter on success
          });
          // Set full screen content callback
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              print('Ad dismissed');
              ad.dispose();
              setState(() {
                _isRewardedAdLoaded = false;
              });
              _loadRewardedAd(); // Reload for next time
              
              // Only navigate to results page if user earned the reward
              if (_userEarnedReward) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultPage(
                      topicQuestions: topicQuestions,
                      userAnswers: userAnswers,
                    ),
                  ),
                );
                // Reset for next time
                _userEarnedReward = false;
              }
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              print('Ad failed to show: ${error.message}');
              ad.dispose();
              setState(() {
                _isRewardedAdLoaded = false;
                _isLoadingAd = false;
              });
              
              // Retry loading ad
              _retryLoadingAd();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('Rewarded ad failed to load: ${error.message}, error code: ${error.code}');
          setState(() {
            _isRewardedAdLoaded = false;
            _isLoadingAd = false;
          });
          
          // Retry loading the ad
          _retryLoadingAd();
        },
      ),
    );
  }
  
  void _retryLoadingAd() {
    _adRetryAttempt++;
    
    if (_adRetryAttempt <= _maxRetryAttempts) {
      print('Retrying ad load. Attempt ${_adRetryAttempt} of $_maxRetryAttempts');
      
      // Exponential backoff: increase delay with each retry
      final waitTime = _retryDelay * _adRetryAttempt;
      
      Future.delayed(waitTime, () {
        if (mounted) {
          _loadRewardedAd();
        }
      });
    } else {
      print('Maximum retry attempts reached. Giving up on loading ad.');
      _adRetryAttempt = 0; // Reset for next time
      
      if (mounted) {
        // Instead of showing a snackbar, navigate directly to results as a fallback
        _showAdFailedDialog();
      }
    }
  }
  
  // Show a more student-friendly ad dialog
  void _showAdErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(message),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Try Again'),
              onPressed: () {
                Navigator.of(context).pop();
                _loadRewardedAd();
              },
            ),
          ],
        );
      },
    );
  }
  
  // Show dialog when ad fails completely but allow continuing
  void _showAdFailedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Connection Issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
              SizedBox(height: 16),
              Text('We\'re having trouble connecting to the servers.'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Try Again'),
              onPressed: () {
                Navigator.of(context).pop();
                _loadRewardedAd();
              },
            ),
            // TextButton(
            //   child: Text('View Results Anyway'),
            //   onPressed: () {
            //     Navigator.of(context).pop();
            //     // Skip the ad and go straight to results
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => ResultPage(
            //           topicQuestions: topicQuestions,
            //           userAnswers: userAnswers,
            //         ),
            //       ),
            //     );
            //   },
            // ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadTopics() async {
    try {
      final topicsSnapshot = await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.subjectId)
          .collection('topics')
          .get();
          
      if (topicsSnapshot.docs.isEmpty) {
        return [];
      }
      
      final topics = topicsSnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();
      
      // Safely dispose the old controller if it exists
      if (_isTabControllerInitialized) {
        _tabController.dispose();
      }
      
      // Set tab controller with the correct length
      setState(() {
        _tabController = TabController(length: topics.length, vsync: this);
        _isTabControllerInitialized = true;
        
        // Listen to tab changes to update current topic
        _tabController.addListener(() {
          if (!_tabController.indexIsChanging) {
            setState(() {
              _currentTopicIndex = _tabController.index;
            });
          }
        });
      });
      
      // Load questions for each topic
      for (var topic in topics) {
        await _loadQuestionsForTopic(topic['id']);
      }
      
      // Calculate total questions after loading all topics
      _calculateProgress();
      
      return topics;
    } catch (e) {
      print('Error loading topics: $e');
      throw e; // Re-throw to be caught by FutureBuilder
    }
  }
  
  Future<void> _loadQuestionsForTopic(String topicId) async {
    try {
      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.subjectId)
          .collection('topics')
          .doc(topicId)
          .collection('questions')
          .get();
          
      // Convert to list and shuffle
      List<Question> allQuestions = questionsSnapshot.docs
          .map((doc) => Question.fromFirestore(doc))
          .toList();
      
      // Shuffle and select up to 6 questions
      allQuestions.shuffle();
      List<Question> selectedQuestions = allQuestions.take(6).toList();
      
      // Initialize user answers for this topic
      Map<String, String> topicAnswers = {};
      for (var question in selectedQuestions) {
        topicAnswers[question.id] = '';
      }
      
      setState(() {
        topicQuestions[topicId] = selectedQuestions;
        userAnswers[topicId] = topicAnswers;
      });
    } catch (e) {
      print('Error loading questions for topic $topicId: $e');
    }
  }
  
  // Calculate overall test progress
  void _calculateProgress() {
    int total = 0;
    int answered = 0;
    
    topicQuestions.forEach((topicId, questions) {
      total += questions.length;
      
      // Count answered questions
      if (userAnswers.containsKey(topicId)) {
        userAnswers[topicId]!.forEach((questionId, answer) {
          if (answer.isNotEmpty) {
            answered++;
          }
        });
      }
    });
    
    setState(() {
      _totalQuestions = total;
      _answeredQuestions = answered;
    });
  }
  
  void _updateAnswer(String topicId, String questionId, String answer) {
    setState(() {
      userAnswers[topicId]![questionId] = answer;
      // Recalculate progress
      _calculateProgress();
    });
  }
  
  void _submitTest() {
    // Check if all questions have been answered
    _calculateProgress();
    
    if (_answeredQuestions < _totalQuestions) {
      _showIncompleteTestDialog();
      return;
    }
    
    // Show improved notification about ad
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Great job!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
              SizedBox(height: 16),
              Text('You\'ve completed the test! A brief advertisement will appear before your results.'),
              SizedBox(height: 16),
              LinearProgressIndicator(),
            ],
          ),
        );
      },
    );
    
    // Dismiss notification after 2 seconds and proceed with ad
    Future.delayed(Duration(seconds: 2), () {
      // Dismiss the notification dialog
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Set user reward flag to false initially
      _userEarnedReward = false;
      
      // Show rewarded ad if loaded
      if (_isRewardedAdLoaded && _rewardedAd != null) {
        _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            print('User earned reward: ${reward.amount} ${reward.type}');
            // Mark that user watched the ad and earned the reward
            _userEarnedReward = true;
            // The navigation to result page happens in onAdDismissedFullScreenContent
            // but only if _userEarnedReward is true
          },
        );
      } else {
        // If ad is not ready, check if max retries were reached
        if (_adRetryAttempt >= _maxRetryAttempts) {
          // If max retries reached, provide option to proceed without ad or retry again
          _loadRewardedAd();
        } else {
          // Otherwise show loading dialog with retry option
          _showLoadingAdDialog();
        }
      }
    });
  }
  
  // Show dialog when test is incomplete
  void _showIncompleteTestDialog() {
    int unanswered = _totalQuestions - _answeredQuestions;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Test Incomplete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'You have $unanswered ${unanswered == 1 ? "question" : "questions"} remaining.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Would you like to complete them or submit anyway?',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Submit Anyway'),
              onPressed: () {
                Navigator.of(context).pop();
                // Continue with submission
                _showPreAdDialog();
              },
            ),
            ElevatedButton(
              child: Text('Continue Test'),
              onPressed: () {
                Navigator.of(context).pop();
                // Find first unanswered question and navigate to it
                _navigateToUnansweredQuestion();
              },
            ),
          ],
        );
      },
    );
  }
  
  // Find and navigate to first unanswered question
  void _navigateToUnansweredQuestion() {
    // Iterate through topics
    for (int i = 0; i < topicQuestions.length; i++) {
      String topicId = topicQuestions.keys.elementAt(i);
      Map<String, String>? topicAnswers = userAnswers[topicId];
      
      if (topicAnswers != null) {
        // Check each question in this topic
        for (String questionId in topicAnswers.keys) {
          if (topicAnswers[questionId]?.isEmpty ?? true) {
            // Found unanswered question, switch to this tab
            _tabController.animateTo(i);
            return;
          }
        }
      }
    }
  }
  
  void _showPreAdDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Preparing Your Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, size: 48, color: Colors.amber),
              SizedBox(height: 16),
              Text('Almost there! A brief advertisement will appear before your results.'),
              SizedBox(height: 16),
              LinearProgressIndicator(),
            ],
          ),
        );
      },
    );
    
    // Dismiss notification after 2 seconds and proceed with ad
    Future.delayed(Duration(seconds: 2), () {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Set user reward flag to false initially
      _userEarnedReward = false;
      
      // Show rewarded ad if loaded
      if (_isRewardedAdLoaded && _rewardedAd != null) {
        _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            print('User earned reward: ${reward.amount} ${reward.type}');
            _userEarnedReward = true;
          },
        );
      } else {
        _showLoadingAdDialog();
      }
    });
  }
  
  void _showLoadingAdDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Connecting...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please wait while we prepare your results'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Retry'),
              onPressed: () {
                Navigator.of(context).pop();
                _loadRewardedAd();
                // Wait a bit for ad to load then try submitting again
                Future.delayed(Duration(seconds: 2), () {
                  _submitTest();
                });
              },
            ),
          ],
        );
      },
    );
    
    // Try to load the ad
    _loadRewardedAd();
    
    // Check periodically if ad is loaded and dismiss dialog if it is
    Future.delayed(Duration(seconds: 1), () {
      _checkAdLoaded(context);
    });
  }
  
  void _checkAdLoaded(BuildContext dialogContext) {
    if (_isRewardedAdLoaded) {
      // If dialog is still showing, dismiss it
      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }
      // Show the ad
      _submitTest();
    } else if (_isLoadingAd) {
      // Check again after a delay
      Future.delayed(Duration(seconds: 1), () {
        _checkAdLoaded(dialogContext);
      });
    } else {
      // If failed to load and dialog is still showing, update it to error state
      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
        _showAdErrorDialog(
          "Connection Issue", 
          "Please check your internet connection and try again."
        );
      }
    }
  }
  
  @override
  void dispose() {
    if (_isTabControllerInitialized) {
      _tabController.dispose();
    }
    // Dispose the rewarded ad
    _rewardedAd?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _topicsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return WillPopScope(
            onWillPop: () async {
              Navigator.of(context).pop();
              return false; // Return false to prevent the default back button behavior
            },
            child: Scaffold(
              appBar: AppBar(title: Text('Getting Your Test Ready...')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading questions...'),
                  ],
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return WillPopScope(
            onWillPop: () async {
              Navigator.of(context).pop();
              return false;
            },
            child: Scaffold(
              appBar: AppBar(title: Text('Oops!')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Failed to load your test questions'),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text('Try Again'),
                      onPressed: () {
                        setState(() {
                          _topicsFuture = _loadTopics();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return WillPopScope(
            onWillPop: () async {
              Navigator.of(context).pop();
              return false;
            },
            child: Scaffold(
              appBar: AppBar(title: Text('No Content')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No topics available for this subject yet'),
                    SizedBox(height: 8),
                    Text('Check back later!', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }
        
        // Topics loaded successfully
        final topics = snapshot.data!;
        
        return WillPopScope(
          onWillPop: () async {
            Navigator.of(context).pop();
            return false;
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text('Practice Test'),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: topics.map((topic) => Tab(text: topic['name'])).toList(),
                labelColor: Colors.blue,
                indicatorColor: Colors.blue,
                indicatorWeight: 3,
              ),
            ),
            body: Column(
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: _totalQuestions > 0 ? _answeredQuestions / _totalQuestions : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                
                // Progress text
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress: $_answeredQuestions of $_totalQuestions questions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        '${(_answeredQuestions / _totalQuestions * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: topics.map((topic) {
                      String topicId = topic['id'];
                      List<Question> questions = topicQuestions[topicId] ?? [];
                      
                      return questions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.quiz, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No questions available for this topic'),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: questions.length,
                              itemBuilder: (context, index) {
                                Question question = questions[index];
                                return QuestionCard(
                                  question: question,
                                  selectedAnswer: userAnswers[topicId]![question.id] ?? '',
                                  onAnswerSelected: (answer) => 
                                      _updateAnswer(topicId, question.id, answer),
                                  questionNumber: index + 1,
                                );
                              },
                            );
                    }).toList(),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: BottomAppBar(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous topic button
                    IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: _currentTopicIndex > 0 
                          ? () => _tabController.animateTo(_currentTopicIndex - 1)
                          : null,
                    ),
                    
                    // Submit button
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue,
                        ),
                        onPressed: _submitTest,
                        child: Text(
                          'FINISH & VIEW RESULTS',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    
                    // Next topic button
                    IconButton(
                      icon: Icon(Icons.arrow_forward),
                      onPressed: _currentTopicIndex < topics.length - 1
                          ? () => _tabController.animateTo(_currentTopicIndex + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Question model - unchanged
class Question {
  final String id;
  final String text;
  final List<String> options;
  final String correctAnswer;
  
  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctAnswer,
  });
  
  factory Question.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Question(
      id: doc.id,
      text: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['answer'] ?? '',
    );
  }
}

// Improved QuestionCard Widget
class QuestionCard extends StatelessWidget {
  final Question question;
  final String selectedAnswer;
  final Function(String) onAnswerSelected;
  final int questionNumber;
  
  QuestionCard({
    required this.question,
    required this.selectedAnswer,
    required this.onAnswerSelected,
    required this.questionNumber,
  });
  
  @override
  Widget build(BuildContext context) {
    bool isAnswered = selectedAnswer.isNotEmpty;
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAnswered ? Colors.blue.shade200 : Colors.grey.shade300,
          width: isAnswered ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question number with status indicator
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAnswered ? Colors.blue : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$questionNumber',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            // Status indicator
            isAnswered
                ? Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4, left: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Answered',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4, left: 4),
                    child: Row(
                      children: [
                        Icon(Icons.radio_button_unchecked, color: Colors.orange, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Not answered yet',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
            
            SizedBox(height: 12),
            
            // Answer options
            ...question.options.map((option) {
              // Determine if this option is selected
              bool isSelected = selectedAnswer == option;
              
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => onAnswerSelected(option),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? Colors.blue : Colors.grey,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}