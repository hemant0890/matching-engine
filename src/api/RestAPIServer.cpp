#include "api/RestAPIServer.hpp"
#include "core/Types.hpp"
#include "core/FeeConfig.hpp"
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <cstring>
#include <iostream>
#include <sstream>
#include <chrono>
#include <iomanip>

namespace MatchingEngine {
namespace API {

RestAPIServer::RestAPIServer(MatchingEngineCore& engine, int port)
    : engine_(engine), port_(port), running_(false), server_socket_(-1) {}

RestAPIServer::~RestAPIServer() {
    stop();
}

void RestAPIServer::start() {
    if (running_) return;
    
    running_ = true;
    server_thread_ = std::thread(&RestAPIServer::serverLoop, this);
    
    std::cout << "REST API Server started on port " << port_ << std::endl;
}

void RestAPIServer::stop() {
    if (!running_) return;
    
    running_ = false;
    
    if (server_socket_ >= 0) {
        close(server_socket_);
        server_socket_ = -1;
    }
    
    if (server_thread_.joinable()) {
        server_thread_.join();
    }
    
    std::cout << "REST API Server stopped" << std::endl;
}

void RestAPIServer::serverLoop() {
    // Create socket
    server_socket_ = socket(AF_INET, SOCK_STREAM, 0);
    if (server_socket_ < 0) {
        std::cerr << "Failed to create socket" << std::endl;
        return;
    }
    
    // Set socket options
    int opt = 1;
    setsockopt(server_socket_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    // Bind socket
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port_);
    
    if (bind(server_socket_, (struct sockaddr*)&address, sizeof(address)) < 0) {
        std::cerr << "Failed to bind socket" << std::endl;
        close(server_socket_);
        return;
    }
    
    // Listen
    if (listen(server_socket_, 10) < 0) {
        std::cerr << "Failed to listen on socket" << std::endl;
        close(server_socket_);
        return;
    }
    
    std::cout << "REST API listening on port " << port_ << std::endl;
    
    // Accept connections
    while (running_) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        
        int client_socket = accept(server_socket_, (struct sockaddr*)&client_addr, &client_len);
        if (client_socket < 0) {
            if (running_) {
                std::cerr << "Failed to accept connection" << std::endl;
            }
            continue;
        }
        
        // Handle client in separate thread (for simplicity, could use thread pool)
        std::thread([this, client_socket]() {
            handleClient(client_socket);
        }).detach();
    }
}

void RestAPIServer::handleClient(int client_socket) {
    char buffer[4096];
    ssize_t bytes_read = read(client_socket, buffer, sizeof(buffer) - 1);
    
    if (bytes_read <= 0) {
        close(client_socket);
        return;
    }
    
    buffer[bytes_read] = '\0';
    std::string request(buffer);
    
    std::string response = handleRequest(request);
    
    write(client_socket, response.c_str(), response.size());
    close(client_socket);
}

std::string RestAPIServer::handleRequest(const std::string& request) {
    std::istringstream iss(request);
    std::string method, path, version;
    iss >> method >> path >> version;
    
    // Extract body (after double newline)
    size_t body_start = request.find("\r\n\r\n");
    std::string body;
    if (body_start != std::string::npos) {
        body = request.substr(body_start + 4);
    }
    
    std::string response_body;
    std::string content_type = "application/json";
    int status_code = 200;
    std::string status_text = "OK";
    
    try {
        if (method == "POST" && path == "/api/v1/orders") {
            response_body = handleOrderSubmit(body);
        }
        else if (method == "DELETE" && path.find("/api/v1/orders/") == 0) {
            std::string order_id = path.substr(15);
            response_body = handleOrderCancel(order_id);
        }
        else if (method == "GET" && path.find("/api/v1/orders/") == 0) {
            std::string order_id = path.substr(15);
            response_body = handleOrderQuery(order_id);
        }
        else if (method == "GET" && path.find("/api/v1/orderbook/") == 0) {
            std::string symbol = path.substr(18);
            response_body = handleOrderBookQuery(symbol);
        }
        else {
            status_code = 404;
            status_text = "Not Found";
            ErrorResponse err{"not_found", "Endpoint not found"};
            response_body = err.toJson();
        }
    } catch (const std::exception& e) {
        status_code = 500;
        status_text = "Internal Server Error";
        ErrorResponse err{"internal_error", e.what()};
        response_body = err.toJson();
    }
    
    // Build HTTP response
    std::ostringstream response;
    response << "HTTP/1.1 " << status_code << " " << status_text << "\r\n";
    response << "Content-Type: " << content_type << "\r\n";
    response << "Content-Length: " << response_body.size() << "\r\n";
    response << "Access-Control-Allow-Origin: *\r\n";
    response << "Connection: close\r\n";
    response << "\r\n";
    response << response_body;
    
    return response.str();
}

std::string RestAPIServer::handleOrderSubmit(const std::string& body) {
    OrderRequest req = OrderRequest::fromJson(body);
    
    // Create order
    auto order = std::make_shared<Order>(
        "",
        req.symbol,
        stringToOrderType(req.order_type),
        stringToOrderSide(req.side),
        req.price,
        req.quantity
    );
    
    if (!req.client_order_id.empty()) {
        order->client_order_id = req.client_order_id;
    }
    
    // Set stop price for stop orders
    if (req.stop_price > 0.0) {
        order->stop_price = req.stop_price;
    }
    
    // Submit to engine
    std::string order_id = engine_.submitOrder(order);
    
    OrderResponse resp;
    if (!order_id.empty()) {
        resp.success = true;
        resp.order_id = order_id;
        resp.message = "Order accepted";
        resp.status = orderStatusToString(order->status);
        
        // If order was filled, include trade information with fees
        if (order->status == OrderStatus::FILLED || 
            order->status == OrderStatus::PARTIAL_FILL) {
            
            if (order->filled_quantity > 0.0) {
                resp.has_trade = true;
                resp.trade_quantity = order->filled_quantity;
                
                // Use actual average fill price (not order price)
                resp.trade_price = order->average_fill_price;
                
                // Calculate fees based on filled amount
                double trade_value = resp.trade_price * resp.trade_quantity;
                resp.maker_fee = trade_value * 0.001;  // 0.1%
                resp.taker_fee = trade_value * 0.002;  // 0.2%
                resp.maker_fee_rate = 0.001;
                resp.taker_fee_rate = 0.002;
            }
        }
    } else {
        resp.success = false;
        resp.order_id = "";
        resp.message = "Order rejected";
        resp.status = "REJECTED";
    }
    
    return resp.toJson();
}

std::string RestAPIServer::handleOrderCancel(const std::string& order_id) {
    bool cancelled = engine_.cancelOrder(order_id);
    
    OrderResponse resp;
    resp.success = cancelled;
    resp.order_id = order_id;
    resp.message = cancelled ? "Order cancelled" : "Order not found or already filled";
    resp.status = cancelled ? "CANCELLED" : "UNKNOWN";
    
    return resp.toJson();
}

std::string RestAPIServer::handleOrderQuery(const std::string& order_id) {
    auto order = engine_.getOrder(order_id);
    
    if (!order) {
        ErrorResponse err{"not_found", "Order not found"};
        return err.toJson();
    }
    
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(8);
    oss << "{";
    oss << "\"order_id\":\"" << order->order_id << "\",";
    oss << "\"symbol\":\"" << order->symbol << "\",";
    oss << "\"type\":\"" << orderTypeToString(order->type) << "\",";
    oss << "\"side\":\"" << orderSideToString(order->side) << "\",";
    oss << "\"price\":" << order->price << ",";
    oss << "\"quantity\":" << order->quantity << ",";
    oss << "\"filled_quantity\":" << order->filled_quantity << ",";
    oss << "\"status\":\"" << orderStatusToString(order->status) << "\"";
    oss << "}";
    
    return oss.str();
}

std::string RestAPIServer::handleOrderBookQuery(const std::string& symbol) {
    auto book = engine_.getOrderBook(symbol);
    
    if (!book) {
        ErrorResponse err{"not_found", "Symbol not found"};
        return err.toJson();
    }
    
    auto bids = book->getBids(10);
    auto asks = book->getAsks(10);
    
    // Get current timestamp
    auto now = std::chrono::system_clock::now();
    auto now_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(now.time_since_epoch()).count();
    auto now_sec = now_ns / 1000000000;
    auto now_nsec = now_ns % 1000000000;
    
    std::time_t time = static_cast<std::time_t>(now_sec);
    std::tm* tm_info = std::gmtime(&time);
    
    char time_buffer[80];
    std::strftime(time_buffer, sizeof(time_buffer), "%Y-%m-%dT%H:%M:%S", tm_info);
    
    std::ostringstream timestamp;
    timestamp << time_buffer << "." << std::setfill('0') << std::setw(9) << now_nsec << "Z";
    
    OrderBookSnapshot snapshot;
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
    
    return snapshot.toJson();
}

} // namespace API
} // namespace MatchingEngine
