import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:futapedia/firebase_services.dart/auth.dart';
import 'package:futapedia/login%20pages/loading.dart';
import 'package:routemaster/routemaster.dart';

class StudentLoginPage extends StatefulWidget {
  const StudentLoginPage({super.key});

  @override
  _StudentLoginPageState createState() => _StudentLoginPageState();
}
 
class _StudentLoginPageState extends State<StudentLoginPage> {
  
  bool login = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  AuthServices authservice = AuthServices();


  Future<void> handleAnonymousLogin(BuildContext context) async {
    final navigatorContext = context;

    try {
      final anonhandle = await authservice.signInAnon(context);
      
      if (anonhandle?.user != null) {
        // print("Anonymous data: $anonhandle");
        
        // Navigate to home after successful login
        if(!navigatorContext.mounted) return;
        Routemaster.of(context).replace('/home');

      } else {
        // print("Anonymous login failed.");
        setState(() {
          login = false;
        });
      }
    } catch (e) {
      // print("Error during anonymous login: $e");
    }
  }

  Future<UserCredential?> _handleGoogleSignIn(BuildContext context) async{
    
    final navigatorContext = context;

    try{
      final googlehandle = await authservice.signInWithGoogle(context);

      if (googlehandle?.user != null){

        if(navigatorContext.mounted){

          Routemaster.of(context).replace('/home');

        }

      }else{
        setState(() {
          login = false;
        });
      }

    }catch(e){
        //print('Error during login: $e');
    }
    return null;
  }




  @override
  Widget build(BuildContext context) {
    return login? Loading() : Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[100]!, Colors.purple[200]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(25), 
                    child: Image.asset('images/futapedia.jpg', scale: 5),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Welcome to FUTApedia',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 40),
                  
                  
                  ElevatedButton(
                    onPressed:() {
                      setState(() {
                        login = true;
                      });
                      handleAnonymousLogin(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        //Image.asset('images/google_logo.jpg', height: 20),
                        Icon(Icons.person_4_rounded, size: 23, color: Colors.black),
                        SizedBox(width: 10),
                        Text(
                          'Sign in Anonymous',
                          style: TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10),


                  ElevatedButton(
                    onPressed:() {
                      setState(() {
                        login = true;
                      });
                      _handleGoogleSignIn(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('images/google_logo.jpg', height: 20),
                        SizedBox(width: 10),
                        Text(
                          'Sign in with Google',
                          style: TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
