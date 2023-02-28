import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'dart:convert' show json;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart' as permissionLocation;
import 'package:image_picker/image_picker.dart';


import 'login.dart';

//import 'package:actionz/helper/api.dart';

import 'package:actionz/helper/jwtToken.dart';

const SERVER_IP = 'https://actionzpr.actsumbagteng.com/api';

class LiveLocationPage extends StatefulWidget {

  const LiveLocationPage({Key? key}) : super(key: key);

  @override
  _LiveLocationPageState createState() => _LiveLocationPageState();
}

class _LiveLocationPageState extends State<LiveLocationPage> {
  LocationData? _currentLocation;
  late final MapController _mapController;
  final TextEditingController _searchController = TextEditingController();

  bool _liveUpdate = false;


  String? _serviceError = '';

  int interActiveFlags = InteractiveFlag.all;

  final Location _locationService = Location();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    initLocationService();
  }

  void initLocationService() async {
    await _locationService.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
    );

    LocationData? location;
    bool serviceEnabled;
    bool serviceRequestResult;

      serviceEnabled = await _locationService.serviceEnabled();

      var permissionSatus = await permissionLocation.Permission.location.status;
      if (serviceEnabled) {
        if(permissionSatus == PermissionStatus.denied){
          await permissionLocation.openAppSettings();
        }
        final permission = await permissionLocation.Permission.locationWhenInUse.request();
        print(permissionSatus);
        if (permission == permissionLocation.PermissionStatus.granted) {
          location = await _locationService.getLocation();
          _currentLocation = location;
          _locationService.onLocationChanged
              .listen((LocationData result) async {
            if (mounted) {
              setState(() {
                _currentLocation = result;

                // If Live Update is enabled, move map center
                if (_liveUpdate) {
                  _mapController.move(
                      LatLng(_currentLocation!.latitude!,
                          _currentLocation!.longitude!),
                      _mapController.zoom);
                }
              });
            }
          });
        }else if (permission == permissionLocation.PermissionStatus.denied) {
          _serviceError = 'Permission denied';
        }else if(permission == permissionLocation.PermissionStatus.permanentlyDenied){
          _serviceError = 'Permission Permanently Denied';
          await permissionLocation.openAppSettings();
        }
      } else {
        serviceRequestResult = await _locationService.requestService();
        if (serviceRequestResult) {
          initLocationService();
          return;
        }
      }

  }

  @override
  Widget build(BuildContext context) {
    LatLng currentLatLng;

    // Until currentLocation is initially updated, Widget can locate to 0, 0
    // by default or store previous location value to show.
    if (_currentLocation != null) {
      currentLatLng =
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
    } else {
      currentLatLng = LatLng(0.293347, 101.706825);
    }

    final markers = <Marker>[
      Marker(
        width: 80,
        height: 80,
        point: currentLatLng,
        builder: (ctx) => const FlutterLogo(
          textColor: Colors.blue,
          key: ObjectKey(Colors.blue),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Stack(
          children: [
            Container(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center:
                  LatLng(currentLatLng.latitude, currentLatLng.longitude),
                  zoom: 20,
                  interactiveFlags: interActiveFlags,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.fleaflet.flutter_map.example',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
            Positioned(
                top: 10,
                right: 15,
                left: 15,
              child: Container(

                child: Row(
                  children: [
                      IconButton(
                        splashColor: Colors.grey,
                        icon: Icon(Icons.menu),
                        onPressed: () {},
                      ),
                    Expanded(
                        child: _serviceError!.isEmpty
                            ? TextFormField(
                            controller: _searchController,
                            maxLines: 1,
                            decoration: InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                contentPadding: const EdgeInsets.all(16),
                                filled: true,
                                hintStyle: TextStyle(color: Colors.grey[800]),
                                hintText: "Cari id outlet",
                                fillColor: Colors.white70
                            ),
                            onFieldSubmitted: (value) async {
                              print(value);
                              await postOutlet(value);
                            }
                        )
                            : Text(
                            'Error occured while acquiring location. Error Message : '
                                '$_serviceError')
                    ),
                  ]
                ),
              )
            ),
          ],
      ),
      floatingActionButton: Builder(builder: (BuildContext context) {
        return FloatingActionButton(
          onPressed: () {
            setState(() {
              _liveUpdate = !_liveUpdate;

              if (_liveUpdate) {
                interActiveFlags = InteractiveFlag.rotate |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom;

                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'In live update mode only zoom and rotation are enable'),
                ));
              } else {
                interActiveFlags = InteractiveFlag.all;
              }
            });
          },
          child: _liveUpdate
              ? const Icon(Icons.location_on)
              : const Icon(Icons.location_off),
        );
      }),
    );
  }
  Future<dynamic> postOutlet(String idOutlet) async {
    var token = await jwtToken().getJwt();
    var res = await http.post(
        Uri.parse("$SERVER_IP/getOutlet.php"),
        headers: {
          "Authorization": token.toString()
        },
        body: {
          'id_outlet' : idOutlet
        }
    );
    if(res.statusCode == 200) {
      var responseJson = json.decode(res.body);
      if(responseJson['data'] != 'not found'){
        setState(() {
          _liveUpdate = !_liveUpdate;
          if (!_liveUpdate) {
            interActiveFlags = InteractiveFlag.all;
          }
        });
        return showModalBottomSheet(
          context: context,
          isScrollControlled: true, // set this to true
          builder: (_) {
            return DraggableScrollableSheet(
              expand: false,
              builder: (BuildContext context, ScrollController scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: CustomScrollViewContent(responseJson['data']),
                );              },
            );
          },
        );
      }else{
        return ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'ID Outlet tidak ditemukan'),
        ));
      }
    }else if(res.statusCode == 401){
      @override
      void run() {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
      }
      run();
    }else{
      return res.statusCode;
    }
  }
}

class CustomScrollViewContent extends StatelessWidget {
  CustomScrollViewContent(this.outletDetail);

  final dynamic outletDetail;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 12.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: const EdgeInsets.all(0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
        ),
        child: CustomInnerContent(outletDetail),
      ),
    );
  }
}

class CustomInnerContent extends StatelessWidget {
  CustomInnerContent(this.outletDetail);

  final dynamic outletDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(height: 12),
        CustomDraggingHandle(outletDetail),
        SizedBox(height: 16),
        Title(),
        SizedBox(height: 16),
        CustomHorizontallyScrolling(outletDetail),
        SizedBox(height: 24),
        CustomFeaturedListsText(outletDetail),
        SizedBox(height: 16),
        CustomFeaturedItemsGrid(outletDetail),
        SizedBox(height: 24),
        CustomRecentPhotosText(outletDetail),
        SizedBox(height: 16),
        CustomRecentPhotoLarge(),
        SizedBox(height: 12),
        CustomRecentPhotosSmall(outletDetail),
        SizedBox(height: 16),
      ],
    );
  }
}

class CustomDraggingHandle extends StatelessWidget {
  CustomDraggingHandle(this.outletDetail);

  final dynamic outletDetail;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      width: 30,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
    );
  }
}

class Title extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text('Outlet Profile', style: TextStyle(fontSize: 22, color: Colors.black45)),
        SizedBox(width: 8),
        Container(
          height: 24,
          width: 24,
          child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.black54),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
        ),
      ],
    );
  }
}

class CustomHorizontallyScrolling extends StatelessWidget {
  CustomHorizontallyScrolling(this.outletDetail);

  final dynamic outletDetail;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Recent Photo', style: TextStyle(fontSize: 22, color: Colors.black45)),
            SizedBox(width: 8),
            CustomPhoto(),
            SizedBox(width: 12),
            CustomPhoto(),
            SizedBox(width: 12),
            CustomPhoto(),
            SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class CustomFeaturedListsText extends StatelessWidget {
  CustomFeaturedListsText(this.outletDetail);

  final dynamic outletDetail;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      //only to left align the text
      child: Row(
        children: <Widget>[Text("Featured Lists", style: TextStyle(fontSize: 14))],
      ),
    );
  }
}

class CustomFeaturedItemsGrid extends StatelessWidget {
  CustomFeaturedItemsGrid(this.outletDetail);

  final dynamic outletDetail;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        //to avoid scrolling conflict with the dragging sheet
        physics: NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(0),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        shrinkWrap: true,
        children: <Widget>[
          CustomFeaturedItem(),
          CustomFeaturedItem(),
          CustomFeaturedItem(),
          CustomFeaturedItem(),
        ],
      ),
    );
  }
}

class CustomRecentPhotosText extends StatelessWidget {
  CustomRecentPhotosText(this.outletDetail);

  final dynamic outletDetail;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: <Widget>[
          Text("Recent Photos", style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class CustomRecentPhotoLarge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomFeaturedItem(),
    );
  }
}

class CustomRecentPhotosSmall extends StatelessWidget {
  CustomRecentPhotosSmall(this.outletDetail);

  final dynamic outletDetail;
  @override
  Widget build(BuildContext context) {
    return CustomFeaturedItemsGrid(outletDetail);
  }
}

class CustomPhoto extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: 100,
      decoration: BoxDecoration(
        color: Colors.grey[500],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class CustomFeaturedItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[500],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

