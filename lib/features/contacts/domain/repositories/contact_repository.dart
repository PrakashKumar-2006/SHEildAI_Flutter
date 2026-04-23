import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/contact_model.dart';

abstract class ContactRepository {
  Future<Either<Failure, List<ContactModel>>> getContacts();
  Future<Either<Failure, ContactModel>> addContact(ContactModel contact);
  Future<Either<Failure, void>> updateContact(ContactModel contact);
  Future<Either<Failure, void>> deleteContact(String contactId);
  Future<Either<Failure, void>> setPrimaryContact(String contactId);
}
