#include "publishers/MarketDataPublisher.hpp"
#include <iostream>
#include <sstream>
#include <iomanip>

namespace MatchingEngine {
namespace Publishers {

MarketDataPublisher::MarketDataPublisher(MatchingEngineCore& engine, 
                                          API::WebSocketServer& ws_server)
    : engine_(engine), ws_server_(ws_server), running_(false), update_interval_ms_(100) {}

MarketDataPublisher::~MarketDataPublisher() {
    stop();
}

void MarketDataPublisher::start() {
    if (running_) return;
    
    running_ = true;
    publisher_thread_ = std::thread(&MarketDataPublisher::publishLoop, this);
    
    std::cout << "Market Data Publisher started" << std::endl;
}

void MarketDataPublisher::stop() {
    if (!running_) return;
    
    running_ = false;
    
    if (publisher_thread_.joinable()) {
        publisher_thread_.join();
    }
    
    std::cout << "Market Data Publisher stopped" << std::endl;
}

void MarketDataPublisher::publishSnapshot(const Symbol& symbol) {
    auto book = engine_.getOrderBook(symbol);
    if (!book) return;
    
    auto bids = book->getBids(10);
    auto asks = book->getAsks(10);
    
    // Get current timestamp
    auto now = std::chrono::system_clock::now();
    auto now_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(
        now.time_since_epoch()).count();
    auto now_sec = now_ns / 1000000000;
    auto now_nsec = now_ns % 1000000000;
    
    std::time_t time = static_cast<std::time_t>(now_sec);
    std::tm* tm_info = std::gmtime(&time);
    
    char time_buffer[80];
    std::strftime(time_buffer, sizeof(time_buffer), "%Y-%m-%dT%H:%M:%S", tm_info);
    
    std::ostringstream timestamp;
    timestamp << time_buffer << "." << std::setfill('0') << std::setw(9) << now_nsec << "Z";
    
    API::OrderBookSnapshot snapshot;
    snapshot.timestamp = timestamp.str();
    snapshot.symbol = symbol;
    
    for (const auto& [price, qty] : bids) {
        std::ostringstream p, q;
        p << std::fixed << std::setprecision(2) << price;
        q << std::fixed << std::setprecision(8) << qty;
        snapshot.bids.emplace_back(p.str(), q.str());
    }
    
    for (const auto& [price, qty] : asks) {
        std::ostringstream p, q;
        p << std::fixed << std::setprecision(2) << price;
        q << std::fixed << std::setprecision(8) << qty;
        snapshot.asks.emplace_back(p.str(), q.str());
    }
    
    // Broadcast to all WebSocket clients
    ws_server_.broadcast(snapshot.toJson());
}

void MarketDataPublisher::publishLoop() {
    while (running_) {
        // For now, we don't have a list of active symbols
        // In production, you'd maintain a set of symbols to publish
        // For demo purposes, this method is called on-demand via publishSnapshot
        
        std::this_thread::sleep_for(std::chrono::milliseconds(update_interval_ms_));
    }
}

} // namespace Publishers
} // namespace MatchingEngine
