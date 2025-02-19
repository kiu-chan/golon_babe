class MasterTreeInfo {
  final int id;
  final String treeType;
  final String? scientificName;
  final String? tayName;  
  final String? branch;
  final String? treeClass;
  final String? division;
  final String? family;
  final String? genus;

  MasterTreeInfo({
    required this.id,
    required this.treeType,
    this.scientificName,
    this.tayName,
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
      tayName: json['tay_name'],
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
      'tay_name': tayName,
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
  final String? imageBase64;
  final String? note;
  final String? createdAt;
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
    this.imageBase64,
    this.note,
    this.createdAt,
    this.masterInfo,
  });

factory TreeDetails.fromJson(Map<String, dynamic> json) {
  // Kiểm tra các trường bắt buộc
  if (json['id'] == null || json['master_tree_id'] == null) {
    throw Exception('Missing required fields: id or master_tree_id');
  }

  return TreeDetails(
    id: json['id'],
    masterTreeId: json['master_tree_id'],
    coordinateX: json['coordinate_x'] != null ? 
      double.tryParse(json['coordinate_x'].toString()) : null,
    coordinateY: json['coordinate_y'] != null ? 
      double.tryParse(json['coordinate_y'].toString()) : null,
    height: json['height'] != null ? 
      double.tryParse(json['height'].toString()) : null,
    diameter: json['trunk_diameter'] != null ? 
      double.tryParse(json['trunk_diameter'].toString()) : null,
    coverLevel: json['canopy_coverage'],
    seaLevel: json['sea_level_height'] != null ? 
      double.tryParse(json['sea_level_height'].toString()) : null,
    imageBase64: json['image_base64'],
    note: json['notes'],
    createdAt: json['created_at']?.toString(),
    masterInfo: json['tree_type'] != null ? MasterTreeInfo.fromJson({
      'id': json['master_tree_id'],
      'tree_type': json['tree_type'],
      'scientific_name': json['scientific_name'],
      'tay_name': json['tay_name'],
      'branch': json['branch'],
      'class': json['class'],
      'division': json['division'],
      'family': json['family'],
      'genus': json['genus'],
    }) : null,
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
      'image_base64': imageBase64,
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

class TreeAdditionalImage {
  final int? id;
  final int treeDetailId;
  final String imageBase64;
  final String? createdAt;

  TreeAdditionalImage({
    this.id,
    required this.treeDetailId,
    required this.imageBase64,
    this.createdAt,
  });

  factory TreeAdditionalImage.fromJson(Map<String, dynamic> json) {
    return TreeAdditionalImage(
      id: json['id'],
      treeDetailId: json['tree_detail_id'],
      imageBase64: json['image_base64'],
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tree_detail_id': treeDetailId,
      'image_base64': imageBase64,
      'created_at': createdAt,
    };
  }
}