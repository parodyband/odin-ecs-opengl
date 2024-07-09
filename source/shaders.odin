package game

import gl "vendor:OpenGL"
import "core:fmt"

VERTEX_SHADER :: `
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in mat4 instanceModelMatrix;
layout (location = 5) in vec3 instanceColor;
out vec3 vertexColor;
uniform mat4 view;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * instanceModelMatrix * vec4(aPos, 1.0);
    vertexColor = instanceColor;
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


Shader :: struct {
    program:       u32,
    transform_loc: i32,
    view_loc:      i32,
    projection_loc: i32,
}

create_shader_program :: proc() -> (shader: Shader, ok: bool) {
    program, program_ok := gl.load_shaders_source(VERTEX_SHADER, FRAGMENT_SHADER)
    if !program_ok {
        fmt.println("Failed to create shader program")
        return
    }

    shader.program = program
    shader.view_loc = gl.GetUniformLocation(program, "view")
    shader.projection_loc = gl.GetUniformLocation(program, "projection")

    if shader.view_loc == -1 || shader.projection_loc == -1 {
        fmt.println("Failed to get uniform locations")
        gl.DeleteProgram(program)
        return
    }

    ok = true
    return
}

delete_shader_program :: proc(shader: ^Shader) {
    gl.DeleteProgram(shader.program)
}

use_shader :: proc(shader: ^Shader) {
    gl.UseProgram(shader.program)
}