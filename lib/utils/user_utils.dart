import 'package:shared_preferences/shared_preferences.dart';

// STORE USER DATA FUNCTION
Future<void> storeUserData(
    {required String userId,
    required String token,
    required String profileID,
    required String email,
    required String username}) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setString('savedUserId', userId);
  prefs.setString('savedEmail', email);
  prefs.setString('savedToken', token);
  prefs.setString('savedUsername', username);
  prefs.setString('savedProfile_id', profileID);
}

Future<String> getUserToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('savedToken') ?? "";
}

Future<String> getProfileId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('savedProfile_id') ?? "";
}
