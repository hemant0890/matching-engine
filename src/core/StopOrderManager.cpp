#include "core/StopOrderManager.hpp"
#include <algorithm>
#include <iostream>

namespace MatchingEngine {

void StopOrderManager::addStopOrder(OrderPtr order) {
    if (!order || !order->isStopOrder()) {
        std::cerr << "Error: Attempted to add non-stop order to StopOrderManager" << std::endl;
        return;
    }
    
    std::lock_guard<std::mutex> lock(mutex_);
    
    order->status = OrderStatus::PENDING;  // Pending trigger
    stop_orders_[order->symbol].push_back(order);
    
    std::cout << "[StopOrderManager] Added " << orderTypeToString(order->type) 
              << " order " << order->order_id 
              << " with stop price " << order->stop_price << std::endl;
}

std::vector<OrderPtr> StopOrderManager::checkTriggers(const Symbol& symbol, Price last_trade_price) {
    std::lock_guard<std::mutex> lock(mutex_);
    
    std::vector<OrderPtr> triggered;
    
    auto it = stop_orders_.find(symbol);
    if (it == stop_orders_.end() || it->second.empty()) {
        return triggered;
    }
    
    auto& orders = it->second;
    
    // Check each stop order
    for (auto order_it = orders.begin(); order_it != orders.end(); ) {
        auto& order = *order_it;
        
        if (order->shouldTrigger(last_trade_price)) {
            std::cout << "[StopOrderManager] TRIGGERED: " << orderTypeToString(order->type)
                      << " order " << order->order_id
                      << " at stop price " << order->stop_price
                      << " (market price: " << last_trade_price << ")" << std::endl;
            
            // Convert stop order to executable order
            if (order->type == OrderType::STOP_LOSS) {
                // Stop-loss becomes a MARKET order
                order->type = OrderType::MARKET;
                order->price = 0.0;
            } else if (order->type == OrderType::STOP_LIMIT) {
                // Stop-limit becomes a LIMIT order at its limit price
                order->type = OrderType::LIMIT;
                // order->price already set to limit price
            } else if (order->type == OrderType::TAKE_PROFIT) {
                // Take-profit becomes a MARKET order
                order->type = OrderType::MARKET;
                order->price = 0.0;
            }
            
            triggered.push_back(order);
            order_it = orders.erase(order_it);
        } else {
            ++order_it;
        }
    }
    
    return triggered;
}

bool StopOrderManager::cancelStopOrder(const OrderId& order_id) {
    std::lock_guard<std::mutex> lock(mutex_);
    
    // Search all symbols
    for (auto& [symbol, orders] : stop_orders_) {
        auto it = std::find_if(orders.begin(), orders.end(),
            [&order_id](const OrderPtr& order) {
                return order->order_id == order_id;
            });
        
        if (it != orders.end()) {
            (*it)->status = OrderStatus::CANCELLED;
            orders.erase(it);
            
            std::cout << "[StopOrderManager] Cancelled stop order " << order_id << std::endl;
            return true;
        }
    }
    
    return false;
}

std::vector<OrderPtr> StopOrderManager::getStopOrders(const Symbol& symbol) const {
    std::lock_guard<std::mutex> lock(mutex_);
    
    auto it = stop_orders_.find(symbol);
    if (it != stop_orders_.end()) {
        return it->second;
    }
    
    return {};
}

size_t StopOrderManager::getStopOrderCount() const {
    std::lock_guard<std::mutex> lock(mutex_);
    
    size_t count = 0;
    for (const auto& [symbol, orders] : stop_orders_) {
        count += orders.size();
    }
    
    return count;
}

} // namespace MatchingEngine
