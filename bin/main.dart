import 'dart:io';
import 'package:at_find_api/at_find_api.dart';
import 'package:at_find_api/config_util.dart';

void main(List<String> params) async {
  print('AtFindApi main starting up...');
  // ignore: omit_local_variable_types
  String certificateChain = ConfigUtil.getYaml()['security']['certificateChainLocation'];
  // ignore: omit_local_variable_types
  String serverKey = ConfigUtil.getYaml()['security']['privateKeyLocation'];
  var targetFile = File(certificateChain);
  var fileExists = await targetFile.exists();
  var securityContext;
  if(fileExists) {
    securityContext = SecurityContext()
      ..useCertificateChain(certificateChain)
      ..usePrivateKey(serverKey);
  }
  try {
    int port;
    if(params.isNotEmpty) port = int.parse(params[0]);
    port ??= 443;
    print('AtFindApi starting up...');
    var address = InternetAddress.anyIPv4;
    var atFindApi =  AtFindApi();
    var serverRequests = await atFindApi.init(address, port, securityContext);
    await for (HttpRequest request in serverRequests) {
      atFindApi.handleRequest(request);
    }
  } catch(error) {
    print(error.toString());
  }
}
