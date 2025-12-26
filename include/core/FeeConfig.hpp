#pragma once

namespace MatchingEngine {

/**
 * @brief Fee configuration for maker-taker model
 */
struct FeeConfig {
    // Maker fee: charged when order ADDS liquidity (rests on book)
    static constexpr double MAKER_FEE_RATE = 0.001;  // 0.1%
    
    // Taker fee: charged when order REMOVES liquidity (matches immediately)
    static constexpr double TAKER_FEE_RATE = 0.002;  // 0.2%
    
    /**
     * Calculate maker fee for a trade
     */
    static double calculateMakerFee(double price, double quantity) {
        return price * quantity * MAKER_FEE_RATE;
    }
    
    /**
     * Calculate taker fee for a trade
     */
    static double calculateTakerFee(double price, double quantity) {
        return price * quantity * TAKER_FEE_RATE;
    }
};

} // namespace MatchingEngine
