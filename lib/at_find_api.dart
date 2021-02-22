import 'dart:convert';
import 'dart:io';
import 'package:at_find_api/config_util.dart';
import 'package:at_utils/at_utils.dart';
import 'package:at_lookup/at_lookup.dart';
import 'package:http_server/http_server.dart';
import 'package:http/http.dart' as http;
import 'package:base2e15/base2e15.dart';

class AtFindApi {
  final bool _debug = true;
  final bool _verbose = true;

  static final root_url = ConfigUtil.getYaml()['root_server']['host'];
  static final root_port = ConfigUtil.getYaml()['root_server']['port'];

  Future init(InternetAddress address, int port,
      SecurityContext securityContext) async {
    print('AtFindApi listening on $address port: $port');
    if (securityContext == null) {
      final server = await HttpServer.bind(address, port);
      server.defaultResponseHeaders.remove('x-frame-options', 'SAMEORIGIN');
      return server;
    } else {
      final server =
          await HttpServer.bindSecure(address, port, securityContext);
      server.defaultResponseHeaders.remove('x-frame-options', 'SAMEORIGIN');
      return server;
    }
  }

  void handleRequest(HttpRequest request) async {
    try {
      if (_debug) print(request.method);
      if (request.method.toLowerCase() == 'get' ||
          request.method.toLowerCase() == 'head') {
        var atp;
        var action;
        final params = request.uri.queryParameters;
        if (_debug) print('handleRequest received params: $params');
        atp = params['atp'];
        final pathSegments = request.uri.pathSegments;
        if (_debug) print('received pathSegments: $pathSegments');
        if (pathSegments.isNotEmpty && params.isNotEmpty) {
          if (_debug) print('handleRequest received pathSegments and params');
          action = pathSegments[0];
          switch (action) {
            case 'api':
              await _dataHandler(request, atp);
              break;
            case 'status':
              await _statusHandler(request, atp);
              break;
            case 'twitter':
              await _twitterdataHandler(request, params['twitterhandle']);
              break;
            case 'insta':
              await _instadataHandler(request, params['instahandle']);
              break;
//            case 'embed':
//              await _embedHandler(request, atp);
//              break;
            default:
              throw Exception('handleRequest: The action: "' +
                  action +
                  '" was not recognized.');
          }
        } else if (pathSegments.isNotEmpty) {
          if (_debug)
            print('handleRequest received only pathSegments: $pathSegments.');
          if (pathSegments[0] == 'health') {
            await _healthHandler(request);
          }
          // this parses request urls of the form:
          // https://localhost/status/@colin or
          // https://localhost/status/colin or
          else if (pathSegments[0] == 'status' && pathSegments.length > 1) {
            // assume the arp is segment [1]
            var atsign = pathSegments[1];
            atsign = atsign.startsWith('@') ? atsign : '@' + atsign;
            atsign = AtUtils.fixAtSign(atsign);
            await _statusHandler(request, atsign);
          } else if (pathSegments[0] == 'profile') {
//            var resource = '';

          } else {
            var resource = '';
            for (var i = 0; i < pathSegments.length; i++) {
              resource += '/' + pathSegments[i];
            }
            await _contentHandler(request, resource);
          }
        } else {
          print(
              'handleRequest no pathSegments or params found, sending to index.html.');
          await _contentHandler(request, '/index.html');
        }
      } else {
        await request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..write('Unsupported request: ${request.method}.');
        print('only GET or HEAD methods are allowed.');
//        await request.response.flush();
        await request.response.close();
//        throw Exception('only GET methods are allowed.');
      }
    } on Exception catch (exception) {
      print(exception.toString());
      await request.response
        ..statusCode = HttpStatus.internalServerError;
//      await request.response.flush();
      await request.response.close();
    } catch (error) {
      print(error.toString());
      await request.response
        ..statusCode = HttpStatus.internalServerError;
//      await request.response.flush();
      await request.response.close();
    }
  }

  void _twitterdataHandler(request, String twitterhandle) async {
    if (twitterhandle != null) {
      final response = await http.get(
        'https://api.twitter.com/1.1/statuses/user_timeline.json?screen_name=' +
            twitterhandle +
            '&count=30',
        headers: {
          HttpHeaders.authorizationHeader:
              'Bearer AAAAAAAAAAAAAAAAAAAAABMZEAEAAAAAuhF5liIkoc9UyhDEiXffcCjRzeo%3DJte2eVKdOZVuiy6ZRnJSmNU01ieAYx0vyZYy5XQCaCTxKQ39xv'
        },
      );
      final responseJson = json.decode(response.body);
      await request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(responseJson));
      await request.response.close();
    } else {
      await request.response
        ..headers.contentType = ContentType.text
        ..statusCode = HttpStatus.badRequest;
//      await request.response.flush();
      await request.response.close();
    }
  }

  void _instadataHandler(request, String instahandle) async {
    if (instahandle != null) {
      final response = await http.get(
        'https://www.instagram.com/' + instahandle + '/?__a=1',
      );
      final responseJson = json.decode(response.body);
      await request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(jsonEncode(responseJson));
//      await request.response.flush();
      await request.response.close();
      // return responseJson;
    } else {
      await request.response
        ..headers.contentType = ContentType.text
        ..statusCode = HttpStatus.badRequest;
//      await request.response.flush();
      await request.response.close();
    }
  }

  void _dataHandler(HttpRequest request, String atp) async {
    if (_debug) print('_dataHandler received atp: $atp');
    var responseData = [];
    var service;
    var value;
    // could be
    // @alice
    // profile@alice
    if (atp != null) {
      atp = atp.trim().toLowerCase();
      List a = atp.split('@');
      if (a.length == 1 || atp.startsWith('@')) {
        // alice or @alice
        atp = atp.startsWith('@') ? atp : '@' + atp;
        atp = AtUtils.fixAtSign(atp);
        // ignore: omit_local_variable_types
        AtLookupImpl atLookupImpl = AtLookupImpl(atp, root_url, root_port);
        if (_debug) print('_dataHandler getting keysList for: $atp');
        final keysList =
            await atLookupImpl.scan(regex: '.persona@', auth: false);
        if (_debug) print('_dataHandler received keysList: $keysList');
        if (_debug)
          print('_dataHandler keysList has: ${keysList.length} items');
        if (keysList != null) {
          for (var i = 0; i < keysList.length; i++) {
            var sep = keysList[i].split('@');
            service = sep[0];
            //TODO remove this hack
            service = service?.replaceFirst('"', '');
            if (_verbose)
              print('_dataHandler found item $i service: $service, atp: $atp');
            value = await atLookupImpl.lookup(service, atp,
                auth: false, metadata: true);
            value = value?.replaceFirst('data:', '');
            var responseObj = {service: _getValue(value)};
            responseData.add(responseObj);
          }
          await atLookupImpl.close();
        }
      } else if (a.length == 2 && a[0] != null) {
        // profile@alice
        String service = a[0];
        service = service.trim().toLowerCase();
        String atsign = a[1];
        atsign = atsign.trim().toLowerCase();
        atsign = atsign.startsWith('@') ? atsign : '@' + atsign;
        atsign = AtUtils.fixAtSign(atsign);
        var atLookupImpl = AtLookupImpl(atsign, root_url, root_port);
        value = await atLookupImpl.lookup(service, atsign,
            auth: false, metadata: true);
        await atLookupImpl.close();
        value = value?.replaceFirst('data:', '');
        var responseObj = {service: _getValue(value)};
        responseData.add(responseObj);
      } else {
        await request.response
          ..headers.contentType = ContentType.text
          ..statusCode = HttpStatus.badRequest;
//        await request.response.flush();
        await request.response.close();
      }
      if (request.method.toLowerCase() == 'get') {
        await request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode(responseData));
//        await request.response.flush();
        await request.response.close();
      } else {
        await request.response
          ..headers.contentType = ContentType.text
          ..statusCode = HttpStatus.badRequest;
//        await request.response.flush();
        await request.response.close();
      }
    }
  }

  ///Returns the [value] data. Performs data encoding if it is image.
  dynamic _getValue(var value) {
    if (value == null) {
      return value;
    }
    value = jsonDecode(value);
    if (value['data'] == null) {
      return value['data'];
    }
    var isCustomData = value['key'].contains('custom_');
    var valueData = isCustomData ? jsonDecode(value['data']) : value['data'];
    var isImage = isCustomData
        ? valueData['type'] == 'Image'
        : value['metaData'] != null ? value['metaData']['isBinary'] : false;

    if (isImage) {
      var bytes =
          Base2e15.decode(isCustomData ? valueData['value'] : valueData);
      if (_verbose) print('_dataHandler found image: ${bytes.length} bytes');
      // value = 'data:image/png;base64,'+base64Encode(bytes);
      var baseEncodedData = base64Encode(bytes);
      if (isCustomData) {
        valueData['value'] = baseEncodedData;
        value['data'] = jsonEncode(valueData);
      } else {
        value['data'] = baseEncodedData;
      }
      if (_verbose) print('_dataHandler found value: ${value['data']}');
      if (_verbose)
        print('_dataHandler encoded image: ${value.length} characters');
    }
    return value['data'];
  }

  void _statusHandler(HttpRequest request, String atp) async {
    // Looks up an @server and reports back status using a response code
    //
    // Response codes are:
    // Not Found(404) @server has no root location, is not running and is not activated
    // Service Unavailable(503) @server has root location, is not running and is not activated
    // I'm a teapot(418) @server has root location, is running and but not activated
    // OK (200) @server has root location, is running and is activated
    // Internal Server Error(500) at_find_api internal error
    // Bad Gateway(502) @root server is down
    // Method Not Allowed(405) only GET and HEAD are allowed

    if (_debug) print('_statusHandler received atp: $atp');
    int responseCode;
    var testKey = 'publickey$atp';
    // request could be of the form:
    // @alice
    // profile@alice
    if (atp != null) {
      atp = atp.trim().toLowerCase();
      List a = atp.split('@');
      // alice or @alice
      if (a.length == 1 || atp.startsWith('@')) {
        atp = atp.startsWith('@') ? atp : '@' + atp;
        atp = AtUtils.fixAtSign(atp);
        // ignore: omit_local_variable_types
        AtLookupImpl atLookupImpl = AtLookupImpl(atp, root_url, root_port);
        await AtLookupImpl.findSecondary(atp, root_url, root_port)
            .then((serverLocation) async {
          if (_debug)
            print('_statusHandler received serverLocation: $serverLocation');
          if (serverLocation == null || serverLocation.isEmpty) {
            // Not Found(404) @server has no root location, is not running and is not activated
            responseCode = HttpStatus.notFound;
          } else {
            await atLookupImpl.scan(auth: false).then((keysList) async {
              if (_debug) print('keysList: $keysList');
              if (keysList.isNotEmpty) {
                if (keysList.contains(testKey)) {
                  var value =
                      await atLookupImpl.lookup('publickey', atp, auth: false);
                  // print('publickey exists with value $value');
                  value = value?.replaceFirst('data:', '');
                  // print('lookup changed to $value');
                  if (value != null && value != 'null') {
                    // OK (200) @server has root location, is running and is activated
                    responseCode = HttpStatus.ok;
                  } else {
                    // print('value is null : $value');
                    // I'm a teapot(418) @server has root location, is running and but not activated
                    responseCode = 418;
                  }
                } else {
                  // print('testKey not found: $testKey');
                  // I'm a teapot(418) @server has root location, is running and but not activated
                  responseCode = 418;
                }
              } else {
                // print('keysList is empty : $keysList');
                // I'm a teapot(418) @server has root location, is running and but not activated
                responseCode = 418;
              }
            }).catchError((error) {
              print(error);
              // Service Unavailable(503) @server has root location, is not running and is not activated
              responseCode = HttpStatus.serviceUnavailable;
              if (_debug) print('_statusHandler scan error: $error');
            });
          }
        }).catchError((e) {
          // 502 - the @root server is down
          responseCode = HttpStatus.badGateway;
          if (_debug) print('_statusHandler findSecondary error: $e');
        });
//        await atLookupImpl.close();
        // get request method
        if (request.method.toLowerCase() == 'get') {
          await request.response
//            ..headers.contentType = ContentType.html
            ..statusCode = responseCode;
//            ..write(jsonEncode(responseData));
//          await request.response.flush();
          await request.response.close();
        }

        // head request method
        else if (request.method.toLowerCase() == 'head') {
          await request.response
//            ..headers.contentType = ContentType.html
            ..statusCode = HttpStatus.ok;
//          await request.response.flush();
          await request.response.close();
        }
      }
      // otherwise, treat as a bad request
      else {
        await request.response
//          ..headers.contentType = ContentType.text
          ..statusCode = HttpStatus.methodNotAllowed;
//        await request.response.flush();
        await request.response.close();
      }
    }
  }

  void _contentHandler(HttpRequest request, String resource) async {
    if (_debug) print('_contentHandler received resource: $resource.');
    try {
      // ignore: omit_local_variable_types
      VirtualDirectory staticFiles = VirtualDirectory('.');
      var targetFile = File('web' + resource);
      var fileExists = await targetFile.exists();
      if (fileExists) {
        if (_debug)
          print(
              '_contentHandler found resource: $resource, content will be served.');
        if (request.method.toLowerCase() == 'get') {
          await request.response
            ..headers.contentType = ContentType.html
            ..statusCode = HttpStatus.ok;
          staticFiles.serveFile(targetFile, request);
        } else {
          await request.response
            ..headers.contentType = ContentType.html
            ..statusCode = HttpStatus.ok;
//          await request.response.flush();
          await request.response.close();
        }
      } else {
        if (_debug)
          print(
              '_contentHandler resource: $resource, not found, returning 404 error.');
        await _contentHandler(request, '/index.html');
        /*	await request.response
          ..headers.contentType = ContentType.html
          ..statusCode = HttpStatus.notFound;
//        ..write(response);
//        await request.response.flush();
        await request.response.close();*/
      }
    } on Exception catch (exception) {
      print(exception.toString());
//      await request.response.flush();
      await request.response.close();
    } catch (error) {
      print(error.toString());
//      await request.response.flush();
      await request.response.close();
    }
  }

//  Future<String> _embedHandler(HttpRequest request, String resource) async {
//    var response = '';
//    // ignore: omit_local_variable_types
//    VirtualDirectory staticFiles = VirtualDirectory('.');
//    var targetFile = File('web/index.html');
//    staticFiles.serveFile(targetFile, request);
//    return response;
//  }

  void _healthHandler(HttpRequest request) async {
    await request.response
      ..statusCode = HttpStatus.ok;
//    await request.response.flush();
    await request.response.close();
  }
}
