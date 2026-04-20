BINARY_NAME=komodo-notifier

.PHONY: all clean build-linux-amd64 build-linux-arm64 build-mac-arm64

all: clean build-linux-amd64 build-linux-arm64 build-mac-arm64

build-linux-amd64:
	GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -trimpath -o build/${BINARY_NAME}-linux-amd64 main.go

build-linux-arm64:
	GOOS=linux GOARCH=arm64 go build -ldflags="-s -w" -trimpath -o build/${BINARY_NAME}-linux-arm64 main.go

build-mac-arm64:
	GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -trimpath -o build/${BINARY_NAME}-darwin-arm64 main.go

clean:
	rm -rf build/
