import 'dart:async';
import 'package:postgres/postgres.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseConfig {
  String host;
  int port;
  String database;
  String username;
  String password;
  bool useSSL;

  DatabaseConfig({
    this.host = 'mario-pgbouncer2.ntoric.com',
    this.port = 6432,
    this.database = 'mariodb',
    this.username = 'mariodbuser',
    this.password = 'mariodbpassword',
    this.useSSL = false,
  });

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'database': database,
    'username': username,
    'password': password,
    'useSSL': useSSL,
  };

  factory DatabaseConfig.fromJson(Map<String, dynamic> json) => DatabaseConfig(
    host: json['host'] ?? 'mario-pgbouncer2.ntoric.com',
    port: json['port'] ?? 6432,
    database: json['database'] ?? 'mariodb',
    username: json['username'] ?? 'mariodbuser',
    password: json['password'] ?? 'mariodbpassword',
    useSSL: json['useSSL'] ?? false,
  );
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Connection? _connection;
  DatabaseConfig _config = DatabaseConfig();

  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionStatusChanged => _connectionStatusController.stream;

  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool? _lastStatus;

  void _notifyStatus(bool status) {
    if (_lastStatus != status) {
      _lastStatus = status;
      _connectionStatusController.add(status);
    }
  }

  void startConnectionMonitor() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _checkAndReconnect();
    });
  }

  void stopConnectionMonitor() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> _checkAndReconnect() async {
    if (_isConnecting) return;
    
    final active = await isConnected();
    if (!active) {
      print('Database connection lost. Attempting automatic reconnection...');
      _notifyStatus(false);
      await connect();
    } else {
      _notifyStatus(true);
    }
  }

  Connection? get connection => _connection;
  DatabaseConfig get config => _config;

  Future<void> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('db_config');
    if (configJson != null) {
      try {
        final entries = configJson.split(',').map((e) {
          final parts = e.split('=');
          if (parts.length >= 2) {
            // Join sublist in case value contains '='
            return MapEntry(parts[0], parts.sublist(1).join('='));
          }
          return const MapEntry('', '');
        }).where((entry) => entry.key.isNotEmpty);

        _config = DatabaseConfig.fromJson(
          Map<String, dynamic>.from(Map<String, String>.fromEntries(entries)),
        );
      } catch (e) {
        print('Error parsing db_config from SharedPreferences: $e');
        _config = DatabaseConfig();
      }
    }
  }

  Future<void> saveConfig(DatabaseConfig config) async {
    _config = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('db_config', 
      'host=${config.host},port=${config.port},database=${config.database},username=${config.username},password=${config.password},useSSL=${config.useSSL}');
  }

  Future<bool> connect() async {
    if (_isConnecting) return false;
    _isConnecting = true;
    try {
      _connection = await Connection.open(
        Endpoint(
          host: _config.host,
          port: _config.port,
          database: _config.database,
          username: _config.username,
          password: _config.password,
        ),
        settings: ConnectionSettings(
          sslMode: _config.useSSL ? SslMode.require : SslMode.disable,
        ),
      ).timeout(const Duration(seconds: 5));
      _notifyStatus(true);
      startConnectionMonitor();
      return true;
    } catch (e) {
      print('Database connection error: $e');
      _notifyStatus(false);
      startConnectionMonitor();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    stopConnectionMonitor();
    await _connection?.close();
    _connection = null;
    _notifyStatus(false);
  }

  Future<bool> isConnected() async {
    if (_connection == null) return false;
    try {
      await _connection!.execute(Sql.named('SELECT 1'));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> verifyConnection() async {
    if (_connection == null) throw Exception('Database not connected');
    
    // Just verify we can query the database
    // Tables are assumed to be created by the Node.js backend
    await _connection!.execute(Sql.named('SELECT 1'));
  }

  Future<List<Map<String, dynamic>>> query(String sql, [Map<String, dynamic>? params]) async {
    if (_connection == null) throw Exception('Database not connected');
    
    final result = await _connection!.execute(Sql.named(sql), parameters: params);
    
    return result.map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < result.schema.columns.length; i++) {
        map[result.schema.columns[i].columnName!] = row[i];
      }
      return map;
    }).toList();
  }

  Future<Map<String, dynamic>?> queryOne(String sql, [Map<String, dynamic>? params]) async {
    final results = await query(sql, params);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> execute(String sql, [Map<String, dynamic>? params]) async {
    if (_connection == null) throw Exception('Database not connected');
    await _connection!.execute(Sql.named(sql), parameters: params);
  }

  Future<dynamic> transaction(Future<dynamic> Function() action) async {
    if (_connection == null) throw Exception('Database not connected');
    
    await _connection!.execute(Sql.named('BEGIN'));
    try {
      final result = await action();
      await _connection!.execute(Sql.named('COMMIT'));
      return result;
    } catch (e) {
      await _connection!.execute(Sql.named('ROLLBACK'));
      rethrow;
    }
  }
}