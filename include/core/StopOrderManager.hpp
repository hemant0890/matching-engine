#pragma once

#include "Order.hpp"
#include "Types.hpp"
#include <vector>
#include <memory>
#include <map>
#include <mutex>

// Minimal: Stop order management

namespace MatchingEngine {

class StopOrderManager {
public:
    StopOrderManager() = default;
    
    void addStopOrder(OrderPtr order);
    std::vector<OrderPtr> checkTriggers(const Symbol& symbol, Price last_trade_price);
    bool cancelStopOrder(const OrderId& order_id);
    std::vector<OrderPtr> getStopOrders(const Symbol& symbol) const;
    size_t getStopOrderCount() const;

private:
    std::map<Symbol, std::vector<OrderPtr>> stop_orders_; // Stop orders by symbol
    mutable std::mutex mutex_; // Thread safety
};

} // namespace MatchingEngine
