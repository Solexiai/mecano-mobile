import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:image_picker/image_picker.dart';
import '../../lib/services/booking/booking_photos.dart';
import '../../lib/services/booking/booking_photo_preparation.dart';
import '../../lib/services/booking/booking_photo_encoder_web.dart' as encoder;

void main() {
  final button = web.HTMLButtonElement()..id='select-photo'..textContent='Select photo';
  final raw = web.HTMLButtonElement()..id='select-raw'..textContent='Select and inspect stages';
  final result = web.HTMLDivElement()..id='result'..textContent='READY';
  web.document.body!.append(button);
  web.document.body!.append(raw);
  web.document.body!.append(result);
  button.onclick = ((web.Event event) {
    result.textContent='PICKING';
    selectBookingPhotoUpload().then((upload) {
      result.textContent=jsonEncode({'ok':upload!=null,'uploadInvoked':false});
    }).catchError((Object error, StackTrace stack) {
      result.textContent=jsonEncode({'ok':false,'error':error.toString(),'reason':error is BookingPhotoFormatException ? error.reason.name : null,'stack':stack.toString()});
    });
  }).toJS;
  raw.onclick = ((web.Event event) { () async {
    final stages=<String,Object?>{};
    result.textContent='PICKING';
    try {
      final file=await ImagePicker().pickImage(source:ImageSource.gallery,imageQuality:null);
      if(file==null) {result.textContent='CANCELLED';return;}
      stages['picker']={'name':file.name,'mime':file.mimeType,'size':await file.length()};
      final bytes=await file.readAsBytes();
      stages['input']={'bytes':bytes.length,'magicMime':bookingPhotoMime(bytes)};
      try {
        final prepared=await prepareBookingPhotoBytes(bytes);
        stages['prepared']={'bytes':prepared.length,'mime':bookingPhotoMime(prepared)};
      } catch(error,stack) {
        stages['prepareError']=error.toString();
        stages['prepareStack']=stack.toString();
        try {
          final b=await encoder.encodeBookingPhoto(bytes,bookingPhotoMime(bytes)??'image/jpeg');
          stages['directEncoder']={'bytes':b.length,'mime':bookingPhotoMime(b)};
        } catch(error,stack) { stages['encoderError']=error.toString(); stages['encoderStack']=stack.toString(); }
      }
    } catch(error,stack) {stages['error']=error.toString();stages['stack']=stack.toString();}
    result.textContent=jsonEncode(stages);
    }();
  }).toJS;
}
