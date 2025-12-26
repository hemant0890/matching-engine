#pragma once

#include "Order.hpp"
#include <deque>
#include <algorithm>

namespace MatchingEngine {

/**
 * @brief Represents all orders at a specific price level
 * Uses deque for FIFO time priority
 */
class PriceLevel {
public:
    Price price;
    std::deque<OrderPtr> orders;  // FIFO queue
    Quantity total_quantity;
    
    explicit PriceLevel(Price p = 0.0) : price(p), total_quantity(0.0) {}
    
    void addOrder(OrderPtr order) {
        orders.push_back(order);
        total_quantity += order->remainingQuantity();
    }
    
    bool removeOrder(const OrderId& order_id) {
        auto it = std::find_if(orders.begin(), orders.end(),
            [&](const OrderPtr& o) { return o->order_id == order_id; });
        
        if (it != orders.end()) {
            total_quantity -= (*it)->remainingQuantity();
            orders.erase(it);
            return true;
        }
        return false;
    }
    
    void updateQuantity() {
        total_quantity = 0.0;
        for (const auto& order : orders) {
            total_quantity += order->remainingQuantity();
        }
    }
    
    bool isEmpty() const {
        return orders.empty();
    }
    
    OrderPtr frontOrder() {
        return orders.empty() ? nullptr : orders.front();
    }
    
    void removeFrontOrder() {
        if (!orders.empty()) {
            total_quantity -= orders.front()->remainingQuantity();
            orders.pop_front();
        }
    }
};

} // namespace MatchingEngine
