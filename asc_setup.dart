import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

const keyId = '853IQM8TC6VX';
const issuerId = '7c8a4cba-398c-4e88-88bb-9252f72ecdc9';
const p8File = 'AuthKey_853IQM8TC6VX.p8';

const bundleId = 'com.electrosolar.pass.pro';
const appName = '電光證照霸 PRO';
const sku = 'ESPPRO2026';
const iapId = 'esp_pro_lifetime_590';

void main() async {
  print('🚀 啟動 App Store Connect 遠端配置程序 (Windows 跨平台模式)...');

  // 1. 檢查本機私鑰
  if (!File(p8File).existsSync()) {
    print('❌ 致命錯誤：找不到私鑰 $p8File。請確認檔案已放置於專案根目錄！');
    exit(1);
  }

  // 2. 簽署 Apple 專用 JWT (ES256)
  final p8String = File(p8File).readAsStringSync();
  final jwt = JWT(
    {
      'iss': issuerId,
      'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 1200,
      'aud': 'appstoreconnect-v1'
    },
    header: {'alg': 'ES256', 'kid': keyId, 'typ': 'JWT'},
  );
  
  final token = jwt.sign(ECPrivateKey(p8String), algorithm: JWTAlgorithm.ES256);
  print('✅ JWT 授權簽章生成成功。');

  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };
