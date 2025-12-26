#include "publishers/TradePublisher.hpp"

namespace MatchingEngine {
namespace Publishers {

TradePublisher::TradePublisher(API::WebSocketServer& ws_server)
    : ws_server_(ws_server) {}

void TradePublisher::publishTrade(const Trade& trade) {
    // Broadcast trade to all WebSocket clients
    ws_server_.broadcast(trade.toJson());
}

} // namespace Publishers
} // namespace MatchingEngine
