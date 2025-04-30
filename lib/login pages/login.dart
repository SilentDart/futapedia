import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
            width: 500.w,
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(40.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50.r),
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
                  SizedBox(height: 20.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50.r), 
                    child: Image.asset('images/futapedia.jpg', width: 200.r,),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Welcome to FUTApedia',
                    style: TextStyle(fontSize: 25.sp, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 40.h),
                  
                  
                  SizedBox(
                    height: 45.h,
                    child: ElevatedButton(
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
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          //Image.asset('images/google_logo.jpg', height: 20),
                          Icon(Icons.person_4_rounded, size: 23.sp, color: Colors.black),
                          SizedBox(width: 15.w),
                          Text(
                            'Sign in Anonymous',
                            style: TextStyle(color: Colors.black, fontSize: 18.sp),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 15.h),


                  SizedBox(
                    height: 45.h,
                    child: ElevatedButton(
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
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('images/google_logo.jpg', height: 20.h),
                          SizedBox(width: 15.w),
                          Text(
                            'Sign in with Google',
                            style: TextStyle(color: Colors.black, fontSize: 18.sp),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
