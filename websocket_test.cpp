/*
 * WebSocket Test Client
 * 
 * This is a simple C++ WebSocket client to test the matching engine's
 * WebSocket feeds (market data and trades).
 * 
 * Compile:
 *   g++ -std=c++17 -o websocket_test websocket_test.cpp -pthread
 * 
 * Usage:
 *   ./websocket_test              (connects to both feeds)
 *   ./websocket_test market       (market data only)
 *   ./websocket_test trades       (trade feed only)
 */

#include <iostream>
#include <string>
#include <thread>
#include <atomic>
#include <mutex>
#include <cstring>
#include <csignal>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <vector>
#include <sstream>
#include <iomanip>

// ANSI color codes for pretty output
#define RESET   "\033[0m"
#define RED     "\033[31m"
#define GREEN   "\033[32m"
#define YELLOW  "\033[33m"
#define BLUE    "\033[34m"
#define MAGENTA "\033[35m"
#define CYAN    "\033[36m"
#define BOLD    "\033[1m"

std::atomic<bool> running(true);
std::mutex output_mutex;  // For thread-safe console output

// Simple base64 encoding
static const char base64_chars[] = 
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "0123456789+/";

std::string base64_encode(const unsigned char* bytes, size_t len) {
    std::string ret;
    int val = 0;
    int valb = -6;
    
    for (size_t i = 0; i < len; i++) {
        val = (val << 8) + bytes[i];
        valb += 8;
        while (valb >= 0) {
            ret.push_back(base64_chars[(val >> valb) & 0x3F]);
            valb -= 6;
        }
    }
    
    if (valb > -6) {
        ret.push_back(base64_chars[((val << 8) >> (valb + 8)) & 0x3F]);
    }
    
    while (ret.size() % 4) {
        ret.push_back('=');
    }
    
    return ret;
}

// WebSocket handshake
bool performWebSocketHandshake(int sock, int port) {
    // Generate a random key (simplified)
    unsigned char key_bytes[16];
    for (int i = 0; i < 16; i++) {
        key_bytes[i] = rand() % 256;
    }
    std::string key = base64_encode(key_bytes, 16);
    
    // Build handshake request
    std::ostringstream request;
    request << "GET / HTTP/1.1\r\n";
    request << "Host: localhost:" << port << "\r\n";
    request << "Upgrade: websocket\r\n";
    request << "Connection: Upgrade\r\n";
    request << "Sec-WebSocket-Key: " << key << "\r\n";
    request << "Sec-WebSocket-Version: 13\r\n";
    request << "\r\n";
    
    std::string req_str = request.str();
    send(sock, req_str.c_str(), req_str.size(), 0);
    
    // Read response
    char buffer[4096];
    ssize_t n = recv(sock, buffer, sizeof(buffer) - 1, 0);
    if (n <= 0) {
        return false;
    }
    
    buffer[n] = '\0';
    std::string response(buffer);
    
    // Check for successful handshake
    return (response.find("101 Switching Protocols") != std::string::npos);
}

// Decode WebSocket frame
std::string decodeWebSocketFrame(const std::vector<unsigned char>& frame) {
    if (frame.size() < 2) return "";
    
    bool fin = (frame[0] & 0x80) != 0;
    unsigned char opcode = frame[0] & 0x0F;
    
    if (opcode != 0x01 && opcode != 0x02) { // Text or Binary
        return "";
    }
    
    bool masked = (frame[1] & 0x80) != 0;
    uint64_t payload_len = frame[1] & 0x7F;
    
    size_t header_len = 2;
    
    if (payload_len == 126) {
        if (frame.size() < 4) return "";
        payload_len = (frame[2] << 8) | frame[3];
        header_len = 4;
    } else if (payload_len == 127) {
        if (frame.size() < 10) return "";
        payload_len = 0;
        for (int i = 0; i < 8; i++) {
            payload_len = (payload_len << 8) | frame[2 + i];
        }
        header_len = 10;
    }
    
    if (masked) {
        header_len += 4; // Mask key
    }
    
    if (frame.size() < header_len + payload_len) {
        return "";
    }
    
    std::string payload;
    payload.reserve(payload_len);
    
    for (size_t i = 0; i < payload_len; i++) {
        payload.push_back(frame[header_len + i]);
    }
    
    return payload;
}

// Receive WebSocket message
std::string receiveWebSocketMessage(int sock) {
    std::vector<unsigned char> frame;
    unsigned char byte;
    
    while (true) {
        ssize_t n = recv(sock, &byte, 1, 0);
        if (n <= 0) {
            return "";
        }
        
        frame.push_back(byte);
        
        // Try to decode after we have minimum bytes
        if (frame.size() >= 2) {
            std::string msg = decodeWebSocketFrame(frame);
            if (!msg.empty()) {
                return msg;
            }
        }
        
        // Prevent infinite growth
        if (frame.size() > 100000) {
            return "";
        }
    }
}

// Pretty print JSON (basic formatting)
void prettyPrintJSON(const std::string& json, const std::string& color) {
    std::cout << color;
    
    int indent = 0;
    bool in_string = false;
    bool escape_next = false;
    
    for (char c : json) {
        if (escape_next) {
            std::cout << c;
            escape_next = false;
            continue;
        }
        
        if (c == '\\') {
            escape_next = true;
            std::cout << c;
            continue;
        }
        
        if (c == '"') {
            in_string = !in_string;
            std::cout << c;
            continue;
        }
        
        if (in_string) {
            std::cout << c;
            continue;
        }
        
        switch (c) {
            case '{':
            case '[':
                std::cout << c << std::endl;
                indent++;
                std::cout << std::string(indent * 2, ' ');
                break;
            case '}':
            case ']':
                std::cout << std::endl;
                indent--;
                std::cout << std::string(indent * 2, ' ') << c;
                break;
            case ',':
                std::cout << c << std::endl;
                std::cout << std::string(indent * 2, ' ');
                break;
            case ':':
                std::cout << c << ' ';
                break;
            default:
                std::cout << c;
        }
    }
    
    std::cout << RESET << std::endl;
}

// Monitor a WebSocket feed
void monitorFeed(const std::string& feed_name, int port, const std::string& color) {
    std::cout << BOLD << feed_name << " Feed Monitor Started" << RESET << std::endl;
    std::cout << "Connecting to ws://localhost:" << port << "..." << std::endl;
    
    // Create socket
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        std::cerr << RED << "Failed to create socket" << RESET << std::endl;
        return;
    }
    
    // Connect to server
    struct sockaddr_in server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    inet_pton(AF_INET, "127.0.0.1", &server_addr.sin_addr);
    
    if (connect(sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
        std::cerr << RED << "Failed to connect to localhost:" << port << RESET << std::endl;
        std::cerr << RED << "Is the server running?" << RESET << std::endl;
        close(sock);
        return;
    }
    
    std::cout << GREEN << "Connected to localhost:" << port << RESET << std::endl;
    
    // Perform WebSocket handshake
    if (!performWebSocketHandshake(sock, port)) {
        std::cerr << RED << "WebSocket handshake failed" << RESET << std::endl;
        close(sock);
        return;
    }
    
    std::cout << GREEN << "✓ WebSocket handshake successful" << RESET << std::endl;
    std::cout << "Waiting for messages..." << std::endl;
    std::cout << std::string(60, '=') << std::endl;
    
    int message_count = 0;
    
    // Receive messages
    while (running) {
        std::string message = receiveWebSocketMessage(sock);
        
        if (message.empty()) {
            if (!running) break;
            std::cerr << RED << "Connection closed or error" << RESET << std::endl;
            break;
        }
        
        message_count++;
        
        // Lock output to prevent interleaving
        {
            std::lock_guard<std::mutex> lock(output_mutex);
            
            // Print message header
            std::cout << std::endl;
            std::cout << BOLD << color << "━━━ " << feed_name << " Message #" 
                      << message_count << " ━━━" << RESET << std::endl;
            
            // Print timestamp
            auto now = std::chrono::system_clock::now();
            auto time_t = std::chrono::system_clock::to_time_t(now);
            std::cout << CYAN << "Received: " << std::put_time(std::localtime(&time_t), "%H:%M:%S") 
                      << RESET << std::endl;
            
            // Print JSON message
            prettyPrintJSON(message, color);
            
            std::cout << std::string(60, '*') << std::endl;
        }
    }
    
    close(sock);
    std::cout << feed_name << " feed monitor stopped." << std::endl;
}

void printBanner() {
    std::cout << std::endl;
    std::cout << BOLD << CYAN;
    std::cout << "╔════════════════════════════════════════════════════════════╗" << std::endl;
    std::cout << "║                                                            ║" << std::endl;
    std::cout << "║        WebSocket Test Client - Matching Engine            ║" << std::endl;
    std::cout << "║                                                            ║" << std::endl;
    std::cout << "╚════════════════════════════════════════════════════════════╝" << std::endl;
    std::cout << RESET << std::endl;
}

void printUsage() {
    std::cout << "Usage:" << std::endl;
    std::cout << "  ./websocket_test              - Monitor both feeds" << std::endl;
    std::cout << "  ./websocket_test market       - Monitor market data only" << std::endl;
    std::cout << "  ./websocket_test trades       - Monitor trade feed only" << std::endl;
    std::cout << std::endl;
    std::cout << "Feeds:" << std::endl;
    std::cout << "  Market Data: ws://localhost:8081 (Order book snapshots)" << std::endl;
    std::cout << "  Trade Feed:  ws://localhost:8082 (Trade executions)" << std::endl;
    std::cout << std::endl;
    std::cout << "Press Ctrl+C to stop." << std::endl;
    std::cout << std::endl;
}

void signalHandler(int signum) {
    std::cout << std::endl << "Shutting down..." << std::endl;
    running = false;
}

int main(int argc, char* argv[]) {
    // Setup signal handler
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);
    
    srand(time(NULL));
    
    printBanner();
    
    std::string mode = "both";
    if (argc > 1) {
        mode = argv[1];
    }
    
    if (mode != "both" && mode != "market" && mode != "trades") {
        std::cerr << RED << "Invalid mode: " << mode << RESET << std::endl;
        printUsage();
        return 1;
    }
    
    printUsage();
    
    std::cout << BOLD << "Starting monitors..." << RESET << std::endl;
    std::cout << std::string(60, '=') << std::endl;
    
    std::thread market_thread, trade_thread;
    
    if (mode == "both" || mode == "market") {
        market_thread = std::thread(monitorFeed, "Market Data", 8081, GREEN);
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
    
    if (mode == "both" || mode == "trades") {
        trade_thread = std::thread(monitorFeed, "Trade Feed", 8082, YELLOW);
    }
    
    // Wait for threads
    if (market_thread.joinable()) {
        market_thread.join();
    }
    
    if (trade_thread.joinable()) {
        trade_thread.join();
    }
    
    std::cout << std::endl;
    std::cout << BOLD << GREEN << "WebSocket test client stopped." << RESET << std::endl;
    
    return 0;
}
