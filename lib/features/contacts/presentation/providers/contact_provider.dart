import 'package:flutter/foundation.dart';
import '../../data/repositories/contact_repository_impl.dart';
import '../../domain/models/contact_model.dart';

class ContactProvider extends ChangeNotifier {
  final ContactRepositoryImpl _contactRepository;

  List<ContactModel> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  ContactProvider({required ContactRepositoryImpl contactRepository})
      : _contactRepository = contactRepository;

  List<ContactModel> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ContactModel? get primaryContact {
    try {
      return _contacts.firstWhere((contact) => contact.isPrimary);
    } catch (e) {
      return null;
    }
  }

  Future<void> loadContacts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _contactRepository.getContacts();
      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (contacts) {
          _contacts = contacts;
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addContact({
    required String name,
    required String phone,
    String? relationship,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final contact = ContactModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        phone: phone,
        relationship: relationship,
        isPrimary: _contacts.isEmpty, // First contact is primary by default
        createdAt: DateTime.now(),
      );

      final result = await _contactRepository.addContact(contact);
      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (_) {
          _contacts.add(contact);
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateContact(ContactModel contact) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _contactRepository.updateContact(contact);
      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (_) {
          final index = _contacts.indexWhere((c) => c.id == contact.id);
          if (index != -1) {
            _contacts[index] = contact;
          }
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteContact(String contactId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _contactRepository.deleteContact(contactId);
      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (_) {
          _contacts.removeWhere((c) => c.id == contactId);
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPrimaryContact(String contactId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _contactRepository.setPrimaryContact(contactId);
      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (_) {
          // Reload contacts to get updated primary status
          loadContacts();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
