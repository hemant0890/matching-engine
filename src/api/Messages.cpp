#include "api/Messages.hpp"
#include <sstream>
#include <iomanip>

namespace MatchingEngine {
namespace API {

// Simple JSON builder (no external dependencies)
static std::string escapeJson(const std::string& str) {
    std::ostringstream oss;
    for (char c : str) {
        switch (c) {
            case '"': oss << "\\\""; break;
            case '\\': oss << "\\\\"; break;
            case '\n': oss << "\\n"; break;
            case '\r': oss << "\\r"; break;
            case '\t': oss << "\\t"; break;
            default: oss << c; break;
        }
    }
    return oss.str();
}

std::string OrderRequest::toJson() const {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(8);
    oss << "{";
    oss << "\"symbol\":\"" << escapeJson(symbol) << "\",";
    oss << "\"order_type\":\"" << escapeJson(order_type) << "\",";
    oss << "\"side\":\"" << escapeJson(side) << "\",";
    oss << "\"quantity\":" << quantity << ",";
    oss << "\"price\":" << price;
    if (!client_order_id.empty()) {
        oss << ",\"client_order_id\":\"" << escapeJson(client_order_id) << "\"";
    }
    oss << "}";
    return oss.str();
}

OrderRequest OrderRequest::fromJson(const std::string& json) {
    OrderRequest req;
    
    // Simple JSON parsing (for production, use nlohmann/json)
    size_t pos = 0;
    
    auto findValue = [&](const std::string& key) -> std::string {
        std::string search = "\"" + key + "\"";
        size_t start = json.find(search, pos);
        if (start == std::string::npos) return "";
        
        start = json.find(":", start);
        if (start == std::string::npos) return "";
        start++;
        
        // Skip whitespace
        while (start < json.size() && (json[start] == ' ' || json[start] == '\t')) start++;
        
        if (json[start] == '"') {
            // String value
            start++;
            size_t end = json.find("\"", start);
            return json.substr(start, end - start);
        } else {
            // Number value
            size_t end = start;
            while (end < json.size() && (isdigit(json[end]) || json[end] == '.' || json[end] == '-')) end++;
            return json.substr(start, end - start);
        }
    };
    
    req.symbol = findValue("symbol");
    req.order_type = findValue("order_type");
    req.side = findValue("side");
    
    std::string qty_str = findValue("quantity");
    std::string price_str = findValue("price");
    std::string stop_price_str = findValue("stop_price");
    
    req.quantity = qty_str.empty() ? 0.0 : std::stod(qty_str);
    req.price = price_str.empty() ? 0.0 : std::stod(price_str);
    req.stop_price = stop_price_str.empty() ? 0.0 : std::stod(stop_price_str);
    req.client_order_id = findValue("client_order_id");
    
    return req;
}

std::string OrderResponse::toJson() const {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(8);
    
    oss << "{";
    oss << "\"success\":" << (success ? "true" : "false") << ",";
    oss << "\"order_id\":\"" << escapeJson(order_id) << "\",";
    oss << "\"message\":\"" << escapeJson(message) << "\",";
    oss << "\"status\":\"" << escapeJson(status) << "\"";
    
    // Add trade information if trade occurred
    if (has_trade) {
        oss << ",\"trade\":{";
        oss << "\"price\":" << trade_price << ",";
        oss << "\"quantity\":" << trade_quantity << ",";
        oss << "\"maker_fee\":" << maker_fee << ",";
        oss << "\"taker_fee\":" << taker_fee << ",";
        oss << "\"maker_fee_rate\":" << maker_fee_rate << ",";
        oss << "\"taker_fee_rate\":" << taker_fee_rate;
        oss << "}";
    }
    
    oss << "}";
    return oss.str();
}

std::string OrderBookSnapshot::toJson() const {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(8);
    
    oss << "{";
    oss << "\"timestamp\":\"" << escapeJson(timestamp) << "\",";
    oss << "\"symbol\":\"" << escapeJson(symbol) << "\",";
    
    oss << "\"bids\":[";
    for (size_t i = 0; i < bids.size(); ++i) {
        if (i > 0) oss << ",";
        oss << "[\"" << bids[i].first << "\",\"" << bids[i].second << "\"]";
    }
    oss << "],";
    
    oss << "\"asks\":[";
    for (size_t i = 0; i < asks.size(); ++i) {
        if (i > 0) oss << ",";
        oss << "[\"" << asks[i].first << "\",\"" << asks[i].second << "\"]";
    }
    oss << "]";
    
    oss << "}";
    return oss.str();
}

std::string ErrorResponse::toJson() const {
    std::ostringstream oss;
    oss << "{";
    oss << "\"error\":\"" << escapeJson(error) << "\",";
    oss << "\"message\":\"" << escapeJson(message) << "\"";
    oss << "}";
    return oss.str();
}

} // namespace API
} // namespace MatchingEngine
