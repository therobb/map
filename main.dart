import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helper/jwtToken.dart';
import 'pages/home.dart';
import 'pages/login.dart';

const SERVER_IP = 'https://actionzpr.actsumbagteng.com/api';

void main() {
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  Future<String> get jwtOrEmpty async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    var jwt = await pref.getString("token");
    if(jwt == null) return "";
    return jwt;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Authentication Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder(
          future: jwtOrEmpty,
          builder: (context, snapshot) {
            if(!snapshot.hasData) return LoginPage(); //return CircularProgressIndicator();
            if(snapshot.data != "") {
                  return LiveLocationPage();
            } else {
              return LoginPage();
            }
          }
      ),
    );
  }
}

