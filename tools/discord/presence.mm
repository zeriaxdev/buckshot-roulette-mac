#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <poll.h>
#include <signal.h>
#include <unistd.h>
#include <cerrno>
#include <climits>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>

static bool alive(pid_t pid) { return kill(pid, 0) == 0; }

static bool transfer(int fd, void *buffer, size_t size, bool writing) {
    char *bytes = static_cast<char *>(buffer);
    while (size) {
        ssize_t count = writing ? send(fd, bytes, size, 0) : recv(fd, bytes, size, 0);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return false;
        bytes += count; size -= count;
    }
    return true;
}

static bool frame(int fd, uint32_t opcode, NSData *data) {
    uint32_t header[] = {opcode, static_cast<uint32_t>(data.length)};
    return transfer(fd, header, sizeof(header), true)
        && transfer(fd, const_cast<void *>(data.bytes), data.length, true);
}

static bool send_json(int fd, uint32_t opcode, NSDictionary *message) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
    return data && frame(fd, opcode, data);
}

static NSData *read_frame(int fd, uint32_t &opcode) {
    uint32_t header[2];
    if (!transfer(fd, header, sizeof(header), false) || header[1] > 65536) return nil;
    opcode = header[0];
    NSMutableData *data = [NSMutableData dataWithLength:header[1]];
    if (!transfer(fd, data.mutableBytes, data.length, false)) return nil;
    return data;
}

static NSDictionary *reply(int fd, NSString *nonce = nil) {
    for (int i = 0; i < 12; ++i) {
        uint32_t opcode;
        NSData *data = read_frame(fd, opcode);
        if (!data) return nil;
        if (opcode == 3) { if (!frame(fd, 4, data)) return nil; continue; }
        if (opcode != 1) return nil;
        id message = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![message isKindOfClass:[NSDictionary class]]) return nil;
        if (!nonce || [message[@"nonce"] isEqual:nonce]) return message;
    }
    return nil;
}

static int connect_discord() {
    const char *directory = getenv("TMPDIR");
    if (!directory) directory = "/tmp";
    for (int i = 0; i < 10; ++i) {
        sockaddr_un address{}; address.sun_family = AF_UNIX;
        int length = snprintf(address.sun_path, sizeof(address.sun_path), "%s/discord-ipc-%d", directory, i);
        if (length < 0 || static_cast<size_t>(length) >= sizeof(address.sun_path)) return -1;
        int fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0) return -1;
        int yes = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
        timeval timeout{1, 0};
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
        if (connect(fd, reinterpret_cast<sockaddr *>(&address), sizeof(address)) == 0) return fd;
        close(fd);
    }
    return -1;
}

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    char *end;
    long value = strtol(argv[1], &end, 10);
    if (*end || value <= 1 || value > INT_MAX) return 2;
    pid_t game = static_cast<pid_t>(value);
    time_t started = time(nullptr);
    // A separate helper keeps Discord disconnects and socket delays off the game thread.
    while (alive(game)) {
        @autoreleasepool {
            int fd = connect_discord();
            if (fd < 0) { usleep(500000); continue; }
            bool ok = send_json(fd, 0, @{@"v": @1, @"client_id": @"1225535693791432814"});
            NSDictionary *ready = ok ? reply(fd) : nil;
            if (![ready[@"evt"] isEqual:@"READY"]) { close(fd); usleep(500000); continue; }
            ok = send_json(fd, 1, @{@"cmd": @"SET_ACTIVITY", @"nonce": @"playing",
                @"args": @{@"pid": @(game), @"activity": @{@"timestamps": @{@"start": @(started)}}}});
            NSDictionary *accepted = ok ? reply(fd, @"playing") : nil;
            if (![accepted[@"cmd"] isEqual:@"SET_ACTIVITY"] || [accepted[@"evt"] isEqual:@"ERROR"]) { close(fd); return 0; }
            while (alive(game)) {
                pollfd event{fd, POLLIN, 0};
                int count = poll(&event, 1, 250);
                if (count < 0 && errno == EINTR) continue;
                if (count < 0 || (event.revents & (POLLERR | POLLHUP | POLLNVAL))) break;
                if (count == 0) continue;
                uint32_t opcode;
                NSData *data = read_frame(fd, opcode);
                if (!data || opcode == 2) break;
                if (opcode == 3 && !frame(fd, 4, data)) break;
            }
            if (!alive(game)) send_json(fd, 1, @{@"cmd": @"SET_ACTIVITY", @"nonce": @"clear", @"args": @{@"pid": @(game)}});
            close(fd);
        }
        if (alive(game)) usleep(500000);
    }
    return 0;
}
