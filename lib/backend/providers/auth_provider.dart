import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/delivery_person.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DeliveryPersonnelModel? _deliveryPersonnel;
  bool _isLoading = false;
  String? _error;

  DeliveryPersonnelModel? get deliveryPersonnel => _deliveryPersonnel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _deliveryPersonnel != null;

  // Check login state
  Future<void> checkLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('deliveryPersonnelId');
    if (userId != null) {
      try {
        final doc =
            await _firestore.collection('delivery_personnel').doc(userId).get();
        if (doc.exists) {
          _deliveryPersonnel =
              DeliveryPersonnelModel.fromMap(doc.data()!, doc.id);
          notifyListeners();
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  // Signup
  Future<void> signup(
      String name, String email, String password, String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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
        );
        await _firestore
            .collection('delivery_personnel')
            .doc(user.uid)
            .set(deliveryPersonnel.toMap());
        _deliveryPersonnel = deliveryPersonnel;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('deliveryPersonnelId', user.uid);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('deliveryPersonnelId', user.uid);
        } else {
          throw Exception('Delivery personnel not found');
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('deliveryPersonnelId');
    _deliveryPersonnel = null;
    notifyListeners();
  }
}
