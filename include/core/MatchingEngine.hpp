#pragma once

#include "Order.hpp"
#include "Trade.hpp"
#include "OrderBook.hpp"
#include "StopOrderManager.hpp"
#include <unordered_map>
#include <memory>
#include <vector>
#include <mutex>
#include <atomic>
#include <functional>

namespace MatchingEngine {

/**
 * @brief Main matching engine
 * Handles order validation, routing, and lifecycle management
 */
class MatchingEngineCore {
public:
    MatchingEngineCore();
    
    // Core operations
    std::string submitOrder(OrderPtr order);
    bool cancelOrder(const OrderId& order_id);
    OrderPtr getOrder(const OrderId& order_id) const;
    
    // Market data
    std::shared_ptr<OrderBook> getOrderBook(const Symbol& symbol) const;
    std::pair<std::optional<Price>, std::optional<Price>> getBBO(const Symbol& symbol) const;
    
    // Callbacks
    void setTradeCallback(std::function<void(const Trade&)> callback) {
        trade_callback_ = callback;
    }
    
    void setBookUpdateCallback(std::function<void(const Symbol&)> callback) {
        book_update_callback_ = callback;
    }
    
    // Statistics
    uint64_t getTotalOrdersProcessed() const { return total_orders_processed_; }
    uint64_t getTotalTradesExecuted() const { return total_trades_executed_; }

private:
    // Order books per symbol
    std::unordered_map<Symbol, std::shared_ptr<OrderBook>> order_books_;
    mutable std::mutex order_books_mutex_;
    
    // Stop order manager
    StopOrderManager stop_order_manager_;
    
    // Order tracking
    std::unordered_map<OrderId, OrderPtr> all_orders_;
    mutable std::mutex orders_mutex_;
    
    // Callbacks
    std::function<void(const Trade&)> trade_callback_;
    std::function<void(const Symbol&)> book_update_callback_;
    
    // Statistics
    std::atomic<uint64_t> total_orders_processed_;
    std::atomic<uint64_t> total_trades_executed_;
    std::atomic<uint64_t> order_id_counter_;
    
    // Helper methods
    bool validateOrder(const OrderPtr& order, std::string& error) const;
    void processOrder(OrderPtr order);
    std::shared_ptr<OrderBook> getOrCreateOrderBook(const Symbol& symbol);
    std::string generateOrderId();
    
    void processMarketOrder(OrderPtr order, std::shared_ptr<OrderBook> book);
    void processLimitOrder(OrderPtr order, std::shared_ptr<OrderBook> book);
    void processIOCOrder(OrderPtr order, std::shared_ptr<OrderBook> book);
    void processFOKOrder(OrderPtr order, std::shared_ptr<OrderBook> book);
    void processStopOrder(OrderPtr order);
    void checkAndTriggerStopOrders(const Symbol& symbol, Price last_trade_price);
};

} // namespace MatchingEngine
