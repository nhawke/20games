const std = @import("std");
const rl = @import("raylib");
const rlm = @import("raylib-math");

const printf = std.debug.print;

const screenWidth = 600;
const screenHeight = 800;

const paddleHeight = 15;
const paddleWidth = blockWidth;
const paddleMargin = 30;
const paddleVelocity = 5;

const ballRadius = 5;
const ballStartSpeed = 6.0;
const ballMaxSpeed = 10.0;
const ballInitialAngleCone = std.math.degreesToRadians(f32, 120.0);

const startingLives = 3;

const scoreY = 20;
const scoreMargin = 70;
const scoreSize = 60;

const resultTextSize = 100;
const resultY = screenHeight / 3;
const resultMargin = 50;

const blockColumns = 14;
const blockRows = 8;
const blockPadding = 5;
const blockStartY = 2 * screenHeight / 3;
const blockWidth = (screenWidth - blockPadding) / blockColumns - blockPadding;
const blockHeight = 15;

const State = struct {
    // paddle positions are the center of the paddle.
    playerPos: f32,
    lives: u8,
    score: u8,
    ballPos: rl.Vector2,
    ballDir: rl.Vector2,
    ballSpeed: f32,
    field: [blockRows][blockColumns]bool,
    rng: std.rand.Random,
    state: GameState,
};

const GameState = enum {
    playing,
    done,
};

var state: State = undefined;

pub fn main() !void {
    rl.initWindow(screenWidth, screenHeight, "Pong");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    rl.setTraceLogLevel(.log_none);

    var rand = std.rand.DefaultPrng.init(@bitCast(rl.getTime()));
    var rng = rand.random();

    state.rng = rng;

    restartGame();

    while (!rl.windowShouldClose()) {
        update();

        render();
    }
}

// NOTE: rendering is done in game coordinates
fn update() void {
    if (rl.isKeyPressed(.key_r)) {
        restartGame();
    }

    if (state.state != .playing) {
        return;
    }

    if (rl.isKeyDown(.key_a)) {
        state.playerPos -= paddleVelocity;
    }
    if (rl.isKeyDown(.key_d)) {
        state.playerPos += paddleVelocity;
    }

    // clamp paddle position
    state.playerPos = @min(state.playerPos, screenWidth - paddleWidth);
    state.playerPos = @max(state.playerPos, 0);

    // move ball
    const ballDelta = rlm.vector2Scale(state.ballDir, state.ballSpeed);
    state.ballPos = rlm.vector2Add(state.ballPos, ballDelta);

    // check for paddle collisions
    if (ballCollidingWithRect(state.ballPos, ballRadius, rl.Vector2.init(state.playerPos, paddleMargin), paddleWidth, paddleHeight) and state.ballDir.y < 0) {
        state.ballDir.y *= -1.0;
    }

    // check for block collisions
    for (0..blockRows) |row| {
        for (0..blockColumns) |col| {
            if (state.ballPos.y < blockStartY) {
                continue;
            }
            if (!state.field[row][col]) {
                continue;
            }
            const blockPos = rl.Vector2.init(@floatFromInt(blockX(col)), @floatFromInt(blockY(row)));

            if (ballCollidingWithRect(state.ballPos, ballRadius, blockPos, blockWidth, blockHeight)) {
                state.field[row][col] = false;
                state.score += 1;

                state.ballDir.y *= -1.0;
                const accelFactor: f32 = @floatFromInt(row / 2 + 1);
                state.ballSpeed += 0.1 * accelFactor;

                state.ballSpeed = @min(state.ballSpeed, ballMaxSpeed);
            }
        }
    }

    // top wall
    if (state.ballPos.y >= screenHeight - ballRadius) {
        state.ballDir.y *= -1.0;
    }

    // left wall
    if (state.ballPos.x <= ballRadius) {
        state.ballDir.x *= -1.0;
    }

    // right wall
    if (state.ballPos.x >= screenWidth - ballRadius) {
        state.ballDir.x *= -1.0;
    }

    // bottom wall
    if (state.ballPos.y <= ballRadius) {
        resetBall();

        state.lives -= 1;
        if (state.lives == 0) {
            state.state = .done;
        }
    }
}

fn ballCollidingWithRect(ballPos: rl.Vector2, radius: i32, pos: rl.Vector2, width: i32, height: i32) bool {
    const fradius: f32 = @floatFromInt(radius);

    // left edge
    if (pos.x > ballPos.x + fradius) {
        return false;
    }
    // right edge
    if (pos.x + @as(f32, @floatFromInt(width)) < ballPos.x - fradius) {
        return false;
    }
    // bottom
    if (pos.y > ballPos.y + fradius) {
        return false;
    }
    // top
    if (pos.y + @as(f32, @floatFromInt(height)) < ballPos.y - fradius) {
        return false;
    }

    return true;
}

fn restartGame() void {
    state.playerPos = screenHeight / 2;
    state.score = 0;
    state.lives = startingLives;

    for (0..blockRows) |row| {
        for (0..blockColumns) |col| {
            state.field[row][col] = true;
        }
    }

    resetBall();
    state.state = .playing;
}

fn resetBall() void {
    state.ballPos = rl.Vector2.init(screenWidth / 2, screenHeight / 2);
    state.ballSpeed = ballStartSpeed;

    var ballAngle = (state.rng.float(f32) - 0.5) * ballInitialAngleCone;

    // rotate 90 degrees to the right so ball is heading downward
    ballAngle -= std.math.pi / 2.0;
    state.ballDir = rl.Vector2.init(@cos(ballAngle), @sin(ballAngle));
}

// returns the block x coord in game space
fn blockX(col: usize) i32 {
    return @intCast((blockWidth + blockPadding) * col + blockPadding);
}

// returns the block y coord in game space
fn blockY(row: usize) i32 {
    return @intCast(blockStartY + ((blockHeight + blockPadding) * row));
}

// NOTE: rendering is done in screen coordinates (y = 0 at top)
fn render() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.black);

    // draw paddle
    rl.drawRectangle(
        @as(i32, @intFromFloat(state.playerPos)),
        screenHeight - paddleMargin,
        paddleWidth,
        paddleHeight,
        rl.Color.gray,
    );

    // draw blocks in the field
    const colorTable = [_]rl.Color{
        rl.Color.red,
        rl.Color.orange,
        rl.Color.yellow,
        rl.Color.green,
    };

    for (0..blockRows) |row| {
        for (0..blockColumns) |col| {
            if (!state.field[row][col]) {
                continue;
            }

            rl.drawRectangle(
                blockX(col),
                screenHeight - blockY(row),
                blockWidth,
                blockHeight,
                colorTable[(row / 2) % colorTable.len],
            );
        }
    }

    // draw score
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var textBuf = std.fmt.allocPrintZ(alloc, "{d}", .{state.score}) catch "ERR";
    rl.drawText(
        textBuf,
        scoreMargin,
        scoreY,
        scoreSize,
        rl.Color.white,
    );

    textBuf = std.fmt.allocPrintZ(alloc, "{d}", .{state.lives}) catch "ERR";
    rl.drawText(
        textBuf,
        scoreMargin + 200,
        scoreY,
        scoreSize,
        rl.Color.white,
    );

    switch (state.state) {
        .playing => {
            // draw ball
            rl.drawCircle(
                @intFromFloat(state.ballPos.x),
                screenHeight - @as(i32, @intFromFloat(state.ballPos.y)),
                ballRadius,
                rl.Color.white,
            );
        },
        .done => {},
    }
}
