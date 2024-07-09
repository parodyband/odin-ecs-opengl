package main

import "core:fmt"
import "vendor:glfw"
import gl "vendor:OpenGL"

import game "source"

main :: proc() {
    window, window_ok := game.init_window()
    if !window_ok {
        fmt.println("Failed to initialize window")
        return
    }
    defer game.destroy_window(&window)

    shader, shader_ok := game.create_shader_program()
    if !shader_ok {
        fmt.println("Failed to create shader program")
        return
    }
    defer game.delete_shader_program(&shader)

    renderer, renderer_ok := game.init_renderer()
    if !renderer_ok {
        fmt.println("Failed to initialize renderer")
        return
    }
    defer game.destroy_renderer(renderer)

    world := game.init_world()
    defer game.destroy_world(&world)

    game_instance := game.init_game(&world, &window, &shader, renderer.vao)

    systems := []game.System{
        {"Spawn", game.spawn_system},
        {"Movement", game.movement_system},
        {"Color Fade", game.color_fade_system},
        {"Cleanup", game.cleanup_system},
    }

    for !game.window_should_close(&window) {
        game.update_game(&game_instance)

        for system in systems {
            system.update(&world)
        }

        game.render_system(&world, &shader, renderer, window.width, window.height)

        game.update_window(&window)
    }
}
