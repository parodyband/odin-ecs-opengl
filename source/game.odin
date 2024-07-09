package game

import "core:math/rand"
import "core:math"
import "vendor:glfw"
import m "core:math/linalg"
import fmt "core:fmt"

Game :: struct {
    world:        ^World,
    window:       ^Window,
    shader:       ^Shader,
    vao:          u32,
    time:         f64,
    delta_time:   f64,
    last_fps_time: f64,
    frame_count:  int,
}

init_game :: proc(world: ^World, window: ^Window, shader: ^Shader, vao: u32) -> Game {
    return Game{
        world = world,
        window = window,
        shader = shader,
        vao = vao,
        time = glfw.GetTime(),
        delta_time = 0,
        last_fps_time = glfw.GetTime(),
        frame_count = 0,
    }
}

update_game :: proc(game: ^Game) {
    current_time := glfw.GetTime()
    game.delta_time = current_time - game.time
    game.time = current_time

    game.frame_count += 1

    if current_time - game.last_fps_time >= 1.0 {
        fps := f64(game.frame_count) / (current_time - game.last_fps_time)
        entity_count := len(game.world.entities)
        fmt.printf("FPS: %.1f, Entities: %d\n", fps, entity_count)
        
        game.frame_count = 0
        game.last_fps_time = current_time
    }

    game.world.time += game.delta_time
    game.world.delta_time = game.delta_time
}

spawn_system :: proc(world: ^World) {
    num_entities := 100
    for i in 0..<num_entities {
        if len(world.entities) >= 50000 do break

        e := create_entity(world, {.Transform, .Velocity, .Color})
        set_transform(world, e, Transform{
            position = {rand.float32_range(-4.5, 4.5), rand.float32_range(-4.5, 4.5), 0},
            scale = {rand.float32_range(0.025, 0.05), rand.float32_range(0.025, 0.05)},
            rotation = rand.float32_range(0, 2*math.PI),
        })
        set_velocity(world, e, Velocity{rand.float32_range(-1, 1), rand.float32_range(-1, 1)})
        set_color(world, e, Color{
            r = rand.float32_range(0.5, 255.0),
            g = rand.float32_range(0.5, 255.0),
            b = rand.float32_range(0.5, 255.0),
        })
    }
}

movement_system :: proc(world: ^World) {
    for e, _ in world.entities {
        if e >= Entity(len(world.components.mask)) do continue
        if .Transform in world.components.mask[e] && .Velocity in world.components.mask[e] {
            world.components.transform[e].position.x += world.components.velocity[e].dx * f32(world.delta_time)
            world.components.transform[e].position.y += world.components.velocity[e].dy * f32(world.delta_time)
            
            if abs(world.components.transform[e].position.x) > 5 || abs(world.components.transform[e].position.y) > 5 {
                remove_entity(world, e)
            }
        }
    }
}

color_fade_system :: proc(world: ^World) {
    fade_rate :f32= 100  // Adjust this value to control fade speed
    
    for e, _ in world.entities {
        if e >= Entity(len(world.components.mask)) do continue
        if .Color in world.components.mask[e] {
            color := &world.components.color[e]
            color.r = max(0, color.r - fade_rate * f32(world.delta_time))
            color.g = max(0, color.g - fade_rate * f32(world.delta_time))
            color.b = max(0, color.b - fade_rate * f32(world.delta_time))
            
            // Remove entity if it becomes too dark
            if color.r <= 0.1 && color.g <= 0.1 && color.b <= 0.1 {
                remove_entity(world, e)
            }
        }
    }
}

cleanup_system :: proc(world: ^World) {
    for e in world.entities_to_remove {
        if e in world.entities {
            delete_key(&world.entities, e)
        }
    }
    
    clear(&world.entities_to_remove)
}