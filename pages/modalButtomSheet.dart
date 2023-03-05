import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:actionz/pages/CustomAlertDialog.dart';
import 'package:actionz/helper/jwtToken.dart';
import 'package:location/location.dart';
import 'package:intl/intl.dart';

const SERVER_IP = 'https://actionzpr.actsumbagteng.com/api';

class modalBottomSheet {
  static void show(BuildContext context, Map<String, dynamic>? responseJson) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) {
          return DraggableScrollableSheet(
            expand: false,
            builder: (BuildContext context, ScrollController scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: CustomScrollViewContent(responseJson),
              );
            },
          );
        },
      );
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
    final Map<String, dynamic> visit = {
      'visit' : outletDetail['data']['visit']??"",
      'id_outlet' : outletDetail['data']['profile']['id_outlet']
    };
    return Column(
      children: <Widget>[
        SizedBox(height: 12),
        CustomDraggingHandle(),
        SizedBox(height: 16),
        Title(),
        SizedBox(height: 16),
        CustomFeaturedListsText('Recent Photo'),
        SizedBox(height: 12),
        CustomHorizontallyScrolling(visit),
        SizedBox(height: 24),
        CustomFeaturedListsText('Overview'),
        SizedBox(height: 16),
        overviewItemsGrid(outletDetail),
        SizedBox(height: 24),
        performanceText(outletDetail),
        SizedBox(height: 16),
        Flexible(
          child: PerformanceItem(outletDetail['data']['performance']),
        ),
        SizedBox(height: 12),
      ],
    );
  }
}

class CustomDraggingHandle extends StatelessWidget {
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
            SizedBox(width: 8),
            CustomPhoto(titles: 'Arrival', outletDetail: outletDetail),
            SizedBox(width: 12),
            CustomPhoto(titles: 'Storefront', outletDetail: outletDetail),
            SizedBox(width: 12),
            CustomPhoto(titles: 'Owner', outletDetail: outletDetail),
            SizedBox(width: 12),
            CustomPhoto(titles: 'Departed', outletDetail: outletDetail),
            SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class CustomPhoto extends StatefulWidget {

  final String titles;
  final dynamic outletDetail;
  const CustomPhoto({Key? key, required this.titles,required this.outletDetail}) : super(key: key);
  @override
  _CustomPhotoState createState() => _CustomPhotoState(titles);
}

class _CustomPhotoState extends State<CustomPhoto> {
  File? _image;
  bool _isUploading = false;
  String titles;
  _CustomPhotoState(this.titles);
  final Location _locationService = Location();
  Future<void> _takePicture() async {
    // Check if camera permission is granted
    final token = await jwtToken().getJwt();
    final user = await jwtToken().getUser();
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final headers = {'Authorization': token};
    LocationData? location = await _locationService.getLocation();
    final body = {
      'id_outlet': widget.outletDetail?['id_outlet'],
      'username': user,
      'longitude': location.longitude!.toDouble(),
      'latitude': location.latitude!.toDouble(),
      'titles': titles,
      'datetime': formattedDate,
    };
    final status = await Permission.camera.request();
    if (status.isGranted) {
      // Launch the camera
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxHeight: 600,
        maxWidth: 800,
      );
      if (image != null) {
        setState(() {
          _image = File(image.path);
          _isUploading = true;
        });
        // Create a multipart request
        final request = http.MultipartRequest(
          'POST',
          Uri.parse("$SERVER_IP/visit.php"),
        );

        body.forEach((key, value) {
          request.fields[key] = value.toString();
        });
        // Add the image to the request
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          _image!.path,
        ));
        request.headers.addAll(headers);

        // Send the request to the server
        final response = await request.send();
        if (response.statusCode == 200) {

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Container(
                child: Text('Photo upload successful'),
              ),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return CustomAlertDialog(
                title: "Error from server",
                content: "Failed to upload photos, please try again.",
              );
            },
          );
        }
        setState(() {
          _isUploading = false;
        });
      }
    } else if (status.isDenied) {
      // Show a popup with an "OK" button to notify the user that they need to enable the camera permission
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return CustomAlertOpenApp(
            title: "Camera Permission Required",
            content: "Please enable camera permission in the app settings.",
          );
        },
      );
    } else if (status.isPermanentlyDenied) {
      // Show a popup with an "OK" button to notify the user that they need to enable the camera permission and redirect them to the app settings page
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return CustomAlertOpenApp(
            title: "Camera Permission Required",
            content: "Please enable camera permission in the app settings.",
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String cols_titles = 'img_$titles';
    final dynamic img_name = widget.outletDetail['visit']?.isNotEmpty == true ? widget.outletDetail['visit'][cols_titles.toString().toLowerCase()] ?? "" : "";
    final String links = '$SERVER_IP/images/visit/$img_name.jpg';
    return GestureDetector(
      onTap: _takePicture,
      child: Container(
        height: 170,
        width: 170,
        decoration: BoxDecoration(
          color: Colors.grey[500],
          borderRadius: BorderRadius.circular(8),
          image: _image != null ? DecorationImage(
            image: FileImage(_image!),
            fit: BoxFit.cover,
          ) : img_name != "" ? DecorationImage(
            image: NetworkImage(links),
            fit: BoxFit.cover,
          ) : null,
        ),
        child: Stack(
          children: [
            _image == null
                ? Icon(
              Icons.camera_alt,
              color: Colors.white,
            )
                : SizedBox(),
            _isUploading
                ? Center(
              child: CircularProgressIndicator(),
            )
                : SizedBox(),
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Text(
                titles,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomFeaturedListsText extends StatelessWidget {
  CustomFeaturedListsText(this.title);

  final dynamic title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      //only to left align the text
      child: Row(
        children: <Widget>[Text(title.toString(), style: TextStyle(fontSize: 14))],
      ),
    );
  }
}

class overviewItemsGrid extends StatelessWidget {
  overviewItemsGrid(this.outletDetail);

  final dynamic outletDetail;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.count(
        //to avoid scrolling conflict with the dragging sheet
        physics: NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(0),
        crossAxisCount: 1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        shrinkWrap: true,
        children: <Widget>[
          overviewItem(outletDetail),
        ],
      ),
    );
  }
}

class overviewItem extends StatelessWidget {
  final dynamic? outletDetail;

  overviewItem(this.outletDetail);

  @override
  Widget build(BuildContext context) {
    if (outletDetail == null) {
      return Text('Outlet detail is null');
    }
    String idOutlet = outletDetail?["data"]["profile"]["id_outlet"] ?? "NAN";
    String rs = outletDetail?["data"]["profile"]["rs"] ?? "-";
    String owner = outletDetail?['data']['profile']?['nama_pemilik']??" -";
    String nama = outletDetail?['data']['profile']?['nama_outlet']??' -';
    String kabupaten = outletDetail?['data']['profile']?['kabupaten']??' -';
    String kecamatan =  outletDetail?['data']['profile']?['kecamatan']??' -';
    final List<Map<String, dynamic>> leftListData = [
      {'title': 'ID DIGIPOS/RS', 'content': '$idOutlet / $rs'},
      {'title': 'NAMA OUTLET', 'content': nama},
      {'title': 'KABUPATEN', 'content': kabupaten},
      {'title': 'KECAMATAN', 'content': kecamatan},
      {'title': 'OWNER', 'content': owner},
    ];
    String fisik = outletDetail?["data"]["profile"]?["fisik"]??' -';
    String tanggal_kunjungan = outletDetail?['data']['visit']?['tanggal']??" -";
    String catatan = outletDetail?['data']['visit']?['catatan']??" -";
    final List<Map<String, dynamic>> rightListData = [
      {'title': 'KATEGORI', 'content': fisik},
      {'title': 'KUNJUNGAN TERAKHIR', 'content': tanggal_kunjungan},
      {'title': 'CATATAN', 'content': catatan},
    ];
    return
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(
                  Radius.circular(10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xffDDDDDD),
                    blurRadius: 6.0,
                    spreadRadius: 2.0,
                    offset: Offset(0.0, 0.0),
                  )
                ],
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: double.infinity,
                        height: 330.0,
                        child: ListView.builder(
                          itemCount: leftListData.length,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(leftListData[index]['title'],
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              subtitle: Text(
                                leftListData[index]['content'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              dense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: -50,horizontal: 10),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        width: double.infinity,
                        height: 330.0,
                        child: ListView.builder(
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: rightListData.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(
                                rightListData[index]['title'],
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              subtitle: Text(
                                rightListData[index]['content'],
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              dense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: -50, horizontal: 10),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              )
          )
      );
  }
}

class performanceText extends StatelessWidget {
  performanceText(this.outletDetail);

  final dynamic outletDetail;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: <Widget>[
          Text("Performance", style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class PerformanceItem extends StatelessWidget {
  final dynamic outletDetail;
  PerformanceItem(this.outletDetail);

  @override
  Widget build(BuildContext context) {
    final performanceData = <String, Map<String, dynamic>>{};

    for (final key in outletDetail.keys) {
      performanceData[key] = outletDetail[key] as Map<String, dynamic>;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(
            Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xffDDDDDD),
              blurRadius: 6.0,
              spreadRadius: 2.0,
              offset: Offset(0.0, 0.0),
            )
          ],
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Column(
                    children: List.generate(
                      (performanceData.length / 2).ceil(),
                          (index) {
                        final firstIndex = index * 2;
                        final secondIndex = firstIndex + 1;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: PerformanceTile(
                                  title: performanceData.keys.elementAt(firstIndex),
                                  data: performanceData.values.elementAt(firstIndex),
                                ),
                              ),
                            ),
                            if (secondIndex < performanceData.length)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: PerformanceTile(
                                    title: performanceData.keys.elementAt(secondIndex),
                                    data: performanceData.values.elementAt(secondIndex),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PerformanceTile extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  PerformanceTile({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 10),
      title: Text(title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in data.entries)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.key,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                Text(NumberFormatter.format(double.parse(entry.value)).toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class NumberFormatter {
  static String format(double number) {
    if (number == 0) {
      return "0";
    }
    final formatter = NumberFormat('#,##0.##');
    final formattedNumber = formatter.format(number);
    final decimalPart = formattedNumber.split('.').first;
    return decimalPart.replaceAll(RegExp(r'^0+'), '');
  }
}
