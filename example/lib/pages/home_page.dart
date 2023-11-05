// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:ui';

import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/extensions.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:flutter_quill_extensions/presentation/embeds/embed_types/image.dart';
import 'package:flutter_quill_extensions/presentation/embeds/embed_types/video.dart';
import 'package:flutter_quill_extensions/presentation/models/config/toolbar/buttons/video.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../universal_ui/universal_ui.dart';
import '../widgets/time_stamp_embed_widget.dart';
import 'read_only_page.dart';

enum _SelectionType {
  none,
  word,
  // line,
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final QuillController _controller;
  late final Future<void> _loadDocumentFromAssetsFuture;
  final FocusNode _focusNode = FocusNode();
  Timer? _selectAllTimer;
  _SelectionType _selectionType = _SelectionType.none;

  @override
  void dispose() {
    _selectAllTimer?.cancel();
    // Dispose the controller to free resources
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDocumentFromAssetsFuture = _loadFromAssets();
  }

  Future<void> _loadFromAssets() async {
    try {
      final result = await rootBundle.loadString(isDesktop()
          ? 'assets/sample_data_nomedia.json'
          : 'assets/sample_data.json');
      final doc = Document.fromJson(jsonDecode(result));
      _controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (error) {
      final doc = Document()..insert(0, 'Empty asset');
      _controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadDocumentFromAssetsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Flutter Quill',
            ),
            actions: [
              IconButton(
                onPressed: () => _insertTimeStamp(
                  _controller,
                  DateTime.now().toString(),
                ),
                icon: const Icon(Icons.add_alarm_rounded),
              ),
              IconButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: Text(
                      _controller.document.toPlainText(
                        [
                          ...FlutterQuillEmbeds.editorBuilders(),
                          TimeStampEmbedBuilderWidget()
                        ],
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.text_fields_rounded),
              )
            ],
          ),
          drawer: Drawer(
            child: _buildMenuBar(context),
          ),
          body: _buildWelcomeEditor(context),
        );
      },
    );
  }

  bool _onTripleClickSelection() {
    final controller = _controller;

    _selectAllTimer?.cancel();
    _selectAllTimer = null;

    // If you want to select all text after paragraph, uncomment this line
    // if (_selectionType == _SelectionType.line) {
    //   final selection = TextSelection(
    //     baseOffset: 0,
    //     extentOffset: controller.document.length,
    //   );

    //   controller.updateSelection(selection, ChangeSource.REMOTE);

    //   _selectionType = _SelectionType.none;

    //   return true;
    // }

    if (controller.selection.isCollapsed) {
      _selectionType = _SelectionType.none;
    }

    if (_selectionType == _SelectionType.none) {
      _selectionType = _SelectionType.word;
      _startTripleClickTimer();
      return false;
    }

    if (_selectionType == _SelectionType.word) {
      final child = controller.document.queryChild(
        controller.selection.baseOffset,
      );
      final offset = child.node?.documentOffset ?? 0;
      final length = child.node?.length ?? 0;

      final selection = TextSelection(
        baseOffset: offset,
        extentOffset: offset + length,
      );

      controller.updateSelection(selection, ChangeSource.remote);

      // _selectionType = _SelectionType.line;

      _selectionType = _SelectionType.none;

      _startTripleClickTimer();

      return true;
    }

    return false;
  }

  void _startTripleClickTimer() {
    _selectAllTimer = Timer(const Duration(milliseconds: 900), () {
      _selectionType = _SelectionType.none;
    });
  }

  QuillEditor get quillEditor {
    if (kIsWeb) {
      return QuillEditor(
        focusNode: _focusNode,
        scrollController: ScrollController(),
        configurations: QuillEditorConfigurations(
          placeholder: 'Add content',
          readOnly: false,
          scrollable: true,
          autoFocus: false,
          expands: false,
          padding: EdgeInsets.zero,
          onTapUp: (details, p1) {
            return _onTripleClickSelection();
          },
          customStyles: const DefaultStyles(
            h1: DefaultTextBlockStyle(
              TextStyle(
                fontSize: 32,
                height: 1.15,
                fontWeight: FontWeight.w300,
              ),
              VerticalSpacing(16, 0),
              VerticalSpacing(0, 0),
              null,
            ),
            sizeSmall: TextStyle(fontSize: 9),
          ),
          embedBuilders: [
            ...defaultEmbedBuildersWeb,
            TimeStampEmbedBuilderWidget()
          ],
        ),
      );
    }
    return QuillEditor(
      configurations: QuillEditorConfigurations(
        placeholder: 'Add content',
        readOnly: false,
        autoFocus: false,
        enableSelectionToolbar: isMobile(),
        expands: false,
        padding: EdgeInsets.zero,
        onImagePaste: _onImagePaste,
        onTapUp: (details, p1) {
          return _onTripleClickSelection();
        },
        customStyles: const DefaultStyles(
          h1: DefaultTextBlockStyle(
            TextStyle(
              fontSize: 32,
              height: 1.15,
              fontWeight: FontWeight.w300,
            ),
            VerticalSpacing(16, 0),
            VerticalSpacing(0, 0),
            null,
          ),
          sizeSmall: TextStyle(fontSize: 9),
          subscript: TextStyle(
            fontFamily: 'SF-UI-Display',
            fontFeatures: [FontFeature.subscripts()],
          ),
          superscript: TextStyle(
            fontFamily: 'SF-UI-Display',
            fontFeatures: [FontFeature.superscripts()],
          ),
        ),
        embedBuilders: [
          ...FlutterQuillEmbeds.editorBuilders(),
          TimeStampEmbedBuilderWidget()
        ],
      ),
      scrollController: ScrollController(),
      focusNode: _focusNode,
    );
  }

  QuillToolbar get quillToolbar {
    if (kIsWeb) {
      return QuillToolbar(
        configurations: QuillToolbarConfigurations(
          embedButtons: FlutterQuillEmbeds.toolbarButtons(
            imageButtonOptions: QuillToolbarImageButtonOptions(
              imageButtonConfigurations: QuillToolbarImageConfigurations(
                onImageInsertedCallback: (image) async {
                  _onImagePickCallback(File(image));
                },
              ),
              // webImagePickImpl: _webImagePickImpl,
            ),
          ),
          buttonOptions: QuillToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(
              afterButtonPressed: _focusNode.requestFocus,
            ),
          ),
        ),
        // afterButtonPressed: _focusNode.requestFocus,
      );
    }
    if (_isDesktop()) {
      return QuillToolbar(
        configurations: QuillToolbarConfigurations(
          embedButtons: FlutterQuillEmbeds.toolbarButtons(
            imageButtonOptions: QuillToolbarImageButtonOptions(
              imageButtonConfigurations: QuillToolbarImageConfigurations(
                onImageInsertedCallback: (image) async {
                  _onImagePickCallback(File(image));
                },
              ),
              // onImagePickCallback: _onImagePickCallback,
              // filePickImpl: openFileSystemPickerForDesktop,
            ),
          ),
          showAlignmentButtons: true,
          buttonOptions: QuillToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(
              afterButtonPressed: _focusNode.requestFocus,
            ),
          ),
        ),
        // afterButtonPressed: _focusNode.requestFocus,
      );
    }
    return QuillToolbar(
      configurations: QuillToolbarConfigurations(
        embedButtons: FlutterQuillEmbeds.toolbarButtons(
          videoButtonOptions: QuillToolbarVideoButtonOptions(
            videoConfigurations: QuillToolbarVideoConfigurations(
              onVideoInsertedCallback: (video) =>
                  _onVideoPickCallback(File(video)),
            ),
          ),
          imageButtonOptions: QuillToolbarImageButtonOptions(
            imageButtonConfigurations: QuillToolbarImageConfigurations(
              onImageInsertedCallback: (image) async {
                _onImagePickCallback(File(image));
              },
            ),
            // provide a callback to enable picking images from device.
            // if omit, "image" button only allows adding images from url.
            // same goes for videos.
            // onImagePickCallback: _onImagePickCallback,
            // uncomment to provide a custom "pick from" dialog.
            // mediaPickSettingSelector: _selectMediaPickSetting,
            // uncomment to provide a custom "pick from" dialog.
            // cameraPickSettingSelector: _selectCameraPickSetting,
          ),
          // videoButtonOptions: QuillToolbarVideoButtonOptions(
          //   onVideoPickCallback: _onVideoPickCallback,
          // ),
        ),
        showAlignmentButtons: true,
        buttonOptions: QuillToolbarButtonOptions(
          base: QuillToolbarBaseButtonOptions(
            afterButtonPressed: _focusNode.requestFocus,
          ),
        ),
      ),
      // afterButtonPressed: _focusNode.requestFocus,
    );
  }

  Widget _buildWelcomeEditor(BuildContext context) {
    // BUG in web!! should not releated to this pull request
    ///
    ///══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞═════════════════════
    ///══════════════════════════════════════
    // The following bool object was thrown building MediaQuery
    //(MediaQueryData(size: Size(769.0, 1205.0),
    // devicePixelRatio: 1.0, textScaleFactor: 1.0, platformBrightness:
    //Brightness.dark, padding:
    // EdgeInsets.zero, viewPadding: EdgeInsets.zero, viewInsets:
    // EdgeInsets.zero,
    // systemGestureInsets:
    // EdgeInsets.zero, alwaysUse24HourFormat: false, accessibleNavigation:
    // false,
    // highContrast: false,
    // disableAnimations: false, invertColors: false, boldText: false,
    //navigationMode: traditional,
    // gestureSettings: DeviceGestureSettings(touchSlop: null), displayFeatures:
    // []
    // )):
    //   false
    // The relevant error-causing widget was:
    //   SafeArea
    ///
    ///
    return SafeArea(
      child: QuillProvider(
        configurations: QuillConfigurations(
          controller: _controller,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              flex: 15,
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: quillEditor,
              ),
            ),
            kIsWeb
                ? Expanded(
                    child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: quillToolbar,
                  ))
                : Container(
                    child: quillToolbar,
                  )
          ],
        ),
      ),
    );
  }

  bool _isDesktop() => !kIsWeb && !Platform.isAndroid && !Platform.isIOS;

  Future<String?> openFileSystemPickerForDesktop(BuildContext context) async {
    return await FilesystemPicker.open(
      context: context,
      rootDirectory: await getApplicationDocumentsDirectory(),
      fsType: FilesystemType.file,
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );
  }

  // Renders the image picked by imagePicker from local file storage
  // You can also upload the picked image to any server (eg : AWS s3
  // or Firebase) and then return the uploaded image URL.
  Future<String> _onImagePickCallback(File file) async {
    // Copies the picked file from temporary cache to applications directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final copiedFile =
        await file.copy('${appDocDir.path}/${path.basename(file.path)}');
    return copiedFile.path.toString();
  }

  // Future<String?> _webImagePickImpl(
  //     OnImagePickCallback onImagePickCallback) async {
  //   final result = await FilePicker.platform.pickFiles();
  //   if (result == null) {
  //     return null;
  //   }

  //   // Take first, because we don't allow picking multiple files.
  //   final fileName = result.files.first.name;
  //   final file = File(fileName);

  //   return onImagePickCallback(file);
  // }

  // Renders the video picked by imagePicker from local file storage
  // You can also upload the picked video to any server (eg : AWS s3
  // or Firebase) and then return the uploaded video URL.
  Future<String> _onVideoPickCallback(File file) async {
    // Copies the picked file from temporary cache to applications directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final copiedFile =
        await file.copy('${appDocDir.path}/${path.basename(file.path)}');
    return copiedFile.path.toString();
  }

  // // ignore: unused_element
  // Future<MediaPickSetting?> _selectMediaPickSetting(BuildContext context) =>
  //     showDialog<MediaPickSetting>(
  //       context: context,
  //       builder: (ctx) => AlertDialog(
  //         contentPadding: EdgeInsets.zero,
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             TextButton.icon(
  //               icon: const Icon(Icons.collections),
  //               label: const Text('Gallery'),
  //               onPressed: () => Navigator.pop(ctx,
  // MediaPickSetting.gallery),
  //             ),
  //             TextButton.icon(
  //               icon: const Icon(Icons.link),
  //               label: const Text('Link'),
  //               onPressed: () => Navigator.pop(ctx, MediaPickSetting.link),
  //             )
  //           ],
  //         ),
  //       ),
  //     );

  // // ignore: unused_element
  // Future<MediaPickSetting?> _selectCameraPickSetting(BuildContext context) =>
  //     showDialog<MediaPickSetting>(
  //       context: context,
  //       builder: (ctx) => AlertDialog(
  //         contentPadding: EdgeInsets.zero,
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             TextButton.icon(
  //               icon: const Icon(Icons.camera),
  //               label: const Text('Capture a photo'),
  //               onPressed: () => Navigator.pop(ctx, MediaPickSetting.camera),
  //             ),
  //             TextButton.icon(
  //               icon: const Icon(Icons.video_call),
  //               label: const Text('Capture a video'),
  //               onPressed: () => Navigator.pop(ctx, MediaPickSetting.video),
  //             )
  //           ],
  //         ),
  //       ),
  //     );

  Widget _buildMenuBar(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Divider(
          thickness: 2,
          indent: size.width * 0.1,
          endIndent: size.width * 0.1,
        ),
        ListTile(
          title: const Center(
              child: Text(
            'Read only demo',
          )),
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: _readOnly,
        ),
        Divider(
          thickness: 2,
          indent: size.width * 0.1,
          endIndent: size.width * 0.1,
        ),
      ],
    );
  }

  void _readOnly() {
    Navigator.pop(super.context);
    Navigator.push(
      super.context,
      MaterialPageRoute(
        builder: (context) => ReadOnlyPage(),
      ),
    );
  }

  Future<String> _onImagePaste(Uint8List imageBytes) async {
    // Saves the image to applications directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final file = await File(
      '${appDocDir.path}/${path.basename('${DateTime.now().millisecondsSinceEpoch}.png')}',
    ).writeAsBytes(imageBytes, flush: true);
    return file.path.toString();
  }

  static void _insertTimeStamp(QuillController controller, String string) {
    controller.document.insert(controller.selection.extentOffset, '\n');
    controller.updateSelection(
      TextSelection.collapsed(
        offset: controller.selection.extentOffset + 1,
      ),
      ChangeSource.local,
    );

    controller.document.insert(
      controller.selection.extentOffset,
      TimeStampEmbed(string),
    );

    controller.updateSelection(
      TextSelection.collapsed(
        offset: controller.selection.extentOffset + 1,
      ),
      ChangeSource.local,
    );

    controller.document.insert(controller.selection.extentOffset, ' ');
    controller.updateSelection(
      TextSelection.collapsed(
        offset: controller.selection.extentOffset + 1,
      ),
      ChangeSource.local,
    );

    controller.document.insert(controller.selection.extentOffset, '\n');
    controller.updateSelection(
      TextSelection.collapsed(
        offset: controller.selection.extentOffset + 1,
      ),
      ChangeSource.local,
    );
  }
}
