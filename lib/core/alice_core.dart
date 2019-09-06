import 'package:alice/model/alice_http_call.dart';
import 'package:alice/model/alice_http_error.dart';
import 'package:alice/model/alice_http_response.dart';
import 'package:alice/ui/alice_calls_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class AliceCore {
  GlobalKey<NavigatorState> _navigatorKey;
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
}
