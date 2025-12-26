#pragma once

#include "core/MatchingEngine.hpp"
#include "Messages.hpp"
#include <thread>
#include <atomic>
#include <string>
#include <functional>

namespace MatchingEngine {
namespace API {

/**
 * @brief Simple REST API server for order submission
 * Uses basic TCP sockets (no external dependencies)
 */
class RestAPIServer {
public:
    RestAPIServer(MatchingEngineCore& engine, int port = 8080);
    ~RestAPIServer();
    
    void start();
    void stop();
    bool isRunning() const { return running_; }

private:
    MatchingEngineCore& engine_;
    int port_;
    std::atomic<bool> running_;
    std::thread server_thread_;
    int server_socket_;
    
    void serverLoop();
    void handleClient(int client_socket);
    std::string handleRequest(const std::string& request);
    std::string handleOrderSubmit(const std::string& body);
    std::string handleOrderCancel(const std::string& order_id);
    std::string handleOrderQuery(const std::string& order_id);
    std::string handleOrderBookQuery(const std::string& symbol);
};

} // namespace API
} // namespace MatchingEngine
