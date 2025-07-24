import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String?> uploadToImageKit(File imageFile) async {
  const imageKitUploadUrl = 'https://upload.imagekit.io/api/v1/files/upload';
  const imageKitPublicKey = 'public_TSyHm1tXMTquu1fCvdnBav15zbM=';
  const folderName = 'meals';

  final request = http.MultipartRequest('POST', Uri.parse(imageKitUploadUrl))
    ..fields['fileName'] = 'meal_${DateTime.now().millisecondsSinceEpoch}.jpg'
    ..fields['publicKey'] = imageKitPublicKey
    ..fields['folder'] = folderName
    ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

  final response = await request.send();

  if (response.statusCode == 200) {
    final resData = await response.stream.bytesToString();
    final jsonData = json.decode(resData);
    return jsonData['url'];
  } else {
    print('ImageKit upload failed: ${response.statusCode}');
    return null;
  }
}
