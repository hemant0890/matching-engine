#pragma once

#include "Types.hpp"
#include <string>
#include <chrono>

namespace MatchingEngine {

/**
 * @brief Represents an executed trade
 */
class Trade {
public:
    std::string trade_id;
    Symbol symbol;
    Price price;
    Quantity quantity;
    OrderId maker_order_id;
    OrderId taker_order_id;
    std::string aggressor_side;  // "buy" or "sell"
    Timestamp timestamp;
    
    // Fee information
    double maker_fee;           // Fee charged to maker
    double taker_fee;           // Fee charged to taker
    double maker_fee_rate;      // Maker fee rate (e.g., 0.001 = 0.1%)
    double taker_fee_rate;      // Taker fee rate (e.g., 0.002 = 0.2%)
    
    Trade() : timestamp(getCurrentTimestamp()), 
              maker_fee(0.0), taker_fee(0.0), 
              maker_fee_rate(0.0), taker_fee_rate(0.0) {}
    
    Trade(const std::string& tid, const Symbol& sym, Price p, Quantity q,
          const OrderId& maker, const OrderId& taker, const std::string& aggressor)
        : trade_id(tid), symbol(sym), price(p), quantity(q),
          maker_order_id(maker), taker_order_id(taker),
          aggressor_side(aggressor), timestamp(getCurrentTimestamp()),
          maker_fee(0.0), taker_fee(0.0), 
          maker_fee_rate(0.0), taker_fee_rate(0.0) {}
    
    std::string toJson() const;

private:
    static Timestamp getCurrentTimestamp() {
        auto now = std::chrono::system_clock::now();
        return std::chrono::duration_cast<std::chrono::nanoseconds>(
            now.time_since_epoch()).count();
    }
};

} // namespace MatchingEngine
