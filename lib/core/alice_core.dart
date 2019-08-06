import 'dart:convert';
import 'dart:io';

import 'package:alice/model/alice_http_error.dart';
import 'package:alice/ui/alert_helper.dart';
import 'package:alice/ui/alice_calls_list_screen.dart';
import 'package:alice/model/alice_http_call.dart';
import 'package:alice/model/alice_http_response.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info/package_info.dart';
import 'package:open_file/open_file.dart';

class AliceCore {
  GlobalKey<NavigatorState> _navigatorKey;
  JsonEncoder _encoder = new JsonEncoder.withIndent('  ');

  List<AliceHttpCall> calls;
  PublishSubject<int> changesSubject;
  PublishSubject<AliceHttpCall> callUpdateSubject;

  AliceCore(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    calls = List();
    changesSubject = PublishSubject();
    callUpdateSubject = PublishSubject();
  }

  dispose() {
    changesSubject.close();
    callUpdateSubject.close();
  }

  void navigateToCallListScreen() {
    var context = getContext();
    if (context == null) {
      print(
          "Cant start Alice HTTP Inspector. Please add NavigatorKey to your application");
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AliceCallsListScreen(this)),
    );
  }

  BuildContext getContext() {
    if (_navigatorKey != null &&
        _navigatorKey.currentState != null &&
        _navigatorKey.currentState.overlay != null) {
      return _navigatorKey.currentState.overlay.context;
    } else {
      return null;
    }
  }

  void addCall(AliceHttpCall call) {
    calls.add(call);
  }

  void addError(AliceHttpError error, int requestId) {
    AliceHttpCall selectedCall = _selectCall(requestId);

    if (selectedCall == null) {
      print("Selected call is null");
      return;
    }

    selectedCall.error = error;
    changesSubject.sink.add(requestId);
    callUpdateSubject.sink.add(selectedCall);
  }

  void addResponse(AliceHttpResponse response, int requestId) {
    AliceHttpCall selectedCall = _selectCall(requestId);

    if (selectedCall == null) {
      print("Selected call is null");
      return;
    }
    selectedCall.loading = false;
    selectedCall.response = response;
    selectedCall.duration = response.time.millisecondsSinceEpoch -
        selectedCall.request.time.millisecondsSinceEpoch;

    changesSubject.sink.add(requestId);
    callUpdateSubject.sink.add(selectedCall);
  }

  void removeCalls() {
    calls = List();
    changesSubject.sink.add(0);
  }

  AliceHttpCall _selectCall(int requestId) {
    AliceHttpCall requestedCall;
    calls.forEach((call) {
      if (call.id == requestId) {
        requestedCall = call;
      }
    });
    return requestedCall;
  }

  void saveHttpRequests(BuildContext context) {
    _checkPermissions(context);
  }

  void _checkPermissions(BuildContext context) async {
    PermissionStatus permission = await PermissionHandler()
        .checkPermissionStatus(PermissionGroup.storage);
    if (permission == PermissionStatus.granted) {
      _saveToFile(context);
    } else {
      Map<PermissionGroup, PermissionStatus> permissions =
          await PermissionHandler()
              .requestPermissions([PermissionGroup.storage]);
      if (permissions.containsKey(PermissionGroup.storage) &&
          permissions[PermissionGroup.storage] == PermissionStatus.granted) {
        _saveToFile(context);
      } else {
        AlertHelper.showAlert(context, "Permission error",
            "Permission not granted. Couldn't save logs.");
      }
    }
  }

  Future<String> _saveToFile(BuildContext context) async {
    try {
      if (calls.length == 0) {
        AlertHelper.showAlert(context, "Error", "There are no logs to save");
        return "";
      }

      Directory externalDir = await getExternalStorageDirectory();
      String fileName =
          "alice_log_${DateTime.now().millisecondsSinceEpoch}.txt";
      File file = File(externalDir.path.toString() + "/" + fileName);
      file.createSync();
      IOSink sink = file.openWrite(mode: FileMode.append);

      var packageInfo = await PackageInfo.fromPlatform();
      sink.write("Alice - HTTP Inspector\n");
      sink.write("App name:  ${packageInfo.appName}\n");
      sink.write("Package: ${packageInfo.packageName}\n");
      sink.write("Version: ${packageInfo.version}\n");
      sink.write("Build number: ${packageInfo.buildNumber}\n");
      sink.write("Generated: " + DateTime.now().toIso8601String() + "\n");
      calls.forEach((AliceHttpCall call) {
        sink.write("\n");
        sink.write("==============================================\n");
        sink.write("Id: ${call.id}\n");
        sink.write("==============================================\n");
        sink.write("Server: ${call.server} \n");
        sink.write("Method: ${call.method} \n");
        sink.write("Endpoint: ${call.endpoint} \n");
        sink.write("Client: ${call.client} \n");
        sink.write("Duration ${call.duration} ms\n");
        sink.write("Secured connection: ${call.duration}\n");
        sink.write("Completed: ${!call.loading} \n");
        sink.write("Request time: ${call.request.time}\n");
        sink.write("Request content type: ${call.request.contentType}\n");
        sink.write(
            "Request cookies: ${_encoder.convert(call.request.cookies)}\n");
        sink.write(
            "Request headers: ${_encoder.convert(call.request.headers)}\n");
        sink.write("Request size: ${call.request.size} bytes\n");
        sink.write("Request body: ${_encoder.convert(call.request.body)}\n");
        sink.write("Response time: ${call.response.time}\n");
        sink.write("Response status: ${call.response.status}\n");
        sink.write("Response size: ${call.response.size} bytes\n");
        sink.write(
            "Response headers: ${_encoder.convert(call.response.headers)}\n");
        sink.write("Response body: ${_encoder.convert(call.response.body)}\n");
        if (call.error != null) {
          sink.write("Error: ${call.error.error}\n");
          if (call.error.stackTrace != null) {
            sink.write("Error stacktrace: ${call.error.stackTrace}\n");
          }
        }
        sink.write("==============================================\n");
        sink.write("\n");
      });

      await sink.flush();
      await sink.close();
      AlertHelper.showAlert(
          context, "Success", "Sucessfully saved logs in ${file.path}",
          secondButtonTitle: "View file",
          secondButtonAction: () => OpenFile.open(file.path));
      return file.path;
    } catch (exception) {
      AlertHelper.showAlert(
          context, "Error", "Failed to save http calls to file");
      print(exception);
    }

    return "";
  }

}
