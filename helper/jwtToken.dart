import 'package:shared_preferences/shared_preferences.dart';

class jwtToken {
  Future<String> getJwt() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    var jwt = await pref.getString("token");
    if(jwt == null) {
      return "";
    }else{
      return jwt;
    }
  }
}