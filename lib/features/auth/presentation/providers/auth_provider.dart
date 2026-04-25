import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/mongo_service.dart';

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
    try {
      _auth = FirebaseAuth.instance;
      _isFirebaseAvailable = true;
      _auth!.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
      });
    } catch (e) {
      debugPrint("AuthProvider: Firebase not available. Auth features will be disabled. Error: $e");
      _isFirebaseAvailable = false;
    }
  }

  bool get isFirebaseAvailable => _isFirebaseAvailable;


  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;
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
        
        setLoading(false);
        return true;
      } catch (e) {
        debugPrint('Local signup failed: $e. Falling back to Guest Explorer mode.');
        _user = MockUser(uid: 'guest_explorer', email: email, displayName: 'Guest Explorer');
        await _storageService.setUserName('Guest Explorer');
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
        
        setLoading(false);
        return true;
      } catch (e) {
        debugPrint('Local login failed: $e. Falling back to Guest Explorer mode.');
        _user = MockUser(uid: 'guest_explorer', email: email, displayName: 'Guest Explorer');
        await _storageService.setUserName('Guest Explorer');
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
            
            // Sync Firebase display name if it's null
            if (_user!.displayName == null || _user!.displayName!.isEmpty) {
              await _user!.updateDisplayName(name);
              await _user!.reload();
              _user = _auth?.currentUser;
            }
          }
        } catch (dbError) {
          debugPrint("Failed to sync user data from MongoDB: $dbError");
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
         final userName = _user!.displayName ?? (_user!.email?.split('@')[0] ?? 'Google User');
         
         // Save to local storage for quick access
         await _storageService.setUserPhone(_user!.email ?? '');
         await _storageService.setUserName(userName);
         
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
           } else if (existingUser['name'] == null || existingUser['name'] == existingUser['email']?.split('@')[0]) {
             // Update name if it's currently just a fallback
             await mongoService.updateUser(_user!.email!, {'name': userName});
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
    _user = null;
    notifyListeners();
  }
}
