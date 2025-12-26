#include "../include/core/MatchingEngine.hpp"
#include <iostream>
#include <cassert>

using namespace MatchingEngine;

void test_simple_match() {
    std::cout << "Test: Simple Match... ";
    
    MatchingEngineCore engine;
    int trade_count = 0;
    
    engine.setTradeCallback([&](const Trade& trade) {
        trade_count++;
    });
    
    // Submit sell order
    auto sell = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                         OrderSide::SELL, 50000.0, 1.0);
    engine.submitOrder(sell);
    
    // Submit matching buy order
    auto buy = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                        OrderSide::BUY, 50000.0, 1.0);
    engine.submitOrder(buy);
    
    assert(trade_count == 1);
    assert(buy->status == OrderStatus::FILLED);
    assert(sell->status == OrderStatus::FILLED);
    
    std::cout << "PASS\n";
}

void test_partial_fill() {
    std::cout << "Test: Partial Fill... ";
    
    MatchingEngineCore engine;
    
    // Sell 2.0
    auto sell = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                         OrderSide::SELL, 50000.0, 2.0);
    engine.submitOrder(sell);
    
    // Buy 1.0
    auto buy = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                        OrderSide::BUY, 50000.0, 1.0);
    engine.submitOrder(buy);
    
    assert(buy->status == OrderStatus::FILLED);
    assert(sell->status == OrderStatus::PARTIAL_FILL);
    assert(sell->remainingQuantity() == 1.0);
    
    std::cout << "PASS\n";
}

void test_market_order() {
    std::cout << "Test: Market Order... ";
    
    MatchingEngineCore engine;
    
    // Add sell order
    auto sell = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                         OrderSide::SELL, 50000.0, 1.0);
    engine.submitOrder(sell);
    
    // Market buy
    auto buy = std::make_shared<Order>("", "BTC-USDT", OrderType::MARKET, 
                                        OrderSide::BUY, 0.0, 1.0);
    engine.submitOrder(buy);
    
    assert(buy->status == OrderStatus::FILLED);
    assert(sell->status == OrderStatus::FILLED);
    
    std::cout << "PASS\n";
}

void test_ioc_order() {
    std::cout << "Test: IOC Order... ";
    
    MatchingEngineCore engine;
    
    // Add sell for 0.5
    auto sell = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                         OrderSide::SELL, 50000.0, 0.5);
    engine.submitOrder(sell);
    
    // IOC buy for 1.0 - should fill 0.5, cancel 0.5
    auto buy = std::make_shared<Order>("", "BTC-USDT", OrderType::IOC, 
                                        OrderSide::BUY, 50000.0, 1.0);
    engine.submitOrder(buy);
    
    assert(buy->status == OrderStatus::PARTIAL_FILL);
    assert(buy->filled_quantity == 0.5);
    
    std::cout << "PASS\n";
}

void test_fok_success() {
    std::cout << "Test: FOK Success... ";
    
    MatchingEngineCore engine;
    
    // Add enough liquidity
    auto sell1 = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                          OrderSide::SELL, 50000.0, 0.8);
    auto sell2 = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                          OrderSide::SELL, 50100.0, 0.5);
    engine.submitOrder(sell1);
    engine.submitOrder(sell2);
    
    // FOK for 1.0 - can be filled
    auto buy = std::make_shared<Order>("", "BTC-USDT", OrderType::FOK, 
                                        OrderSide::BUY, 50100.0, 1.0);
    engine.submitOrder(buy);
    
    assert(buy->status == OrderStatus::FILLED);
    
    std::cout << "PASS\n";
}

void test_fok_failure() {
    std::cout << "Test: FOK Failure... ";
    
    MatchingEngineCore engine;
    
    // Add insufficient liquidity
    auto sell = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                         OrderSide::SELL, 50000.0, 0.5);
    engine.submitOrder(sell);
    
    // FOK for 1.0 - cannot be filled
    auto buy = std::make_shared<Order>("", "BTC-USDT", OrderType::FOK, 
                                        OrderSide::BUY, 50000.0, 1.0);
    engine.submitOrder(buy);
    
    assert(buy->status == OrderStatus::CANCELLED);
    assert(buy->filled_quantity == 0.0);
    
    std::cout << "PASS\n";
}

void test_price_time_priority() {
    std::cout << "Test: Price-Time Priority... ";
    
    MatchingEngineCore engine;
    std::string first_matched;
    
    engine.setTradeCallback([&](const Trade& trade) {
        if (first_matched.empty()) {
            first_matched = trade.maker_order_id;
        }
    });
    
    // Add two sell orders at same price
    auto sell1 = std::make_shared<Order>("FIRST", "BTC-USDT", OrderType::LIMIT, 
                                          OrderSide::SELL, 50000.0, 1.0);
    auto sell2 = std::make_shared<Order>("SECOND", "BTC-USDT", OrderType::LIMIT, 
                                          OrderSide::SELL, 50000.0, 1.0);
    sell1->order_id = "FIRST";
    sell2->order_id = "SECOND";
    
    engine.submitOrder(sell1);
    engine.submitOrder(sell2);
    
    // Buy should match with first order
    auto buy = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                        OrderSide::BUY, 50000.0, 1.0);
    engine.submitOrder(buy);
    
    assert(first_matched == "FIRST");
    
    std::cout << "PASS\n";
}

void test_no_trade_through() {
    std::cout << "Test: No Trade-Through... ";
    
    MatchingEngineCore engine;
    std::vector<double> trade_prices;
    
    engine.setTradeCallback([&](const Trade& trade) {
        trade_prices.push_back(trade.price);
    });
    
    // Add sells at different prices
    auto sell1 = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                          OrderSide::SELL, 50000.0, 1.0);
    auto sell2 = std::make_shared<Order>("", "BTC-USDT", OrderType::LIMIT, 
                                          OrderSide::SELL, 50100.0, 1.0);
    engine.submitOrder(sell1);
    engine.submitOrder(sell2);
    
    // Buy 2.0 - should match 50000 first, then 50100
    auto buy = std::make_shared<Order>("", "BTC-USDT", OrderType::MARKET, 
                                        OrderSide::BUY, 0.0, 2.0);
    engine.submitOrder(buy);
    
    assert(trade_prices.size() == 2);
    assert(trade_prices[0] == 50000.0);  // Best price first!
    assert(trade_prices[1] == 50100.0);
    
    std::cout << "PASS\n";
}

int main() {
    std::cout << "=================================\n";
    std::cout << "Running Matching Engine Tests\n";
    std::cout << "=================================\n\n";
    
    test_simple_match();
    test_partial_fill();
    test_market_order();
    test_ioc_order();
    test_fok_success();
    test_fok_failure();
    test_price_time_priority();
    test_no_trade_through();
    
    std::cout << "\n=================================\n";
    std::cout << "All Tests Passed!\n";
    std::cout << "=================================\n";
    
    return 0;
}