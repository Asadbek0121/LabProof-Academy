import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void registerOpenSupportSheet(void Function() callback) {
  try {
    globalContext.setProperty('openSupportSheet'.toJS, callback.toJS);
  } catch (_) {}
}

void registerTriggerSupportSubmit(
  void Function(String subject, String body) callback,
) {
  try {
    globalContext.setProperty(
      'triggerSupportSubmit'.toJS,
      ((JSString subject, JSString body) {
        callback(subject.toDart, body.toDart);
      }).toJS,
    );
  } catch (_) {}
}
