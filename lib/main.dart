import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info/device_info.dart';
import 'package:upgrader/upgrader.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/services.dart' show PlatformException;

const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    'This channel is used for important notifications.', // description
    importance: Importance.high,
    playSound: true);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin1 =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('A bg message just showed up :  ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // static Future<String> get _url async {
  //   await Future.delayed(const Duration(seconds: 1));
  //   return 'https://flutter.dev/';
  // }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Synigence',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Synigence'),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late String initiateUrl;
  WebViewController? _controller;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  bool isLoading=true;
  final _key = UniqueKey();

  // Future<void> _initPackageInfo() async {
  //   final PackageInfo info = await PackageInfo.fromPlatform();
  //   print("Appname" +info.buildNumber);
  // }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _firebaseMessaging.requestPermission();

    Future<String> _getId() async {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        IosDeviceInfo iosDeviceInfo = await deviceInfo.iosInfo;
        return iosDeviceInfo.identifierForVendor; // unique ID on iOS
      } else {
        AndroidDeviceInfo androidDeviceInfo = await deviceInfo.androidInfo;
        return androidDeviceInfo.androidId; // unique ID on Android
      }
    }

    Future<bool> initUniLinks(String token) async {
      // Platform messages may fail, so we use a try/catch PlatformException.
      try {
        final initialLink = await getInitialLink();
        if (initialLink == null) {
          setState(() {
            initiateUrl =
                'https://screens.wipoc.synigence.co/wi-pages/index.php?_dtoken=' +
                    token;
          });
          print("Initial url ----> " + initiateUrl.toString());
        } else {
          setState(() {
            initiateUrl = initialLink.toString() + '?_dtoken=' + token;
          });
          print("Initial url ----> " + initiateUrl.toString());
        }

        // Parse the link and warn the user, if it is not correct,
        // but keep in mind it could be `null`.
      } on PlatformException {
        // Handle exception by warning the user their action did not succeed
        // return?
      }
      return true;
    }

    _firebaseMessaging.getToken().then((token) async {
      assert(token != null);
      print("Firebase msg token: " + token!);
      _getId().then((id) async {
        await FirebaseFirestore.instance
            .collection("device_id")
            .doc(id)
            .set({'token': token});
      });
      initUniLinks(token);
    });

    // _initPackageInfo();

    // PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
    //   String appName = packageInfo.appName;
    //   String packageName = packageInfo.packageName;
    //   String version = packageInfo.version;
    //   String buildNumber = packageInfo.buildNumber;
    // });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channel.description,
                color: Colors.blue,
                playSound: true,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: const IOSNotificationDetails(
                presentBadge: true,
                presentAlert: true,
                presentSound: true,
              )
            ));
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        // showDialog(
        //     context: context,
        //     builder: (_) {
        //       return AlertDialog(
        //         title: Text('notification.title'),
        //         content: SingleChildScrollView(
        //           child: Column(
        //             crossAxisAlignment: CrossAxisAlignment.start,
        //             children: [Text('notification.body')],
        //           ),
        //         ),
        //       );
        //     });
      }
    });
  }

  // void showNotification() {
  //     print('Got it');
  //   flutterLocalNotificationsPlugin.show(
  //       0,
  //       "Testing",
  //       "How you doin ?",
  //       NotificationDetails(
  //           android: AndroidNotificationDetails(channel.id, channel.name, channel.description,
  //               importance: Importance.high,
  //               color: Colors.blue,
  //               playSound: true,
  //               icon: '@mipmap/ic_launcher')));
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: UpgradeAlert(
            child: Stack(
              children: [
              WebView(
              key: _key,
              initialUrl: initiateUrl,
              javascriptMode: JavascriptMode.unrestricted,
              onWebViewCreated:
                  (WebViewController webViewController) async {
                _controller = webViewController;
                // await _controller!.loadUrl(initiateUrl);
              },
              onPageFinished: (finish) {
                setState(() {
                  isLoading = false;
                });
              },
            ),
            isLoading ? Center( child: CircularProgressIndicator(),)
        : Stack()
              ],
            )));
  }
}
