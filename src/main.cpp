#include "core/MatchingEngine.hpp"
#include "api/RestAPIServer.hpp"
#include "api/WebSocketServer.hpp"
#include "publishers/MarketDataPublisher.hpp"
#include "publishers/TradePublisher.hpp"
#include <iostream>
#include <signal.h>
#include <atomic>

using namespace MatchingEngine;

std::atomic<bool> keep_running(true);

void signal_handler(int signal) {
    std::cout << "\nShutting down..." << std::endl;
    keep_running = false;
}

int main(int argc, char* argv[]) {
    // Setup signal handler
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    std::cout << "========================================" << std::endl;
    std::cout << "  Matching Engine Server" << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << std::endl;
    
    // Create matching engine
    MatchingEngineCore engine;
    
    // Create WebSocket servers
    API::WebSocketServer market_data_ws(8081);
    API::WebSocketServer trade_ws(8082);
    
    // Create publishers
    Publishers::TradePublisher trade_publisher(trade_ws);
    Publishers::MarketDataPublisher market_data_publisher(engine, market_data_ws);
    
    // Set up callbacks
    engine.setTradeCallback([&](const Trade& trade) {
        std::cout << "Trade: " << trade.toJson() << std::endl;
        trade_publisher.publishTrade(trade);
        
        // Note: Market data will be published by processLimitOrder
        // if there's a partial fill (order rests on book)
        // No need to publish here for fully filled orders
    });
    
    // Callback when orders are added to book (before any matching)
    engine.setBookUpdateCallback([&](const Symbol& symbol) {
        market_data_publisher.publishSnapshot(symbol);
    });
    
    // Start servers
    try {
        market_data_ws.start();
        trade_ws.start();
        market_data_publisher.start();
        
        // Start REST API (this will block in its own thread)
        API::RestAPIServer rest_api(engine, 8080);
        rest_api.start();
        
        std::cout << std::endl;
        std::cout << "========================================" << std::endl;
        std::cout << "  Server Status" << std::endl;
        std::cout << "========================================" << std::endl;
        std::cout << "REST API:        http://localhost:8080" << std::endl;
        std::cout << "Market Data WS:  ws://localhost:8081" << std::endl;
        std::cout << "Trade Feed WS:   ws://localhost:8082" << std::endl;
        std::cout << std::endl;
        std::cout << "API Endpoints:" << std::endl;
        std::cout << "  POST   /api/v1/orders           - Submit order" << std::endl;
        std::cout << "  GET    /api/v1/orders/{id}      - Get order status" << std::endl;
        std::cout << "  DELETE /api/v1/orders/{id}      - Cancel order" << std::endl;
        std::cout << "  GET    /api/v1/orderbook/{sym}  - Get order book" << std::endl;
        std::cout << std::endl;
        std::cout << "Press Ctrl+C to stop..." << std::endl;
        std::cout << "========================================" << std::endl;
        std::cout << std::endl;
        
        // Keep running until signal
        while (keep_running) {
            std::this_thread::sleep_for(std::chrono::seconds(1));
            
            // Print statistics
            if (engine.getTotalTradesExecuted() > 0) {
                std::cout << "\rStats: Orders=" << engine.getTotalOrdersProcessed()
                          << " Trades=" << engine.getTotalTradesExecuted()
                          << " WS Clients=" << (market_data_ws.clientCount() + trade_ws.clientCount())
                          << "   " << std::flush;
            }
        }
        
        std::cout << std::endl << "Stopping servers..." << std::endl;
        
        rest_api.stop();
        market_data_publisher.stop();
        market_data_ws.stop();
        trade_ws.stop();
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    std::cout << "Server stopped cleanly" << std::endl;
    
    return 0;
}
