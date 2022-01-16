import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flowder/flowder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_assistant_client/event/back_btn_visibility.dart';
import 'package:mobile_assistant_client/event/delete_op.dart';
import 'package:mobile_assistant_client/event/refresh_all_file_list.dart';
import 'package:mobile_assistant_client/event/update_bottom_item_num.dart';
import 'package:mobile_assistant_client/event/update_delete_btn_status.dart';
import 'package:mobile_assistant_client/model/FileItem.dart';
import 'package:mobile_assistant_client/model/FileNode.dart';
import 'package:mobile_assistant_client/model/ResponseEntity.dart';
import 'package:mobile_assistant_client/model/UIModule.dart';
import 'package:mobile_assistant_client/network/device_connection_manager.dart';
import 'package:mobile_assistant_client/util/event_bus.dart';
import 'package:mobile_assistant_client/util/file_util.dart';
import 'package:mobile_assistant_client/util/system_app_launcher.dart';
import 'package:mobile_assistant_client/widget/confirm_dialog_builder.dart';
import 'package:mobile_assistant_client/widget/progress_indictor_dialog.dart';

import 'all_file_manager.dart';

class AllFileIconModePage extends StatefulWidget {
  late _AllFileIconModeState? state;

  @override
  State<StatefulWidget> createState() {
    state = _AllFileIconModeState();
    debugPrint("DownloadIconModePage, createState, instance: $this");
    return state!;
  }

  void updateFiles(List<FileItem> files) {
    state?.updateFiles(files);
  }

  void setSelectedFiles(List<FileItem> files) {
    state?.updateSelectedFiles(files);
  }
}

class _AllFileIconModeState extends State<AllFileIconModePage>
    with AutomaticKeepAliveClientMixin {
  final _divider_line_color = Color(0xffe0e0e0);
  final _BACKGROUND_FILE_SELECTED = Color(0xffe6e6e6);
  final _BACKGROUND_FILE_NORMAL = Colors.white;

  final _FILE_NAME_TEXT_COLOR_NORMAL = Color(0xff515151);

  final _FILE_NAME_TEXT_COLOR_SELECTED = Colors.white;

  final _BACKGROUND_FILE_NAME_NORMAL = Colors.white;
  final _BACKGROUND_FILE_NAME_SELECTED = Color(0xff5d87ed);

  final _URL_SERVER =
      "http://${DeviceConnectionManager.instance.currentDevice?.ip}:8080";

  StreamSubscription<RefreshAllFileList>? _refreshDownloadFileList;
  StreamSubscription<DeleteOp>? _deleteOpSubscription;

  DownloaderCore? _downloaderCore;
  ProgressIndicatorDialog? _progressIndicatorDialog;

  final _KB_BOUND = 1 * 1024;
  final _MB_BOUND = 1 * 1024 * 1024;
  final _GB_BOUND = 1 * 1024 * 1024 * 1024;

  int _renamingFileIndex = -1;
  String? _newFileName = null;

  bool _isControlPressed = false;
  bool _isShiftPressed = false;

  @override
  void initState() {
    super.initState();

    _registerEventBus();

    debugPrint("_DownloadIconModeState: initState, instance: $this");
  }

  void _registerEventBus() {
    _refreshDownloadFileList =
        eventBus.on<RefreshAllFileList>().listen((event) {
      setState(() {});
    });

    _deleteOpSubscription = eventBus.on<DeleteOp>().listen((event) {
      List<FileNode> selectedNodes = AllFileManager.instance.selectedFiles();
      if (selectedNodes.length <= 0) {
        debugPrint("Warning: selectedNodes is empty!!!");
      } else {
        _tryToDeleteFiles(selectedNodes);
      }
    });
  }

  void _unRegisterEventBus() {
    _refreshDownloadFileList?.cancel();
    _deleteOpSubscription?.cancel();
  }

  void _setAllSelected() {
    setState(() {
      List<FileNode> allFiles = AllFileManager.instance.allFiles();

      List<FileNode> selectedFiles = [];
      selectedFiles.addAll(allFiles);
      AllFileManager.instance.updateSelectedFiles(selectedFiles);

      updateBottomItemNum();
      _setDeleteBtnEnabled(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    String getFileTypeIcon(bool isDir, String extension) {
      if (isDir) {
        return "icons/ic_large_type_folder.png";
      } else {
        if (_isAudio(extension)) {
          return "icons/ic_large_type_audio.png";
        }

        if (_isTextFile(extension)) {
          return "icons/ic_large_type_txt.png";
        }

        return "icons/ic_large_type_doc.png";
      }
    }

    List<FileNode> files = AllFileManager.instance.allFiles();
    List<FileNode> selectedFiles = AllFileManager.instance.selectedFiles();

    int dirStackLength = AllFileManager.instance.dirStackLength();

    Widget content = Column(children: [
      Container(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  child: GestureDetector(
                    child: Text("手机存储",
                        style: TextStyle(
                            color: Color(0xff5b5c61),
                            fontSize: 12.0,
                            inherit: false)),
                    onTap: () {
                      _backToRootDir();
                    },
                  ),
                  margin: EdgeInsets.only(right: 10),
                ),
                ...List.generate(dirStackLength, (index) {
                  List<FileNode> fileNodes =
                      AllFileManager.instance.dirStackToList();
                  FileNode fileNode = fileNodes[index];

                  return GestureDetector(
                    child: Row(
                      children: [
                        Image.asset("icons/ic_right_arrow.png", height: 20),
                        Container(
                          child: Text(fileNode.data.name,
                              style: TextStyle(
                                  color: Color(0xff5b5c61),
                                  fontSize: 12.0,
                                  inherit: false)),
                          padding: EdgeInsets.only(right: 5),
                        ),
                      ],
                    ),
                    onTap: () {
                      _tryToOpenDirectory(fileNode, (files) {
                        setState(() {
                          AllFileManager.instance.popTo(fileNode);
                          AllFileManager.instance.updateSelectedFiles([]);
                          AllFileManager.instance.updateFiles(files);
                          AllFileManager.instance.updateCurrentDir(fileNode);
                          _updateBackBtnVisibility();
                          _setDeleteBtnEnabled(
                              AllFileManager.instance.selectedFileCount() > 0);
                          updateBottomItemNum();
                        });
                      }, (error) {});
                    },
                  );
                })
              ],
            ),
          ),
          color: Color(0xfffaf9fa),
          padding: EdgeInsets.fromLTRB(10, 0, 0, 0),
          height: 30),
      Divider(color: _divider_line_color, height: 1.0, thickness: 1.0),
      Expanded(
          child: Container(
              child: GridView.builder(
                itemBuilder: (BuildContext context, int index) {
                  FileNode fileItem = files[index];

                  bool isDir = fileItem.data.isDir;

                  String name = fileItem.data.name;
                  String extension = "";
                  int pointIndex = name.lastIndexOf(".");
                  if (pointIndex != -1) {
                    extension = name.substring(pointIndex + 1);
                  }

                  String fileTypeIcon = getFileTypeIcon(isDir, extension);

                  Widget icon =
                      Image.asset(fileTypeIcon, width: 100, height: 100);

                  if (_isImageFile(extension)) {
                    String encodedPath = Uri.encodeFull(
                        "${fileItem.data.folder}/${fileItem.data.name}");
                    String imageUrl =
                        "${_URL_SERVER}/stream/image/thumbnail2?path=${encodedPath}&width=400&height=400";
                    icon = Container(
                      child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          memCacheWidth: 400,
                          fadeOutDuration: Duration.zero,
                          fadeInDuration: Duration.zero,
                          errorWidget: (context, url, error) {
                            return Image.asset("icons/brokenImage.png",
                                width: 100, height: 100);
                          }),
                      decoration: BoxDecoration(
                          border: new Border.all(
                              color: Color(0xffdedede), width: 1),
                          borderRadius:
                              new BorderRadius.all(Radius.circular(2.0))),
                      padding: EdgeInsets.all(6),
                    );
                  }

                  if (FileUtil.isVideo(fileItem.data)) {
                    String videoThumbnail =
                        "${_URL_SERVER}/stream/video/thumbnail2?path=${fileItem.data.folder}/${fileItem.data.name}&width=400&height=400";
                    icon = Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: videoThumbnail,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          memCacheWidth: 400,
                          fadeOutDuration: Duration.zero,
                          fadeInDuration: Duration.zero,
                        ),
                        Positioned(
                          child: Image.asset("icons/ic_video_indictor.png",
                              width: 20, height: 20),
                          left: 15,
                          bottom: 8,
                        )
                      ],
                    );
                  }

                  final inputController = TextEditingController();

                  inputController.text = fileItem.data.name;

                  final focusNode = FocusNode();

                  focusNode.addListener(() {
                    if (focusNode.hasFocus) {
                      inputController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: inputController.text.length);
                    }
                  });

                  return Listener(
                    child: Column(children: [
                      GestureDetector(
                          child: Container(
                            child: icon,
                            decoration: BoxDecoration(
                                color: _isContainsFile(selectedFiles, fileItem)
                                    ? _BACKGROUND_FILE_SELECTED
                                    : _BACKGROUND_FILE_NORMAL,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(4.0))),
                            padding: EdgeInsets.all(8),
                          ),
                          onTap: () {
                            debugPrint("All file icon mode page: icon#onTap");

                            _setFileSelected(fileItem);
                          },
                          onDoubleTap: () {
                            if (fileItem.data.isDir) {
                              debugPrint(
                                  "_tryToOpenDirectory: ${fileItem.data.name}");

                              _tryToOpenDirectory(fileItem, (files) {
                                setState(() {
                                  AllFileManager.instance
                                      .updateSelectedFiles([]);
                                  AllFileManager.instance.updateFiles(files);
                                  AllFileManager.instance
                                      .updateCurrentDir(fileItem);
                                  AllFileManager.instance.pushToStack(fileItem);
                                  _updateBackBtnVisibility();
                                  _setDeleteBtnEnabled(AllFileManager.instance
                                          .selectedFileCount() >
                                      0);
                                  updateBottomItemNum();
                                });
                              }, (error) {});
                            } else {
                              _openWithSystemApp(fileItem.data);
                            }
                          }),
                      GestureDetector(
                        child: Container(
                          constraints: BoxConstraints(maxWidth: 150),
                          child: Stack(
                            children: [
                              Visibility(
                                child: Text(
                                  fileItem.data.name,
                                  style: TextStyle(
                                      inherit: false,
                                      fontSize: 14,
                                      color: _isContainsFile(
                                                  selectedFiles, fileItem) &&
                                              index != _renamingFileIndex
                                          ? _FILE_NAME_TEXT_COLOR_SELECTED
                                          : _FILE_NAME_TEXT_COLOR_NORMAL),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                visible: (index != _renamingFileIndex),
                              ),
                              Visibility(
                                child: Container(
                                  child: IntrinsicWidth(
                                    child: TextField(
                                      controller: inputController,
                                      focusNode: index == _renamingFileIndex
                                          ? focusNode
                                          : null,
                                      decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Color(0xffcccbcd),
                                                  width: 3,
                                                  style: BorderStyle.solid)),
                                          enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Color(0xffcccbcd),
                                                  width: 3,
                                                  style: BorderStyle.solid),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: Color(0xffcccbcd),
                                                  width: 4,
                                                  style: BorderStyle.solid),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          contentPadding:
                                              EdgeInsets.fromLTRB(8, 3, 8, 3)),
                                      cursorColor: Color(0xff333333),
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xff333333)),
                                      onChanged: (value) {
                                        debugPrint("onChange, $value");
                                        _newFileName = value;
                                      },
                                    ),
                                  ),
                                  height: 30,
                                ),
                                visible: index == _renamingFileIndex,
                                maintainState: false,
                                maintainSize: false,
                              )
                            ],
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                            color: _isContainsFile(selectedFiles, fileItem) &&
                                    index != _renamingFileIndex
                                ? _BACKGROUND_FILE_NAME_SELECTED
                                : _BACKGROUND_FILE_NAME_NORMAL,
                          ),
                          margin: EdgeInsets.only(top: 10),
                          padding: EdgeInsets.fromLTRB(5, 3, 5, 3),
                        ),
                        onTap: () {
                          debugPrint("All file icon mode page: text#onTap");
                          _setFileSelected(fileItem);
                        },
                        onDoubleTap: () {
                          debugPrint(
                              "_tryToOpenDirectory: ${fileItem.data.name}");

                          _tryToOpenDirectory(fileItem, (files) {
                            setState(() {
                              AllFileManager.instance.updateSelectedFiles([]);
                              AllFileManager.instance.updateFiles(files);
                              AllFileManager.instance
                                  .updateCurrentDir(fileItem);
                              AllFileManager.instance.pushToStack(fileItem);
                              _updateBackBtnVisibility();
                            });
                          }, (error) {});
                        },
                      )
                    ]),
                    onPointerDown: (e) {
                      debugPrint("All file icon mode page: onPointerDown");

                      if (_isMouseRightClicked(e)) {
                        _openMenu(e.position, fileItem);

                        if (!AllFileManager.instance.isSelected(fileItem)) {
                          _setFileSelected(fileItem);
                        }
                      }
                    },
                  );
                },
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.0,
                    mainAxisSpacing: 10),
                padding: EdgeInsets.all(10.0),
                itemCount: files.length,
              ),
              color: Colors.white)),
    ]);

    return Focus(
      autofocus: true,
      canRequestFocus: true,
      child: GestureDetector(
        child: content,
        onTap: () {
          _clearSelectedFiles();
          _resetRenamingFileIndex();
        },
      ),
      onKey: (node, event) {
        debugPrint("Outside key pressed: ${event.logicalKey.keyId}, ${event.logicalKey.keyLabel}");

        _isControlPressed = Platform.isMacOS ? event.isMetaPressed : event.isControlPressed;
        _isShiftPressed = event.isShiftPressed;

        if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
          _onEnterKeyPressed();
          return KeyEventResult.handled;
        }

        if (Platform.isMacOS) {
          if (event.isMetaPressed &&
              event.isKeyPressed(LogicalKeyboardKey.keyA)) {
            _onControlAndAPressed();
            return KeyEventResult.handled;
          }
        } else {
          if (event.isControlPressed &&
              event.isKeyPressed(LogicalKeyboardKey.keyA)) {
            _onControlAndAPressed();
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
    );
  }

  void _onEnterKeyPressed() {
    debugPrint("_onEnterKeyPressed.");
    if (_renamingFileIndex == -1) {
      if (_isSingleFileSelected()) {
        FileNode fileNode = AllFileManager.instance.selectedFiles().single;
        setState(() {
          _renamingFileIndex = AllFileManager.instance.indexOf(fileNode);
        });
      }
    } else {
      if (_isSingleFileSelected()) {
        FileNode fileNode = AllFileManager.instance
            .selectedFiles()
            .single;
        String oldFileName = fileNode.data.name;
        if (_newFileName != null && _newFileName?.trim() != "" && oldFileName != _newFileName) {
          _rename(fileNode, _newFileName!, () {
            setState(() {
              fileNode.data.name = _newFileName!;
              _resetRenamingFileIndex();
            });
          }, (error) {
            SmartDialog.showToast("文件重命名失败！");
          });
        }
      }

    }
  }

  bool _isSingleFileSelected() {
    var selectedFiles = AllFileManager.instance.selectedFiles();
    return selectedFiles.length == 1;
  }

  void _onControlAndAPressed() {
    debugPrint("_onControlAndAPressed.");
    _setAllSelected();
  }

  void _openMenu(Offset position, FileNode fileNode) {
    RenderBox? overlay =
        Overlay.of(context)?.context.findRenderObject() as RenderBox;

    String name = fileNode.data.name;

    showMenu(
        context: context,
        position: RelativeRect.fromSize(
            Rect.fromLTRB(position.dx, position.dy, 0, 0),
            overlay.size ?? Size(0, 0)),
        items: [
          PopupMenuItem(
              child: Text("打开"),
              onTap: () {
                _openFile(fileNode);
              }),
          PopupMenuItem(
              child: Text("重命名"),
              onTap: () {
                setState(() {
                  List<FileNode> allFiles = AllFileManager.instance.allFiles();
                  _renamingFileIndex = allFiles.indexOf(fileNode);
                });
              }),
          PopupMenuItem(
              child: Text("拷贝$name到电脑"),
              onTap: () {
                _openFilePicker(fileNode.data);
              }),
          PopupMenuItem(
              child: Text("删除"),
              onTap: () {
                Future<void>.delayed(
                    const Duration(),
                    () => _tryToDeleteFiles(
                        AllFileManager.instance.selectedFiles()));
              }),
        ]);
  }

  void _openFile(FileNode file) {
    if (file.data.isDir) {
      _tryToOpenDirectory(file, (files) {
        setState(() {
          AllFileManager.instance.updateSelectedFiles([]);
          AllFileManager.instance.updateFiles(files);
          AllFileManager.instance.updateCurrentDir(file);
          AllFileManager.instance.pushToStack(file);
          _updateBackBtnVisibility();
          _setDeleteBtnEnabled(AllFileManager.instance.selectedFileCount() > 0);
          updateBottomItemNum();
        });
      }, (error) {});
    } else {
      _openWithSystemApp(file.data);
    }
  }

  void _openFilePicker(FileItem fileItem) async {
    String? dir = await FilePicker.platform
        .getDirectoryPath(dialogTitle: "选择目录", lockParentWindow: true);

    if (null != dir) {
      debugPrint("Select directory: $dir");

      _showDownloadProgressDialog(fileItem);

      _downloadFile(fileItem, dir, () {
        _progressIndicatorDialog?.dismiss();
      }, (error) {
        SmartDialog.showToast(error);
      }, (current, total) {
        if (_progressIndicatorDialog?.isShowing == true) {
          if (current > 0) {
            setState(() {
              _progressIndicatorDialog?.title = "正在导出文件夹 ${fileItem.name}";
            });
          }

          setState(() {
            _progressIndicatorDialog?.subtitle =
                "${_convertToReadableSize(current)}/${_convertToReadableSize(total)}";
            _progressIndicatorDialog?.updateProgress(current / total);
          });
        }
      });
    }
  }

  void _showDownloadProgressDialog(FileItem fileItem) {
    if (null == _progressIndicatorDialog) {
      _progressIndicatorDialog = ProgressIndicatorDialog(context: context);
      _progressIndicatorDialog?.onCancelClick(() {
        _downloaderCore?.cancel();
        _progressIndicatorDialog?.dismiss();
      });
    }

    String title = fileItem.isDir ? "正在压缩中，请稍后..." : "正在准备中，请稍后...";
    _progressIndicatorDialog?.title = title;

    if (!_progressIndicatorDialog!.isShowing) {
      _progressIndicatorDialog!.show();
    }
  }

  String _convertToReadableSize(int size) {
    if (size < _KB_BOUND) {
      return "${size} bytes";
    }
    if (size >= _KB_BOUND && size < _MB_BOUND) {
      return "${(size / 1024).toStringAsFixed(1)} KB";
    }

    if (size >= _MB_BOUND && size <= _GB_BOUND) {
      return "${(size / 1024 / 1024).toStringAsFixed(1)} MB";
    }

    return "${(size / 1024 / 1024 / 1024).toStringAsFixed(1)} GB";
  }

  void _downloadFile(FileItem fileItem, String dir, void onSuccess(),
      void onError(String error), void onDownload(current, total)) async {
    String name = fileItem.name;

    if (fileItem.isDir) {
      name = "${name}.zip";
    }

    var options = DownloaderUtils(
        progress: ProgressImplementation(),
        file: File("$dir/$name"),
        onDone: () {
          debugPrint("Download ${fileItem.name} done");
          onSuccess.call();
        },
        progressCallback: (current, total) {
          debugPrint("total: $total");
          debugPrint(
              "Downloading ${fileItem.name}, percent: ${current / total}");
          onDownload.call(current, total);
        });

    String api =
        "${_URL_SERVER}/stream/file?path=${fileItem.folder}/${fileItem.name}";

    if (fileItem.isDir) {
      api =
          "${_URL_SERVER}/stream/dir?path=${fileItem.folder}/${fileItem.name}";
    }

    if (null == _downloaderCore) {
      _downloaderCore = await Flowder.download(api, options);
    } else {
      _downloaderCore?.download(api, options);
    }
  }

  bool _isMouseRightClicked(PointerDownEvent event) {
    return event.kind == PointerDeviceKind.mouse &&
        event.buttons == kSecondaryMouseButton;
  }

  void _tryToOpenDirectory(FileNode dir, Function(List<FileNode>) onSuccess,
      Function(String) onError) {
    debugPrint("_tryToOpenDirectory, dir: ${dir.data.folder}/${dir.data.name}");
    _getFiles((files) {
      List<FileNode> allFiles =
          files.map((e) => FileNode(dir, e, dir.level + 1)).toList();

      onSuccess.call(allFiles);
    }, (error) {
      debugPrint("_tryToOpenDirectory, error: $error");

      onError.call(error);
    }, path: "${dir.data.folder}/${dir.data.name}");
  }

  void _openWithSystemApp(FileItem fileItem) {
    SystemAppLauncher.openFile(fileItem);
  }

  void _backToRootDir() {
    _getFiles((files) {
      List<FileNode> allFiles = files.map((e) => FileNode(null, e, 0)).toList();

      setState(() {
        AllFileManager.instance.updateSelectedFiles([]);
        AllFileManager.instance.updateFiles(allFiles);
        AllFileManager.instance.updateCurrentDir(null);
        AllFileManager.instance.clearDirStack();
        _updateBackBtnVisibility();
        _setDeleteBtnEnabled(AllFileManager.instance.selectedFileCount() > 0);
        updateBottomItemNum();
      });
    }, (error) {
      debugPrint("_tryToOpenDirectory, error: $error");
    });
  }

  void _updateBackBtnVisibility() {
    var isRoot = AllFileManager.instance.isRoot();
    debugPrint("Icon mode, _updateBackBtnVisibility, isRoot: $isRoot");
    eventBus.fire(BackBtnVisibility(!isRoot, module: UIModule.Download));
  }

  void _getFiles(
      Function(List<FileItem> files) onSuccess, Function(String error) onError,
      {String? path = null}) {
    var url = Uri.parse("${_URL_SERVER}/file/list");
    http
        .post(url,
            headers: {"Content-Type": "application/json"},
            body: json.encode({"path": path == null ? "" : path}))
        .then((response) {
      if (response.statusCode != 200) {
        onError.call(response.reasonPhrase != null
            ? response.reasonPhrase!
            : "Unknown error");
      } else {
        var body = response.body;
        debugPrint("Get download file list, body: $body");

        final map = jsonDecode(body);
        final httpResponseEntity = ResponseEntity.fromJson(map);

        if (httpResponseEntity.isSuccessful()) {
          final data = httpResponseEntity.data as List<dynamic>;

          onSuccess.call(data
              .map((e) => FileItem.fromJson(e as Map<String, dynamic>))
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

  void _clearSelectedFiles() {
    setState(() {
      List<FileNode> selectedFiles = AllFileManager.instance.selectedFiles();
      selectedFiles.clear();
      AllFileManager.instance.updateSelectedFiles(selectedFiles);

      updateBottomItemNum();
      _setDeleteBtnEnabled(false);
    });
  }

  void _setDeleteBtnEnabled(bool enable) {
    eventBus.fire(UpdateDeleteBtnStatus(enable, module: UIModule.Download));
  }

  bool _isControlDown() {
    return _isControlPressed;
  }

  bool _isShiftDown() {
    return _isShiftPressed;
  }

  void _setFileSelected(FileNode fileItem) {
    debugPrint("Shift key down status: ${_isShiftDown()}");
    debugPrint("Control key down status: ${_isControlDown()}");

    List<FileNode> allFiles = AllFileManager.instance.allFiles();
    List<FileNode> selectedFiles = AllFileManager.instance.selectedFiles();

    if (!_isContainsFile(selectedFiles, fileItem)) {
      if (_isControlDown()) {
        setState(() {
          selectedFiles.add(fileItem);
          AllFileManager.instance.updateSelectedFiles(selectedFiles);
        });
      } else if (_isShiftDown()) {
        if (selectedFiles.length == 0) {
          setState(() {
            selectedFiles.add(fileItem);
            AllFileManager.instance.updateSelectedFiles(selectedFiles);
          });
        } else if (selectedFiles.length == 1) {
          int index = allFiles.indexOf(selectedFiles[0]);

          int current = allFiles.indexOf(fileItem);

          if (current > index) {
            setState(() {
              selectedFiles = allFiles.sublist(index, current + 1);
              AllFileManager.instance.updateSelectedFiles(selectedFiles);
            });
          } else {
            setState(() {
              selectedFiles = allFiles.sublist(current, index + 1);
              AllFileManager.instance.updateSelectedFiles(selectedFiles);
            });
          }
        } else {
          int maxIndex = 0;
          int minIndex = 0;

          for (int i = 0; i < selectedFiles.length; i++) {
            FileNode current = selectedFiles[i];
            int index = allFiles.indexOf(current);
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

          int current = allFiles.indexOf(fileItem);

          if (current >= minIndex && current <= maxIndex) {
            setState(() {
              selectedFiles = allFiles.sublist(current, maxIndex + 1);
              AllFileManager.instance.updateSelectedFiles(selectedFiles);
            });
          } else if (current < minIndex) {
            setState(() {
              selectedFiles = allFiles.sublist(current, maxIndex + 1);
              AllFileManager.instance.updateSelectedFiles(selectedFiles);
            });
          } else if (current > maxIndex) {
            setState(() {
              selectedFiles = allFiles.sublist(minIndex, current + 1);
              AllFileManager.instance.updateSelectedFiles(selectedFiles);
            });
          }
        }
      } else {
        setState(() {
          selectedFiles.clear();
          selectedFiles.add(fileItem);
          AllFileManager.instance.updateSelectedFiles(selectedFiles);
        });
      }
    } else {
      debugPrint("It's already contains this image, id: ${fileItem.data.name}");

      if (_isControlDown()) {
        setState(() {
          selectedFiles.remove(fileItem);
          AllFileManager.instance.updateSelectedFiles(selectedFiles);
        });
      } else if (_isShiftDown()) {
        setState(() {
          selectedFiles.remove(fileItem);
          AllFileManager.instance.updateSelectedFiles(selectedFiles);
        });
      } else {
        setState(() {
          selectedFiles.clear();
          selectedFiles.add(fileItem);
          AllFileManager.instance.updateSelectedFiles(selectedFiles);
        });
      }
    }

    _setDeleteBtnEnabled(selectedFiles.length > 0);
    updateBottomItemNum();

    int currentIndex = AllFileManager.instance.indexOf(fileItem);
    if (currentIndex != _renamingFileIndex && _renamingFileIndex != -1) {
      _resetRenamingFileIndex();
    }
  }

  void _rename(FileNode file, String newName, Function() onSuccess,
      Function(String error) onError) {
    var url = Uri.parse("${_URL_SERVER}/file/rename");
    http
        .post(url,
            headers: {"Content-Type": "application/json"},
            body: json.encode({
              "folder": file.data.folder,
              "file": file.data.name,
              "newName": newName,
              "isDir": file.data.isDir
            }))
        .then((response) {
      if (response.statusCode != 200) {
        onError.call(response.reasonPhrase != null
            ? response.reasonPhrase!
            : "Unknown error");
      } else {
        var body = response.body;
        debugPrint("_rename, body: $body");

        final map = jsonDecode(body);
        final httpResponseEntity = ResponseEntity.fromJson(map);

        if (httpResponseEntity.isSuccessful()) {
          onSuccess.call();
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

  void _resetRenamingFileIndex() {
    setState(() {
      _renamingFileIndex = -1;
      _newFileName = null;
    });
  }

  void _deleteFiles(List<FileNode> files, Function() onSuccess,
      Function(String error) onError) {
    var url = Uri.parse("${_URL_SERVER}/file/deleteMulti");
    http
        .post(url,
            headers: {"Content-Type": "application/json"},
            body: json.encode({
              "paths": files
                  .map((node) => "${node.data.folder}/${node.data.name}")
                  .toList()
            }))
        .then((response) {
      if (response.statusCode != 200) {
        onError.call(response.reasonPhrase != null
            ? response.reasonPhrase!
            : "Unknown error");
      } else {
        var body = response.body;
        debugPrint("_deleteFiles, body: $body");

        final map = jsonDecode(body);
        final httpResponseEntity = ResponseEntity.fromJson(map);

        if (httpResponseEntity.isSuccessful()) {
          onSuccess.call();
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

  void _showConfirmDialog(
      String content,
      String desc,
      String negativeText,
      String positiveText,
      Function(BuildContext context) onPositiveClick,
      Function(BuildContext context) onNegativeClick) {
    Dialog dialog = ConfirmDialogBuilder()
        .content(content)
        .desc(desc)
        .negativeBtnText(negativeText)
        .positiveBtnText(positiveText)
        .onPositiveClick(onPositiveClick)
        .onNegativeClick(onNegativeClick)
        .build();

    showDialog(
        context: context,
        builder: (context) {
          return dialog;
        },
        barrierDismissible: false);
  }

  void _tryToDeleteFiles(List<FileNode> files) {
    _showConfirmDialog("确定删除这${files.length}个项目吗？", "注意：删除的文件无法恢复", "取消", "删除",
        (context) {
      Navigator.of(context, rootNavigator: true).pop();

      SmartDialog.showLoading();

      _deleteFiles(files, () {
        SmartDialog.dismiss();

        setState(() {
          List<FileNode> allFiles = AllFileManager.instance.allFiles();
          files.forEach((file) {
            if (allFiles.contains(file)) {
              allFiles.remove(file);
            }
          });
          AllFileManager.instance.updateFiles(allFiles);
          AllFileManager.instance.clearSelectedFiles();
        });
      }, (error) {
        SmartDialog.dismiss();

        SmartDialog.showToast(error);
      });
    }, (context) {
      Navigator.of(context, rootNavigator: true).pop();
    });
  }

  void rebuild() {
    setState(() {
      debugPrint("强制刷新页面");
    });
  }

  bool _isContainsFile(List<FileNode> files, FileNode current) {
    for (FileNode file in files) {
      if (file.data.folder == current.data.folder &&
          file.data.name == current.data.name) {
        return true;
      }
    }

    return false;
  }

  void updateFiles(List<FileItem> files) {}

  void updateSelectedFiles(List<FileItem> files) {}

  bool _isAudio(String extension) {
    if (extension.toLowerCase() == "mp3") return true;
    if (extension.toLowerCase() == "wav") return true;

    return false;
  }

  bool _isTextFile(String extension) {
    if (extension.toLowerCase() == "txt") return true;

    return false;
  }

  bool _isImageFile(String extension) {
    if (extension.toLowerCase() == "jpg") return true;
    if (extension.toLowerCase() == "jpeg") return true;
    if (extension.toLowerCase() == "png") return true;

    return false;
  }

  bool _isDoc(String extension) {
    if (_isAudio(extension)) return false;
    if (_isTextFile(extension)) return false;

    return true;
  }

  void updateBottomItemNum() {
    eventBus.fire(UpdateBottomItemNum(AllFileManager.instance.totalFileCount(),
        AllFileManager.instance.selectedFileCount(),
        module: UIModule.Download));
  }

  @override
  bool get wantKeepAlive => false;

  @override
  void deactivate() {
    super.deactivate();

    _unRegisterEventBus();
    debugPrint("_DownloadIconModeState: deactivate, instance: $this");
  }

  @override
  void dispose() {
    super.dispose();
    _downloaderCore?.cancel();
  }
}
