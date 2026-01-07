import SwiftUI

struct ContentView: View {
    @StateObject private var controller = WeatherController()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // AI 建議區塊
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("AI 小助手建議")
                        }
                        .font(.headline)
                        .foregroundColor(.purple)
                        
                        Text(controller.aiAdvice)
                            .font(.subheadline)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(15)
                    .padding(.horizontal)

                    // 天氣列表區塊
                    ForEach(controller.weatherItems) { item in
                        HStack {
                            Text(item.date)
                            Spacer()
                            Text("\(item.temp, specifier: "%.1f")°")
                                .bold()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("AI 天氣助手")
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    controller.updateAllData()
                }) {
                    if controller.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("同步最新氣象與 AI 建議")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                .disabled(controller.isLoading)
            }
        }
    }
}
