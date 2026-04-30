import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/mongo_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/contact_model.dart';
import '../../domain/repositories/contact_repository.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class ContactRepositoryImpl implements ContactRepository {
  final MongoService _mongoService;
  final StorageService _storageService;

  ContactRepositoryImpl(this._mongoService, this._storageService);

  String get _userEmail => _storageService.getString(AppConstants.keyUserEmail) ?? '';
  String get _userPhone => _storageService.getString(AppConstants.keyUserPhone) ?? '';

  @override
  Future<Either<Failure, List<ContactModel>>> getContacts() async {
    try {
      if (_userEmail.isEmpty && _userPhone.isEmpty) return const Right([]);
      
      final contactsData = await _mongoService.getContactsForUser(
        email: _userEmail,
        phone: _userPhone,
      );
      final contacts = contactsData.map((json) {
        // Map MongoDB _id to string id for ContactModel
        final Map<String, dynamic> mappedJson = Map.from(json);
        if (json['_id'] != null) {
          mappedJson['id'] = json['_id'].toString();
        }
        return ContactModel.fromJson(mappedJson);
      }).toList();

      // Sort: primary first, then by name
      contacts.sort((a, b) {
        if (a.isPrimary && !b.isPrimary) return -1;
        if (!a.isPrimary && b.isPrimary) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return Right(contacts);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ContactModel>> addContact(ContactModel contact) async {
    try {
      if (_userEmail.isEmpty) return Left(StorageFailure('User not logged in'));
      
      final contactData = contact.toJson();
      contactData['user_email'] = _userEmail;
      // Remove local ID if it's just a timestamp, let Mongo handle it or keep it as metadata
      
      await _mongoService.addContact(_userEmail, contactData);
      return Right(contact);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateContact(ContactModel contact) async {
    try {
      if (contact.id.isEmpty) return Left(StorageFailure('Contact ID missing'));
      
      final updates = contact.toJson();
      updates.remove('id');
      updates.remove('_id');
      
      await _mongoService.updateContact(contact.id, updates);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteContact(String contactId) async {
    try {
      await _mongoService.deleteContact(contactId);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setPrimaryContact(String contactId) async {
    try {
      final contactsResult = await getContacts();
      return contactsResult.fold(
        (failure) => Left(failure),
        (contacts) async {
          for (final contact in contacts) {
            final isTarget = contact.id == contactId;
            await _mongoService.updateContact(contact.id, {'isPrimary': isTarget});
          }
          return const Right(null);
        },
      );
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
