import 'package:http/http.dart' as http;
import 'dart:convert' show json;

import 'jwtToken.dart';
const SERVER_IP = 'https://actionzpr.actsumbagteng.com/api';
class getApi{

  Future<dynamic> postOutlet(String idOutlet) async {
    var res = await http.post(
        Uri.parse("$SERVER_IP/getOutlet.php"),
        headers: {
          "Authorization": jwtToken().getJwt().toString()
        },
        body: {
          'id_outlet' : idOutlet
        }
    );
    if(res.statusCode == 200) {
      var responseJson = json.decode(res.body);
      if(responseJson['data'] != 'not found'){
        return responseJson;
      }else{
        return 404;
      }
    }
    return 404;
  }
}