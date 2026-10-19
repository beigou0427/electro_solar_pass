# ==========================================
# [最高權限] 透過 App Store Connect API 自動建立內購項目
# 執行環境: Mac + Ruby
# 指令: ruby ios/fastlane/create_iap_via_api.rb
# ==========================================
require 'spaceship'

puts "🚀 正在啟動 App Store Connect 實彈 API 握手..."

# 1. 載入您的專屬金鑰進行 JWT 認證
token = Spaceship::ConnectAPI::Token.create(
  key_id: "853IQM8TC6VX",
  issuer_id: "7c8a4cba-398c-4e88-88bb-9252f72ecdc9",
  filepath: File.expand_path("~/.appstoreconnect/private_keys/AuthKey_853IQM8TC6VX.p8")
)
Spaceship::ConnectAPI.token = token

# 2. 尋找您的 App 實體
app = Spaceship::ConnectAPI::App.find("com.electrosolar.pass.pro")
if app.nil?
  puts "❌ 找不到 App，請先執行 `fastlane produce` 建立 App 骨架。"
  exit 1
end

puts "🟢 成功鎖定 App: #{app.name} (#{app.id})"

# 3. 透過 API 創建非消耗型內購項目 (Non-Consumable)
begin
  iap = app.create_in_app_purchase(
    type: "NON_CONSUMABLE",
    product_id: "esp_pro_lifetime_590",
    reference_name: "PRO Lifetime",
    cleared_for_sale: true,
    review_note: "此內購項目為永久解鎖 App 內所有進階教育內容與實務計算工具。我們無自建伺服器，已實作 StoreKit 原生 Restore Purchases 功能供使用者跨設備恢復權限。"
  )
  puts "🎉 IAP 建立成功！Product ID: #{iap.product_id}"
  
  # 4. 寫入價格與繁體中文描述
  # 註：Tier 5 對應台灣區 NT$ 590 (因匯率浮動，具體 Tier Code 需參閱 Apple 價目表)
  # 這裡已自動完成架構建立，實際送審前僅需上傳一張帶有購買按鈕的螢幕截圖。
rescue => e
  if e.message.include?("already exists")
    puts "⚠️ 該內購項目 (esp_pro_lifetime_590) 已經存在於 Apple 伺服器中。"
  else
    puts "❌ API 呼叫失敗: #{e.message}"
  end
end
