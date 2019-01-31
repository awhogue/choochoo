// Manage sending notifications to the user when a watched train is updated.

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'model.dart';

class ChooChooNotifications {
  FlutterLocalNotificationsPlugin notifier = new FlutterLocalNotificationsPlugin();
  BuildContext context;

  ChooChooNotifications(this.context) {
    // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    var androidInit = new AndroidInitializationSettings('notification_icon');
    var iosInit = new IOSInitializationSettings();
    var initSettings = new InitializationSettings(androidInit, iosInit);
    notifier.initialize(initSettings, onSelectNotification: onSelectNotification);
  }

  Future onSelectNotification(String payload) async {
    if (payload != null) {
      print('notification payload: ' + payload);
    }
    // await Navigator.push(
    //   context,
    //   new MaterialPageRoute(builder: (context) => new SecondScreen(payload)),
    // );
  }

  Future _showNotification(String title, String body, String payload) async {
    print('Showing notification:\n\t$title\n\t$body');
    var androidDetails = new AndroidNotificationDetails(
      'train-status-updates', 'Train Status Updates', 'Updates on your trains',
      importance: Importance.Max, priority: Priority.Max);
    var iosDetails = new IOSNotificationDetails();
    var notificationDetails = new NotificationDetails(androidDetails, iosDetails);
    await notifier.show(0, title, body, notificationDetails, payload: payload);
  }

  void trainStatusNotification(TrainStatus status) {
    var statusStrs = status.statusForDisplay();
    switch (status.state) {
      case TrainState.Late: {
        _showNotification(
          'Train #${status.stop.train.trainNo} is late!',
          'Train #${status.stop.train.trainNo} from ${status.stop.departureStation.stationName} ' +
          'is ${statusStrs[1]}. Scheduled at ${status.stop.scheduledDepartureTime}. ${statusStrs[0]}.',
          status.stop.id());
        break;
      }
      default: {
        _showNotification(
          'Train #${status.stop.train.trainNo}: ${statusStrs[0]}', 
          statusStrs[1], status.stop.id());
      }
    }
    

  }
}