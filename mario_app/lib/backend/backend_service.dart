import 'database_service.dart';
import 'auth_backend.dart';
import 'stores_backend.dart';
import 'tables_backend.dart';
import 'categories_backend.dart';
import 'items_backend.dart';
import 'orders_backend.dart';
import 'bills_backend.dart';
import 'system_backend.dart';

export 'database_service.dart';

class BackendService {
  static final BackendService _instance = BackendService._internal();
  factory BackendService() => _instance;
  BackendService._internal();

  final DatabaseService database = DatabaseService();
  
  late final AuthBackend auth;
  late final StoresBackend stores;
  late final TablesBackend tables;
  late final CategoriesBackend categories;
  late final ItemsBackend items;
  late final OrdersBackend orders;
  late final BillsBackend bills;
  late final SystemBackend system;

  String? _currentToken;
  Map<String, dynamic>? _currentUser;

  Future<void> initialize() async {
    await database.loadConfig();
    
    auth = AuthBackend(database);
    stores = StoresBackend(database);
    tables = TablesBackend(database);
    categories = CategoriesBackend(database);
    items = ItemsBackend(database);
    orders = OrdersBackend(database);
    bills = BillsBackend(database);
    system = SystemBackend(database);
  }

  Future<bool> connectToDatabase(DatabaseConfig config) async {
    await database.saveConfig(config);
    final connected = await database.connect();
    if (connected) {
      await database.verifyConnection();
    }
    return connected;
  }

  Future<void> disconnect() async {
    await database.disconnect();
  }

  Future<bool> get isConnected => database.isConnected();
  
  String? get currentToken => _currentToken;
  Map<String, dynamic>? get currentUser => _currentUser;
  
  set currentToken(String? token) => _currentToken = token;

  Future<bool> login(String username, String password) async {
    final result = await auth.login(username, password);
    if (result != null) {
      _currentToken = result['token'];
      _currentUser = result['user'];
      return true;
    }
    return false;
  }

  Future<bool> validateToken() async {
    if (_currentToken == null) return false;
    final user = auth.verifyToken(_currentToken!);
    if (user != null) {
      _currentUser = await auth.getMe(_currentToken!);
      return _currentUser != null;
    }
    return false;
  }

  void logout() {
    _currentToken = null;
    _currentUser = null;
  }

  String? get currentUserId => _currentUser?['id'];
  String? get currentUserRole => _currentUser?['role'];
  String? get currentStoreId => _currentUser?['storeId'];
}