const std = @import("std");
const rl = @import("raylib");
const rlm = @import("raylib-math");

const screenWidth = 800;
const screenHeight = 600;

const paddleHeight = 100;
const paddleWidth = 25;
const paddleMargin = 20;
const paddleVelocity = 5;

const ballRadius = 10;
const ballVelocity = 6.0;
const ballInitialAngleCone = std.math.degreesToRadians(f32, 120.0);

const pointsToWin = 3;

const scoreY = 20;
const scoreMargin = 70;
const scoreSize = 60;

const winText = "WIN";
const loseText = "LOSE";

const resultTextSize = 100;
const resultY = screenHeight / 3;
const resultMargin = 50;

const State = struct {
    // paddle positions are the center of the paddle.
    player1Pos: f32,
    player2Pos: f32,
    player1Score: u8,
    player2Score: u8,
    ballPos: rl.Vector2,
    ballDir: rl.Vector2,
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

fn update() void {
    if (rl.isKeyPressed(.key_r)) {
        restartGame();
    }

    if (state.state != .playing) {
        return;
    }

    if (rl.isKeyDown(.key_w)) {
        state.player1Pos -= paddleVelocity;
    }
    if (rl.isKeyDown(.key_s)) {
        state.player1Pos += paddleVelocity;
    }

    if (rl.isKeyDown(.key_up)) {
        state.player2Pos -= paddleVelocity;
    }
    if (rl.isKeyDown(.key_down)) {
        state.player2Pos += paddleVelocity;
    }

    // clamp paddle positions
    state.player1Pos = @min(state.player1Pos, screenHeight - paddleHeight / 2);
    state.player1Pos = @max(state.player1Pos, paddleHeight / 2);

    state.player2Pos = @min(state.player2Pos, screenHeight - paddleHeight / 2);
    state.player2Pos = @max(state.player2Pos, paddleHeight / 2);

    // check for ball collisions
    const p1Edge = paddleMargin + paddleWidth;
    if (collidingWithPaddle(p1Edge, state.player1Pos) and state.ballDir.x < 0) {
        state.ballDir.x *= -1.0;
    }

    const p2Edge = screenWidth - paddleMargin - paddleWidth;
    if (collidingWithPaddle(p2Edge, state.player2Pos) and state.ballDir.x > 0) {
        state.ballDir.x *= -1.0;
    }

    // top wall
    if (state.ballPos.y <= ballRadius) {
        state.ballDir.y *= -1.0;
    }

    // bottom wall
    if (state.ballPos.y >= screenHeight - ballRadius) {
        state.ballDir.y *= -1.0;
    }

    // left wall, point for p1
    if (state.ballPos.x <= ballRadius) {
        state.player2Score += 1;
        resetBall();
    }

    // right wall, point for p1
    if (state.ballPos.x >= screenWidth - ballRadius) {
        state.player1Score += 1;
        resetBall();
    }

    const ballDelta = rlm.vector2Scale(state.ballDir, ballVelocity);
    state.ballPos = rlm.vector2Add(state.ballPos, ballDelta);

    if (state.player1Score == pointsToWin or state.player2Score == pointsToWin) {
        state.state = .done;
    }
}

fn collidingWithPaddle(px: f32, py: f32) bool {
    // ball collides with paddle if the ball is touching the inner edge of the paddle
    if (std.math.fabs(state.ballPos.x - px) <= ballRadius) {
        if (state.ballPos.y >= py - paddleHeight / 2 and state.ballPos.y <= py + paddleHeight / 2) {
            return true;
        }
    }
    return false;
}

fn restartGame() void {
    state.player1Pos = screenHeight / 2;
    state.player2Pos = screenHeight / 2;
    state.player1Score = 0;
    state.player2Score = 0;
    resetBall();
    state.state = .playing;
}

fn resetBall() void {
    state.ballPos = rl.Vector2.init(screenWidth / 2, screenHeight / 2);

    var ballAngle = (state.rng.float(f32) - 0.5) * ballInitialAngleCone;
    if (state.rng.float(f32) < 0.5) {
        ballAngle += std.math.pi;
    }
    state.ballDir = rl.Vector2.init(@cos(ballAngle), @sin(ballAngle));
}

fn render() void {
    rl.beginDrawing();
    defer rl.endDrawing();

    rl.clearBackground(rl.Color.black);

    // draw stage
    rl.drawLineEx(
        rl.Vector2.init(screenWidth / 2, 0),
        rl.Vector2.init(screenWidth / 2, screenHeight),
        5.0,
        rl.Color.white,
    );

    // draw player paddles
    rl.drawRectangle(
        paddleMargin,
        @as(i32, @intFromFloat(state.player1Pos)) - (paddleHeight / 2),
        paddleWidth,
        paddleHeight,
        rl.Color.white,
    );

    rl.drawRectangle(
        screenWidth - paddleMargin - paddleWidth,
        @as(i32, @intFromFloat(state.player2Pos)) - (paddleHeight / 2),
        paddleWidth,
        paddleHeight,
        rl.Color.white,
    );

    // draw scores
    var scoreBuf = [2:0]u8{ 0, 0 };
    scoreBuf[0] = '0' + state.player1Score;
    rl.drawText(
        &scoreBuf,
        scoreMargin,
        scoreY,
        scoreSize,
        rl.Color.white,
    );

    scoreBuf[0] = '0' + state.player2Score;
    const p2ScoreWidth = rl.measureText(&scoreBuf, scoreSize);
    rl.drawText(
        &scoreBuf,
        screenWidth - scoreMargin - p2ScoreWidth,
        scoreY,
        scoreSize,
        rl.Color.white,
    );

    switch (state.state) {
        .playing => {
            // draw ball
            rl.drawRectangle(
                @intFromFloat(state.ballPos.x - ballRadius),
                @intFromFloat(state.ballPos.y - ballRadius),
                ballRadius * 2,
                ballRadius * 2,
                rl.Color.white,
            );
        },
        .done => {
            const p1Text = if (state.player1Score == pointsToWin) winText else loseText;
            const p2Text = if (state.player2Score == pointsToWin) winText else loseText;

            const p1ResultWidth = rl.measureText(p1Text, resultTextSize);
            rl.drawText(
                p1Text,
                screenWidth / 2 - resultMargin - p1ResultWidth,
                resultY,
                resultTextSize,
                rl.Color.white,
            );

            rl.drawText(
                p2Text,
                screenWidth / 2 + resultMargin,
                resultY,
                resultTextSize,
                rl.Color.white,
            );
        },
    }
}
