class MasterTreeInfo {
  final int id;
  final String treeType;
  final String? scientificName;
  final String? vietnameseName;
  final String? branch;
  final String? treeClass;
  final String? division;
  final String? family;
  final String? genus;

  MasterTreeInfo({
    required this.id,
    required this.treeType,
    this.scientificName,
    this.vietnameseName,
    this.branch,
    this.treeClass,
    this.division,
    this.family,
    this.genus,
  });

  factory MasterTreeInfo.fromJson(Map<String, dynamic> json) {
    return MasterTreeInfo(
      id: json['id'],
      treeType: json['tree_type'],
      scientificName: json['scientific_name'],
      vietnameseName: json['vietnamese_name'],
      branch: json['branch'],
      treeClass: json['class'],
      division: json['division'],
      family: json['family'],
      genus: json['genus'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tree_type': treeType,
      'scientific_name': scientificName,
      'vietnamese_name': vietnameseName,
      'branch': branch,
      'class': treeClass,
      'division': division,
      'family': family,
      'genus': genus,
    };
  }
}

class TreeDetails {
  final int? id;
  final int masterTreeId;
  final double? coordinateX;
  final double? coordinateY;
  final double? height;
  final double? diameter;
  final String? coverLevel;
  final double? seaLevel;
  final String? imagePath;
  final String? note;
  final String? createdAt;  // Đổi kiểu từ DateTime sang String
  final MasterTreeInfo? masterInfo;

  TreeDetails({
    this.id,
    required this.masterTreeId,
    this.coordinateX,
    this.coordinateY,
    this.height,
    this.diameter,
    this.coverLevel,
    this.seaLevel,
    this.imagePath,
    this.note,
    this.createdAt,
    this.masterInfo,
  });

  factory TreeDetails.fromJson(Map<String, dynamic> json) {
    return TreeDetails(
      id: json['id'],
      masterTreeId: json['master_tree_id'],
      coordinateX: json['coordinate_x'] != null ? double.parse(json['coordinate_x'].toString()) : null,
      coordinateY: json['coordinate_y'] != null ? double.parse(json['coordinate_y'].toString()) : null,
      height: json['height'] != null ? double.parse(json['height'].toString()) : null,
      diameter: json['trunk_diameter'] != null ? double.parse(json['trunk_diameter'].toString()) : null,
      coverLevel: json['canopy_coverage'],
      seaLevel: json['sea_level_height'] != null ? double.parse(json['sea_level_height'].toString()) : null,
      imagePath: json['image_url'],
      note: json['notes'],
      createdAt: json['created_at']?.toString(),  // Chỉ chuyển sang String
      masterInfo: json['tree_type'] != null 
        ? MasterTreeInfo.fromJson({
            'id': json['master_tree_id'],
            'tree_type': json['tree_type'],
            'scientific_name': json['scientific_name'],
            'vietnamese_name': json['vietnamese_name'],
            'branch': json['branch'],
            'class': json['class'],
            'division': json['division'],
            'family': json['family'],
            'genus': json['genus'],
          }) 
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'master_tree_id': masterTreeId,
      'coordinate_x': coordinateX,
      'coordinate_y': coordinateY,
      'height': height,
      'trunk_diameter': diameter,
      'canopy_coverage': coverLevel,
      'sea_level_height': seaLevel,
      'image_url': imagePath,
      'notes': note,
      'created_at': createdAt,
    };
  }
}

class TreeConstants {
  static const List<String> coverLevels = [
    'Dày đặc', 
    'Trung bình', 
    'Thưa thớt'
  ];
}