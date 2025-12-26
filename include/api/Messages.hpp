#pragma once

#include <string>
#include <vector>

namespace MatchingEngine {
namespace API {

// Request to submit a new order
struct OrderRequest {
    std::string symbol;
    std::string order_type;  // "market", "limit", "ioc", "fok", "stop_loss", "stop_limit", "take_profit"
    std::string side;        // "buy", "sell"
    double quantity;
    double price;            // 0 for market orders, limit price for stop_limit
    double stop_price;       // Trigger price for stop orders
    std::string client_order_id;  // Optional
    
    std::string toJson() const;
    static OrderRequest fromJson(const std::string& json);
};

// Response for order submission
struct OrderResponse {
    bool success;
    std::string order_id;
    std::string message;
    std::string status;
    
    // Trade information (if order was filled)
    bool has_trade;
    double trade_price;
    double trade_quantity;
    double maker_fee;
    double taker_fee;
    double maker_fee_rate;
    double taker_fee_rate;
    
    OrderResponse() : success(false), has_trade(false), 
                     trade_price(0), trade_quantity(0),
                     maker_fee(0), taker_fee(0),
                     maker_fee_rate(0), taker_fee_rate(0) {}
    
    std::string toJson() const;
};

// Order book snapshot (L2 data)
struct OrderBookSnapshot {
    std::string timestamp;
    std::string symbol;
    std::vector<std::pair<std::string, std::string>> bids;  // [price, quantity]
    std::vector<std::pair<std::string, std::string>> asks;  // [price, quantity]
    
    std::string toJson() const;
};

// Error response
struct ErrorResponse {
    std::string error;
    std::string message;
    
    std::string toJson() const;
};

} // namespace API
} // namespace MatchingEngine
