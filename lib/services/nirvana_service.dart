// lib/services/nirvana_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class NirvanaService {
  final String baseUrl = 'https://gc-api.nirvanahq.com/api';
  final String appId = 'com.nirvanahq.focus';
  final String appVersion = '3.9.8';
  final storage = FlutterSecureStorage();
  final uuid = Uuid();
  
  void testFunctionality() {
    print('NirvanaService is working!');
  }

  // Convert string to MD5
  String _generateMd5(String input) {
    return crypto.md5.convert(utf8.encode(input)).toString();
  }
  
  // Login with email and password
  Future<String> login(String email, String password) async {
    try {
      // Convert password to MD5 as in Chrome extension
      final md5Password = _generateMd5(password);
      
      final url = '$baseUrl/auth/new?appid=$appId&appversion=$appVersion';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'gmtoffset': '-3',
          'u': email,
          'p': md5Password
        })
      );
      
      final data = jsonDecode(response.body);
      
      if (data['results'] != null && 
          data['results'][0] != null && 
          data['results'][0]['auth'] != null) {
        final token = data['results'][0]['auth']['token'];
        
        // Save token and email
        await storage.write(key: 'authToken', value: token);
        await storage.write(key: 'userEmail', value: email);
        
        return token;
      } else if (data['results'] != null && 
                data['results'][0] != null && 
                data['results'][0]['error'] != null) {
        throw Exception(data['results'][0]['error']['message']);
      }
      
      throw Exception('Login failed');
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }
  
  // Check if logged in
  Future<Map<String, String?>> checkAuth() async {
    final token = await storage.read(key: 'authToken');
    final email = await storage.read(key: 'userEmail');
    
    return {
      'token': token,
      'email': email
    };
  }
  
  // Add task
  Future<void> createTask(String title, String notes) async {
    try {
      final authToken = await storage.read(key: 'authToken');
      if (authToken == null) throw Exception('Not authenticated');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final taskId = uuid.v4(); // UUID for the task
      
      final params = {
        'return': 'everything',
        'since': timestamp.toString(),
        'authtoken': authToken,
        'appid': appId,
        'appversion': appVersion,
        'clienttime': timestamp.toString(),
        'requestid': uuid.v4()
      };
      
      final queryString = Uri(queryParameters: params).query;
      
      final taskData = [{
        'method': 'task.save',
        'id': taskId,
        'type': 0,
        '_type': timestamp,
        'parentid': '',
        '_parentid': timestamp,
        'waitingfor': '',
        '_waitingfor': timestamp,
        'state': 0,
        '_state': timestamp,
        'completed': 0,
        '_completed': timestamp,
        'cancelled': 0,
        '_cancelled': timestamp,
        'seq': timestamp,
        '_seq': timestamp,
        'seqt': 0,
        '_seqt': timestamp,
        'seqp': 0,
        '_seqp': timestamp,
        'name': title,
        '_name': timestamp,
        'tags': ',',
        '_tags': timestamp,
        'note': notes,
        '_note': timestamp,
        'ps': 0,
        '_ps': timestamp,
        'etime': 0,
        '_etime': timestamp,
        'energy': 0,
        '_energy': timestamp,
        'startdate': '',
        '_startdate': timestamp,
        'duedate': '',
        '_duedate': timestamp,
        'recurring': '',
        '_recurring': timestamp,
        'deleted': 0,
        '_deleted': timestamp
      }];
      
      final response = await http.post(
        Uri.parse('$baseUrl/everything?$queryString'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
          'Referer': 'https://focus.nirvanahq.com/',
          'Origin': 'https://focus.nirvanahq.com'
        },
        body: jsonEncode(taskData)
      );
      
      final data = jsonDecode(response.body);
      
      if (data['results'] != null && 
          data['results'][0] != null && 
          data['results'][0]['error'] != null) {
        throw Exception(data['results'][0]['error']['message']);
      }
      
      return;
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }
  
  // Logout
  Future<void> logout() async {
    await storage.delete(key: 'authToken');
    await storage.delete(key: 'userEmail');
  }
}