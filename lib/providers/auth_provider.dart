import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/subscriber_model.dart';
import '../core/services/firebase_service.dart';
import '../core/services/storage_service.dart';
import 'notification_provider.dart';

class AuthProvider extends ChangeNotifier {
  SubscriberModel? _currentSubscriber;
  NotificationProvider? _notificationProvider;
  bool _isLoading = false;
  String? _errorMessage;

  SubscriberModel? get currentSubscriber => _currentSubscriber;
  bool get isAuthenticated => _currentSubscriber != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void attachNotificationProvider(NotificationProvider notifProvider) {
    _notificationProvider = notifProvider;
  }

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    // Check cached subscriber first
    _currentSubscriber = StorageService.getCachedSubscriber();
    notifyListeners();

    // Check Firebase Auth state if available
    final auth = FirebaseService.auth;
    if (auth != null) {
      auth.authStateChanges().listen((User? user) async {
        if (user != null) {
          final subscriber = await FirebaseService.getSubscriber(user.uid);
          if (subscriber != null) {
            _currentSubscriber = subscriber;
            await StorageService.saveCachedSubscriber(subscriber);
            notifyListeners();
          }
        }
      });
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Module 1: New subscriber registration
  Future<bool> registerSubscriber({
    required String fullName,
    required String mobileNumber,
    required String email,
    required String password,
    required String confirmPassword,
    required String operatorName,
    required String simType,
    required String deviceModel,
    required bool locationConsent,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (password != confirmPassword) {
        throw 'Passwords do not match.';
      }

      if (password.length < 6) {
        throw 'Password must be at least 6 characters.';
      }

      String uid;
      final auth = FirebaseService.auth;

      if (FirebaseService.isInitialized && auth != null) {
        try {
          final userCredential = await auth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
          uid = userCredential.user!.uid;
        } catch (e) {
          if (e is FirebaseAuthException) {
            throw e.message ?? 'Registration failed.';
          }
          uid = const Uuid().v4();
        }
      } else {
        // Fallback offline / local demo user ID
        uid = const Uuid().v4();
      }

      final newSubscriber = SubscriberModel(
        uid: uid,
        fullName: fullName.trim(),
        email: email.trim(),
        phone: mobileNumber.trim(),
        operatorName: operatorName,
        simType: simType,
        deviceModel: deviceModel.trim(),
        locationConsent: locationConsent,
        isRoaming: false,
        createdAt: DateTime.now(),
      );

      // Persist in Firestore
      await FirebaseService.saveSubscriber(newSubscriber);

      // Persist in local storage
      await StorageService.saveCachedSubscriber(newSubscriber);
      _currentSubscriber = newSubscriber;

      // Trigger registration security notification
      await _notificationProvider?.triggerSecurityNotification(
        userId: newSubscriber.uid,
        title: '🎉 Welcome to RoamEase!',
        body: 'Subscriber profile registered for ${newSubscriber.fullName} on ${newSubscriber.operatorName} (${newSubscriber.simType}).',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Secure Login
  Future<bool> loginSubscriber({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final auth = FirebaseService.auth;

      if (FirebaseService.isInitialized && auth != null) {
        try {
          final userCredential = await auth.signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
          final uid = userCredential.user!.uid;
          final remoteSubscriber = await FirebaseService.getSubscriber(uid);

          if (remoteSubscriber != null) {
            _currentSubscriber = remoteSubscriber;
          } else {
            // Build profile from user data
            _currentSubscriber = SubscriberModel(
              uid: uid,
              fullName: userCredential.user?.displayName ?? 'Subscriber',
              email: email.trim(),
              phone: '+91 9876543210',
              operatorName: 'Reliance Jio',
              simType: '5G',
              deviceModel: 'Android Device',
              locationConsent: true,
              createdAt: DateTime.now(),
            );
            await FirebaseService.saveSubscriber(_currentSubscriber!);
          }
        } catch (e) {
          if (e is FirebaseAuthException) {
            throw e.message ?? 'Login failed. Please check credentials.';
          }
          // If auth network failed, check cached
          _currentSubscriber = StorageService.getCachedSubscriber();
          if (_currentSubscriber == null || _currentSubscriber!.email.toLowerCase() != email.trim().toLowerCase()) {
            throw 'Unable to connect to Firebase. Using offline account if previously saved.';
          }
        }
      } else {
        // Offline / Demo mode authentication
        final cached = StorageService.getCachedSubscriber();
        if (cached != null && cached.email.toLowerCase() == email.trim().toLowerCase()) {
          _currentSubscriber = cached;
        } else {
          // Provide demo subscriber
          _currentSubscriber = SubscriberModel(
            uid: 'subscriber_demo_01',
            fullName: 'Alexander Wright',
            email: email.trim().isNotEmpty ? email.trim() : 'alexander.wright@roamease.io',
            phone: '+1 (555) 234-5678',
            operatorName: 'T-Mobile US',
            simType: '5G',
            deviceModel: 'Samsung Galaxy S24 Ultra',
            locationConsent: true,
            isRoaming: false,
            createdAt: DateTime.now().subtract(const Duration(days: 30)),
          );
        }
      }

      if (_currentSubscriber != null) {
        await StorageService.saveCachedSubscriber(_currentSubscriber!);

        // Trigger login security notification
        await _notificationProvider?.triggerSecurityNotification(
          userId: _currentSubscriber!.uid,
          title: '🔐 Security Notice: Terminal Login',
          body: 'Active session started on ${_currentSubscriber!.deviceModel}.',
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Forgot Password
  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final auth = FirebaseService.auth;
      if (FirebaseService.isInitialized && auth != null) {
        await auth.sendPasswordResetEmail(email: email.trim());
      }
      // Simulate delay if offline
      await Future.delayed(const Duration(milliseconds: 600));

      // Trigger password reset security notification
      await _notificationProvider?.triggerSecurityNotification(
        userId: _currentSubscriber?.uid ?? 'guest',
        title: '🔑 Password Reset Requested',
        body: 'Password reset instructions were dispatched to $email.',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Edit and Update Subscriber Profile
  Future<bool> updateProfile({
    required String fullName,
    required String phone,
    required String operatorName,
    required String simType,
    required String deviceModel,
    required bool locationConsent,
  }) async {
    if (_currentSubscriber == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = _currentSubscriber!.copyWith(
        fullName: fullName.trim(),
        phone: phone.trim(),
        operatorName: operatorName,
        simType: simType,
        deviceModel: deviceModel.trim(),
        locationConsent: locationConsent,
        updatedAt: DateTime.now(),
      );

      await FirebaseService.saveSubscriber(updated);
      await StorageService.saveCachedSubscriber(updated);
      _currentSubscriber = updated;

      // Trigger profile update security notification
      await _notificationProvider?.triggerSecurityNotification(
        userId: updated.uid,
        title: '🛡️ Profile Updated',
        body: 'Subscriber profile details and SIM configuration were saved.',
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Toggle Roaming status
  Future<void> setRoamingStatus(bool isRoaming) async {
    if (_currentSubscriber == null) return;
    final updated = _currentSubscriber!.copyWith(
      isRoaming: isRoaming,
      updatedAt: DateTime.now(),
    );
    await FirebaseService.saveSubscriber(updated);
    await StorageService.saveCachedSubscriber(updated);
    _currentSubscriber = updated;
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    try {
      await FirebaseService.auth?.signOut();
    } catch (_) {}
    await StorageService.clearCachedSubscriber();
    _currentSubscriber = null;
    notifyListeners();
  }

  // Delete Account
  Future<bool> deleteAccount() async {
    if (_currentSubscriber == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final uid = _currentSubscriber!.uid;
      await FirebaseService.deleteSubscriber(uid);
      try {
        await FirebaseService.auth?.currentUser?.delete();
      } catch (_) {}

      await StorageService.clearCachedSubscriber();
      _currentSubscriber = null;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
