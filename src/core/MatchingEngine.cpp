#include "core/MatchingEngine.hpp"
#include <iostream>
#include <sstream>
#include <iomanip>
#include <cmath>

namespace MatchingEngine {

MatchingEngineCore::MatchingEngineCore()
    : total_orders_processed_(0), total_trades_executed_(0), order_id_counter_(0) {}

std::string MatchingEngineCore::submitOrder(OrderPtr order) {
    // Generate order ID if needed
    if (order->order_id.empty()) {
        order->order_id = generateOrderId();
    }
    
    // Validate
    std::string error;
    if (!validateOrder(order, error)) {
        order->status = OrderStatus::REJECTED;
        return "";
    }
    
    // Store
    {
        std::lock_guard<std::mutex> lock(orders_mutex_);
        all_orders_[order->order_id] = order;
    }
    
    // Process
    processOrder(order);
    total_orders_processed_.fetch_add(1, std::memory_order_relaxed);
    
    return order->order_id;
}

bool MatchingEngineCore::cancelOrder(const OrderId& order_id) {
    OrderPtr order;
    {
        std::lock_guard<std::mutex> lock(orders_mutex_);
        auto it = all_orders_.find(order_id);
        if (it == all_orders_.end()) return false;
        order = it->second;
    }
    
    // If it's a pending stop order, cancel from stop order manager
    if (order->status == OrderStatus::PENDING && order->isStopOrder()) {
        return stop_order_manager_.cancelStopOrder(order_id);
    }
    
    if (order->status != OrderStatus::ACTIVE && 
        order->status != OrderStatus::PARTIAL_FILL) {
        return false;
    }
    
    auto book = getOrderBook(order->symbol);
    if (!book) return false;
    
    return book->cancelOrder(order_id);
}

OrderPtr MatchingEngineCore::getOrder(const OrderId& order_id) const {
    std::lock_guard<std::mutex> lock(orders_mutex_);
    auto it = all_orders_.find(order_id);
    return (it != all_orders_.end()) ? it->second : nullptr;
}

std::shared_ptr<OrderBook> MatchingEngineCore::getOrderBook(const Symbol& symbol) const {
    std::lock_guard<std::mutex> lock(order_books_mutex_);
    auto it = order_books_.find(symbol);
    return (it != order_books_.end()) ? it->second : nullptr;
}

std::pair<std::optional<Price>, std::optional<Price>> 
MatchingEngineCore::getBBO(const Symbol& symbol) const {
    auto book = getOrderBook(symbol);
    return book ? book->getBBO() : std::make_pair(std::nullopt, std::nullopt);
}

bool MatchingEngineCore::validateOrder(const OrderPtr& order, std::string& error) const {
    if (order->symbol.empty()) {
        error = "Symbol required";
        return false;
    }
    
    if (order->quantity <= 0.0) {
        error = "Quantity must be positive";
        return false;
    }
    
    if (order->quantity < Config::MIN_ORDER_SIZE) {
        error = "Quantity below minimum";
        return false;
    }
    
    if ((order->type == OrderType::LIMIT) && order->price <= 0.0) {
        error = "Limit orders require positive price";
        return false;
    }
    
    if ((order->type == OrderType::MARKET) && order->price != 0.0) {
        error = "Market orders should not specify price";
        return false;
    }
    
    return true;
}

void MatchingEngineCore::processOrder(OrderPtr order) {
    // Check if this is a stop order
    if (order->isStopOrder()) {
        processStopOrder(order);
        return;
    }
    
    auto book = getOrCreateOrderBook(order->symbol);
    
    switch (order->type) {
        case OrderType::MARKET:
            processMarketOrder(order, book);
            break;
        case OrderType::LIMIT:
            processLimitOrder(order, book);
            break;
        case OrderType::IOC:
            processIOCOrder(order, book);
            break;
        case OrderType::FOK:
            processFOKOrder(order, book);
            break;
        default:
            std::cerr << "Unknown order type" << std::endl;
            order->status = OrderStatus::REJECTED;
            break;
    }
}

std::shared_ptr<OrderBook> MatchingEngineCore::getOrCreateOrderBook(const Symbol& symbol) {
    std::lock_guard<std::mutex> lock(order_books_mutex_);
    
    auto it = order_books_.find(symbol);
    if (it == order_books_.end()) {
        auto book = std::make_shared<OrderBook>(symbol);
        order_books_[symbol] = book;
        return book;
    }
    
    return it->second;
}

std::string MatchingEngineCore::generateOrderId() {
    uint64_t id = order_id_counter_.fetch_add(1, std::memory_order_relaxed);
    std::ostringstream oss;
    oss << "ORD" << std::setfill('0') << std::setw(12) << id;
    return oss.str();
}

void MatchingEngineCore::processMarketOrder(OrderPtr order, std::shared_ptr<OrderBook> book) {
    // Market orders match against all available liquidity at any price
    auto trades = book->matchOrder(order);
    
    // Publish trades
    if (trade_callback_) {
        for (const auto& trade : trades) {
            trade_callback_(trade);
            total_trades_executed_.fetch_add(1, std::memory_order_relaxed);
            
            // Check if any stop orders should be triggered by this trade
            checkAndTriggerStopOrders(order->symbol, trade.price);
        }
    }
    
    // Set final status (market orders NEVER rest on book)
    if (order->isFullyFilled()) {
        order->status = OrderStatus::FILLED;
    } else if (order->filled_quantity > 0.0) {
        order->status = OrderStatus::PARTIAL_FILL;  // Got partial fill, rest cancelled
    } else {
        order->status = OrderStatus::CANCELLED;  // No liquidity available (rare)
    }
}

void MatchingEngineCore::processLimitOrder(OrderPtr order, std::shared_ptr<OrderBook> book) {
    // Add order to book first to show it in market data
    book->addOrder(order);
    order->status = OrderStatus::ACTIVE;
    
    // Publish market data to show the order on the book  
    if (book_update_callback_) {
        book_update_callback_(order->symbol);
    }
    
    // Now match the order against the OPPOSITE side
    // (matchOrder only looks at opposite side, so our order won't match itself)
    auto trades = book->matchOrder(order);
    
    // Publish trades
    if (trade_callback_) {
        for (const auto& trade : trades) {
            trade_callback_(trade);
            total_trades_executed_.fetch_add(1, std::memory_order_relaxed);
            
            // Check stop orders
            checkAndTriggerStopOrders(order->symbol, trade.price);
        }
    }
    
    // If order was fully filled, remove it from the book
    if (order->isFullyFilled()) {
        book->cancelOrder(order->order_id);
        order->status = OrderStatus::FILLED;
        // No need to publish - trade already published
        // Book state hasn't changed (order matched with opposite side)
    } else if (order->filled_quantity > 0.0) {
        order->status = OrderStatus::PARTIAL_FILL;
        // Order still on book with reduced quantity - publish update
        if (book_update_callback_) {
            book_update_callback_(order->symbol);
        }
    }
    // If no fill, status remains ACTIVE (already on book, no need to publish again)
}

void MatchingEngineCore::processIOCOrder(OrderPtr order, std::shared_ptr<OrderBook> book) {
    // IOC (Immediate-Or-Cancel): Match immediately, never rest on book
    // DO NOT add order to book - match directly against opposite side
    
    auto trades = book->matchOrder(order);
    
    // Publish trades
    if (trade_callback_) {
        for (const auto& trade : trades) {
            trade_callback_(trade);
            total_trades_executed_.fetch_add(1, std::memory_order_relaxed);
            
            // Check stop orders
            checkAndTriggerStopOrders(order->symbol, trade.price);
        }
    }
    
    // Set status - remainder is ALWAYS cancelled
    if (order->isFullyFilled()) {
        order->status = OrderStatus::FILLED;
    } else {
        // Any remainder is cancelled (this is the IOC behavior)
        if (order->filled_quantity > 0.0) {
            order->status = OrderStatus::PARTIAL_FILL;  // Then cancelled
        } else {
            order->status = OrderStatus::CANCELLED;  // Nothing filled
        }
    }
    
    // CRITICAL: IOC NEVER rests on book
    // Order was never added, so nothing to remove
}

void MatchingEngineCore::processFOKOrder(OrderPtr order, std::shared_ptr<OrderBook> book) {
    // FOK (Fill-Or-Kill): All-or-nothing execution
    // Must fill ENTIRE order immediately or reject completely
    
    // Step 1: Check if can fill completely at limit price or better
    if (!book->canFillFOK(order)) {
        order->status = OrderStatus::CANCELLED;
        // NO trades executed - order is killed entirely
        return;
    }
    
    // Step 2: Fill completely (we verified it's possible)
    auto trades = book->matchOrder(order);
    
    // Step 3: Publish trades
    if (trade_callback_) {
        for (const auto& trade : trades) {
            trade_callback_(trade);
            total_trades_executed_.fetch_add(1, std::memory_order_relaxed);
            
            // Check stop orders
            checkAndTriggerStopOrders(order->symbol, trade.price);
        }
    }
    
    // Step 4: Verify fully filled (should always be true if canFillFOK worked)
    if (order->isFullyFilled()) {
        order->status = OrderStatus::FILLED;
    } else {
        // This should NEVER happen if canFillFOK() is correct
        // But handle defensively - cancel the order
        order->status = OrderStatus::CANCELLED;
        // In production, this would be logged as an error
    }
    
    // FOK NEVER rests on book - it's either filled or killed
}

// ============================================================================
// STOP ORDER PROCESSING (BONUS FEATURE)
// ============================================================================

void MatchingEngineCore::processStopOrder(OrderPtr order) {
    // Validate stop order has stop_price
    if (order->stop_price <= 0.0) {
        std::cerr << "Stop order requires positive stop_price" << std::endl;
        order->status = OrderStatus::REJECTED;
        return;
    }
    
    // For STOP_LIMIT, also validate limit price
    if (order->type == OrderType::STOP_LIMIT && order->price <= 0.0) {
        std::cerr << "Stop-limit order requires positive limit price" << std::endl;
        order->status = OrderStatus::REJECTED;
        return;
    }
    
    // Add to stop order manager
    stop_order_manager_.addStopOrder(order);
    order->status = OrderStatus::PENDING;  // Waiting for trigger
    
    std::cout << "[MatchingEngine] Stop order " << order->order_id 
              << " added with stop price " << order->stop_price << std::endl;
}

void MatchingEngineCore::checkAndTriggerStopOrders(const Symbol& symbol, Price last_trade_price) {
    // Check if any stop orders should be triggered
    auto triggered_orders = stop_order_manager_.checkTriggers(symbol, last_trade_price);
    
    // Process each triggered order
    for (auto& order : triggered_orders) {
        std::cout << "[MatchingEngine] Processing triggered stop order " << order->order_id << std::endl;
        
        // Stop order has been converted to MARKET or LIMIT
        // Process it normally
        processOrder(order);
    }
}

} // namespace MatchingEngine
