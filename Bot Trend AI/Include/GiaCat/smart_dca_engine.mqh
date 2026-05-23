#ifndef SMART_DCA_ENGINE_MQH
#define SMART_DCA_ENGINE_MQH

// === CẤU HÌNH SMART DCA ENGINE (LƯỚI DCA THÔNG MINH XÁC SUẤT) ===

class CSmartDCAEngine {
private:
   string   m_symbol;
   double   m_base_multiplier;  // Hệ số nhân DCA cơ bản (InpHeLotMul, ví dụ: 1.18)
   double   m_max_martingale;   // Ngưỡng chặn Martingale tối đa (Cứng 1.25)
   double   m_min_recovery_prob; // Xác suất hồi phục tối thiểu để DCA (ví dụ: 60.0%)

public:
   // Constructor
   CSmartDCAEngine() :
      m_symbol(""),
      m_base_multiplier(1.18),
      m_max_martingale(1.25),
      m_min_recovery_prob(60.0) {}

   // Khởi tạo Smart DCA
   void Init(string symbol, double base_mul, double min_rec_prob) {
      m_symbol = symbol;
      m_base_multiplier = base_mul;
      if(m_base_multiplier > m_max_martingale) {
         m_base_multiplier = m_max_martingale; // Ràng buộc cứng tối đa 1.25
      }
      m_min_recovery_prob = min_rec_prob;
   }

   // Tính toán điểm số Xác suất hồi phục (Recovery Probability Score) [0.0 - 100.0]
   double CalculateRecoveryProbability(double regimeScore,     // [0: Ranging -> 100: Trending]
                                       double atrScore,        // [0: Low Vol -> 100: High Vol/Spike]
                                       double trendPressure,   // Lực ép xu hướng ngược chiều [0: Không ép -> 100: Ép cực mạnh]
                                       double basketHealth,    // Sức khỏe rổ hiện tại [0: Nguy kịch -> 100: Khỏe mạnh]
                                       double spreadQuality)   // Chất lượng spread [0: Giãn nới cực mạnh -> 100: Cực chuẩn/hẹp]
   {
      // Công thức tính xác suất hồi phục tuyến tính có trọng số:
      // - Trend ép càng mạnh -> Xác suất hồi phục rổ ngược trend càng thấp (trọng số 30%)
      // - Càng Trending mạnh -> Càng dễ bị kéo lưới dài -> Giảm xác suất hồi (trọng số 25%)
      // - Biến động ATR quá cao -> Dễ quét cháy -> Giảm xác suất hồi (trọng số 15%)
      // - Sức khỏe rổ lệnh hiện tại (trọng số 20%)
      // - Chất lượng Spread vào lệnh (trọng số 10%)
      
      double riskPoints = (0.25 * regimeScore) + 
                          (0.15 * atrScore) + 
                          (0.30 * trendPressure) + 
                          (0.20 * (100.0 - basketHealth)) + 
                          (0.10 * (100.0 - spreadQuality));
                          
      double probability = 100.0 - riskPoints;
      if(probability < 0.0) probability = 0.0;
      if(probability > 100.0) probability = 100.0;
      
      return probability;
   }

   // Hàm quyết định xem có cho phép mở thêm lệnh DCA hay không
   bool EvaluateDCAExecution(int currentLayers, 
                             double recoveryProb, 
                             bool isTrendAligned, 
                             int maxLayersLimit,
                             string &reason) 
   {
      // 1. Kiểm tra giới hạn số lượng lớp lệnh tối đa
      if(currentLayers >= maxLayersLimit) {
         reason = StringFormat("DCA Denied: Chạm giới hạn số lớp tối đa (%d/%d)", currentLayers, maxLayersLimit);
         return false;
      }

      // 2. Kiểm tra Xác suất hồi phục
      if(recoveryProb < m_min_recovery_prob) {
         reason = StringFormat("DCA Denied: Xác suất hồi phục quá thấp (Prob = %.1f%% vs Min = %.1f%%)", recoveryProb, m_min_recovery_prob);
         return false;
      }

      // 3. Quy tắc ép xu hướng ngược chiều (Không nhồi DCA vô tội vạ vào xu hướng dốc đứng)
      if(!isTrendAligned && recoveryProb < 75.0) {
         // Nếu đi ngược xu hướng chính mà xác suất hồi phục ở mức trung bình/thấp, cấm mở lệnh
         reason = StringFormat("DCA Denied: Đi ngược xu hướng mạnh với xác suất hồi phục trung bình (Prob = %.1f%%)", recoveryProb);
         return false;
      }

      reason = StringFormat("DCA Approved: Xác suất hồi phục đảm bảo (Prob = %.1f%%)", recoveryProb);
      return true;
   }

   // Hàm tính toán Lot DCA thích ứng không có gia tốc Martingale cao (Martingale Decay)
   // Khối lượng lệnh sau tăng chậm dần khi lớp lệnh tăng cao để bảo vệ margin
   double CalculateAdaptiveLot(int layerIndex, double baseLot) {
      double multiplier = m_base_multiplier;
      
      // Quy tắc giảm dần Martingale theo lớp lệnh:
      if(layerIndex >= 15) {
         multiplier = 1.00; // Flat lot hoàn toàn từ lớp 15 trở đi
      }
      else if(layerIndex >= 10) {
         multiplier = 1.05; // Giảm mạnh hệ số nhân xuống 1.05
      }
      else if(layerIndex >= 5) {
         multiplier = 1.10; // Giảm nhẹ hệ số nhân xuống 1.10
      }

      // Đảm bảo không bao giờ vượt qua 1.25x
      if(multiplier > m_max_martingale) {
         multiplier = m_max_martingale;
      }

      // Tính toán khối lượng: Lot = baseLot * (multiplier ^ layerIndex)
      // Để tránh nhân dồn quá lớn, ta giới hạn khối lượng tăng trưởng:
      double calculatedLot = baseLot * MathPow(multiplier, layerIndex);
      return calculatedLot;
   }
};

#endif
