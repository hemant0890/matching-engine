#pragma once

#include "core/Trade.hpp"
#include "api/WebSocketServer.hpp"

namespace MatchingEngine {
namespace Publishers {

/**
 * @brief Publishes trade executions to WebSocket clients
 */
class TradePublisher {
public:
    TradePublisher(API::WebSocketServer& ws_server);
    
    void publishTrade(const Trade& trade);

private:
    API::WebSocketServer& ws_server_;
};

} // namespace Publishers
} // namespace MatchingEngine
