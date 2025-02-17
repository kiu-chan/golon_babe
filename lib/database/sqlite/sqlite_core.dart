import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SQLiteCore {
  static Database? _database;
  static final SQLiteCore _instance = SQLiteCore._internal();
  
  factory SQLiteCore() => _instance;
  SQLiteCore._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, 'trees_database.db');
    
    print('Khởi tạo database tại: $dbPath');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        print('Tạo các bảng database...');
        
        // Bảng master_tree_info
        await db.execute('''
          CREATE TABLE master_tree_info (
            id INTEGER PRIMARY KEY,
            tree_type TEXT NOT NULL,
            scientific_name TEXT,
            tay_name TEXT,
            branch TEXT,
            class TEXT,
            division TEXT,
            family TEXT,
            genus TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Bảng tree_details
        await db.execute('''
          CREATE TABLE tree_details (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            master_tree_id INTEGER NOT NULL,
            coordinate_x REAL,
            coordinate_y REAL,
            height REAL,
            trunk_diameter REAL,
            canopy_coverage TEXT,
            sea_level_height REAL,
            image_base64 TEXT,
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            sync_status TEXT DEFAULT 'pending',
            FOREIGN KEY (master_tree_id) REFERENCES master_tree_info (id)
              ON DELETE CASCADE
              ON UPDATE CASCADE
          )
        ''');

        // Tạo các indexes để tối ưu truy vấn
        await db.execute('CREATE INDEX idx_master_tree_id ON tree_details(master_tree_id)');
        await db.execute('CREATE INDEX idx_sync_status ON tree_details(sync_status)');
        await db.execute('CREATE INDEX idx_created_at ON tree_details(created_at)');
        
        print('Đã tạo xong cấu trúc database');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('Nâng cấp database từ version $oldVersion lên $newVersion');
      },
      onOpen: (db) {
        print('Đã mở database thành công');
      },
    );
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('Đã đóng kết nối database');
    }
  }

  Future<void> vacuum() async {
    try {
      final db = await database;
      await db.execute('VACUUM');
      print('Đã dọn dẹp database');
    } catch (e) {
      print('Lỗi khi dọn dẹp database: $e');
    }
  }
}