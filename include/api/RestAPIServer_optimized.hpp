#pragma once

#include "core/MatchingEngine.hpp"
#include "Messages.hpp"
#include <thread>
#include <atomic>
#include <string>
#include <vector>
#include <queue>
#include <mutex>
#include <condition_variable>

namespace MatchingEngine {
namespace API {

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
    int server_socket_;
    
    static constexpr int WORKER_THREADS = 8;
    static constexpr int SOCKET_BACKLOG = 1024;
    
    std::vector<std::thread> worker_threads_;
    std::thread accept_thread_;
    
    std::queue<int> client_queue_;
    std::mutex queue_mutex_;
    std::condition_variable queue_cv_;
    
    void acceptLoop();
    void workerLoop();
    void handleClient(int client_socket);
    std::string handleRequest(const std::string& request);
    std::string handleOrderSubmit(const std::string& body);
    std::string handleOrderCancel(const std::string& order_id);
    std::string handleOrderQuery(const std::string& order_id);
    std::string handleOrderBookQuery(const std::string& symbol);
};

} // namespace API
} // namespace MatchingEngine
