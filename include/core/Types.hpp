// Minimal: Core types and enums for matching engine
#pragma once

#include <string>
#include <cstdint>
#include <optional>

namespace MatchingEngine {

enum class OrderType {
    MARKET,
    LIMIT,
    IOC,
    FOK,
    STOP_LOSS,
    STOP_LIMIT,
    TAKE_PROFIT
};

enum class OrderSide {
    BUY,
    SELL
};

enum class OrderStatus {
    PENDING,
    ACTIVE,
    PARTIAL_FILL,
    FILLED,
    CANCELLED,
    REJECTED
};

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

using OrderId = std::string;
using Symbol = std::string;
using Price = double;
using Quantity = double;
using Timestamp = uint64_t;

namespace Config {
    constexpr int MAX_PRICE_DECIMALS = 2;
    constexpr int MAX_QUANTITY_DECIMALS = 8;
    constexpr double MIN_ORDER_SIZE = 0.00000001;
    constexpr double EPSILON = 1e-9;
}

} // namespace MatchingEngine
