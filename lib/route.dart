import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:futapedia/home/home.dart';
import 'package:futapedia/home/second_semester.dart';
import 'package:futapedia/main.dart';
import 'package:futapedia/notification/scheduler_page.dart';
// import 'package:futapedia/schedule_reminder.dart';
// import 'package:futapedia/pdfs/all_download.dart';
// import 'package:futapedia/pdfs/services/local_file_screen.dart';
import 'package:futapedia/settings/theme.dart';
import 'package:futapedia/study_material/past%20questions/question_explorer.dart';
import 'package:futapedia/study_material/pdf/pdf_explorer.dart';
import 'package:futapedia/study_material/services/encrypted_pdfviewer.dart';
// import 'package:futapedia/study_material/services/notf_pref.dart';
import 'package:futapedia/templates/course_details.dart';
import 'package:futapedia/templates/youtube_player.dart';
import 'package:futapedia/test.dart/subject_selection.dart';
// import 'package:futapedia/test_notification.dart';
import 'package:routemaster/routemaster.dart';
import 'package:futapedia/login%20pages/json_load.dart';
import 'package:futapedia/login%20pages/login.dart';




RouteMap getAppRoutes() {
  return RouteMap(
    onUnknownRoute: (path) => Redirect('/home'),
    routes: {
      '/': (_) => MaterialPage(child: UpdateCheckerWrapper(child:MainScreen())),

      '/login': (_) => MaterialPage(child: StudentLoginPage()),

      '/google_drive':(_) => MaterialPage(child:GoogleDriveManagerScreen()),

      '/google_past_questions':(_) => MaterialPage(child: PastQuestionGoogleDriveManager()),


      '/encryptedpdfviewer': (route) => MaterialPage(
        child: EncryptedFileViewer(
          fileName: FileViewerState.fileName,
          fileData: FileViewerState.fileData!,
        ),
      ),


      '/encryptedpqpdfviewer': (route) => MaterialPage(
        child: EncryptedFileViewer(
          fileName: PQFileViewerState.fileName,
          fileData: PQFileViewerState.fileData!,
        ),
      ),


      '/home': (route) {
        final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            return const Redirect('/');
          }
          return MaterialPage(child: NavigateScreen(child:SecondSemester()));
      },
 
      '/theme':(_) => const MaterialPage(child: ThemeSelector()),

      // '/downloads': (_) => const MaterialPage(child: LocalFilesScreen()),

      // '/all_downloads':(_) => const MaterialPage(child: StudentDownloadsView()),

      '/notifications': (_) => const MaterialPage(child: SchedulerPage()),
      

      '/course_details/:courseName': (route) {
        return MaterialPage(
          child: CourseDetailsPage(
            courseName: route.pathParameters['courseName']!,
          ),
        );
      },

      '/video_player': (route) {
        final url = route.queryParameters['url'];
        return MaterialPage(
          child: YouTubePlayerWidget(youtubeLink: url ?? ''),
        );
      },
      

      '/test':(route) {
        final url = route.queryParameters['url'];
        return MaterialPage(
          child: SubjectSelectionPage(
            level: url ?? ''
          ),
        ) ;
      },
    },
  );
}
