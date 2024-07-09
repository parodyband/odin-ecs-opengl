package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:time"
import gl "vendor:OpenGL"
import "vendor:glfw"
import m "core:math/linalg"
import "base:runtime"

TITLE :: "ECS Sprite Renderer"

VERTEX_SHADER :: `
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
out vec3 vertexColor;
uniform mat4 transform;
uniform vec3 spriteColor;
void main() {
    gl_Position = transform * vec4(aPos, 1.0);
    vertexColor = spriteColor;
}
`

FRAGMENT_SHADER :: `
#version 330 core
in vec3 vertexColor;
out vec4 FragColor;
void main() {
    FragColor = vec4(vertexColor, 1.0);
}
`

Entity :: distinct int

ComponentFlag :: enum u32 {
    Transform,
    Velocity,
    Color,
}

ComponentMask :: bit_set[ComponentFlag]

Components :: struct {
    mask:      [dynamic]ComponentMask,
    transform: [dynamic]Transform,
    velocity:  [dynamic]Velocity,
    color:     [dynamic]Color,
}

Transform :: struct { 
    position: m.Vector3f32,
    scale:    m.Vector2f32,
    rotation: f32,
}
Velocity :: struct { dx, dy: f32 }
Color    :: struct { r, g, b: f32 }

World :: struct {
    components:         Components,
    next_entity:        Entity,
    entities:           map[Entity]bool,
    entities_to_remove: [dynamic]Entity,
    time:               f64,
    delta_time:         f64,
}

System :: struct {
    name:   string,
    update: proc(world: ^World),
}

create_entity :: proc(w: ^World, mask: ComponentMask) -> Entity {
    e := w.next_entity
    w.next_entity += 1

    append(&w.components.mask, mask)
    w.entities[e] = true

    if .Transform in mask do append(&w.components.transform, Transform{})
    if .Velocity  in mask do append(&w.components.velocity, Velocity{})
    if .Color     in mask do append(&w.components.color, Color{})

    return e
}

remove_entity :: proc(w: ^World, e: Entity) {
    append(&w.entities_to_remove, e)
}

set_transform :: proc(w: ^World, e: Entity, t: Transform) {
    if .Transform not_in w.components.mask[e] {
        w.components.mask[e] += {.Transform}
        append(&w.components.transform, t)
    } else {
        w.components.transform[e] = t
    }
}

set_velocity :: proc(w: ^World, e: Entity, v: Velocity) {
    if .Velocity not_in w.components.mask[e] {
        w.components.mask[e] += {.Velocity}
        append(&w.components.velocity, v)
    } else {
        w.components.velocity[e] = v
    }
}

set_color :: proc(w: ^World, e: Entity, c: Color) {
    if .Color not_in w.components.mask[e] {
        w.components.mask[e] += {.Color}
        append(&w.components.color, c)
    } else {
        w.components.color[e] = c
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

render_system :: proc(world: ^World, program: u32, vao: u32, transform_loc: i32, color_loc: i32, width, height: i32) {
    gl.Viewport(0, 0, width, height)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    gl.UseProgram(program)

    aspect_ratio := f32(width) / f32(height)
    scale_factor := 1.0 / max(aspect_ratio, 1.0)

    for e, _ in world.entities {
        if e >= Entity(len(world.components.mask)) do continue
        if .Transform in world.components.mask[e] && .Color in world.components.mask[e] {
            transform := world.components.transform[e]
            color := world.components.color[e]

            position := transform.position
            if aspect_ratio > 1.0 {
                position.x *= scale_factor
            } else {
                position.y *= scale_factor
            }

            translate_mat := m.matrix4_translate_f32(position)
            rotate_mat := m.matrix4_rotate_f32(transform.rotation, {0, 0, 1})
            scale_mat := m.matrix4_scale_f32({transform.scale.x * scale_factor, transform.scale.y * scale_factor, 1})

            model_matrix := m.matrix_mul(translate_mat, m.matrix_mul(rotate_mat, scale_mat))

            gl.UniformMatrix4fv(transform_loc, 1, gl.FALSE, &model_matrix[0, 0])
            gl.Uniform3f(color_loc, 
                         f32(color.r) / 255.0, 
                         f32(color.g) / 255.0, 
                         f32(color.b) / 255.0)

            gl.BindVertexArray(vao)
            gl.DrawArrays(gl.TRIANGLES, 0, 6)
        }
    }
}

spawn_system :: proc(world: ^World) {
    num_entities := 10 // Reduced for testing
    for i in 0..<num_entities {
        if len(world.entities) >= 10000 do break

        e := create_entity(world, {.Transform, .Velocity, .Color})
        set_transform(world, e, Transform{
            position = {rand.float32_range(-4.5, 4.5), rand.float32_range(-4.5, 4.5), 0},
            scale = {rand.float32_range(0.05, 0.15), rand.float32_range(0.05, 0.15)},
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

cleanup_system :: proc(world: ^World) {
    for e in world.entities_to_remove {
        if e in world.entities {
            delete_key(&world.entities, e)
        }
    }
    
    clear(&world.entities_to_remove)
}

framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    context = runtime.default_context()
    gl.Viewport(0, 0, width, height)
}

main :: proc() {
    if !glfw.Init() {
        fmt.println("Failed to initialize GLFW")
        return
    }
    defer glfw.Terminate()

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    window := glfw.CreateWindow(800, 600, TITLE, nil, nil)
    if window == nil {
        fmt.println("Failed to create GLFW window")
        return
    }
    defer glfw.DestroyWindow(window)

    glfw.MakeContextCurrent(window)
    gl.load_up_to(3, 3, glfw.gl_set_proc_address)

    glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)

    program, program_ok := gl.load_shaders_source(VERTEX_SHADER, FRAGMENT_SHADER)
    if !program_ok {
        fmt.println("Failed to create shader program")
        return
    }
    defer gl.DeleteProgram(program)

    transform_loc := gl.GetUniformLocation(program, "transform")
    color_loc := gl.GetUniformLocation(program, "spriteColor")
    if transform_loc == -1 || color_loc == -1 {
        fmt.println("Failed to get uniform locations")
        return
    }

    vertices := [?]f32{
        -0.5, -0.5, 0.0,  1.0, 1.0, 1.0,
         0.5, -0.5, 0.0,  1.0, 1.0, 1.0,
         0.5,  0.5, 0.0,  1.0, 1.0, 1.0,
        -0.5, -0.5, 0.0,  1.0, 1.0, 1.0,
         0.5,  0.5, 0.0,  1.0, 1.0, 1.0,
        -0.5,  0.5, 0.0,  1.0, 1.0, 1.0,
    }

    vao: u32
    gl.GenVertexArrays(1, &vao)
    defer gl.DeleteVertexArrays(1, &vao)
    gl.BindVertexArray(vao)

    vbo: u32
    gl.GenBuffers(1, &vbo)
    defer gl.DeleteBuffers(1, &vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 3 * size_of(f32))
    gl.EnableVertexAttribArray(1)

    world := World{
        components = Components{
            mask      = make([dynamic]ComponentMask),
            transform = make([dynamic]Transform),
            velocity  = make([dynamic]Velocity),
            color     = make([dynamic]Color),
        },
        next_entity = 0,
        entities = make(map[Entity]bool),
        entities_to_remove = make([dynamic]Entity),
        time = glfw.GetTime(),
        delta_time = 0,
    }
    defer {
        delete(world.components.mask)
        delete(world.components.transform)
        delete(world.components.velocity)
        delete(world.components.color)
        delete(world.entities)
        delete(world.entities_to_remove)
    }

    systems := []System{
        {"Spawn", spawn_system},
        {"Movement", movement_system},
        {"Color Fade", color_fade_system},
        {"Cleanup", cleanup_system},
    }

    last_frame_time := glfw.GetTime()
    frame_count := 0
    last_fps_print_time := last_frame_time

    for !glfw.WindowShouldClose(window) {
        current_time := glfw.GetTime()
        world.delta_time = current_time - last_frame_time
        world.time += world.delta_time
        last_frame_time = current_time

        frame_count += 1

        if current_time - last_fps_print_time >= 1.0 {
            fps := f64(frame_count) / (current_time - last_fps_print_time)
            entity_count := len(world.entities)
            fmt.printf("FPS: %.1f, Entities: %d\n", fps, entity_count)
            
            frame_count = 0
            last_fps_print_time = current_time
        }

        for system in systems {
            system.update(&world)
        }

        width, height := glfw.GetFramebufferSize(window)
        render_system(&world, program, vao, transform_loc, color_loc, i32(width), i32(height))

        glfw.SwapBuffers(window)
        glfw.PollEvents()
    }
}