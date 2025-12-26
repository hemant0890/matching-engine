#pragma once

#include <thread>
#include <atomic>
#include <vector>
#include <mutex>
#include <string>
#include <set>

namespace MatchingEngine {
namespace API {

/**
 * @brief Simple WebSocket server for real-time data streaming
 * Note: This is a simplified implementation for demonstration
 * Production should use a proper WebSocket library
 */
class WebSocketServer {
public:
    WebSocketServer(int port);
    ~WebSocketServer();
    
    void start();
    void stop();
    void broadcast(const std::string& message);
    bool isRunning() const { return running_; }
    size_t clientCount() const;

private:
    int port_;
    std::atomic<bool> running_;
    std::thread server_thread_;
    int server_socket_;
    
    std::set<int> clients_;
    mutable std::mutex clients_mutex_;
    
    void serverLoop();
    void handleClient(int client_socket);
    bool performWebSocketHandshake(int socket);
    void sendWebSocketFrame(int socket, const std::string& message);
    std::string receiveWebSocketFrame(int socket);
};

} // namespace API
} // namespace MatchingEngine
