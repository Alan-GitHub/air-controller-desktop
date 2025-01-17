import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../model/device.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constant.dart';

abstract class DeviceDiscoverManager {
  static final DeviceDiscoverManager _instance = DeviceDiscoverManagerImpl();

  static DeviceDiscoverManager get instance {
    return _instance;
  }

  void startDiscover();

  void stopDiscover();

  void onDeviceFind(void callback(Device device));

  bool isDiscovering();
}

class DeviceDiscoverManagerImpl implements DeviceDiscoverManager {
  RawDatagramSocket? udpSocket;
  var _isDiscovering = false;
  Function(Device device)? _onDeviceFind;

  @override
  void startDiscover() {
    if (_isDiscovering) {
      debugPrint("It's discovering, start discover is invalid!");
      return;
    }

    RawDatagramSocket.bind(InternetAddress.anyIPv4, Constant.PORT_SEARCH)
        .then((udpSocket) {
      this.udpSocket = udpSocket;

      udpSocket.listen((event) {
        Datagram? datagram = udpSocket.receive();

        Uint8List? data = datagram?.data;

        if (null != data) {
          String str = String.fromCharCodes(data);
          debugPrint(str + ", ip: ${udpSocket.address.address}");

          if (_isValidData(str)) {
            Device device = _convertToDevice(str);
            _onDeviceFind?.call(device);

            _responseToDesktop(device.ip);

            debugPrint("Device: $device");
          } else {
            debugPrint("It's not valid, str: ${str}");
          }
        }

        debugPrint("ip: ${udpSocket.address.address}");
      });

      debugPrint("Udp listen started, port: ${Constant.PORT_SEARCH}");
    }).catchError((error) {
      debugPrint("startDiscover error: $error");
    });
  }

  void _responseToDesktop(String address) async {
    DeviceInfoPlugin deviceInfo = new DeviceInfoPlugin();
    String deviceName = "";
    String? ip = "";

    if (Platform.isMacOS) {
      MacOsDeviceInfo macOsDeviceInfo = await deviceInfo.macOsInfo;
      deviceName = macOsDeviceInfo.computerName;

      NetworkInfo networkInfo = NetworkInfo();
      ip = await networkInfo.getWifiIP();
    }

    String data =
        "${Constant.CMD_SEARCH_RES_PREFIX}${Constant.RADNOM_STR_RES_SEARCH}#${Constant.PLATFORM_MACOS}#$deviceName#$ip";

    this.udpSocket?.send(
        utf8.encode(data),
        InternetAddress(address, type: InternetAddressType.IPv4),
        Constant.PORT_SEARCH);
  }

  bool _isValidData(String data) {
    return data.startsWith(
        "${Constant.CMD_SEARCH_PREFIX}${Constant.RANDOM_STR_SEARCH}#");
  }

  Device _convertToDevice(String searchStr) {
    debugPrint("Search str: ${searchStr}");
    int start =
        "${Constant.CMD_SEARCH_PREFIX}${Constant.RANDOM_STR_SEARCH}#".length;
    String deviceStr = searchStr.substring(start);

    debugPrint(deviceStr);

    List<String> strList = deviceStr.split("#");
    int platform = Device.PLATFORM_UNKNOWN;
    if (strList.isNotEmpty) {
      platform = int.parse(strList[0]);
    }

    String name = "";
    if (strList.length > 1) {
      name = strList[1];
    }

    String ip = "";
    if (strList.length > 2) {
      ip = strList[2];
    }

    Device device = Device(platform, name, ip);
    return device;
  }

  @override
  void stopDiscover() {
    udpSocket?.close();
    _isDiscovering = false;
  }

  @override
  void onDeviceFind(void Function(Device device) callback) {
    _onDeviceFind = callback;
  }

  @override
  bool isDiscovering() {
    return _isDiscovering;
  }
}
