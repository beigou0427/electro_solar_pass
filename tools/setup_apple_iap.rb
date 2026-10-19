# ==============================================================================
# 執行長專用：App Store Connect 內購商品 (IAP) 自動建置腳本
# 執行環境：Mac 終端機 (需具備 fastlane 環境)
# 執行指令：fastlane exec ruby tools/setup_apple_iap.rb
# ==============================================================================
require 'spaceship'

puts "🚀 啟動 Spaceship 引擎，對接 App Store Connect API..."

# 載入我們先前配置的 P8 私鑰環境變數
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
  key_id: ENV['APP_STORE_CONNECT_KEY_ID'],
  issuer_id: ENV['APP_STORE_CONNECT_ISSUER_ID'],
  filepath: ENV['APP_STORE_CONNECT_KEY_FILEPATH']
)

bundle_id = "com.electrosolar.pass.pro"
app = Spaceship::ConnectAPI::App.find(bundle_id)

if app.nil?
  puts "❌ 找不到 App！請確認 bundle_id 是否正確，或 App 是否已在後台建立。"
  exit 1
end

# 定義 3 個旗艦商品的 Product ID 與類型
products = [
  { name: "考前 30 天急救包", id: "esp_pro_30d_290", type: "NON_RENEWING_SUBSCRIPTION" },
  { name: "單一證照 180 天穩過包", id: "esp_pro_180d_390", type: "NON_RENEWING_SUBSCRIPTION" },
  { name: "雙證照終身買斷旗艦包", id: "esp_pro_lifetime_590", type: "NON_CONSUMABLE" }
]

products.each do |p|
  puts "📦 正在向蘋果伺服器註冊商品: #{p[:name]} (#{p[:id]})..."
  begin
    # 呼叫底層 API 建立商品
    app.create_in_app_purchase(
      name: p[:name],
      product_id: p[:id],
      in_app_purchase_type: p[:type]
    )
    puts "✅ 註冊成功！"
  rescue => e
    puts "⚠️ 警告或已存在: #{e.message}"
  end
end

puts "🎉 IAP 自動建置腳本執行完畢！後續請登入網頁後台設定台幣定價 (Tier)。"
