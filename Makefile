
# Define variables
BIN_DIR := /usr/local/bin
SRC_DIR := src
TARGET_DIR := target
RELEASE_DIR := $(TARGET_DIR)/release
TARGET_BIN := gptube-cli
YTDLP_URL := https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp
YTDLP_BIN := $(RELEASE_DIR)/yt-dlp

# Define build targets
.PHONY: all clean install

all: $(RELEASE_DIR)/$(TARGET_BIN) $(YTDLP_BIN)

$(YTDLP_BIN):
	mkdir -p $(RELEASE_DIR)
	wget $(YTDLP_URL) -O $(YTDLP_BIN)
	chmod a+rx $(YTDLP_BIN)

$(RELEASE_DIR)/$(TARGET_BIN): $(SRC_DIR)/*.rs
	cargo build --release

install: all
	install -m 755 $(YTDLP_BIN) $(BIN_DIR)/yt-dlp
	install -m 755 $(RELEASE_DIR)/$(TARGET_BIN) $(BIN_DIR)/$(TARGET_BIN)

clean:
	rm -rf $(RELEASE_DIR)

.PHONY: all clean install
