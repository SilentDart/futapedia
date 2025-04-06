// import 'package:futapedia/firebase_services.dart/auth.dart';
// import 'package:futapedia/login%20pages/login.dart';
// import 'package:flutter/material.dart';
// // import 'package:futapedia/model/user.dart';

// class RegistrationPortal extends StatefulWidget {
//   @override
//   _RegistrationPortalState createState() => _RegistrationPortalState();
// }

// class _RegistrationPortalState extends State<RegistrationPortal> {
//   // Form key for validation
//   final _formKey = GlobalKey<FormState>();

//   // Controllers for the registration form
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController usernameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   String error = "";


//   // Department selection
//   String? selectedDepartment;

//   // List of departments (modify as necessary)
//   final List<String> departments = [
//     'Computer Science',
//     'Electrical Engineering',
//     'Mechanical Engineering',
//     'Civil Engineering',
//     'Information Technology',
//     'Cyber Security',
//     'Industrial Engineering',
//     'Chemical Engineering',
//     'Aerospace Engineering',
//     'Biomedical Engineering',
//     'Environmental Engineering',
//     'Data Science',
//   ];

//   // State for password visibility
//   bool isPasswordVisible = false;

//   // Registration handler
//   void handleRegistration() {
//     if (_formKey.currentState!.validate()) {
//       // final name = nameController.text.trim();
//       // final username = usernameController.text.trim();
//       final email = emailController.text.trim();
//       final password = passwordController.text.trim();

//       AuthServices authCall = AuthServices();

//       dynamic result = authCall.registerWithEmail(email: email, password: password);


//       if(result == null){
//         print("There's a problem with with registration process");
//         setState(() {
//           error = "An error has occured, please check your internet connection and try again";
//         });
//       }  else{
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Registration Successful!')),
//         );
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Colors.blue[100]!, Colors.purple[200]!],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//         child: Center(
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.9,
//             constraints: BoxConstraints(maxWidth: 400),
//             padding: EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black12,
//                   blurRadius: 10,
//                   offset: Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: Form(
//               key: _formKey,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Header
//                   Text(
//                     'Registration Portal',
//                     style: TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blue[700],
//                     ),
//                   ),
//                   SizedBox(height: 10),
//                   Text(
//                     'You are on your way to academic success!',
//                     style: TextStyle(color: Colors.grey),
//                   ),
//                   SizedBox(height: 20),

//                   // Registration Form
//                   buildRegistrationForm(),

//                   SizedBox(height: 20),

//                   // Register Button
//                   ElevatedButton(
//                     onPressed: handleRegistration,
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(20),
//                       ),
//                       backgroundColor: Colors.blue, // Background color
//                     ),
//                     child: Text(
//                       'Register',
//                       style: TextStyle(fontWeight: FontWeight.bold),
//                     ),
//                   ),

//                   // "Already have an account? Sign in" Button
//                   SizedBox(height: 20),
//                   TextButton(
//                     onPressed: () {
//                       // Navigate to the login page
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (context) => StudentLoginPage()),
//                       );
//                     },
//                     child: Text(
//                       'Already have an account? Sign in',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: Colors.blue[700],
//                       ),
//                     ),
//                   ),
//                   Text(
//                     error
//                   )
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // Registration Form Widget
//   Widget buildRegistrationForm() {
//     return Column(
//       children: [
//         // Name Field
//         TextFormField(
//           controller: nameController,
//           decoration: InputDecoration(
//             labelText: 'Name',
//             prefixIcon: Icon(Icons.person),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           validator: (value) {
//             if (value == null || value.isEmpty) {
//               return 'Please enter your name';
//             }
//             return null;
//           },
//         ),
//         SizedBox(height: 15),

//         // Username Field
//         TextFormField(
//           controller: usernameController,
//           decoration: InputDecoration(
//             labelText: 'Username',
//             prefixIcon: Icon(Icons.account_circle),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           validator: (value) {
//             if (value == null || value.isEmpty) {
//               return 'Please enter a username';
//             }
//             return null;
//           },
//         ),
//         SizedBox(height: 15),

//         // Email Field
//         TextFormField(
//           controller: emailController,
//           decoration: InputDecoration(
//             labelText: 'Email',
//             prefixIcon: Icon(Icons.email),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//           validator: (value) {
//             if (value == null || value.isEmpty) {
//               return 'Please enter your email';
//             }
//             if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
//                 .hasMatch(value)) {
//               return 'Please enter a valid email address';
//             }
//             return null;
//           },
//         ),
//         SizedBox(height: 15),

//         // Password Field
//         TextFormField(
//           controller: passwordController,
//           obscureText: !isPasswordVisible,
//           decoration: InputDecoration(
//             labelText: 'Password',
//             prefixIcon: Icon(Icons.lock),
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//             suffixIcon: IconButton(
//               icon: Icon(
//                 isPasswordVisible
//                     ? Icons.visibility
//                     : Icons.visibility_off,
//               ),
//               onPressed: () {
//                 setState(() {
//                   isPasswordVisible = !isPasswordVisible;
//                 });
//               },
//             ),
//           ),
//           validator: (value) {
//             if (value == null || value.isEmpty) {
//               return 'Please enter a password';
//             }
//             if (value.length < 6) {
//               return 'Password must be at least 6 characters long';
//             }
//             return null;
//           },
//         ),
//         SizedBox(height: 15),

//         // Department Dropdown Field
//         SingleChildScrollView(
//           scrollDirection: Axis.vertical,
//           child: DropdownButtonFormField<String>(
//             value: selectedDepartment,
//             decoration: InputDecoration(
//               labelText: 'Department',
//               prefixIcon: Icon(Icons.business),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//             items: departments.map((department) {
//               return DropdownMenuItem<String>(
//                 value: department,
//                 child: Text(department),
//               );
//             }).toList(),
//             onChanged: (value) {
//               setState(() {
//                 selectedDepartment = value;
//               });
//             },
//             validator: (value) {
//               if (value == null) {
//                 return 'Please select a department';
//               }
//               return null;
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }
