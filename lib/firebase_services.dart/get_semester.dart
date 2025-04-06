import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Semester {
  Future<void> _getSemesterValueFromFirebaseAndStore() async {
    try {
      DocumentSnapshot semesterValue = await FirebaseFirestore.instance
          .collection('Preference')
          .doc('F or S')
          .get();

      if (semesterValue.exists) {
        // Explicitly cast data() to Map<String, dynamic>
        var data = semesterValue.data() as Map<String, dynamic>?;
        String? semester = data?['semester'];

        if (semester != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('semester', semester);
        }
      }
    } catch (e) {
      // print("Error fetching semester: $e");
    }
  }

  Future<String?> checkSemester() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedSemester = prefs.getString('semester');
    int? lastFetchTime = prefs.getInt('semester_last_fetch');

    // Check if we have a cached value and if it's less than 15 days old
    bool isStale = lastFetchTime == null ||
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastFetchTime)).inDays > 30;

    if (cachedSemester == null || cachedSemester.isEmpty || isStale) {
      await _getSemesterValueFromFirebaseAndStore();
      await prefs.setInt('semester_last_fetch', DateTime.now().millisecondsSinceEpoch);
      return prefs.getString('semester');
    } else {
      return cachedSemester;
    }
  }
}

class PastQuestion {
  Future<void> _getPastQuestionLinkFromFirebaseAndStore() async {
    try {
      DocumentSnapshot pqValue = await FirebaseFirestore.instance
          .collection('Preference')
          .doc('PastQuestion')
          .get();

      if (pqValue.exists) {
        var data = pqValue.data() as Map<String, dynamic>?;
        String? pqLink = data?['PQLink'];

        if (pqLink != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('PQLink', pqLink);
          await prefs.setInt('pq_last_fetch', DateTime.now().millisecondsSinceEpoch);
        }
      }
    } catch (e) {
      // print("Error fetching past question link: $e");
    }
  }

  Future<String?> checkPastQuestionLink() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedPQLink = prefs.getString('PQLink');
    int? lastFetchTime = prefs.getInt('pq_last_fetch');

    bool isStale = lastFetchTime == null ||
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastFetchTime)).inDays > 30;

    if (cachedPQLink == null || cachedPQLink.isEmpty || isStale) {
      await _getPastQuestionLinkFromFirebaseAndStore();
      return prefs.getString('PQLink');
    } else {
      return cachedPQLink;
    }
  }
}

class PDF {
  Future<void> _getPDFLinkFromFirebaseAndStore() async {
    try {
      DocumentSnapshot pdfValue = await FirebaseFirestore.instance
          .collection('Preference')
          .doc('Pdf')
          .get();

      if (pdfValue.exists) {
        var data = pdfValue.data() as Map<String, dynamic>?;
        String? pdfLink = data?['PDFLink'];

        if (pdfLink != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('PDFLink', pdfLink);
          await prefs.setInt('pdf_last_fetch', DateTime.now().millisecondsSinceEpoch);
        }
      }
    } catch (e) {
      // print("Error fetching PDF link: $e");
    }
  }

  Future<String?> checkPDFLink() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedPDFLink = prefs.getString('PDFLink');
    int? lastFetchTime = prefs.getInt('pdf_last_fetch');

    bool isStale = lastFetchTime == null ||
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastFetchTime)).inDays > 30;

    if (cachedPDFLink == null || cachedPDFLink.isEmpty || isStale) {
      await _getPDFLinkFromFirebaseAndStore();
      return prefs.getString('PDFLink');
    } else {
      return cachedPDFLink;
    }
  }
}



// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:encrypt/encrypt.dart' as encrypt;
// import 'dart:convert';

// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// class SecurityHelper {
//   static late encrypt.Key _key;
//   static late encrypt.IV _iv;
//   static late encrypt.Encrypter _encrypter;
//   static final _storage = FlutterSecureStorage();
//   static const _keyKey = 'encryption_key';
//   static const _ivKey = 'encryption_iv';
  
//   static Future<void> initialize() async {
//     // Try to retrieve existing key and IV
//     String? storedKey = await _storage.read(key: _keyKey);
//     String? storedIV = await _storage.read(key: _ivKey);
    
//     if (storedKey == null || storedIV == null) {
//       // Generate new key and IV
//       final key = encrypt.Key.fromSecureRandom(32);
//       final iv = encrypt.IV.fromSecureRandom(16);
      
//       // Store them securely
//       await _storage.write(key: _keyKey, value: base64.encode(key.bytes));
//       await _storage.write(key: _ivKey, value: base64.encode(iv.bytes));
      
//       _key = key;
//       _iv = iv;
//     } else {
//       // Use existing key and IV
//       _key = encrypt.Key(base64.decode(storedKey));
//       _iv = encrypt.IV(base64.decode(storedIV));
//     }
    
//     _encrypter = encrypt.Encrypter(encrypt.AES(_key));
//   }
  
//   static Future<String> encryptData(String text) async {
//     // Ensure initialized
//     final encrypted = _encrypter.encrypt(text, iv: _iv);
//     return encrypted.base64;
//   }
  
//   static Future<String> decryptData(String encryptedText) async {
//     // Ensure initialized
//     final encrypted = encrypt.Encrypted(base64.decode(encryptedText));
//     return _encrypter.decrypt(encrypted, iv: _iv);
//   }
// }

// class Semester {
//   static const String collectionName = 'Preference';
//   static const String documentName = 'F or S';
//   static const String fieldName = 'semester';
//   static const String prefKey = 'semester';
//   static const String lastFetchKey = 'semester_last_fetch';

//   Future<void> _getSemesterValueFromFirebaseAndStore() async {
//     try {
//       DocumentSnapshot snapshot = await FirebaseFirestore.instance
//           .collection(collectionName)
//           .doc(documentName)
//           .get();

//       if (snapshot.exists) {
//         var data = snapshot.data() as Map<String, dynamic>?;
//         String? value = data?[fieldName];

//         if (value != null) {
//           // Encrypt the semester value before storing
//           String encryptedValue = await SecurityHelper.encryptData(value);
          
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           await prefs.setString(prefKey, encryptedValue);
//           await prefs.setInt(lastFetchKey, DateTime.now().millisecondsSinceEpoch);
//         }
//       }
//     } catch (e) {
//       // Consider proper error handling/logging here
//     }
//   }

//   Future<String?> checkSemester() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? encryptedSemester = prefs.getString(prefKey);
//     int? lastFetchTime = prefs.getInt(lastFetchKey);
    
//     // Check if we have a cached value and if it's less than 30 days old
//     bool isStale = lastFetchTime == null || 
//         DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastFetchTime)).inDays > 30;
    
//     if (encryptedSemester == null || encryptedSemester.isEmpty || isStale) {
//       await _getSemesterValueFromFirebaseAndStore();
      
//       // Get the newly stored encrypted value
//       encryptedSemester = prefs.getString(prefKey);
//       if (encryptedSemester == null) return null;
      
//       // Decrypt and return
//       return SecurityHelper.decryptData(encryptedSemester);
//     } else {
//       // Decrypt the cached value
//       return SecurityHelper.decryptData(encryptedSemester);
//     }
//   }
// }

// class PastQuestion {
//   static const String collectionName = 'Preference';
//   static const String documentName = 'PastQuestion';
//   static const String fieldName = 'PQLink';
//   static const String prefKey = 'PQLink';
//   static const String lastFetchKey = 'pq_last_fetch';

//   Future<void> _getPastQuestionLinkFromFirebaseAndStore() async {
//     try {
//       DocumentSnapshot snapshot = await FirebaseFirestore.instance
//           .collection(collectionName)
//           .doc(documentName)
//           .get();

//       if (snapshot.exists) {
//         var data = snapshot.data() as Map<String, dynamic>?;
//         String? link = data?[fieldName];

//         if (link != null) {
//           // Encrypt the link before storing
//           String encryptedLink = await SecurityHelper.encryptData(link);
          
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           await prefs.setString(prefKey, encryptedLink);
//           await prefs.setInt(lastFetchKey, DateTime.now().millisecondsSinceEpoch);
//         }
//       }
//     } catch (e) {
//       // Consider proper error handling here
//     }
//   }

//   Future<String?> checkPastQuestionLink() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? encryptedLink = prefs.getString(prefKey);
//     int? lastFetchTime = prefs.getInt(lastFetchKey);
    
//     // Check if we have a cached value and if it's less than 30 days old
//     bool isStale = lastFetchTime == null || 
//         DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastFetchTime)).inDays > 30;
    
//     if (encryptedLink == null || encryptedLink.isEmpty || isStale) {
//       await _getPastQuestionLinkFromFirebaseAndStore();
      
//       // Get the newly stored encrypted value
//       encryptedLink = prefs.getString(prefKey);
//       if (encryptedLink == null) return null;
      
//       // Decrypt and return
//       return SecurityHelper.decryptData(encryptedLink);
//     } else {
//       // Decrypt the cached value
//       return SecurityHelper.decryptData(encryptedLink);
//     }
//   }
// }

// class PDF {
//   static const String collectionName = 'Preference';
//   static const String documentName = 'Pdf';
//   static const String fieldName = 'PDFLink';
//   static const String prefKey = 'PDFLink';
//   static const String lastFetchKey = 'pdf_last_fetch';

//   Future<void> getPDFLinkFromFirebaseAndStore() async {
//     try {
//       DocumentSnapshot snapshot = await FirebaseFirestore.instance
//           .collection(collectionName)
//           .doc(documentName)
//           .get();

//       if (snapshot.exists) {
//         var data = snapshot.data() as Map<String, dynamic>?;
//         String? link = data?[fieldName];

//         if (link != null) {
//           // Encrypt the link before storing
//           String encryptedLink = await SecurityHelper.encryptData(link);
          
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           await prefs.setString(prefKey, encryptedLink);
//           await prefs.setInt(lastFetchKey, DateTime.now().millisecondsSinceEpoch);
//         }
//       }
//     } catch (e) {
//       // Consider proper error handling here
//     }
//   }

//   Future<String?> checkPDFLink() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? encryptedLink = prefs.getString(prefKey);
//     int? lastFetchTime = prefs.getInt(lastFetchKey);
    
//     // Check if we have a cached value and if it's less than 30 days old
//     bool isStale = lastFetchTime == null || 
//         DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastFetchTime)).inDays > 30;
    
//     if (encryptedLink == null || encryptedLink.isEmpty || isStale) {
//       await getPDFLinkFromFirebaseAndStore();
      
//       // Get the newly stored encrypted value
//       encryptedLink = prefs.getString(prefKey);
//       if (encryptedLink == null) return null;
      
//       // Decrypt and return
//       return SecurityHelper.decryptData(encryptedLink);
//     } else {
//       // Decrypt the cached value
//       return SecurityHelper.decryptData(encryptedLink);
//     }
//   }
// }