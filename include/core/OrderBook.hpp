#pragma once

// Order book for a trading symbol

#include "Order.hpp"
#include "Trade.hpp"
#include "PriceLevel.hpp"
#include <map>
#include <unordered_map>
#include <vector>
#include <optional>
#include <functional>
#include <mutex>
#include <atomic>

namespace MatchingEngine {

class OrderBook {
public:
    explicit OrderBook(const Symbol& symbol);
    
    void addOrder(OrderPtr order);
    bool cancelOrder(const OrderId& order_id);
    std::vector<Trade> matchOrder(OrderPtr order);
    bool canFillFOK(const OrderPtr& order) const;
    
    std::pair<std::optional<Price>, std::optional<Price>> getBBO() const;
    void updateBBO();
    
    std::vector<std::pair<Price, Quantity>> getBids(int depth = 10) const;
    std::vector<std::pair<Price, Quantity>> getAsks(int depth = 10) const;
    
    OrderPtr getOrder(const OrderId& order_id) const;
    const Symbol& getSymbol() const { return symbol_; }
    size_t totalOrders() const;
    double getSpread() const;

private:
    Symbol symbol_;
    
    mutable std::mutex book_mutex_;
    
    std::map<Price, PriceLevel, std::greater<Price>> bids_;
    std::map<Price, PriceLevel, std::less<Price>> asks_;
    
    std::unordered_map<OrderId, OrderPtr> order_map_;
    
    std::optional<Price> best_bid_;
    std::optional<Price> best_ask_;
    
    std::atomic<uint64_t> sequence_counter_;
    std::atomic<uint64_t> trade_id_counter_;
    
    // Helper methods
    void matchAgainstBook(OrderPtr order,
                         std::map<Price, PriceLevel, std::greater<Price>>& book,
                         std::vector<Trade>& trades);
    void matchAgainstBook(OrderPtr order,
                         std::map<Price, PriceLevel, std::less<Price>>& book,
                         std::vector<Trade>& trades);
    void matchAtPriceLevel(OrderPtr taker, PriceLevel& level, std::vector<Trade>& trades);
    Trade createTrade(OrderPtr taker, OrderPtr maker, Price price, Quantity quantity);
    std::string generateTradeId();
};

} 
