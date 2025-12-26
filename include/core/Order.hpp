#pragma once

#include "Types.hpp"
#include <memory>
#include <chrono>

namespace MatchingEngine {

/**
 * @brief Represents a trading order
 */
class Order {
public:
    // Identity
    OrderId order_id;
    OrderId client_order_id;
    Symbol symbol;
    
    // Order parameters
    OrderType type;
    OrderSide side;
    Price price;              // 0 for market orders
    Quantity quantity;
    Quantity filled_quantity;
    Price average_fill_price; // Average price at which order filled
    
    // Stop order parameters (for STOP_LOSS, STOP_LIMIT, TAKE_PROFIT)
    Price stop_price;         // Trigger price (0 if not a stop order)
    
    // State
    OrderStatus status;
    Timestamp timestamp;
    uint64_t sequence;        // For time priority
    
    // Constructors
    Order() = default;
    
    Order(const OrderId& id, const Symbol& sym, OrderType t, OrderSide s, Price p, Quantity q)
        : order_id(id), symbol(sym), type(t), side(s), price(p), quantity(q),
          filled_quantity(0.0), average_fill_price(0.0), stop_price(0.0), status(OrderStatus::PENDING),
          timestamp(getCurrentTimestamp()), sequence(0) {}
    
    // Methods
    Quantity remainingQuantity() const {
        return quantity - filled_quantity;
    }
    
    bool isFullyFilled() const {
        return (quantity - filled_quantity) < Config::EPSILON;
    }
    
    bool canMatchAtPrice(Price match_price) const {
        if (type == OrderType::MARKET) return true;
        
        if (side == OrderSide::BUY) {
            return price >= match_price - Config::EPSILON;
        } else {
            return price <= match_price + Config::EPSILON;
        }
    }
    
    void fill(Quantity qty, Price fill_price) {
        // Update average fill price (weighted average)
        double total_filled = filled_quantity + qty;
        if (total_filled > 0) {
            average_fill_price = ((filled_quantity * average_fill_price) + (qty * fill_price)) / total_filled;
        }
        
        filled_quantity += qty;
        if (isFullyFilled()) {
            status = OrderStatus::FILLED;
        } else {
            status = OrderStatus::PARTIAL_FILL;
        }
    }
    
    // Stop order helpers
    bool isStopOrder() const {
        return type == OrderType::STOP_LOSS || 
               type == OrderType::STOP_LIMIT || 
               type == OrderType::TAKE_PROFIT;
    }
    
    bool shouldTrigger(Price current_price) const {
        if (!isStopOrder() || stop_price <= 0) return false;
        
        if (side == OrderSide::BUY) {
            // Buy stops trigger when price goes UP
            // Stop-loss BUY: triggers when price >= stop_price
            // Take-profit BUY: triggers when price <= stop_price (closing short)
            if (type == OrderType::TAKE_PROFIT) {
                return current_price <= stop_price + Config::EPSILON;
            } else {
                return current_price >= stop_price - Config::EPSILON;
            }
        } else {
            // Sell stops trigger when price goes DOWN
            // Stop-loss SELL: triggers when price <= stop_price
            // Take-profit SELL: triggers when price >= stop_price (closing long)
            if (type == OrderType::TAKE_PROFIT) {
                return current_price >= stop_price - Config::EPSILON;
            } else {
                return current_price <= stop_price + Config::EPSILON;
            }
        }
    }
    
    std::string toString() const;

private:
    static Timestamp getCurrentTimestamp() {
        auto now = std::chrono::system_clock::now();
        return std::chrono::duration_cast<std::chrono::nanoseconds>(
            now.time_since_epoch()).count();
    }
};

using OrderPtr = std::shared_ptr<Order>;

} // namespace MatchingEngine
