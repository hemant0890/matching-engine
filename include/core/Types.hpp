#pragma once

#include <string>
#include <cstdint>
#include <optional>

namespace MatchingEngine {

// Core order types (as per assignment requirements)
enum class OrderType {
    MARKET,      // Execute immediately at best available price
    LIMIT,       // Execute at specified price or better
    IOC,         // Immediate-Or-Cancel
    FOK,         // Fill-Or-Kill
    
    // Advanced order types (BONUS)
    STOP_LOSS,   // Triggers market order when price hits stop price
    STOP_LIMIT,  // Triggers limit order when price hits stop price
    TAKE_PROFIT  // Like stop-loss but for taking profits
};

// Order side
enum class OrderSide {
    BUY,
    SELL
};

// Order status
enum class OrderStatus {
    PENDING,       // Just received, awaiting processing
    ACTIVE,        // Resting on the order book
    PARTIAL_FILL,  // Partially executed
    FILLED,        // Completely executed
    CANCELLED,     // User cancelled or IOC/FOK cancelled
    REJECTED       // Failed validation
};

// Utility functions
inline std::string orderTypeToString(OrderType type) {
    switch (type) {
        case OrderType::MARKET: return "MARKET";
        case OrderType::LIMIT: return "LIMIT";
        case OrderType::IOC: return "IOC";
        case OrderType::FOK: return "FOK";
        case OrderType::STOP_LOSS: return "STOP_LOSS";
        case OrderType::STOP_LIMIT: return "STOP_LIMIT";
        case OrderType::TAKE_PROFIT: return "TAKE_PROFIT";
        default: return "UNKNOWN";
    }
}

inline std::string orderSideToString(OrderSide side) {
    return (side == OrderSide::BUY) ? "BUY" : "SELL";
}

inline std::string orderStatusToString(OrderStatus status) {
    switch (status) {
        case OrderStatus::PENDING: return "PENDING";
        case OrderStatus::ACTIVE: return "ACTIVE";
        case OrderStatus::PARTIAL_FILL: return "PARTIAL_FILL";
        case OrderStatus::FILLED: return "FILLED";
        case OrderStatus::CANCELLED: return "CANCELLED";
        case OrderStatus::REJECTED: return "REJECTED";
        default: return "UNKNOWN";
    }
}

inline OrderType stringToOrderType(const std::string& str) {
    if (str == "market") return OrderType::MARKET;
    if (str == "limit") return OrderType::LIMIT;
    if (str == "ioc") return OrderType::IOC;
    if (str == "fok") return OrderType::FOK;
    if (str == "stop_loss" || str == "stop-loss") return OrderType::STOP_LOSS;
    if (str == "stop_limit" || str == "stop-limit") return OrderType::STOP_LIMIT;
    if (str == "take_profit" || str == "take-profit") return OrderType::TAKE_PROFIT;
    return OrderType::LIMIT; // Default
}

inline OrderSide stringToOrderSide(const std::string& str) {
    return (str == "buy") ? OrderSide::BUY : OrderSide::SELL;
}

// Type aliases
using OrderId = std::string;
using Symbol = std::string;
using Price = double;
using Quantity = double;
using Timestamp = uint64_t;

// Configuration constants
namespace Config {
    constexpr int MAX_PRICE_DECIMALS = 2;
    constexpr int MAX_QUANTITY_DECIMALS = 8;
    constexpr double MIN_ORDER_SIZE = 0.00000001;
    constexpr double EPSILON = 1e-9;
}

} // namespace MatchingEngine
