package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

Screen :: enum {
	HOME,
	GAMEPLAY,
	QUIT,
}

GameState :: struct {
	windowSize:      rl.Vector2,
	paddle:          rl.Rectangle,
	aiPaddle:        rl.Rectangle,
	paddleSpeed:     f32,
	ball:            rl.Rectangle,
	ballDirection:   rl.Vector2,
	ballSpeed:       f32,
	aiTargetY:       f32,
	aiReactionDelay: f32,
	aiReactionTimer: f32,
	scoreCPU:        int,
	scorePlayer:     int,
	boostTimer:      f32,
	screen:          Screen,
	gameWinner:      i32,
}

POINT_GAME :: 5

main :: proc() {
	gs := GameState {
		windowSize = {850, 500},
		paddle = {width = 10, height = 65},
		aiPaddle = {width = 10, height = 65},
		paddleSpeed = 10,
		ball = {width = 15, height = 15},
		ballSpeed = 10,
		aiReactionDelay = 0.1,
		screen = .HOME,
	}

	reset(&gs)

	using gs

	rl.InitWindow(i32(windowSize.x), i32(windowSize.y), "Pong")
	rl.SetTargetFPS(60)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	// game sounds :-)
	point := rl.LoadSound("./audio/point.wav")
	// get a .wav file 😣
	hit := rl.LoadSound("./audio/hit.mp3")

	for !rl.WindowShouldClose() {
		switch screen {
		case .HOME:
			if rl.IsKeyPressed(.ENTER) {
				screen = .GAMEPLAY
			}
		case .GAMEPLAY:
			delta := rl.GetFrameTime()

			boostTimer -= delta

			if rl.IsKeyDown(.UP) {
				paddle.y -= paddleSpeed
			}

			if rl.IsKeyDown(.DOWN) {
				paddle.y += paddleSpeed
			}

			if rl.IsKeyPressed(.SPACE) {
				if boostTimer < 0 {
					boostTimer = 0.2
				}
			}

			if scoreCPU >= POINT_GAME || scorePlayer >= POINT_GAME {
				gameWinner = 1 if scoreCPU > scorePlayer else 2
				scoreCPU, scorePlayer = 0, 0
				screen = .QUIT
				break
			}

			paddle.y = linalg.clamp(paddle.y, 0, windowSize.y - paddle.height)

			// AI movement
			// increase timer by time between last frame and this one
			aiReactionTimer += delta
			// if the timer is done
			if aiReactionTimer >= aiReactionDelay {
				// reset the timer
				aiReactionTimer = 0
				// use ball from last frame for extra delay
				ballMid := ball.y + ball.height / 2
				if ballDirection.x < 0 {
					// set the target to the ball
					aiTargetY = ballMid - aiPaddle.height / 2
					// add or substract 0-20 to add inaccuracy
					aiTargetY += rand.float32_range(-20, 20)

				} else {
					// set the target to screen middle
					aiTargetY = windowSize.y / 2 - aiPaddle.height / 2
				}
			}

			// calculate the distance between paddle and target
			aiPaddleMid := aiPaddle.y + aiPaddle.height / 2
			targetDiff := aiTargetY - aiPaddle.y
			// move either paddle_speed distance or less
			// won't bounce around so much
			aiPaddle.y += linalg.clamp(targetDiff, -paddleSpeed, paddleSpeed) * 0.65
			// clamp to window_size
			aiPaddle.y = linalg.clamp(aiPaddle.y, 0, windowSize.y - aiPaddle.height)

			nextBallRect := ball
			nextBallRect.x += ballSpeed * ballDirection.x
			nextBallRect.y += ballSpeed * ballDirection.y

			if nextBallRect.y >= windowSize.y - ball.height || nextBallRect.y <= 0 {
				ballDirection.y *= -1
			}

			if nextBallRect.x >= windowSize.x - ball.width {
				scoreCPU += 1
				rl.PlaySound(point)
				reset(&gs)
			}

			if nextBallRect.x < 0 {
				scorePlayer += 1
				rl.PlaySound(point)
				reset(&gs)
			}

			if newDirection, ok := moveBall(nextBallRect, paddle); ok {
				if boostTimer > 0 {
					d := 1 + boostTimer / 0.2
					newDirection *= d
				}
				ballDirection = newDirection
				rl.PlaySound(hit)
			} else if newDirection, ok := moveBall(nextBallRect, aiPaddle); ok {
				ballDirection = newDirection
				rl.PlaySound(hit)
			}
			ball.x += ballSpeed * ballDirection.x
			ball.y += ballSpeed * ballDirection.y
		case .QUIT:
			if rl.IsKeyPressed(.ENTER) {
				screen = .GAMEPLAY
			}
		}

		// rendering
		rl.BeginDrawing()

		rl.ClearBackground(rl.BLACK)

		switch screen {
		case .HOME:
			rl.DrawText(fmt.ctprint("PONG"), 250, 20, 120, rl.DARKGRAY)
			rl.DrawText(fmt.ctprint("Based on Atari PONG"), 250, 150, 5, rl.GRAY)
			rl.DrawText(fmt.ctprint("Press ENTER to PLAY"), 250, 250, 33, rl.WHITE)
			rl.DrawText(
				fmt.ctprint("Build with raylib and odin by @clovisphere"),
				10,
				450,
				20,
				rl.GRAY,
			)
		case .GAMEPLAY:
			rl.DrawLine(
				rl.GetScreenWidth() / 2,
				5,
				rl.GetScreenWidth() / 2,
				rl.GetScreenHeight() - 5,
				rl.LIGHTGRAY,
			)

			rl.DrawCircle(rl.GetScreenWidth() / 2, rl.GetScreenHeight() / 2, 20, rl.LIGHTGRAY)

			if boostTimer > 0 {
				rl.DrawRectangleRec(paddle, {u8(255 * (0.2 / boostTimer)), 255, 255, 255})
			} else {
				rl.DrawRectangleRec(paddle, rl.WHITE)
			}

			rl.DrawRectangleRec(aiPaddle, rl.WHITE)
			rl.DrawRectangleRec(ball, {255, u8(255 - 255 / linalg.length(ballDirection)), 0, 255})

			rl.DrawText(fmt.ctprintf("{}", scoreCPU), 12, 12, 32, rl.WHITE)
			rl.DrawText(fmt.ctprintf("{}", scorePlayer), i32(windowSize.x) - 28, 12, 32, rl.WHITE)
		case .QUIT:
			rl.DrawText(fmt.ctprintf("Winner is Player {}", gameWinner), 180, 75, 60, rl.GRAY)
			rl.DrawText(fmt.ctprint("Press ENTER to PLAY AGAIN"), 180, 250, 33, rl.WHITE)
		}

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
}

moveBall :: proc(ball: rl.Rectangle, paddle: rl.Rectangle) -> (rl.Vector2, bool) {
	if rl.CheckCollisionRecs(ball, paddle) {
		ballCenter := rl.Vector2{ball.x + ball.width / 2, ball.y + ball.height / 2}
		paddleCenter := rl.Vector2{paddle.x + paddle.width / 2, paddle.y + paddle.height / 2}
		return linalg.normalize0(ballCenter - paddleCenter), true
	}
	return {}, false
}

reset :: proc(using gs: ^GameState) {
	angle := rand.float32_range(-25, 26)
	if rand.int_max(100) % 2 == 0 do angle += 180
	r := math.to_radians(angle)

	ballDirection.x = math.cos(r)
	ballDirection.y = math.sin(r)

	ball.x = windowSize.x / 2 - ball.width / 2
	ball.y = windowSize.y / 2 - ball.height / 2

	paddleMargin: f32 = 45

	paddle.x = windowSize.x - (paddle.width + paddleMargin)
	paddle.y = windowSize.y / 2 - paddle.height / 2

	aiPaddle.x = paddleMargin
	aiPaddle.y = windowSize.y / 2 - aiPaddle.height / 2
}
