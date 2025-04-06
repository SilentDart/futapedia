import 'package:flutter/material.dart';
import 'package:futapedia/test_remote.dart/test_page.dart';

class ResultPage extends StatelessWidget {
  final Map<String, List<Question>> topicQuestions;
  final Map<String, Map<String, String>> userAnswers;
  
  ResultPage({
    required this.topicQuestions,
    required this.userAnswers,
  });
  
  int _calculateTotalScore() {
    int correctAnswers = 0;
    // ignore: unused_local_variable
    int totalQuestions = 0;
    
    topicQuestions.forEach((topicId, questions) {
      totalQuestions += questions.length;
      
      for (var question in questions) {
        if (userAnswers[topicId]![question.id] == question.correctAnswer) {
          correctAnswers++;
        }
      }
    });
    
    return correctAnswers;
  }
  
  int _calculateTotalQuestions() {
    int total = 0;
    
    topicQuestions.forEach((topicId, questions) {
      total += questions.length;
    });
    
    return total;
  }
  
  @override
  Widget build(BuildContext context) {
    int totalCorrect = _calculateTotalScore();
    int totalQuestions = _calculateTotalQuestions();
    double percentage = totalQuestions > 0 
        ? (totalCorrect / totalQuestions * 100) 
        : 0;
        
    // Counter for question numbering
    int questionCounter = 0;
        
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Results'),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Text(
                  'Score: $totalCorrect/$totalQuestions',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    color: percentage >= 70 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                ...topicQuestions.entries.expand((entry) {
                  String topicId = entry.key;
                  List<Question> questions = entry.value;
                  
                  return questions.map((question) {
                    // Increment counter for each question
                    questionCounter++;
                    
                    String userAnswer = userAnswers[topicId]![question.id] ?? '';
                    bool isCorrect = userAnswer == question.correctAnswer;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question number
                                Container(
                                  padding: EdgeInsets.all(8),
                                  margin: EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$questionCounter',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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
                            SizedBox(height: 16),
                            ...question.options.map((option) {
                              bool isUserAnswer = option == userAnswer;
                              bool isCorrectAnswer = option == question.correctAnswer;
                              
                              Color? textColor;
                              if (isUserAnswer && isCorrect) {
                                textColor = Colors.green;
                              } else if (isUserAnswer && !isCorrect) {
                                textColor = Colors.red;
                              } else if (isCorrectAnswer) {
                                textColor = Colors.green;
                              }
                              
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      isUserAnswer 
                                          ? (isCorrect ? Icons.check_circle : Icons.cancel)
                                          : (isCorrectAnswer ? Icons.check_circle_outline : Icons.radio_button_unchecked),
                                      color: textColor,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: isUserAnswer || isCorrectAnswer 
                                              ? FontWeight.bold 
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  });
                }),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: Text('HOME'),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () {
                    // Pop back to the subject selection page
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text('TRY ANOTHER TEST'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}