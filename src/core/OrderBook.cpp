#include "core/OrderBook.hpp"
#include "core/FeeConfig.hpp"
#include <algorithm>
#include <sstream>
#include <iomanip>

namespace MatchingEngine {

OrderBook::OrderBook(const Symbol& symbol)
    : symbol_(symbol), sequence_counter_(0), trade_id_counter_(0) {}

void OrderBook::addOrder(OrderPtr order) {
    std::lock_guard<std::mutex> lock(book_mutex_);
    
    order->sequence = sequence_counter_.fetch_add(1, std::memory_order_relaxed);
    
    if (order->side == OrderSide::BUY) {
        auto& level = bids_[order->price];
        level.price = order->price;
        level.addOrder(order);
    } else {
        auto& level = asks_[order->price];
        level.price = order->price;
        level.addOrder(order);
    }
    
    order_map_[order->order_id] = order;
    order->status = OrderStatus::ACTIVE;
    
    updateBBO();
}

bool OrderBook::cancelOrder(const OrderId& order_id) {
    std::lock_guard<std::mutex> lock(book_mutex_);
    
    auto it = order_map_.find(order_id);
    if (it == order_map_.end()) return false;
    
    OrderPtr order = it->second;
    
    if (order->side == OrderSide::BUY) {
        auto level_it = bids_.find(order->price);
        if (level_it == bids_.end()) return false;
        
        PriceLevel& level = level_it->second;
        if (!level.removeOrder(order_id)) return false;
        
        if (level.isEmpty()) {
            bids_.erase(level_it);
        }
    } else {
        auto level_it = asks_.find(order->price);
        if (level_it == asks_.end()) return false;
        
        PriceLevel& level = level_it->second;
        if (!level.removeOrder(order_id)) return false;
        
        if (level.isEmpty()) {
            asks_.erase(level_it);
        }
    }
    
    order_map_.erase(it);
    order->status = OrderStatus::CANCELLED;
    updateBBO();
    
    return true;
}

std::vector<Trade> OrderBook::matchOrder(OrderPtr order) {
    std::lock_guard<std::mutex> lock(book_mutex_);
    
    std::vector<Trade> trades;
    
    if (order->side == OrderSide::BUY) {
        matchAgainstBook(order, asks_, trades);
    } else {
        matchAgainstBook(order, bids_, trades);
    }
    
    return trades;
}

void OrderBook::matchAgainstBook(
    OrderPtr taker,
    std::map<Price, PriceLevel, std::less<Price>>& opposite_book,
    std::vector<Trade>& trades) {
    
    // Buy order matching against asks (ascending price)
    while (!taker->isFullyFilled() && !opposite_book.empty()) {
        auto& [price, level] = *opposite_book.begin();
        
        // Check if can match at this price (NO TRADE-THROUGH)
        if (!taker->canMatchAtPrice(price)) {
            break;
        }
        
        matchAtPriceLevel(taker, level, trades);
        
        if (level.isEmpty()) {
            opposite_book.erase(opposite_book.begin());
        }
    }
    
    updateBBO();
}

void OrderBook::matchAgainstBook(
    OrderPtr taker,
    std::map<Price, PriceLevel, std::greater<Price>>& opposite_book,
    std::vector<Trade>& trades) {
    
    // Sell order matching against bids (descending price)
    while (!taker->isFullyFilled() && !opposite_book.empty()) {
        auto& [price, level] = *opposite_book.begin();
        
        // Check if can match at this price (NO TRADE-THROUGH)
        if (!taker->canMatchAtPrice(price)) {
            break;
        }
        
        matchAtPriceLevel(taker, level, trades);
        
        if (level.isEmpty()) {
            opposite_book.erase(opposite_book.begin());
        }
    }
    
    updateBBO();
}

void OrderBook::matchAtPriceLevel(OrderPtr taker, PriceLevel& level, std::vector<Trade>& trades) {
    // Match against orders at this level in FIFO order
    while (!taker->isFullyFilled() && !level.isEmpty()) {
        OrderPtr maker = level.frontOrder();
        
        // Calculate fill quantity
        Quantity fill_qty = std::min(
            taker->remainingQuantity(),
            maker->remainingQuantity()
        );
        
        // Create trade at maker's price (maker was here first)
        Trade trade = createTrade(taker, maker, level.price, fill_qty);
        trades.push_back(trade);
        
        // Update filled quantities
        taker->fill(fill_qty, level.price);
        maker->fill(fill_qty, level.price);
        
        // Remove fully filled maker
        if (maker->isFullyFilled()) {
            level.removeFrontOrder();
        }
        
        level.updateQuantity();
    }
}

Trade OrderBook::createTrade(OrderPtr taker, OrderPtr maker, Price price, Quantity quantity) {
    std::string trade_id = generateTradeId();
    std::string aggressor = (taker->side == OrderSide::BUY) ? "buy" : "sell";
    
    // Create trade
    Trade trade(trade_id, symbol_, price, quantity,
                maker->order_id, taker->order_id, aggressor);
    
    // Calculate fees
    // Maker was already on the book (adds liquidity)
    // Taker is matching now (removes liquidity)
    trade.maker_fee = FeeConfig::calculateMakerFee(price, quantity);
    trade.taker_fee = FeeConfig::calculateTakerFee(price, quantity);
    trade.maker_fee_rate = FeeConfig::MAKER_FEE_RATE;
    trade.taker_fee_rate = FeeConfig::TAKER_FEE_RATE;
    
    return trade;
}

std::string OrderBook::generateTradeId() {
    std::ostringstream oss;
    oss << symbol_ << "_" << std::setfill('0') << std::setw(10) << (trade_id_counter_.fetch_add(1, std::memory_order_relaxed));
    return oss.str();
}

bool OrderBook::canFillFOK(const OrderPtr& order) const {
    Quantity remaining = order->quantity;
    
    if (order->side == OrderSide::BUY) {
        for (const auto& [price, level] : asks_) {
            if (!order->canMatchAtPrice(price)) break;
            remaining -= level.total_quantity;
            if (remaining <= Config::EPSILON) return true;
        }
    } else {
        for (const auto& [price, level] : bids_) {
            if (!order->canMatchAtPrice(price)) break;
            remaining -= level.total_quantity;
            if (remaining <= Config::EPSILON) return true;
        }
    }
    
    return false;
}

std::pair<std::optional<Price>, std::optional<Price>> OrderBook::getBBO() const {
    return {best_bid_, best_ask_};
}

void OrderBook::updateBBO() {
    best_bid_ = bids_.empty() ? std::nullopt : std::optional<Price>(bids_.begin()->first);
    best_ask_ = asks_.empty() ? std::nullopt : std::optional<Price>(asks_.begin()->first);
}

std::vector<std::pair<Price, Quantity>> OrderBook::getBids(int depth) const {
    std::vector<std::pair<Price, Quantity>> result;
    result.reserve(depth);
    
    int count = 0;
    for (const auto& [price, level] : bids_) {
        if (count >= depth) break;
        result.emplace_back(price, level.total_quantity);
        count++;
    }
    
    return result;
}

std::vector<std::pair<Price, Quantity>> OrderBook::getAsks(int depth) const {
    std::vector<std::pair<Price, Quantity>> result;
    result.reserve(depth);
    
    int count = 0;
    for (const auto& [price, level] : asks_) {
        if (count >= depth) break;
        result.emplace_back(price, level.total_quantity);
        count++;
    }
    
    return result;
}

OrderPtr OrderBook::getOrder(const OrderId& order_id) const {
    auto it = order_map_.find(order_id);
    return (it != order_map_.end()) ? it->second : nullptr;
}

double OrderBook::getSpread() const {
    if (best_bid_.has_value() && best_ask_.has_value()) {
        return best_ask_.value() - best_bid_.value();
    }
    return 0.0;
}


size_t OrderBook::totalOrders() const {
    std::lock_guard<std::mutex> lock(book_mutex_);
    return order_map_.size();
}

} // namespace MatchingEngine
