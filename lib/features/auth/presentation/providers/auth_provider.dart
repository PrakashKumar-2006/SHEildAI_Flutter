import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/mongo_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/identity_validator.dart';

// Fallback user class for when Firebase is not configured
class MockUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;

  MockUser({required this.uid, this.email, this.displayName, this.photoURL});
  
  Future<void> updateDisplayName(String name) async {}
  Future<void> reload() async {}
}

class AuthProvider extends ChangeNotifier {
  FirebaseAuth? _auth;
  final StorageService _storageService;
  bool _isFirebaseAvailable = false;

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  dynamic _user; // Using dynamic to support both Firebase User and MockUser

  bool get isSyncing => _isSyncing;

  AuthProvider(this._storageService) {
    // ── Restore persisted session (survives cold restarts) ──────────────────
    // StorageService is synchronously readable after app.dart calls init().
    // If the user previously logged in and did NOT explicitly sign out,
    // we restore a lightweight MockUser so isAuthenticated is true
    // immediately — before the Firebase authStateChanges stream even fires.
    final wasLoggedIn = _storageService.getBool(AppConstants.keyIsLoggedIn) ?? false;
    if (wasLoggedIn) {
      final savedName  = _storageService.getString(AppConstants.keyUserName) ?? 'User';
      final savedPhone = _storageService.getString(AppConstants.keyUserPhone) ?? '';
      final savedEmail = _storageService.getString(AppConstants.keyUserEmail) ?? '';
      _user = MockUser(uid: savedPhone.isNotEmpty ? savedPhone : 'restored_session',
                       email: savedEmail.isNotEmpty ? savedEmail : '',
                       displayName: savedName);
      debugPrint('[AuthProvider] Session restored — user: $savedName');
      syncProfile(); // Ensure name is correct if it was generic
    }

    try {
      _auth = FirebaseAuth.instance;
      _isFirebaseAvailable = true;
      _auth!.authStateChanges().listen((User? user) {
        // Firebase has reported a live session — use it (overrides the
        // MockUser restore above) or, if null, defer to the persisted flag
        // so a Firebase sign-out doesn't unexpectedly kick out MongoDB users.
        if (user != null) {
          _user = user;
          syncProfile(); // Ensure name is correct
          syncUserData(user.email ?? ''); // Sync contacts and full profile
          notifyListeners();
        } else if (!(_storageService.getBool(AppConstants.keyIsLoggedIn) ?? false)) {
          // Only clear if we genuinely have no persisted session.
          _user = null;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint("AuthProvider: Firebase not available. Auth features will be disabled. Error: $e");
      _isFirebaseAvailable = false;
    }
  }

  /// Synchronizes all user data (profile, contacts) from MongoDB to local storage.
  /// This prevents the app from asking for "Trusted Contacts" after every login.
  Future<void> syncUserData(String email) async {
    if (email.isEmpty) return;
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      final mongoService = MongoService();
      if (!mongoService.isConnected) await mongoService.connect();
      
      debugPrint('[AuthProvider] Syncing user data for: $email');
      
      // 1. Fetch User Document with a timeout to prevent hanging
      final userDoc = await mongoService.getUserByEmail(email).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[AuthProvider] Sync timed out for user doc');
          return null;
        },
      );
      if (userDoc != null) {
        final name = userDoc['name'] as String? ?? '';
        final phone = userDoc['phone'] as String? ?? '';
        
        // Update local profile data if not already set
        if (name.isNotEmpty) await _storageService.setUserName(name);
        if (phone.isNotEmpty) {
          if (IdentityValidator.isValidPhone(phone)) {
            await _storageService.setUserPhone(phone);
          } else {
            debugPrint('[AuthProvider] syncUserData: Invalid phone found in DB (e.g. email). Rejecting contamination.');
            // Never overwrite Secure Storage with contamination.
          }
        }
        await _storageService.setUserEmail(email);

        // 2. Sync Trusted Contacts (full name + phone details)
        List<String> trustedContactPhones = [];
        List<Map<String, dynamic>> fullContactDetails = [];
        Set<String> seenPhones = {};
        
        // Fetch from emergency_contacts collection (has full name+phone)
        final contactsFromColl = await mongoService.getContactsByEmail(email).timeout(
          const Duration(seconds: 8),
          onTimeout: () => [],
        );
        for (var c in contactsFromColl) {
          final p = c['phone'] as String?;
          final n = c['name'] as String? ?? 'Guardian';
          if (p != null && !seenPhones.contains(p)) {
            seenPhones.add(p);
            trustedContactPhones.add(p);
            fullContactDetails.add({'name': n, 'phone': p});
          }
        }
        
        // Also try from phone identifier if we have one
        if (phone.isNotEmpty) {
          final contactsByPhone = await mongoService.getContacts(phone).timeout(
            const Duration(seconds: 8),
            onTimeout: () => [],
          );
          for (var c in contactsByPhone) {
            final p = c['phone'] as String?;
            final n = c['name'] as String? ?? 'Guardian';
            if (p != null && !seenPhones.contains(p)) {
              seenPhones.add(p);
              trustedContactPhones.add(p);
              fullContactDetails.add({'name': n, 'phone': p});
            }
          }
        }
        
        // Fallback: Try from user document profile field (phone-only list)
        if (fullContactDetails.isEmpty) {
          final profile = userDoc['profile'] as Map<String, dynamic>?;
          if (profile != null && profile['trustedContacts'] != null) {
            final phones = List<String>.from(profile['trustedContacts']);
            for (final p in phones) {
              if (!seenPhones.contains(p)) {
                seenPhones.add(p);
                trustedContactPhones.add(p);
                fullContactDetails.add({'name': 'Guardian', 'phone': p});
              }
            }
          }
        }

        if (fullContactDetails.isNotEmpty) {
          debugPrint('[AuthProvider] Found ${fullContactDetails.length} contacts in MongoDB, syncing locally with names.');
          // Save full contact details (name + phone) for SafetyProvider to read
          await _storageService.setStringList(
            'trusted_contacts_full',
            fullContactDetails.map((c) => jsonEncode(c)).toList(),
          );
          // Save phone-only list for quick lookup
          await _storageService.setStringList('trusted_contacts', trustedContactPhones);
          await _storageService.setBool('@setup_complete', true);
          await _storageService.setBool('@profile_complete', true);
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error during syncUserData: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Synchronizes user profile data across services.
  /// If the name is generic (e.g., "User" or "Safety Watcher"), it attempts
  /// to extract a better name from the email address.
  Future<void> syncProfile() async {
    if (_user == null) return;

    String? currentName;
    String? email;

    if (_user is User) {
      currentName = (_user as User).displayName;
      email = (_user as User).email;
    } else if (_user is MockUser) {
      currentName = (_user as MockUser).displayName;
      email = (_user as MockUser).email;
    }

    final isGeneric = currentName == null || 
                      currentName.isEmpty || 
                      currentName.toLowerCase() == 'user' || 
                      currentName == 'Safety Watcher';

    if (isGeneric) {
      debugPrint('[AuthProvider] Syncing profile: Name is generic, keeping as is or prompting later.');
      notifyListeners();
    }
  }

  Future<void> updateTrustedContacts(List<String> contacts) async {
    if (_user == null) return;
    
    final email = _user is User ? (_user as User).email : (_user as MockUser).email;
    if (email == null) return;

    try {
      final mongoService = MongoService();
      if (!mongoService.isConnected) await mongoService.connect();
      
      // Update the 'profile.trustedContacts' field in the user document
      await mongoService.updateUser(email, {'profile.trustedContacts': contacts});
      
      // Also update the 'emergency_contacts' collection for backward compatibility
      // (Optional: loop and add if they don't exist)
      
      debugPrint('[AuthProvider] Trusted contacts synced to MongoDB.');
    } catch (e) {
      debugPrint('[AuthProvider] Failed to sync contacts to MongoDB: $e');
    }
  }

  bool get isFirebaseAvailable => _isFirebaseAvailable;


  bool get isLoading => _isLoading;
  String? get error => _error;
  dynamic get user => _user;
  bool get isAuthenticated => _user != null;

  String get userPhone {
    final cachedPhone = _storageService.getString(AppConstants.keyUserPhone) ?? '';
    if (cachedPhone.isNotEmpty && IdentityValidator.isValidPhone(cachedPhone)) return cachedPhone;
    
    if (_user is User) {
      final firebasePhone = (_user as User).phoneNumber ?? '';
      if (firebasePhone.isNotEmpty && IdentityValidator.isValidPhone(firebasePhone)) return firebasePhone;
    }
    return '';
  }

  String get userDisplayName {
    if (_user == null) return '';
    if (_user is User) return (_user as User).displayName ?? 'User';
    if (_user is MockUser) return (_user as MockUser).displayName ?? 'User';
    return 'User';
  }

  Future<void> updateProfile({required String name, required String phone}) async {
    if (_user == null) return;
    
    final currentEmail = _user is User ? (_user as User).email : (_user as MockUser).email;
    if (currentEmail == null) return;

    try {
      final mongoService = MongoService();
      if (!mongoService.isConnected) await mongoService.connect();
      
      // Update MongoDB
      await mongoService.updateUser(currentEmail, {
        'name': name,
        'phone': phone,
      });

      // Update Local Storage
      await _storageService.setUserName(name);
      await _storageService.setUserPhone(phone);

      // Update Firebase Display Name if applicable
      if (_user is User) {
        await (_user as User).updateDisplayName(name);
        await (_user as User).reload();
        _user = _auth?.currentUser;
      } else if (_user is MockUser) {
        _user = MockUser(
          uid: (_user as MockUser).uid,
          email: (_user as MockUser).email,
          displayName: name,
        );
      }
      
      notifyListeners();
      debugPrint('[AuthProvider] Profile updated in MongoDB and local storage.');
    } catch (e) {
      debugPrint('[AuthProvider] Failed to update profile: $e');
      rethrow;
    }
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<bool> signUp(String email, String password, String name) async {
    setLoading(true);
    setError(null);
    if (!_isFirebaseAvailable || _auth == null) {
      // Fallback to MongoDB-only signup
      try {
        final mongoService = MongoService();
        if (!mongoService.isConnected) await mongoService.connect();
        
        final existing = await mongoService.getUser(email);
        if (existing != null) {
          setError('User already exists in database.');
          setLoading(false);
          return false;
        }

        await mongoService.createUser({
          'email': email,
          'phone': '',
          'password': password, // Note: In production use hashing, but this is a fallback for exploration
          'createdAt': DateTime.now().toIso8601String(),
          'name': name,
          'profile': {},
        });

        _user = MockUser(uid: email, email: email, displayName: name);
        await _storageService.setUserPhone('');
        await _storageService.setUserEmail(email);
        await _storageService.setUserName(name);
        await _storageService.setBool(AppConstants.keyIsLoggedIn, true);
        
        setLoading(false);
        return true;
      } catch (e) {
        debugPrint('Local signup failed: $e. Falling back to Guest Explorer mode.');
        _user = MockUser(uid: 'guest_explorer', email: email, displayName: 'Guest Explorer');
        await _storageService.setUserName('Guest Explorer');
        await _storageService.setBool(AppConstants.keyIsLoggedIn, true);
        setLoading(false);
        return true; // Allow exploration even if DB fails
      }
    }
    try {
      UserCredential userCred = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCred.user;
      if (_user != null) {
         // Update Firebase display name
         await _user!.updateDisplayName(name);
         
         // Send verification email
         await _user!.sendEmailVerification();
         
         // Sign out immediately so they can't access the app yet
         await _auth!.signOut();
         _user = null;
         
         // Set success message in error field (LoginScreen will display this in green)
         setError('Verification link sent to $email. Please check your inbox and verify to login.');
         setLoading(false);
         return false; // Return false so UI doesn't navigate
      }
      setLoading(false);
      return false;
    } on FirebaseAuthException catch (e) {
      setError(e.message ?? 'An error occurred during sign up.');
      setLoading(false);
      return false;
    }
  }

  // ── Persist login flag for Firebase signUp path ───────────────────────────
  Future<void> _persistFirebaseSession(dynamic firebaseUser, String? nameOverride) async {
    final name = nameOverride ?? firebaseUser.displayName ?? 'User';
    final email = firebaseUser.email ?? '';
    final phone = firebaseUser is User ? (firebaseUser.phoneNumber ?? '') : '';
    await _storageService.setUserName(name);
    if (phone.isNotEmpty) {
      await _storageService.setUserPhone(phone);
    } else {
      await _storageService.setString(AppConstants.keyUserPhone, '');
    }
    await _storageService.setUserEmail(email);
    await _storageService.setBool(AppConstants.keyIsLoggedIn, true);
  }

  Future<bool> signIn(String email, String password) async {
    setLoading(true);
    setError(null);
    if (!_isFirebaseAvailable || _auth == null) {
      // Fallback to MongoDB-only signin
      try {
        final mongoService = MongoService();
        if (!mongoService.isConnected) await mongoService.connect();
        
        final userData = await mongoService.getUser(email);
        if (userData == null) {
          setError('User not found.');
          setLoading(false);
          return false;
        }

        // Basic password check for the fallback
        if (userData['password'] != null && userData['password'] != password) {
          setError('Invalid password.');
          setLoading(false);
          return false;
        }

        final name = userData['name'] as String? ?? 'User';
        _user = MockUser(uid: email, email: email, displayName: name);
        
        await _storageService.setUserName(name);
        final dbPhone = userData['phone'] as String? ?? '';
        await _storageService.setUserPhone(IdentityValidator.isValidPhone(dbPhone) ? dbPhone : '');
        await _storageService.setUserEmail(email);
        await _storageService.setBool(AppConstants.keyIsLoggedIn, true);
        
        setLoading(false);
        return true;
      } catch (e) {
        debugPrint('Local login failed: $e. Falling back to Guest Explorer mode.');
        _user = MockUser(uid: 'guest_explorer', email: email, displayName: 'Guest Explorer');
        await _storageService.setUserName('Guest Explorer');
        await _storageService.setBool(AppConstants.keyIsLoggedIn, true);
        setLoading(false);
        return true; // Allow exploration even if DB fails
      }
    }
    try {
      UserCredential userCred = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCred.user;
      
      if (_user != null) {
        if (!_user!.emailVerified) {
          await _auth!.signOut();
          _user = null;
          setError('Email not verified. Please check your inbox and verify to login.');
          setLoading(false);
          return false;
        }

        // Fetch user data from MongoDB to sync local storage
        try {
          final mongoService = MongoService();
          if (!mongoService.isConnected) {
            await mongoService.connect();
          }
          var userData = await mongoService.getUser(email);
          
          if (userData == null) {
            // First time logging in after email verification
            await mongoService.createUser({
              'firebase_uid': _user!.uid,
              'email': email,
              'phone': '', 
              'createdAt': DateTime.now().toIso8601String(),
              'name': _user!.displayName ?? 'User',
              'profile': {},
            });
            userData = await mongoService.getUser(email);
          }
          
          if (userData != null && userData['name'] != null) {
            final name = userData['name'] as String;
            final dbPhone = userData['phone'] as String? ?? '';
            final cleanPhone = dbPhone.contains('@') ? '' : dbPhone;
            
            await _storageService.setUserName(name);
            await _storageService.setUserPhone(cleanPhone);
            await _storageService.setUserEmail(email);
            await _storageService.setBool(AppConstants.keyIsLoggedIn, true);
            
            // Sync Firebase display name if it's null
            if (_user!.displayName == null || _user!.displayName!.isEmpty) {
              await _user!.updateDisplayName(name);
              await _user!.reload();
              _user = _auth?.currentUser;
            }
          } else {
            // MongoDB had no extra data — still persist the session
            await _persistFirebaseSession(_user, null);
          }
        } catch (dbError) {
          debugPrint("Failed to sync user data from MongoDB: $dbError");
          await _persistFirebaseSession(_user, null);
        }
        
        // Sync full profile and contacts from MongoDB to prevent redundant setup
        await syncUserData(email);
      }
      
      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      setError(e.message ?? 'Invalid email or password.');
      setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    setLoading(true);
    setError(null);
    try {
      if (!_isFirebaseAvailable || _auth == null) {
        setError('Firebase is not available. Cannot reset password.');
        setLoading(false);
        return false;
      }
      await _auth!.sendPasswordResetEmail(email: email);
      setError('Password reset link sent to $email.');
      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      setError(e.message ?? 'An error occurred while sending reset link.');
      setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    setLoading(true);
    setError(null);
    try {
      // Initialize GoogleSignIn with serverClientId (required in v7.x on Android)
      await GoogleSignIn.instance.initialize(
        serverClientId: '751857328066-89str56pgvprvs23b7qlff5afljgup1b.apps.googleusercontent.com',
      );

      // Trigger the authentication flow (google_sign_in 7.x API)
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      // If user cancels the sign-in
      if (googleUser == null) {
        setLoading(false);
        return false;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // Create a new credential (idToken only in 7.x)
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      if (!_isFirebaseAvailable || _auth == null) {
        setError('Google Sign-In requires Firebase configuration. Please use Email/Password sign-in for exploration.');
        setLoading(false);
        return false;
      }
      // Sign in to Firebase with the Google [UserCredential]
      UserCredential userCred = await _auth!.signInWithCredential(credential);
      _user = userCred.user;
      
      if (_user != null) {
         // Get name from Google or extract from email
         String? googleName = _user!.displayName;
         String? email = _user!.email;
         
         String userName = 'User';
         if (googleName != null && googleName.isNotEmpty && googleName.toLowerCase() != 'user') {
           userName = googleName;
         }

         // Update Firebase display name if it's currently null or just "User"
         if (_user!.displayName == null || _user!.displayName!.isEmpty || _user!.displayName!.toLowerCase() == 'user') {
           try {
             await _user!.updateDisplayName(userName);
             await _user!.reload();
             _user = _auth?.currentUser; // Refresh local instance
           } catch (e) {
             debugPrint('Failed to update Firebase display name: $e');
           }
         }
         
         // Sync with MongoDB first to determine correct phone number
          Map<String, dynamic>? existingUser;
          try {
            final mongoService = MongoService();
            if (!mongoService.isConnected) {
              await mongoService.connect();
            }
            
            existingUser = await mongoService.getUser(_user!.email ?? '');
            if (existingUser == null) {
              await mongoService.createUser({
                'firebase_uid': _user!.uid,
                'email': _user!.email,
                'phone': '',
                'createdAt': DateTime.now().toIso8601String(),
                'name': userName,
                'profile': {'photoUrl': _user!.photoURL},
              });
              existingUser = await mongoService.getUser(_user!.email ?? '');
            } else {
              // Standardize/repair legacy record with firebase_uid
              final updates = <String, dynamic>{};
              if (existingUser['firebase_uid'] == null) {
                updates['firebase_uid'] = _user!.uid;
              }
              
              final existingName = existingUser['name'] as String?;
              if (existingName == null || 
                  existingName.toLowerCase() == 'user' || 
                  existingName == 'Safety Watcher') {
                updates['name'] = userName;
              }
              if (updates.isNotEmpty) {
                await mongoService.updateUser(_user!.email!, updates);
              }
            }
          } catch (dbError) {
            debugPrint("Failed to sync Google user to MongoDB: $dbError");
          }
          
          // Save to local storage for quick access
          final dbPhone = existingUser?['phone'] as String? ?? '';
          final cleanPhone = IdentityValidator.isValidPhone(dbPhone) ? dbPhone : '';
          
          await _storageService.setUserPhone(cleanPhone);
          await _storageService.setUserEmail(_user!.email ?? '');
          await _storageService.setUserName(userName);
          await _storageService.setBool(AppConstants.keyIsLoggedIn, true);
          
          // Sync full profile and contacts from MongoDB to prevent redundant setup
          await syncUserData(_user!.email ?? '');
      }

      setLoading(false);
      return true;
    } catch (e) {
      setError('Google Sign-In failed: ${e.toString()}');
      setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    if (_isFirebaseAvailable && _auth != null) {
      await _auth!.signOut();
      await GoogleSignIn.instance.signOut();
    }
    // Clear the persisted session so the login screen shows next launch.
    await _storageService.setBool(AppConstants.keyIsLoggedIn, false);
    _user = null;
    notifyListeners();
  }

  Future<bool> verifyOTP(String otp) async {
    setLoading(true);
    await Future.delayed(const Duration(seconds: 1)); // Mock verification delay
    
    if (otp == '123456') { // Mock OTP
      setLoading(false);
      return true;
    } else {
      setError('Invalid OTP');
      setLoading(false);
      return false;
    }
  }
}
