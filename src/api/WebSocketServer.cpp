#include "api/WebSocketServer.hpp"
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <iostream>
#include <sstream>
#include <cstring>
#include <vector>

namespace MatchingEngine {
namespace API {

// Simple base64 encoding without OpenSSL
static const char base64_chars[] = 
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "0123456789+/";

static std::string base64_encode(const unsigned char* bytes, size_t len) {
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

// Proper SHA-1 implementation for WebSocket handshake
static void simple_sha1(const std::string& input, unsigned char output[20]) {
    // SHA-1 implementation
    uint32_t h0 = 0x67452301;
    uint32_t h1 = 0xEFCDAB89;
    uint32_t h2 = 0x98BADCFE;
    uint32_t h3 = 0x10325476;
    uint32_t h4 = 0xC3D2E1F0;
    
    // Prepare message
    std::vector<unsigned char> msg(input.begin(), input.end());
    size_t orig_len = msg.size();
    msg.push_back(0x80);
    
    while ((msg.size() % 64) != 56) {
        msg.push_back(0x00);
    }
    
    // Append length
    uint64_t bit_len = orig_len * 8;
    for (int i = 7; i >= 0; i--) {
        msg.push_back((bit_len >> (i * 8)) & 0xFF);
    }
    
    // Process blocks
    for (size_t chunk = 0; chunk < msg.size(); chunk += 64) {
        uint32_t w[80];
        
        // Break chunk into sixteen 32-bit words
        for (int i = 0; i < 16; i++) {
            w[i] = (msg[chunk + i*4] << 24) |
                   (msg[chunk + i*4 + 1] << 16) |
                   (msg[chunk + i*4 + 2] << 8) |
                   (msg[chunk + i*4 + 3]);
        }
        
        // Extend to 80 words
        for (int i = 16; i < 80; i++) {
            uint32_t temp = w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16];
            w[i] = (temp << 1) | (temp >> 31);
        }
        
        uint32_t a = h0, b = h1, c = h2, d = h3, e = h4;
        
        for (int i = 0; i < 80; i++) {
            uint32_t f, k;
            if (i < 20) {
                f = (b & c) | ((~b) & d);
                k = 0x5A827999;
            } else if (i < 40) {
                f = b ^ c ^ d;
                k = 0x6ED9EBA1;
            } else if (i < 60) {
                f = (b & c) | (b & d) | (c & d);
                k = 0x8F1BBCDC;
            } else {
                f = b ^ c ^ d;
                k = 0xCA62C1D6;
            }
            
            uint32_t temp = ((a << 5) | (a >> 27)) + f + e + k + w[i];
            e = d;
            d = c;
            c = (b << 30) | (b >> 2);
            b = a;
            a = temp;
        }
        
        h0 += a;
        h1 += b;
        h2 += c;
        h3 += d;
        h4 += e;
    }
    
    // Produce final hash
    for (int i = 0; i < 4; i++) {
        output[i] = (h0 >> (24 - i * 8)) & 0xFF;
        output[4 + i] = (h1 >> (24 - i * 8)) & 0xFF;
        output[8 + i] = (h2 >> (24 - i * 8)) & 0xFF;
        output[12 + i] = (h3 >> (24 - i * 8)) & 0xFF;
        output[16 + i] = (h4 >> (24 - i * 8)) & 0xFF;
    }
}

WebSocketServer::WebSocketServer(int port)
    : port_(port), running_(false), server_socket_(-1) {}

WebSocketServer::~WebSocketServer() {
    stop();
}

void WebSocketServer::start() {
    if (running_) return;
    
    running_ = true;
    server_thread_ = std::thread(&WebSocketServer::serverLoop, this);
    
    std::cout << "WebSocket Server started on port " << port_ << std::endl;
}

void WebSocketServer::stop() {
    if (!running_) return;
    
    running_ = false;
    
    // Close all client connections
    {
        std::lock_guard<std::mutex> lock(clients_mutex_);
        for (int client : clients_) {
            close(client);
        }
        clients_.clear();
    }
    
    if (server_socket_ >= 0) {
        close(server_socket_);
        server_socket_ = -1;
    }
    
    if (server_thread_.joinable()) {
        server_thread_.join();
    }
    
    std::cout << "WebSocket Server stopped" << std::endl;
}

void WebSocketServer::broadcast(const std::string& message) {
    std::lock_guard<std::mutex> lock(clients_mutex_);
    
    std::vector<int> disconnected;
    
    for (int client : clients_) {
        try {
            sendWebSocketFrame(client, message);
        } catch (...) {
            disconnected.push_back(client);
        }
    }
    
    // Remove disconnected clients
    for (int client : disconnected) {
        clients_.erase(client);
        close(client);
    }
}

size_t WebSocketServer::clientCount() const {
    std::lock_guard<std::mutex> lock(clients_mutex_);
    return clients_.size();
}

void WebSocketServer::serverLoop() {
    server_socket_ = socket(AF_INET, SOCK_STREAM, 0);
    if (server_socket_ < 0) {
        std::cerr << "Failed to create WebSocket socket" << std::endl;
        return;
    }
    
    int opt = 1;
    setsockopt(server_socket_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port_);
    
    if (bind(server_socket_, (struct sockaddr*)&address, sizeof(address)) < 0) {
        std::cerr << "Failed to bind WebSocket socket" << std::endl;
        close(server_socket_);
        return;
    }
    
    if (listen(server_socket_, 10) < 0) {
        std::cerr << "Failed to listen on WebSocket socket" << std::endl;
        close(server_socket_);
        return;
    }
    
    std::cout << "WebSocket listening on port " << port_ << std::endl;
    
    while (running_) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        
        int client_socket = accept(server_socket_, (struct sockaddr*)&client_addr, &client_len);
        if (client_socket < 0) {
            if (running_) {
                std::cerr << "Failed to accept WebSocket connection" << std::endl;
            }
            continue;
        }
        
        std::thread([this, client_socket]() {
            handleClient(client_socket);
        }).detach();
    }
}

void WebSocketServer::handleClient(int client_socket) {
    if (!performWebSocketHandshake(client_socket)) {
        close(client_socket);
        return;
    }
    
    {
        std::lock_guard<std::mutex> lock(clients_mutex_);
        clients_.insert(client_socket);
    }
    
    std::cout << "WebSocket client connected (fd=" << client_socket << ")" << std::endl;
    
    // Keep connection alive
    char buffer[1024];
    while (running_) {
        ssize_t n = read(client_socket, buffer, sizeof(buffer));
        if (n <= 0) break;
        // Ignore client messages for now
    }
    
    {
        std::lock_guard<std::mutex> lock(clients_mutex_);
        clients_.erase(client_socket);
    }
    
    close(client_socket);
    std::cout << "WebSocket client disconnected (fd=" << client_socket << ")" << std::endl;
}

bool WebSocketServer::performWebSocketHandshake(int socket) {
    char buffer[4096];
    ssize_t bytes_read = read(socket, buffer, sizeof(buffer) - 1);
    
    if (bytes_read <= 0) return false;
    
    buffer[bytes_read] = '\0';
    std::string request(buffer);
    
    size_t key_pos = request.find("Sec-WebSocket-Key:");
    if (key_pos == std::string::npos) return false;
    
    key_pos += 18;
    while (key_pos < request.size() && request[key_pos] == ' ') key_pos++;
    
    size_t key_end = request.find("\r\n", key_pos);
    if (key_end == std::string::npos) return false;
    
    std::string key = request.substr(key_pos, key_end - key_pos);
    
    // WebSocket accept key computation
    std::string magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    std::string accept_input = key + magic;
    
    unsigned char hash[20];
    simple_sha1(accept_input, hash);
    
    std::string accept_key = base64_encode(hash, 20);
    
    std::ostringstream response;
    response << "HTTP/1.1 101 Switching Protocols\r\n";
    response << "Upgrade: websocket\r\n";
    response << "Connection: Upgrade\r\n";
    response << "Sec-WebSocket-Accept: " << accept_key << "\r\n";
    response << "\r\n";
    
    std::string resp_str = response.str();
    write(socket, resp_str.c_str(), resp_str.size());
    
    return true;
}

void WebSocketServer::sendWebSocketFrame(int socket, const std::string& message) {
    std::vector<unsigned char> frame;
    
    // FIN bit + text frame opcode
    frame.push_back(0x81);
    
    // Payload length
    size_t len = message.size();
    if (len < 126) {
        frame.push_back(static_cast<unsigned char>(len));
    } else if (len < 65536) {
        frame.push_back(126);
        frame.push_back(static_cast<unsigned char>((len >> 8) & 0xFF));
        frame.push_back(static_cast<unsigned char>(len & 0xFF));
    } else {
        frame.push_back(127);
        for (int i = 7; i >= 0; i--) {
            frame.push_back(static_cast<unsigned char>((len >> (i * 8)) & 0xFF));
        }
    }
    
    // Payload
    frame.insert(frame.end(), message.begin(), message.end());
    
    write(socket, frame.data(), frame.size());
}

std::string WebSocketServer::receiveWebSocketFrame(int socket) {
    // Simplified - just return empty for now
    return "";
}

} // namespace API
} // namespace MatchingEngine
