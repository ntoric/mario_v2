class Item {
  final String id;
  final String storeId;
  final String categoryId;
  final String? categoryName;
  final String name;
  final String? description;
  final double price;
  final String? hsnCode;
  final double taxPercent;
  final bool isActive;

  Item({
    required this.id,
    required this.storeId,
    required this.categoryId,
    this.categoryName,
    required this.name,
    this.description,
    required this.price,
    this.hsnCode,
    required this.taxPercent,
    required this.isActive,
  });

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      storeId: json['storeId'] ?? json['store_id'],
      categoryId: json['categoryId'] ?? json['category_id'],
      categoryName: json['categoryName'] ?? json['category_name'] ?? json['category_id'],
      name: json['name'],
      description: json['description'],
      price: _parseDouble(json['price']),
      hsnCode: json['hsnCode'] ?? json['hsn_code'],
      taxPercent: _parseDouble(json['taxPercent'] ?? json['tax_percent']),
      isActive: json['isActive'] ?? json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'name': name,
      'description': description,
      'price': price,
      'hsnCode': hsnCode,
      'taxPercent': taxPercent,
      'isActive': isActive,
    };
  }
}