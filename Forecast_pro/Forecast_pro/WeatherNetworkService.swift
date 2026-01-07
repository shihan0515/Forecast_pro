import Foundation
import Alamofire

class WeatherNetworkService {
    static let shared = WeatherNetworkService()
    
    private init() {}
    
    // 記錄最後一次 AI 請求時間，防止過於頻繁
    private var lastAIRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 3.0 // 至少間隔 3 秒
    
    // 1. 獲取天氣資料
    func fetchWeather(completion: @escaping (Result<WeatherData, Error>) -> Void) {
        let url = "https://api.open-meteo.com/v1/forecast?latitude=25.0478&longitude=121.5319&daily=temperature_2m_max&timezone=auto"
        
        AF.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    let weatherData = try decoder.decode(WeatherData.self, from: data)
                    completion(.success(weatherData))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 2. 獲取 OpenAI 建議（帶自動重試）
    func fetchAIAdvice(weatherInfo: String, completion: @escaping (String) -> Void) {
        fetchAIAdvice(weatherInfo: weatherInfo, retryCount: 0, maxRetries: 2, completion: completion)
    }
    
    // 帶重試機制的內部方法
    private func fetchAIAdvice(weatherInfo: String, retryCount: Int, maxRetries: Int, completion: @escaping (String) -> Void) {
        // 檢查請求間隔
        if let lastTime = lastAIRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastTime)
            if timeSinceLastRequest < minimumRequestInterval {
                let waitTime = minimumRequestInterval - timeSinceLastRequest
                print("請求間隔太短，等待 \(Int(waitTime)) 秒...")
                DispatchQueue.global().asyncAfter(deadline: .now() + waitTime) {
                    self.fetchAIAdvice(weatherInfo: weatherInfo, retryCount: retryCount, maxRetries: maxRetries, completion: completion)
                }
                return
            }
        }
        
        lastAIRequestTime = Date()
        
        let apiKey = ""
        let url = "https://api.openai.com/v1/chat/completions"
        
        let parameters: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "你是一位貼心的生活秘書。我會提供你接下來一周的天氣預報，請根據氣溫給予穿衣、交通或是否帶傘的簡短建議（約100字）。"],
                ["role": "user", "content": "這是接下來的天氣數據：\(weatherInfo)"]
            ]
        ]
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseData { [weak self] response in
                // 檢查 HTTP 狀態碼
                if let statusCode = response.response?.statusCode {
                    print("OpenAI API 狀態碼: \(statusCode), 重試次數: \(retryCount)/\(maxRetries)")
                    
                    // 處理不同的 HTTP 狀態碼
                    if statusCode != 200 {
                        var errorMessage = ""
                        var retryAfterSeconds: Double? = nilㄦ
                        
                        // 嘗試解析錯誤響應
                        if let data = response.data, let errorString = String(data: data, encoding: .utf8) {
                            print("OpenAI API 錯誤響應: \(errorString)")
                            
                            // 嘗試解析 JSON 錯誤訊息
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let errorObj = json["error"] as? [String: Any] {
                                if let message = errorObj["message"] as? String {
                                    errorMessage = message
                                }
                                // 檢查是否有配額相關信息
                                if let code = errorObj["code"] as? String {
                                    print("錯誤代碼: \(code)")
                                }
                            }
                        }
                        
                        // 檢查 Retry-After header
                        if let retryAfter = response.response?.value(forHTTPHeaderField: "Retry-After"),
                           let seconds = Double(retryAfter) {
                            retryAfterSeconds = seconds
                        }
                        
                        // 如果是 429 錯誤且還有重試次數，則自動重試
                        if statusCode == 429 && retryCount < maxRetries {
                            let waitTime = retryAfterSeconds ?? Double(pow(2.0, Double(retryCount + 1))) * 5.0 // 指數退避：5秒, 10秒, 20秒
                            let waitMinutes = Int(waitTime / 60)
                            let waitSeconds = Int(waitTime.truncatingRemainder(dividingBy: 60))
                            
                            print("遇到速率限制，等待 \(waitMinutes)分\(waitSeconds)秒後重試...")
                            
                            DispatchQueue.global().asyncAfter(deadline: .now() + waitTime) {
                                self?.fetchAIAdvice(weatherInfo: weatherInfo, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                            }
                            return
                        }
                        
                        // 根據狀態碼提供友好的錯誤訊息
                        let userFriendlyMessage: String
                        switch statusCode {
                        case 401:
                            userFriendlyMessage = "API 金鑰無效或已過期。請檢查：\n1. API 金鑰是否正確\n2. 是否還有可用配額\n3. 金鑰是否已啟用"
                        case 403:
                            userFriendlyMessage = "API 金鑰沒有權限訪問此服務，請檢查 API 金鑰權限設定"
                        case 429:
                            if let seconds = retryAfterSeconds {
                                let minutes = Int(seconds / 60)
                                userFriendlyMessage = "請求過於頻繁（已重試 \(retryCount + 1) 次）。\n請檢查：\n1. API 配額是否已用完\n2. 帳戶的速率限制設定\n3. 建議稍候 \(minutes > 0 ? "\(minutes) 分鐘" : "\(Int(seconds)) 秒") 後再試\n\n錯誤詳情：\(errorMessage.isEmpty ? "速率限制" : errorMessage)"
                            } else {
                                userFriendlyMessage = "請求過於頻繁（已重試 \(retryCount + 1) 次）。\n可能原因：\n1. API 配額已用完\n2. 達到每分鐘/每小時請求限制\n3. 建議檢查 OpenAI 帳戶使用情況\n\n錯誤詳情：\(errorMessage.isEmpty ? "速率限制" : errorMessage)"
                            }
                        case 500...599:
                            userFriendlyMessage = "OpenAI 伺服器暫時無法回應，請稍後再試"
                        default:
                            userFriendlyMessage = errorMessage.isEmpty ? "無法取得 AI 建議（錯誤碼：\(statusCode)）" : errorMessage
                        }
                        
                        completion("無法取得 AI 建議：\(userFriendlyMessage)")
                        return
                    }
                }
                
                // 確保 response.data 存在且不為空
                guard let data = response.data, !data.isEmpty else {
                    print("錯誤: 響應數據為空")
                    if let error = response.error {
                        print("Alamofire 錯誤: \(error)")
                    }
                    completion("無法取得 AI 建議：響應數據為空")
                    return
                }
                
                // 打印原始響應以便調試
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("OpenAI API 響應成功: \(jsonString.prefix(500))")
                }
                
                do {
                    let decoder = JSONDecoder()
                    let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)
                    if let content = openAIResponse.choices.first?.message.content {
                        completion(content)
                    } else {
                        print("錯誤: OpenAI 響應中沒有 content")
                        completion("無法取得 AI 建議：響應格式錯誤")
                    }
                } catch {
                    print("JSON 解析錯誤: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("嘗試解析的 JSON: \(jsonString)")
                    }
                    // 更詳細的錯誤信息
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            completion("無法取得 AI 建議：缺少欄位 '\(key.stringValue)' - \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            completion("無法取得 AI 建議：類型不匹配 '\(type)' - \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            completion("無法取得 AI 建議：值為空 '\(type)' - \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            completion("無法取得 AI 建議：數據損壞 - \(context.debugDescription)")
                        @unknown default:
                            completion("無法取得 AI 建議：解析錯誤 - \(error.localizedDescription)")
                        }
                    } else {
                        completion("無法取得 AI 建議：解析錯誤 - \(error.localizedDescription)")
                    }
                }
            }
    }
}
