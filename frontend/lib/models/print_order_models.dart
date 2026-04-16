import 'package:cloud_firestore/cloud_firestore.dart';

class PrintOrderSummary {
  final String filePath;
  final String fileName;
  final String fileSize;
  final String pages;
  final String layout;
  final String paperSize;
  final String perSheet;
  final String margins;
  final String scale;
  final String quality;
  final String printType;
  final bool doubleSide;
  final bool staple;
  final bool lamination;
  final bool glossy;
  final bool spiralBinding;
  final bool tapeBinding;
  final int copies;

  const PrintOrderSummary({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.pages,
    required this.layout,
    required this.paperSize,
    required this.perSheet,
    required this.margins,
    required this.scale,
    required this.quality,
    required this.printType,
    required this.doubleSide,
    required this.staple,
    required this.lamination,
    required this.glossy,
    required this.spiralBinding,
    required this.tapeBinding,
    required this.copies,
  });
}

class PrintOrderRecord {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String ownerId;
  final String ownerName;
  final String shopName;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final String fileType;
  final String fileSize;
  final int pageCount;
  final int copies;
  final String pages;
  final String printType;
  final bool doubleSide;
  final String layout;
  final String paperSize;
  final String perSheet;
  final String margins;
  final String scale;
  final String quality;
  final bool staple;
  final bool lamination;
  final bool glossy;
  final bool spiralBinding;
  final bool tapeBinding;
  final double printCost;
  final double extrasCost;
  final double totalAmount;
  final String paymentId;
  final String status;
  final DateTime? createdAt;
  final DateTime? statusUpdatedAt;
  final DateTime? completedAt;

  const PrintOrderRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.ownerId,
    required this.ownerName,
    required this.shopName,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.fileType,
    required this.fileSize,
    required this.pageCount,
    required this.copies,
    required this.pages,
    required this.printType,
    required this.doubleSide,
    required this.layout,
    required this.paperSize,
    required this.perSheet,
    required this.margins,
    required this.scale,
    required this.quality,
    required this.staple,
    required this.lamination,
    required this.glossy,
    required this.spiralBinding,
    required this.tapeBinding,
    required this.printCost,
    required this.extrasCost,
    required this.totalAmount,
    required this.paymentId,
    required this.status,
    required this.createdAt,
    required this.statusUpdatedAt,
    required this.completedAt,
  });

  bool get isPending => status == PrintOrderStatus.pending;
  bool get isProcessing => status == PrintOrderStatus.processing;
  bool get isCompleted => status == PrintOrderStatus.completed;

  String get statusLabel {
    switch (status) {
      case PrintOrderStatus.processing:
        return 'Processing';
      case PrintOrderStatus.completed:
        return 'Completed';
      case PrintOrderStatus.pending:
      default:
        return 'Pending';
    }
  }

  factory PrintOrderRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};

    DateTime? readTimestamp(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      return null;
    }

    double readDouble(String key) {
      final value = data[key];
      if (value is num) return value.toDouble();
      return 0;
    }

    int readInt(String key) {
      final value = data[key];
      if (value is num) return value.toInt();
      return 0;
    }

    return PrintOrderRecord(
      id: snapshot.id,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'Customer').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      ownerId: (data['ownerId'] ?? '').toString(),
      ownerName: (data['ownerName'] ?? '').toString(),
      shopName: (data['shopName'] ?? '').toString(),
      fileName: (data['fileName'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      downloadUrl: (data['downloadUrl'] ?? '').toString(),
      fileType: (data['fileType'] ?? '').toString(),
      fileSize: (data['fileSize'] ?? '').toString(),
      pageCount: readInt('pageCount'),
      copies: readInt('copies'),
      pages: (data['pages'] ?? 'All').toString(),
      printType: (data['printType'] ?? 'Black & White').toString(),
      doubleSide: data['doubleSide'] == true,
      layout: (data['layout'] ?? 'Portrait').toString(),
      paperSize: (data['paperSize'] ?? 'A4').toString(),
      perSheet: (data['perSheet'] ?? '1').toString(),
      margins: (data['margins'] ?? 'Default').toString(),
      scale: (data['scale'] ?? 'Fit to Page').toString(),
      quality: (data['quality'] ?? 'Standard').toString(),
      staple: data['staple'] == true,
      lamination: data['lamination'] == true,
      glossy: data['glossy'] == true,
      spiralBinding: data['spiralBinding'] == true,
      tapeBinding: data['tapeBinding'] == true,
      printCost: readDouble('printCost'),
      extrasCost: readDouble('extrasCost'),
      totalAmount: readDouble('totalAmount'),
      paymentId: (data['paymentId'] ?? '').toString(),
      status: (data['status'] ?? PrintOrderStatus.pending).toString(),
      createdAt: readTimestamp('createdAt'),
      statusUpdatedAt: readTimestamp('statusUpdatedAt'),
      completedAt: readTimestamp('completedAt'),
    );
  }
}

class PrintOrderStatus {
  static const pending = 'pending';
  static const processing = 'processing';
  static const completed = 'completed';
}
