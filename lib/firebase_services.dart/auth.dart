import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:futapedia/login%20pages/login.dart';
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:routemaster/routemaster.dart';
import 'package:futapedia/firebase_services.dart/user.dart';



class AuthServices  {
  final FirebaseAuth firebaseInstance = FirebaseAuth.instance;
  
  //Uid Function
  Userdetails? useridgetter(userid){
    // Userdetails usernow = Userdetails(uid: uid);
    return userid != null ? Userdetails(uid: userid.uid) : null;
  }
  //Stream
  Stream<Userdetails?> get userstream{
    return firebaseInstance.authStateChanges()
    .map<Userdetails?> (useridgetter);
  }

  //Sign in anonymously
  Future signInAnon(BuildContext context) async {
    try{
      UserCredential anonUser = await firebaseInstance.signInAnonymously();
      if(anonUser.user != null){
      // print(anonUser);
      User? result = anonUser.user;
      return useridgetter(result);
      }else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Connection timeout. Try again"))
        );
        return null;
      }
    }
    catch(e){
      print("Anonymous sign-in error: $e");
      return null;//rethrow;
    }
  }


  //Sign in with google
  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
  // Store the context reference safely at the beginning
    final navigatorContext = context;
    
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // print("Google Sign-In was canceled by user");
        return null;
      }
      
      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Sign in with Firebase
      final UserCredential userCredential = await firebaseInstance.signInWithCredential(credential);
      
      return userCredential;
      // Check if the context is still valid before navigating
      // if (navigatorContext.mounted) {
      //   Routemaster.of(navigatorContext).replace('/');
      // }
      
      // return userCredential;
    } catch (error) {
      // print("Google Sign-In Error Details:");
      // print("Error: $error");
      // print("Stack trace: $stackTrace");
      
      // Only show the snackbar if the context is still valid
      if (navigatorContext.mounted) {
        ScaffoldMessenger.of(navigatorContext).showSnackBar(
          SnackBar(content: Text("Google Sign-In failed. Please try again."))
        );
      }
      
      return null;
    }
  }
}


// Inside a method or button press handler:
Future<void> signOut() async {
  try {
    await FirebaseAuth.instance.signOut();
    StudentLoginPage();
    // Handle successful logout, like navigating to login screen
  } catch (e){}
}