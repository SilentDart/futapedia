import 'package:flutter/material.dart';
import 'package:futapedia/study_material/pdf/pdf_explorer.dart';
// import 'package:futapedia/study_material/services/directoryInfo.dart';


class NavigationProvider extends ChangeNotifier {
  int activeTab = 0;
  String currentPath = '';
  List<DirectoryInfo> breadcrumbs = [];
  
  void setTabAndPath(int tab, String path, List<DirectoryInfo> crumbs) {
    activeTab = tab;
    currentPath = path;
    breadcrumbs = List.from(crumbs);
    notifyListeners();
  }
  
  // Helper method to restore state
  void resetState() {
    activeTab = 0;
    currentPath = '';
    breadcrumbs = [];
    notifyListeners();
  }
}
