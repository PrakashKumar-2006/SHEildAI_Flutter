import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/mongo_service.dart';
import '../../../../core/constants/app_constants.dart';

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
  String? _error;
  dynamic _user; // Using dynamic to support both Firebase User and MockUser

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
      _user = MockUser(uid: savedPhone.isNotEmpty ? savedPhone : 'restored_session',
                       email: savedPhone,
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

    if (isGeneric && email != null && email.isNotEmpty) {
      // Extract name from email: prakash.kumar@gmail.com -> Prakash Kumar
      final namePart = email.split('@')[0];
      final extractedName = namePart
          .split(RegExp(r'[._-]'))
          .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '')
          .join(' ');

      debugPrint('[AuthProvider] Syncing profile: extracted "$extractedName" from "$email"');
      
      // Update local storage
      await _storageService.setUserName(extractedName);
      
      // Update Firebase if applicable
      if (_user is User) {
        try {
          await (_user as User).updateDisplayName(extractedName);
          await (_user as User).reload();
          _user = _auth?.currentUser;
        } catch (e) {
          debugPrint('Failed to update Firebase display name during sync: $e');
        }
      } else if (_user is MockUser) {
        // Update mock user
        _user = MockUser(
          uid: (_user as MockUser).uid,
          email: (_user as MockUser).email,
          displayName: extractedName,
          photoURL: (_user as MockUser).photoURL,
        );
      }

      // Update MongoDB
      try {
        final mongoService = MongoService();
        if (!mongoService.isConnected) await mongoService.connect();
        await mongoService.updateUser(email, {'name': extractedName});
      } catch (e) {
        debugPrint('Failed to update MongoDB during sync: $e');
      }

      notifyListeners();
    }
  }

  bool get isFirebaseAvailable => _isFirebaseAvailable;


  bool get isLoading => _isLoading;
  String? get error => _error;
  dynamic get user => _user;
  bool get isAuthenticated => _user != null;

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
          'phone': email,
          'password': password, // Note: In production use hashing, but this is a fallback for exploration
          'createdAt': DateTime.now().toIso8601String(),
          'name': name,
          'profile': {},
        });

        _user = MockUser(uid: email, email: email, displayName: name);
        await _storageService.setUserPhone(email);
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
         await _user!.reload();
         _user = _auth?.currentUser; // Get updated user instance
         
         await _storageService.setUserPhone(_user!.email ?? '');
         await _storageService.setUserName(name);
         await _storageService.setBool(AppConstants.keyIsLoggedIn, true);
         
         // Save user to MongoDB
         try {
           final mongoService = MongoService();
           if (!mongoService.isConnected) {
             await mongoService.connect();
           }
           await mongoService.createUser({
             'email': email,
             'phone': email, // Fallback since UI might use email as phone
             'createdAt': DateTime.now().toIso8601String(),
             'name': name,
             'profile': {},
           });
         } catch (dbError) {
           debugPrint("Failed to save user to MongoDB: $dbError");
         }
      }
      setLoading(false);
      return true;
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
    await _storageService.setUserName(name);
    await _storageService.setUserPhone(email);
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

        final name = userData['name'] as String? ?? email.split('@')[0];
        _user = MockUser(uid: email, email: email, displayName: name);
        
        await _storageService.setUserName(name);
        await _storageService.setUserPhone(userData['phone'] ?? email);
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
        // Fetch user data from MongoDB to sync local storage
        try {
          final mongoService = MongoService();
          if (!mongoService.isConnected) {
            await mongoService.connect();
          }
          final userData = await mongoService.getUser(email);
          if (userData != null && userData['name'] != null) {
            final name = userData['name'] as String;
            await _storageService.setUserName(name);
            await _storageService.setUserPhone(userData['phone'] ?? email);
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
      }
      
      setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      setError(e.message ?? 'Invalid email or password.');
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
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();

      // If user cancels the sign-in
      if (googleUser == null) {
        setLoading(false);
        return false;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

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
         } else if (email != null && email.isNotEmpty) {
           // Extract name from email: prakash.kumar@gmail.com -> Prakash Kumar
           final namePart = email.split('@')[0];
           userName = namePart
               .split(RegExp(r'[._-]'))
               .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '')
               .join(' ');
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
         
         // Save to local storage for quick access
         await _storageService.setUserPhone(_user!.email ?? '');
         await _storageService.setUserName(userName);
         await _storageService.setBool(AppConstants.keyIsLoggedIn, true);
         
         // Sync with MongoDB
         try {
           final mongoService = MongoService();
           if (!mongoService.isConnected) {
             await mongoService.connect();
           }
           
           final existingUser = await mongoService.getUser(_user!.email ?? '');
           if (existingUser == null) {
             await mongoService.createUser({
               'email': _user!.email,
               'phone': _user!.email,
               'createdAt': DateTime.now().toIso8601String(),
               'name': userName,
               'profile': {'photoUrl': _user!.photoURL},
             });
           } else {
             // Update name if it's currently null, "User", or matches the email prefix exactly (suggesting a previous fallback)
             final existingName = existingUser['name'] as String?;
             final emailPrefix = _user!.email?.split('@')[0];
             
             if (existingName == null || 
                 existingName.toLowerCase() == 'user' || 
                 existingName == emailPrefix ||
                 existingName == 'Safety Watcher') {
               await mongoService.updateUser(_user!.email!, {'name': userName});
             }
           }
         } catch (dbError) {
           debugPrint("Failed to sync Google user to MongoDB: $dbError");
         }
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
}
