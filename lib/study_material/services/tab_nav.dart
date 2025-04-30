import 'package:flutter/material.dart';
import 'package:futapedia/study_material/pdf/pdf_explorer.dart';

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
}