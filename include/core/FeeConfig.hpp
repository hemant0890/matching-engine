#pragma once

// Fee configuration for maker-taker model
namespace MatchingEngine {

struct FeeConfig {
    static constexpr double MAKER_FEE_RATE = 0.001;  // 0.1%
    static constexpr double TAKER_FEE_RATE = 0.002;  // 0.2%
    
    static double calculateMakerFee(double price, double quantity) {
        return price * quantity * MAKER_FEE_RATE;
    }
    
    static double calculateTakerFee(double price, double quantity) {
        return price * quantity * TAKER_FEE_RATE;
    }
};

} 
