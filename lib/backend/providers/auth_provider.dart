import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spark_aquanix_delivery/backend/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:spark_aquanix_delivery/const/app_logger.dart';
import 'dart:convert';

import '../models/delivery_person.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  DeliveryPersonnelModel? _deliveryPersonnel;
  bool _isLoading = false;
  String? _error;

  DeliveryPersonnelModel? get deliveryPersonnel => _deliveryPersonnel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _deliveryPersonnel != null;

  // Get current FCM token
  Future<String?> _getFcmToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      AppLogger.log('Failed to get FCM token: ${e.toString()}');
      return null;
    }
  }

  // Update FCM token in Firestore
  Future<void> _updateFcmToken(String userId) async {
    try {
      final token = await _getFcmToken();
      if (token != null) {
        await _firestore.collection('delivery_personnel').doc(userId).update({
          'fcmToken': token,
        });

        // Also update local model if needed
        if (_deliveryPersonnel != null) {
          _deliveryPersonnel = _deliveryPersonnel!.copyWith(fcmToken: token);
          await _saveUserDataToPrefs(_deliveryPersonnel!);
        }
      }
    } catch (e) {
      AppLogger.log('Failed to update FCM token: ${e.toString()}');
    }
  }

  // Check login state from local storage
  Future<void> checkLoginState() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('userData');

      if (userData != null && userData.isNotEmpty) {
        // Parse stored user data
        final Map<String, dynamic> userMap = json.decode(userData);

        // Create DeliveryPersonnelModel from stored data
        _deliveryPersonnel = DeliveryPersonnelModel.fromMap(
          userMap['userData'],
          userMap['id'],
        );

        // Verify if the user is still authenticated with Firebase
        User? currentUser = _auth.currentUser;
        if (currentUser == null || currentUser.uid != _deliveryPersonnel!.id) {
          // If Firebase auth state doesn't match stored data, refresh from Firestore
          try {
            if (currentUser != null) {
              final doc = await _firestore
                  .collection('delivery_personnel')
                  .doc(currentUser.uid)
                  .get();

              if (doc.exists) {
                _deliveryPersonnel =
                    DeliveryPersonnelModel.fromMap(doc.data()!, doc.id);
                // Update stored data
                await _saveUserDataToPrefs(_deliveryPersonnel!);

                // Update FCM token in background
                _updateFcmToken(currentUser.uid);
              } else {
                // User exists in Auth but not in Firestore, logout
                await logout();
              }
            } else {
              // No active Firebase session, logout
              await logout();
            }
          } catch (e) {
            // Error fetching from Firestore, fallback to stored data
            // We keep the user logged in with local data
          }
        } else {
          // Update FCM token in background and refresh user data
          _updateFcmToken(currentUser.uid);
          _refreshUserData();
        }
      } else {
        // Check if user is logged in with Firebase but not stored locally
        User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          final doc = await _firestore
              .collection('delivery_personnel')
              .doc(currentUser.uid)
              .get();

          if (doc.exists) {
            _deliveryPersonnel =
                DeliveryPersonnelModel.fromMap(doc.data()!, doc.id);
            // Save to preferences
            await _saveUserDataToPrefs(_deliveryPersonnel!);

            // Update FCM token in background
            _updateFcmToken(currentUser.uid);
          } else {
            // User exists in Auth but not in Firestore, logout
            await logout();
          }
        }
      }
    } catch (e) {
      _error = "Failed to check login state: ${e.toString()}";
      // Don't logout on error to prevent unnecessary logouts on network issues
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save user data to SharedPreferences
  Future<void> _saveUserDataToPrefs(DeliveryPersonnelModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = {
        'id': user.id,
        'userData': user.toMap(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString('userData', json.encode(userData));
    } catch (e) {
      // Handle error silently - primary storage is Firebase
    }
  }

  // Refresh user data from Firestore
  Future<void> _refreshUserData() async {
    try {
      if (_deliveryPersonnel != null) {
        final doc = await _firestore
            .collection('delivery_personnel')
            .doc(_deliveryPersonnel!.id)
            .get();

        if (doc.exists) {
          _deliveryPersonnel =
              DeliveryPersonnelModel.fromMap(doc.data()!, doc.id);
          await _saveUserDataToPrefs(_deliveryPersonnel!);
          notifyListeners();
        }
      }
    } catch (e) {
      // Silently handle refresh errors - fallback to cached data
    }
  }

  // Signup
  Future<bool?> signup(
      String name, String email, String password, String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get FCM token first
      final fcmToken = await _getFcmToken();

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        final deliveryPersonnel = DeliveryPersonnelModel(
            id: user.uid,
            name: name,
            email: email,
            phone: phone,
            fcmToken: fcmToken);

        // Save to Firestore
        await _firestore
            .collection('delivery_personnel')
            .doc(user.uid)
            .set(deliveryPersonnel.toMap());

        _deliveryPersonnel = deliveryPersonnel;

        // Save to SharedPreferences
        await _saveUserDataToPrefs(deliveryPersonnel);
        return true;
      }
    } catch (e) {
      _error = "Signup failed: ${e.toString()}";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  // Login
  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        final doc = await _firestore
            .collection('delivery_personnel')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          _deliveryPersonnel =
              DeliveryPersonnelModel.fromMap(doc.data()!, doc.id);

          // Save to SharedPreferences
          await _saveUserDataToPrefs(_deliveryPersonnel!);

          // Update FCM token after successful login
          await _updateFcmToken(user.uid);
        } else {
          throw Exception('Delivery personnel not found');
        }
      }
    } catch (e) {
      _error = "Login failed: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Reset Password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      _error = "Password reset failed: ${e.toString()}";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear FCM token in Firestore if user is logged in
      if (_deliveryPersonnel != null) {
        try {
          await _firestore
              .collection('delivery_personnel')
              .doc(_deliveryPersonnel!.id)
              .update({'fcmToken': null});
        } catch (e) {
          // Silently handle error - proceed with logout
        }
      }

      await _auth.signOut();

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userData');

      _deliveryPersonnel = null;
    } catch (e) {
      _error = "Logout failed: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update delivery personnel profile
  Future<void> updateProfile({
    String? name,
    String? phone,
    String? profileImageUrl,
  }) async {
    if (_deliveryPersonnel == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updates = <String, dynamic>{};

      if (name != null && name.isNotEmpty) {
        updates['name'] = name;
      }

      if (phone != null && phone.isNotEmpty) {
        updates['phone'] = phone;
      }

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        updates['profileImageUrl'] = profileImageUrl;
      }

      if (updates.isNotEmpty) {
        // Update Firestore
        await _firestore
            .collection('delivery_personnel')
            .doc(_deliveryPersonnel!.id)
            .update(updates);

        // Update local model
        final updatedUser = DeliveryPersonnelModel(
          id: _deliveryPersonnel!.id,
          name: name ?? _deliveryPersonnel!.name,
          email: _deliveryPersonnel!.email,
          phone: phone ?? _deliveryPersonnel!.phone,
          fcmToken: _deliveryPersonnel!.fcmToken,
          profileImageUrl:
              profileImageUrl ?? _deliveryPersonnel!.profileImageUrl,
        );

        _deliveryPersonnel = updatedUser;

        // Update SharedPreferences
        await _saveUserDataToPrefs(updatedUser);
      }
    } catch (e) {
      _error = "Profile update failed: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
