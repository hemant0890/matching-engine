#pragma once

#include "Order.hpp"
#include "Types.hpp"
#include <vector>
#include <memory>
#include <map>
#include <mutex>

namespace MatchingEngine {

/**
 * @brief Manages stop orders (STOP_LOSS, STOP_LIMIT, TAKE_PROFIT)
 * 
 * Stop orders are NOT placed on the main order book. Instead, they wait here
 * and get triggered when the market price crosses their stop price.
 */
class StopOrderManager {
public:
    StopOrderManager() = default;
    
    /**
     * @brief Add a stop order to be monitored
     */
    void addStopOrder(OrderPtr order);
    
    /**
     * @brief Check for triggered stop orders based on current market price
     * @param symbol Trading symbol
     * @param last_trade_price Most recent trade price
     * @return Vector of orders that should be triggered
     */
    std::vector<OrderPtr> checkTriggers(const Symbol& symbol, Price last_trade_price);
    
    /**
     * @brief Cancel a stop order
     * @return true if order was found and removed
     */
    bool cancelStopOrder(const OrderId& order_id);
    
    /**
     * @brief Get all pending stop orders for a symbol
     */
    std::vector<OrderPtr> getStopOrders(const Symbol& symbol) const;
    
    /**
     * @brief Get count of pending stop orders
     */
    size_t getStopOrderCount() const;

private:
    // Stop orders organized by symbol
    std::map<Symbol, std::vector<OrderPtr>> stop_orders_;
    
    // Thread safety
    mutable std::mutex mutex_;
};

} // namespace MatchingEngine
