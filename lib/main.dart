import 'package:flutter/material.dart';
import 'package:flutter_swiper/flutter_swiper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:device_info/device_info.dart';
import 'dart:io';
import 'dart:convert';
import 'http.dart';
import 'api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_ijkplayer/flutter_ijkplayer.dart';
// import 'android_back_desktop.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: new MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  var type = 0;
  var datalist;
  var deviceId;
  var dataLength;
  bool isplay = false;

  WebSocketChannel channel;
  IjkMediaController controller;

  var index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getDeviceInfo();
  }

  @override
  void dispose() {
    this.channel.sink.close();
    controller.reset();
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // print("--" + state.toString());
    if (state == AppLifecycleState.paused) {
      if (controller != null && controller.ijkStatus == IjkStatus.playing) {
        controller.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null && controller.ijkStatus == IjkStatus.pause) {
        controller.play();
      }
    }
  }

  void getDisplaylist() async {
    //重置播放器
    setState(() {
      index = 0;
    });
    if (controller != null && controller.ijkStatus == IjkStatus.playing) {
      controller.reset();
    }
    var parmas = {'equipmentNo': deviceId};
    var response = await HttpUtil(context).post(Api.DISPLAY_LIST, data: parmas);
    var datalistInfo = Datalist.fromJson(json.decode(response.toString()));
    if (datalistInfo.code == 0) {
      setState(() {
        datalist = datalistInfo.data.displayerList;
      });
      setState(() {
        dataLength = datalist.length;
      });
      if (datalistInfo.data.playType == 2) {
        setState(() {
          type = 2;
        });
        //判断是否需要初始化
        if (controller != null &&
            controller.ijkStatus == IjkStatus.noDatasource) {
          controller.setNetworkDataSource(this.datalist[0].contentUrl,
              autoPlay: true);
          controller.play();
        } else {
          controller = IjkMediaController();
          controller.setNetworkDataSource(this.datalist[0].contentUrl,
              autoPlay: true);
          Stream<IjkStatus> ijkStatusStream = controller.ijkStatusStream;
          ijkStatusStream.listen((data) {
            print(data);
            var currentIndex = this.index;
            if (data == IjkStatus.complete) {
              setState(() {
                index = currentIndex + 1;
              });
              if (this.datalist != null) {
                if (this.index == this.dataLength) {
                  setState(() {
                    index = 0;
                  });
                }
                controller.reset();
                controller.setNetworkDataSource(this.datalist[index].contentUrl,
                    autoPlay: true);
                controller.play();
              }
            }
          }, onError: (error) {
            print("流发生错误");
          }, onDone: () {
            print("流已完成");
          }, cancelOnError: false);
        }
      } else if (datalistInfo.data.playType == 1) {
        setState(() {
          type = 1;
        });
      }
    } else {
      //没有数据
      setState(() {
        type = 3;
      });
    }
  }

  void getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = new DeviceInfoPlugin();
    if (Platform.isIOS) {
      // IosDeviceInfo iosDeviceInfo = await deviceInfo.iosInfo;
    } else if (Platform.isAndroid) {
      AndroidDeviceInfo androidDeviceInfo = await deviceInfo.androidInfo;
      setState(() {
        deviceId = androidDeviceInfo.id;
      });
    }
    _getMessage();
    getDisplaylist();
  }

  void _getMessage() {
    // print('---' + deviceId);
    this.channel = IOWebSocketChannel.connect(Api.SOCKET_URL + deviceId);
    this.channel.stream.listen(this.onData, onError: onError, onDone: onDone);
  }

  onDone() {
    this.channel = IOWebSocketChannel.connect(Api.SOCKET_URL + deviceId);
    this._getMessage();
  }

  onError(err) {
    debugPrint(err.runtimeType.toString());
    WebSocketChannelException ex = err;
    debugPrint(ex.message);
  }

  onData(event) {
    print(event);
    var socketCode = Socket.fromJson(json.decode(event.toString())).code;
    if (socketCode == 1) {
      getDisplaylist();
    }
  }

  @override
  Widget build(BuildContext context) {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    return WillPopScope(
        onWillPop: () async {
          if (controller != null) {
            controller.dispose();
          }
          Navigator.of(context).pop(true);
          return true;
        },
        child: Scaffold(
            appBar: PreferredSize(
              child: Offstage(
                offstage: true,
              ),
              preferredSize:
                  Size.fromHeight(MediaQuery.of(context).size.height * 0.07),
            ),
            // floatingActionButton: FloatingActionButton(
            //     child: Text(this.index.toString()),
            //     onPressed: () {
            //       //点击主页开始倒计时
            //     },
            //     backgroundColor: Colors.blue),
            body: Container(width: width, height: height, child: content())));
  }

  Widget content() {
    var width = MediaQuery.of(context).size.width;
    var height = MediaQuery.of(context).size.height;
    // if (this.type == 0) {
    //   return Container(
    //       child: new AlertDialog(
    //     title: new Text('设备号'),
    //     content: new SingleChildScrollView(
    //       child: new ListBody(
    //         children: <Widget>[
    //           new Text(this.deviceId != null ? this.deviceId : ''),
    //         ],
    //       ),
    //     ),
    //     actions: <Widget>[
    //       // new FlatButton(
    //       //   child: new Text(this.isplay.toString()),
    //       //   onPressed: () {
    //       //     setState(() {
    //       //       type = 1;
    //       //     });
    //       //     getDisplaylist();
    //       //   },
    //       // ),
    //     ],
    //   ));
    // } else
    if (this.type == 1) {
      return Container(
          child: Swiper(
        autoplayDelay: 8000,
        // autoplayDisableOnInteraction: false,
        itemBuilder: _swiperBuilder,
        itemCount: this.datalist != null ? this.datalist.length : 1,
        scrollDirection: Axis.horizontal,
        autoplay: true,
      ));
    } else if (this.type == 2) {
      if (controller != null) {
        return IjkPlayer(
          mediaController: controller,
          // controllerWidgetBuilder: (mediaController) {
          //   return DefaultIJKControllerWidget(
          //       currentFullScreenState: true, controller: controller);
          //   // 自定义
          // }
        );
      } else {
        return Container();
      }
    } else if ((this.type == 3)) {
      return Container(
          child: Center(
              child: Container(
                  height: 300,
                  child: Column(
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.only(bottom: height * 0.03),
                        child: Image.asset(
                          'lib/image/nodevice.png',
                          width: 200,
                        ),
                      ),
                      Text('暂无数据，请您检查设备号是否正确',
                          style: TextStyle(color: Color(0xff454545))),
                    ],
                  ))));
    } else {
      return Container();
    }
  }

  Widget _swiperBuilder(BuildContext context, int index) {
    if (this.datalist != null) {
      return new FadeInImage.assetNetwork(
        placeholder: 'lib/image/timg.gif',
        image: this.datalist[index].contentUrl,
        // fit: BoxFit.cover,

        // child: CachedNetworkImage(
        //   fit: BoxFit.fill,
        //   // imageUrl: list[index],
        //   imageUrl: this.datalist[index].contentUrl,
        //   fadeOutDuration: Duration(milliseconds: 5000),
        //   // placeholderFadeInDuration: Duration(milliseconds: 5000),
        //   placeholder: (context, url) =>
        //   Image.asset("lib/image/timg.gif"),
        //   errorWidget: (context, url, error) => Icon(Icons.error),
        // ),
      );
    } else {
      return (Image.asset(
        "lib/image/nodata.png",
        fit: BoxFit.cover,
      ));
    }
  }
}

class Socket {
  int code;
  String data;
  String message;

  Socket({this.code, this.data, this.message});

  Socket.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    data = json['data'];
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    data['data'] = this.data;
    data['message'] = this.message;
    return data;
  }
}

class Datalist {
  int code;
  String message;
  Data data;

  Datalist({this.code, this.message, this.data});

  Datalist.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    message = json['message'];
    data = json['data'] != null ? new Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['code'] = this.code;
    data['message'] = this.message;
    if (this.data != null) {
      data['data'] = this.data.toJson();
    }
    return data;
  }
}

class Data {
  int total;
  int playType;
  List<DisplayerList> displayerList;

  Data({this.total, this.playType, this.displayerList});

  Data.fromJson(Map<String, dynamic> json) {
    total = json['total'];
    playType = json['playType'];
    if (json['displayerList'] != null) {
      displayerList = new List<DisplayerList>();
      json['displayerList'].forEach((v) {
        displayerList.add(new DisplayerList.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['total'] = this.total;
    data['playType'] = this.playType;
    if (this.displayerList != null) {
      data['displayerList'] =
          this.displayerList.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class DisplayerList {
  String contentName;
  String contentUrl;
  int playType;

  DisplayerList({this.contentName, this.contentUrl, this.playType});

  DisplayerList.fromJson(Map<String, dynamic> json) {
    contentName = json['contentName'];
    contentUrl = json['contentUrl'];
    playType = json['playType'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['contentName'] = this.contentName;
    data['contentUrl'] = this.contentUrl;
    data['playType'] = this.playType;
    return data;
  }
}
