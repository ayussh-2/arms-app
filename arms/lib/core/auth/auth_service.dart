import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSession {
  final String id;
  final String adminID;
  final String name;
  final String email;
  final String phone1;
  final String? phone2;
  final String? gender;
  final int? age;
  final String? imageURL;
  final String role;
  final String address;
  final String? signURL;
  final int? signURLVersion;
  final OrganizationSession? organization;

  AdminSession({
    required this.id,
    required this.adminID,
    required this.name,
    required this.email,
    required this.phone1,
    this.phone2,
    this.gender,
    this.age,
    this.imageURL,
    required this.role,
    required this.address,
    this.signURL,
    this.signURLVersion,
    this.organization,
  });

  factory AdminSession.fromMap(Map<String, dynamic> map) {
    return AdminSession(
      id: map['id']?.toString() ?? '',
      adminID: map['adminID']?.toString() ?? map['admin_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone1: map['phone1']?.toString() ?? '',
      phone2: map['phone2']?.toString(),
      gender: map['gender']?.toString(),
      age: map['age'] is int ? map['age'] : (map['age'] != null ? int.tryParse(map['age'].toString()) : null),
      imageURL: map['imageURL']?.toString() ?? map['image_url']?.toString() ?? map['img_url']?.toString(),
      role: map['role']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      signURL: map['signURL']?.toString() ?? map['sign_url']?.toString(),
      signURLVersion: map['signURLVersion'] is int ? map['signURLVersion'] : (map['signURLVersion'] != null ? int.tryParse(map['signURLVersion'].toString()) : null),
      organization: map['organization'] != null
          ? OrganizationSession.fromMap(Map<String, dynamic>.from(map['organization']))
          : (map['organisations'] != null
              ? OrganizationSession.fromMap(Map<String, dynamic>.from(map['organisations']))
              : null),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'adminID': adminID,
      'name': name,
      'email': email,
      'phone1': phone1,
      'phone2': phone2,
      'gender': gender,
      'age': age,
      'imageURL': imageURL,
      'role': role,
      'address': address,
      'signURL': signURL,
      'signURLVersion': signURLVersion,
      'organization': organization?.toMap(),
    };
  }

  String toJson() => json.encode(toMap());

  factory AdminSession.fromJson(String source) => AdminSession.fromMap(json.decode(source));
}

class OrganizationSession {
  final String id;
  final String name;
  final String? displayName;
  final String? headerURL;
  final String? logoURL;
  final String? helpLineNumber;
  final String? createdAt;

  OrganizationSession({
    required this.id,
    required this.name,
    this.displayName,
    this.headerURL,
    this.logoURL,
    this.helpLineNumber,
    this.createdAt,
  });

  factory OrganizationSession.fromMap(Map<String, dynamic> map) {
    return OrganizationSession(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? map['display_name']?.toString(),
      headerURL: map['headerURL']?.toString() ?? map['header_url']?.toString(),
      logoURL: map['logoURL']?.toString() ?? map['logo_url']?.toString(),
      helpLineNumber: map['helpLineNumber']?.toString() ?? map['helpline_no']?.toString() ?? map['helpLineNo']?.toString(),
      createdAt: map['createdAt']?.toString() ?? map['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'headerURL': headerURL,
      'logoURL': logoURL,
      'helpLineNumber': helpLineNumber,
      'createdAt': createdAt,
    };
  }
}

class AuthService {
  AuthService._();

  static SharedPreferences? _prefs;
  static AdminSession? _currentAdmin;

  static const String _adminKey = 'auth_admin_session';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final sessionData = _prefs?.getString(_adminKey);
    if (sessionData != null) {
      try {
        _currentAdmin = AdminSession.fromJson(sessionData);
      } catch (e) {
        // Clear corrupt session
        await _prefs?.remove(_adminKey);
      }
    }
  }

  static bool get isLoggedIn => _currentAdmin != null;

  static AdminSession? get currentAdmin => _currentAdmin;

  static Future<void> saveSession(Map<String, dynamic> adminData) async {
    _currentAdmin = AdminSession.fromMap(adminData);
    await _prefs?.setString(_adminKey, _currentAdmin!.toJson());
  }

  static Future<void> clearSession() async {
    _currentAdmin = null;
    await _prefs?.remove(_adminKey);
  }
}
