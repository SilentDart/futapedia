
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:futapedia/main.dart';

class NotificationController {
  /// Use this method to detect when the user taps on a notification
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // Navigate to scheduler page when notification is tapped
    if (receivedAction.channelKey == 'scheduled_channel') {
      // For navigation, you'll need to use a navigation key from your main app
      navigatorKey.currentState?.pushNamed('/scheduler');
    }
  }
}