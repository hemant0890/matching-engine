#include "core/Order.hpp"
#include <sstream>
#include <iomanip>

namespace MatchingEngine {

std::string Order::toString() const {
    std::ostringstream oss;
    oss << std::fixed << std::setprecision(8);
    oss << "Order{id=" << order_id 
        << ", symbol=" << symbol
        << ", type=" << orderTypeToString(type)
        << ", side=" << orderSideToString(side)
        << ", price=" << price
        << ", qty=" << quantity
        << ", filled=" << filled_quantity
        << ", status=" << orderStatusToString(status)
        << "}";
    return oss.str();
}

} // namespace MatchingEngine
