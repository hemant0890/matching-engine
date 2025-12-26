CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O3 -I./include
LDFLAGS = -pthread

SRC_DIR = src
OBJ_DIR = build
TEST_DIR = tests

# Source files
CORE_SOURCES = $(SRC_DIR)/core/Order.cpp \
               $(SRC_DIR)/core/Trade.cpp \
               $(SRC_DIR)/core/OrderBook.cpp \
               $(SRC_DIR)/core/MatchingEngine.cpp \
               $(SRC_DIR)/core/StopOrderManager.cpp

API_SOURCES = $(SRC_DIR)/api/Messages.cpp \
              $(SRC_DIR)/api/RestAPIServer.cpp \
              $(SRC_DIR)/api/WebSocketServer.cpp

PUBLISHER_SOURCES = $(SRC_DIR)/publishers/MarketDataPublisher.cpp \
                    $(SRC_DIR)/publishers/TradePublisher.cpp

ALL_SOURCES = $(CORE_SOURCES) $(API_SOURCES) $(PUBLISHER_SOURCES)

# Object files
OBJECTS = $(ALL_SOURCES:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)

# Executables
TEST_TARGET = $(OBJ_DIR)/test_matching_engine
SERVER_TARGET = $(OBJ_DIR)/matching_engine_server

.PHONY: all clean test server

all: $(TEST_TARGET) $(SERVER_TARGET)

# Create build directories
$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)/core $(OBJ_DIR)/api $(OBJ_DIR)/publishers

# Compile source files
$(OBJ_DIR)/core/%.o: $(SRC_DIR)/core/%.cpp | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/api/%.o: $(SRC_DIR)/api/%.cpp | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJ_DIR)/publishers/%.o: $(SRC_DIR)/publishers/%.cpp | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Build test executable (core only)
CORE_OBJECTS = $(CORE_SOURCES:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)
$(TEST_TARGET): $(CORE_OBJECTS) $(TEST_DIR)/test_main.cpp | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) $(CORE_OBJECTS) $(TEST_DIR)/test_main.cpp -o $@ -pthread

# Build server executable (with API)
$(SERVER_TARGET): $(OBJECTS) $(SRC_DIR)/main.cpp | $(OBJ_DIR)
	$(CXX) $(CXXFLAGS) $(OBJECTS) $(SRC_DIR)/main.cpp -o $@ $(LDFLAGS)

# Run tests
test: $(TEST_TARGET)
	./$(TEST_TARGET)

# Run server
server: $(SERVER_TARGET)
	./$(SERVER_TARGET)

# Clean build artifacts
clean:
	rm -rf $(OBJ_DIR)

# Show help
help:
	@echo "Matching Engine Build System"
	@echo "============================="
	@echo "make          - Build everything"
	@echo "make test     - Build and run tests"
	@echo "make server   - Build and run server"
	@echo "make clean    - Remove build artifacts"
	@echo "make help     - Show this help message"

