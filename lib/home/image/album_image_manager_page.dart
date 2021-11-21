import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:mobile_assistant_client/home/file_manager.dart';
import 'package:mobile_assistant_client/home/image_manager_page.dart';
import 'package:mobile_assistant_client/network/device_connection_manager.dart';
import 'package:sticky_headers/sticky_headers.dart';
import '../../model/ImageItem.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../model/ResponseEntity.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AlbumImageManagerPage extends StatefulWidget {
  _AlbumImageManagerPageState? state;

  AlbumImageManagerPage();

  @override
  State<StatefulWidget> createState() {
    state = _AlbumImageManagerPageState();
    return state!;
  }

  void setArrangeMode(int arrangeMode) {
    state?.setArrangeMode(arrangeMode);
  }
}

class _AlbumImageManagerPageState extends State<AlbumImageManagerPage> with AutomaticKeepAliveClientMixin {
  final _OUT_PADDING = 20.0;
  final _IMAGE_SPACE = 15.0;

  final _URL_SERVER = "http://${DeviceConnectionManager.instance.currentDevice?.ip}:8080";

  List<ImageItem> _allImages = [];

  int _arrangeMode = ImageManagerPage.ARRANGE_MODE_GRID;
  List<ImageItem> _selectedImages = [];

  final _IMAGE_GRID_RADIUS_SELECTED = 5.0;
  final _IMAGE_GRID_RADIUS = 1.0;

  final _IMAGE_GRID_BORDER_WIDTH_SELECTED = 4.0;
  final _IMAGE_GRID_BORDER_WIDTH = 1.0;
  bool _isLoadingCompleted = false;

  late Function() _ctrlAPressedCallback;

  _AlbumImageManagerPageState();

  @override
  void initState() {
    super.initState();

    _ctrlAPressedCallback = () {
      if (_isFront()) {
        _setAllSelected();
      }
      debugPrint("Ctrl + A pressed...");
    };

    _addCtrlAPressedCallback(_ctrlAPressedCallback);

    _getAlbumImages((images) {
      setState(() {
        _allImages = images;
        _isLoadingCompleted = true;
      });
      updateBottomItemNum();
    }, (error) {
      print("Get all images error: $error");
      setState(() {
        _isLoadingCompleted = true;
      });
    });
  }

  void setArrangeMode(int arrangeMode) {
    setState(() {
      _arrangeMode = arrangeMode;
    });
  }

  void _setAllSelected() {
    setState(() {
      _selectedImages.clear();
      _selectedImages.addAll(_allImages);
      updateBottomItemNum();
    });
  }

  void _clearSelectedImages() {
    setState(() {
      _selectedImages.clear();
      updateBottomItemNum();
    });
  }

  bool _isControlDown() {
    FileManagerPage? fileManagerPage = context.findAncestorWidgetOfExactType<FileManagerPage>();
    return fileManagerPage?.state?.isControlDown() == true;
  }

  bool _isShiftDown() {
    FileManagerPage? fileManagerPage = context.findAncestorWidgetOfExactType<FileManagerPage>();
    return fileManagerPage?.state?.isShiftDown() == true;
  }

  void _addCtrlAPressedCallback(Function() callback) {
    FileManagerPage? fileManagerPage = context.findAncestorWidgetOfExactType<FileManagerPage>();
    fileManagerPage?.state?.addCtrlAPressedCallback(callback);
  }

  void _removeCtrlAPressedCallback(Function() callback) {
    FileManagerPage? fileManagerPage = context.findAncestorWidgetOfExactType<FileManagerPage>();
    fileManagerPage?.state?.addCtrlAPressedCallback(callback);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    const color = Color(0xff85a8d0);
    const spinKit = SpinKitCircle(color: color, size: 60.0);

    Widget content = _createContent(_arrangeMode);

    return GestureDetector(
      child: Stack(children: [
        content,
        Visibility(
          child: Container(child: spinKit, color: Colors.white),
          maintainSize: false,
          visible: !_isLoadingCompleted,
        )
      ]),
      onTap: () {
        _clearSelectedImages();
      },
    );
  }

  bool _isContainsImage(List<ImageItem> images, ImageItem current) {
    for (ImageItem imageItem in images) {
      if (imageItem.id == current.id) return true;
    }

    return false;
  }

  void _setDeleteBtnEnabled(bool enable) {
    ImageManagerPage? imageManagerPage = context.findAncestorWidgetOfExactType<ImageManagerPage>();
    imageManagerPage?.state?.setDeleteBtnEnabled(enable);
  }

  void _setImageSelected(ImageItem image) {
    debugPrint("Shift key down status: $_isShiftDown");
    debugPrint("Control key down status: $_isControlDown");

    if (!_isContainsImage(_selectedImages, image)) {
      if (_isControlDown()) {
        setState(() {
          _selectedImages.add(image);
        });
      } else if (_isShiftDown()) {
        if (_selectedImages.length == 0) {
          setState(() {
            _selectedImages.add(image);
          });
        } else if (_selectedImages.length == 1) {
          int index = _allImages.indexOf(_selectedImages[0]);

          int current = _allImages.indexOf(image);

          if (current > index) {
            setState(() {
              _selectedImages = _allImages.sublist(index, current + 1);
            });
          } else {
            setState(() {
              _selectedImages = _allImages.sublist(current, index + 1);
            });
          }
        } else {
          int maxIndex = 0;
          int minIndex = 0;

          for (int i = 0; i < _selectedImages.length; i++) {
            ImageItem current = _selectedImages[i];
            int index = _allImages.indexOf(current);
            if (index < 0) {
              debugPrint("Error image");
              continue;
            }

            if (index > maxIndex) {
              maxIndex = index;
            }

            if (index < minIndex) {
              minIndex = index;
            }
          }

          debugPrint("minIndex: $minIndex, maxIndex: $maxIndex");

          int current = _allImages.indexOf(image);

          if (current >= minIndex && current <= maxIndex) {
            setState(() {
              _selectedImages = _allImages.sublist(current, maxIndex + 1);
            });
          } else if (current < minIndex) {
            setState(() {
              _selectedImages = _allImages.sublist(current, maxIndex + 1);
            });
          } else if (current > maxIndex) {
            setState(() {
              _selectedImages = _allImages.sublist(minIndex, current + 1);
            });
          }
        }
      } else {
        setState(() {
          _selectedImages.clear();
          _selectedImages.add(image);
        });
      }
    } else {
      debugPrint("It's already contains this image, id: ${image.id}");

      if (_isControlDown()) {
        setState(() {
          _selectedImages.remove(image);
        });
      } else if (_isShiftDown()) {
        setState(() {
          _selectedImages.remove(image);
        });
      }
    }

    _setDeleteBtnEnabled(_selectedImages.length > 0);
    updateBottomItemNum();
  }

  Widget _createContent(int arrangeMode) {
    if (_arrangeMode == ImageManagerPage.ARRANGE_MODE_DAILY) {
      return _createDailyContent();
    }

    if (_arrangeMode == ImageManagerPage.ARRANGE_MODE_MONTHLY) {
      return _createMonthlyContent();
    }

    return _createGridContent();
  }

  Widget _createGridContent() {
    return Container(
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            crossAxisSpacing: _IMAGE_SPACE,
            childAspectRatio: 1.0,
            mainAxisSpacing: _IMAGE_SPACE),
        itemBuilder: (BuildContext context, int index) {
          ImageItem image = _allImages[index];
          return Container(
            child: GestureDetector(
              child: CachedNetworkImage(
                imageUrl: "${_URL_SERVER}/stream/image/thumbnail/${image.id}/200/200"
                    .replaceAll("storage/emulated/0/", ""),
                fit: BoxFit.cover,
                width: 200,
                height: 200,
                memCacheWidth: 400,
                fadeOutDuration: Duration.zero,
                fadeInDuration: Duration.zero,
              ),
              onTap: () {
                setState(() {
                  _setImageSelected(image);
                });
              },
              onDoubleTap: () {
                debugPrint("双击");
                _openImageDetail(_allImages, image);
              },
            ),
            decoration: BoxDecoration(
                border: new Border.all(
                    color: _isContainsImage(_selectedImages, image)  ? Color(0xff5d86ec) : Color(0xffdedede),
                    width: _isContainsImage(_selectedImages, image)  ? _IMAGE_GRID_BORDER_WIDTH_SELECTED : _IMAGE_GRID_BORDER_WIDTH
                ),
                borderRadius: new BorderRadius.all(
                    Radius.circular(_isContainsImage(_selectedImages, image)  ? _IMAGE_GRID_RADIUS_SELECTED : _IMAGE_GRID_RADIUS)
                )
            ),
          );
        },
        itemCount: _allImages.length,
        shrinkWrap: true,
      ),
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(_OUT_PADDING, _OUT_PADDING, _OUT_PADDING, 0),
    );
  }

  Widget _createDailyContent() {
    final map = LinkedHashMap<String, List<ImageItem>>();

    final timeFormat = "yyyy年M月d日";

    for (ImageItem imageItem in _allImages) {
      int createTime = imageItem.createTime;

      final df = DateFormat(timeFormat);
      String createTimeStr = df.format(new DateTime.fromMillisecondsSinceEpoch(createTime));

      List<ImageItem>? images = map[createTimeStr];
      if (null == images) {
        images = <ImageItem>[];
        images.add(imageItem);
        map[createTimeStr] = images;
      } else {
        images.add(imageItem);
        map[createTimeStr] = images;
      }
    }

    List<String> keys = map.keys.toList();
    keys.sort((String a, String b) {
      final df = DateFormat(timeFormat);
      DateTime dateTimeA = df.parse(a);
      DateTime dateTimeB = df.parse(b);

      return dateTimeB.millisecondsSinceEpoch - dateTimeA.millisecondsSinceEpoch;
    });

    Map<String, List<ImageItem>> sortedMap = LinkedHashMap();

    keys.forEach((key) {
      sortedMap[key] = map[key]!;
    });

    return ListView.builder(itemBuilder: (BuildContext context, int index) {
      final entry = sortedMap.entries.toList()[index];
      String dateTime = entry.key;
      List<ImageItem> images = entry.value;

      return Container(
          child: StickyHeader(
              header: Container(
                child: Text(
                    dateTime,
                    style: TextStyle(
                        inherit: false,
                        fontSize: 14,
                        color: Color(0xff515151)
                    )
                ),
                color: Colors.white,
              ),
              content: Container(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 100,
                      crossAxisSpacing: _IMAGE_SPACE,
                      childAspectRatio: 1.0,
                      mainAxisSpacing: _IMAGE_SPACE),
                  itemBuilder: (BuildContext context, int index) {
                    ImageItem image = images[index];
                    return Container(
                      child: GestureDetector(
                        child: CachedNetworkImage(
                          imageUrl: "${_URL_SERVER}/stream/image/thumbnail/${image.id}/200/200"
                              .replaceAll("storage/emulated/0/", ""),
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          memCacheWidth: 200,
                          fadeOutDuration: Duration.zero,
                          fadeInDuration: Duration.zero,
                        ),
                        onTap: () {
                          setState(() {
                            _setImageSelected(image);
                          });
                        },
                        onDoubleTap: () {
                          _openImageDetail(_allImages, image);
                        },
                      ),
                      decoration: BoxDecoration(
                          border: new Border.all(
                              color: _isContainsImage(_selectedImages, image)  ? Color(0xff5d86ec) : Color(0xffdedede),
                              width: _isContainsImage(_selectedImages, image)  ? _IMAGE_GRID_BORDER_WIDTH_SELECTED : _IMAGE_GRID_BORDER_WIDTH
                          ),
                          borderRadius: new BorderRadius.all(
                              Radius.circular(_isContainsImage(_selectedImages, image)  ? _IMAGE_GRID_RADIUS_SELECTED : _IMAGE_GRID_RADIUS)
                          )
                      ),
                    );
                  },
                  itemCount: images.length,
                  shrinkWrap: true,
                ),
                color: Colors.white,
                margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
              )
          ),
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(20, 15, 20, 0)
      );
    },
      itemCount: map.length,
    );
  }

  Widget _createMonthlyContent() {
    final map = LinkedHashMap<String, List<ImageItem>>();

    final timeFormat = "yyyy年M月";

    for (ImageItem imageItem in _allImages) {
      int createTime = imageItem.createTime;

      final df = DateFormat(timeFormat);
      String createTimeStr = df.format(new DateTime.fromMillisecondsSinceEpoch(createTime));

      List<ImageItem>? images = map[createTimeStr];
      if (null == images) {
        images = <ImageItem>[];
        images.add(imageItem);
        map[createTimeStr] = images;
      } else {
        images.add(imageItem);
        map[createTimeStr] = images;
      }
    }

    List<String> keys = map.keys.toList();
    keys.sort((String a, String b) {
      final df = DateFormat(timeFormat);
      DateTime dateTimeA = df.parse(a);
      DateTime dateTimeB = df.parse(b);

      return dateTimeB.millisecondsSinceEpoch - dateTimeA.millisecondsSinceEpoch;
    });

    Map<String, List<ImageItem>> sortedMap = LinkedHashMap();

    keys.forEach((key) {
      sortedMap[key] = map[key]!;
    });

    return ListView.builder(itemBuilder: (BuildContext context, int index) {
      final entry = sortedMap.entries.toList()[index];
      String dateTime = entry.key;
      List<ImageItem> images = entry.value;

      return Container(
          child: StickyHeader(
              header: Container(
                child: Text(
                    dateTime,
                    style: TextStyle(
                        inherit: false,
                        fontSize: 14,
                        color: Color(0xff515151)
                    )
                ),
                color: Colors.white,
              ),
              content: Container(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 80,
                      crossAxisSpacing: _IMAGE_SPACE,
                      childAspectRatio: 1.0,
                      mainAxisSpacing: _IMAGE_SPACE),
                  itemBuilder: (BuildContext context, int index) {
                    ImageItem image = images[index];
                    return Container(
                      child: GestureDetector(
                        child: CachedNetworkImage(
                          imageUrl: "${_URL_SERVER}/stream/image/thumbnail/${image.id}/200/200"
                              .replaceAll("storage/emulated/0/", ""),
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          memCacheWidth: 200,
                          fadeOutDuration: Duration.zero,
                          fadeInDuration: Duration.zero,
                        ),
                        onTap: () {
                          setState(() {
                            _setImageSelected(image);
                          });
                        },
                        onDoubleTap: () {
                          _openImageDetail(_allImages, image);
                        },
                      ),
                      decoration: BoxDecoration(
                          border: new Border.all(
                              color: _isContainsImage(_selectedImages, image)  ? Color(0xff5d86ec) : Color(0xffdedede),
                              width: _isContainsImage(_selectedImages, image)  ? _IMAGE_GRID_BORDER_WIDTH_SELECTED : _IMAGE_GRID_BORDER_WIDTH
                          ),
                          borderRadius: new BorderRadius.all(
                              Radius.circular(_isContainsImage(_selectedImages, image)  ? _IMAGE_GRID_RADIUS_SELECTED : _IMAGE_GRID_RADIUS)
                          )
                      ),
                    );
                  },
                  itemCount: images.length,
                  shrinkWrap: true,
                ),
                color: Colors.white,
                margin: EdgeInsets.fromLTRB(0, 10, 0, 0),
              )
          ),
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(20, 15, 20, 0)
      );
    },
      itemCount: map.length,
    );
  }

  void _getAlbumImages(Function(List<ImageItem> images) onSuccess,
      Function(String error) onError) {
    var url = Uri.parse("${_URL_SERVER}/image/albumImages");
    http
        .post(url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({}))
        .then((response) {
      if (response.statusCode != 200) {
        onError.call(response.reasonPhrase != null
            ? response.reasonPhrase!
            : "Unknown error");
      } else {
        var body = response.body;
        debugPrint("Get all image list, body: $body");

        final map = jsonDecode(body);
        final httpResponseEntity = ResponseEntity.fromJson(map);

        if (httpResponseEntity.isSuccessful()) {
          final data = httpResponseEntity.data as List<dynamic>;

          onSuccess.call(data
              .map((e) => ImageItem.fromJson(e as Map<String, dynamic>))
              .toList());
        } else {
          onError.call(httpResponseEntity.msg == null
              ? "Unknown error"
              : httpResponseEntity.msg!);
        }
      }
    }).catchError((error) {
      onError.call(error.toString());
    });
  }

  void _openImageDetail(List<ImageItem> images, ImageItem current) {
    ImageManagerPage? imageManagerPage = context.findAncestorWidgetOfExactType<ImageManagerPage>();
    imageManagerPage?.state?.openImageDetail(images, current);
  }

  void updateBottomItemNum() {
    ImageManagerPage? imageManagerPage = context.findAncestorWidgetOfExactType<ImageManagerPage>();
    imageManagerPage?.state?.updateBottomItemNumber(_allImages.length, 1);
  }

  // 判断当前页面是否在前台显示
  bool _isFront() {
    ImageManagerPage? imageManagerPage = context.findAncestorWidgetOfExactType<ImageManagerPage>();
    int? imageTabIndex = imageManagerPage?.state?.selectedIndex();

    FileManagerPage? fileManagerPage = context.findAncestorWidgetOfExactType<FileManagerPage>();
    int? leftTabIndex = fileManagerPage?.state?.selectedTabIndex();

    return leftTabIndex == FileManagerState.PAGE_INDEX_IMAGE
        && imageTabIndex == ImageManagerState.INDEX_CAMERA_ALBUM;
  }


  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    super.dispose();

    _removeCtrlAPressedCallback(_ctrlAPressedCallback);
  }
}
