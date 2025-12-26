#include "core/Trade.hpp"
#include <sstream>
#include <iomanip>
#include <ctime>

namespace MatchingEngine {

std::string Trade::toJson() const {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(8);
    
    // Format timestamp as ISO 8601
    auto ts_seconds = timestamp / 1000000000;
    auto ts_nanos = timestamp % 1000000000;
    std::time_t time = static_cast<std::time_t>(ts_seconds);
    std::tm* tm_info = std::gmtime(&time);
    
    char time_buffer[80];
    std::strftime(time_buffer, sizeof(time_buffer), "%Y-%m-%dT%H:%M:%S", tm_info);
    
    oss << "{";
    oss << "\"timestamp\":\"" << time_buffer << "." 
        << std::setfill('0') << std::setw(9) << ts_nanos << "Z\",";
    oss << "\"symbol\":\"" << symbol << "\",";
    oss << "\"trade_id\":\"" << trade_id << "\",";
    oss << "\"price\":\"" << price << "\",";
    oss << "\"quantity\":\"" << quantity << "\",";
    oss << "\"aggressor_side\":\"" << aggressor_side << "\",";
    oss << "\"maker_order_id\":\"" << maker_order_id << "\",";
    oss << "\"taker_order_id\":\"" << taker_order_id << "\",";
    
    // Add fee information
    oss << "\"maker_fee\":" << maker_fee << ",";
    oss << "\"taker_fee\":" << taker_fee << ",";
    oss << "\"maker_fee_rate\":" << maker_fee_rate << ",";
    oss << "\"taker_fee_rate\":" << taker_fee_rate;
    
    oss << "}";
    
    return oss.str();
}

} // namespace MatchingEngine
