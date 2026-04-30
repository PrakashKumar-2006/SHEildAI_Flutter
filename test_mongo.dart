import 'package:mongo_dart/mongo_dart.dart';

void main() async {
  try {
    var db = await Db.create('mongodb+srv://mehrashiv8889_db_user:Y551z4tmn7t2rBRo@cluster0.mrafgss.mongodb.net/sheildai?retryWrites=true&w=majority');
    await db.open();
    print('Connected');
    await db.close();
  } catch (e) {
    print('Error: $e');
  }
}
