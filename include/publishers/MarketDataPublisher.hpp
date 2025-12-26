#pragma once

#include "core/MatchingEngine.hpp"
#include "api/WebSocketServer.hpp"
#include "api/Messages.hpp"
#include <thread>
#include <atomic>
#include <chrono>

namespace MatchingEngine {
namespace Publishers {

/**
 * @brief Publishes L2 order book snapshots to WebSocket clients
 */
class MarketDataPublisher {
public:
    MarketDataPublisher(MatchingEngineCore& engine, API::WebSocketServer& ws_server);
    ~MarketDataPublisher();
    
    void start();
    void stop();
    void publishSnapshot(const Symbol& symbol);
    void setUpdateInterval(int milliseconds) { update_interval_ms_ = milliseconds; }

private:
    MatchingEngineCore& engine_;
    API::WebSocketServer& ws_server_;
    std::atomic<bool> running_;
    std::thread publisher_thread_;
    int update_interval_ms_;
    
    void publishLoop();
};

} // namespace Publishers
} // namespace MatchingEngine
