import SwiftUI
import Combine

class WeatherController: ObservableObject {
    @Published var weatherItems: [WeatherItem] = []
    @Published var aiAdvice: String = "點擊下方按鈕獲取 AI 生活建議..."
    @Published var isLoading: Bool = false
    
    private let networkService = WeatherNetworkService.shared
    
    func updateAllData() {
        isLoading = true
        
        // Step 1: 抓天氣
        networkService.fetchWeather { [weak self] result in
            switch result {
            case .success(let data):
                let items = zip(data.daily.time, data.daily.temperature_2m_max).map {
                    WeatherItem(date: $0, temp: $1)
                }
                
                DispatchQueue.main.async {
                    self?.weatherItems = items
                    // Step 2: 抓到天氣後，將資料整理成字串傳給 AI
                    self?.getAIAdvice(items: items)
                }
                
            case .failure(let error):
                print("天氣抓取失敗: \(error)")
                self?.isLoading = false
            }
        }
    }
    
    private func getAIAdvice(items: [WeatherItem]) {
        let weatherDescription = items.map { "\($0.date): \($0.temp)度" }.joined(separator: ", ")
        
        networkService.fetchAIAdvice(weatherInfo: weatherDescription) { [weak self] advice in
            DispatchQueue.main.async {
                self?.aiAdvice = advice
                self?.isLoading = false
            }
        }
    }
}
