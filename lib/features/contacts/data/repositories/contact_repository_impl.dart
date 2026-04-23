import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/hive_service.dart';
import '../../domain/models/contact_model.dart';
import '../../domain/repositories/contact_repository.dart';

class ContactRepositoryImpl implements ContactRepository {
  final HiveService _hiveService;

  ContactRepositoryImpl(this._hiveService);

  @override
  Future<Either<Failure, List<ContactModel>>> getContacts() async {
    try {
      final contactsData = await _hiveService.getContacts();
      final contacts = contactsData.map((json) => ContactModel.fromJson(json)).toList();
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
      await _hiveService.saveContact(contact.toJson());
      return Right(contact);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateContact(ContactModel contact) async {
    try {
      await _hiveService.saveContact(contact.toJson());
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteContact(String contactId) async {
    try {
      await _hiveService.deleteContact(contactId);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setPrimaryContact(String contactId) async {
    try {
      // Get all contacts
      final contactsResult = await getContacts();
      return contactsResult.fold(
        (failure) => Left(failure),
        (contacts) async {
          // Update all contacts to remove primary status
          for (final contact in contacts) {
            final updated = contact.copyWith(isPrimary: false);
            await _hiveService.saveContact(updated.toJson());
          }
          // Set the specified contact as primary
          final primaryContact = contacts.firstWhere((c) => c.id == contactId);
          final updatedPrimary = primaryContact.copyWith(isPrimary: true);
          await _hiveService.saveContact(updatedPrimary.toJson());
          return const Right(null);
        },
      );
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
