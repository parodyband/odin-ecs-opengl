package game

import gl "vendor:OpenGL"
import m "core:math/linalg"

MAX_INSTANCES :: 10000

Renderer :: struct {
    vao, vbo, instance_vbo: u32,
    instance_data: [MAX_INSTANCES]InstanceData,
    instance_count: int,
}

InstanceData :: struct {
    model_matrix: m.Matrix4f32,
    color: m.Vector3f32,
}

init_renderer :: proc() -> (renderer: ^Renderer, ok: bool) {
    renderer = new(Renderer)
    
    vertices := [?]f32{
        -0.5, -0.5, 0.0,
         0.5, -0.5, 0.0,
         0.5,  0.5, 0.0,
        -0.5, -0.5, 0.0,
         0.5,  0.5, 0.0,
        -0.5,  0.5, 0.0,
    }

    gl.GenVertexArrays(1, &renderer.vao)
    gl.BindVertexArray(renderer.vao)

    gl.GenBuffers(1, &renderer.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

    gl.GenBuffers(1, &renderer.instance_vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.instance_vbo)
    gl.BufferData(gl.ARRAY_BUFFER, size_of(renderer.instance_data), nil, gl.DYNAMIC_DRAW)

    // Set up instance data attributes
    gl.VertexAttribPointer(1, 4, gl.FLOAT, gl.FALSE, size_of(InstanceData), 0)
    gl.VertexAttribPointer(2, 4, gl.FLOAT, gl.FALSE, size_of(InstanceData), 4 * size_of(f32))
    gl.VertexAttribPointer(3, 4, gl.FLOAT, gl.FALSE, size_of(InstanceData), 8 * size_of(f32))
    gl.VertexAttribPointer(4, 4, gl.FLOAT, gl.FALSE, size_of(InstanceData), 12 * size_of(f32))
    gl.VertexAttribPointer(5, 3, gl.FLOAT, gl.FALSE, size_of(InstanceData), 16 * size_of(f32))

    gl.VertexAttribDivisor(1, 1)
    gl.VertexAttribDivisor(2, 1)
    gl.VertexAttribDivisor(3, 1)
    gl.VertexAttribDivisor(4, 1)
    gl.VertexAttribDivisor(5, 1)

    gl.EnableVertexAttribArray(1)
    gl.EnableVertexAttribArray(2)
    gl.EnableVertexAttribArray(3)
    gl.EnableVertexAttribArray(4)
    gl.EnableVertexAttribArray(5)

    ok = true
    return
}

destroy_renderer :: proc(renderer: ^Renderer) {
    gl.DeleteVertexArrays(1, &renderer.vao)
    gl.DeleteBuffers(1, &renderer.vbo)
    gl.DeleteBuffers(1, &renderer.instance_vbo)
    free(renderer)
}

render_system :: proc(world: ^World, shader: ^Shader, renderer: ^Renderer, width, height: i32) {
    gl.Viewport(0, 0, width, height)
    gl.Clear(gl.COLOR_BUFFER_BIT)
    use_shader(shader)

    aspect_ratio := f32(width) / f32(height)
    scale_factor := 1.0 / max(aspect_ratio, 1.0)

    view := m.MATRIX4F32_IDENTITY
    
    projection := m.matrix_ortho3d_f32(-1.0 * aspect_ratio, 1.0 * aspect_ratio, -1.0, 1.0, -1.0, 1.0)

    gl.UniformMatrix4fv(shader.view_loc, 1, gl.FALSE, &view[0, 0])
    gl.UniformMatrix4fv(shader.projection_loc, 1, gl.FALSE, &projection[0, 0])

    renderer.instance_count = 0

    for e, _ in world.entities {
        if e >= Entity(len(world.components.mask)) do continue
        if .Transform in world.components.mask[e] && .Color in world.components.mask[e] {
            if renderer.instance_count >= MAX_INSTANCES do break

            transform := &world.components.transform[e]
            color := &world.components.color[e]

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

            renderer.instance_data[renderer.instance_count] = InstanceData{
                model_matrix = model_matrix,
                color = {f32(color.r) / 255.0, f32(color.g) / 255.0, f32(color.b) / 255.0},
            }
            renderer.instance_count += 1
        }
    }

    gl.BindBuffer(gl.ARRAY_BUFFER, renderer.instance_vbo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(InstanceData) * renderer.instance_count, &renderer.instance_data[0])

    gl.BindVertexArray(renderer.vao)
    gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, i32(renderer.instance_count))
}
