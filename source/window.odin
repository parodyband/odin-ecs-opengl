package game

import "vendor:glfw"
import gl "vendor:OpenGL"
import "core:fmt"
import "base:runtime"

TITLE :: "ECS Sprite Renderer"

Window :: struct {
    handle: glfw.WindowHandle,
    width:  i32,
    height: i32,
}

init_window :: proc() -> (window: Window, ok: bool) {
    if !glfw.Init() {
        fmt.println("Failed to initialize GLFW")
        return
    }

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    window.handle = glfw.CreateWindow(800, 600, TITLE, nil, nil)
    if window.handle == nil {
        fmt.println("Failed to create GLFW window")
        return
    }

    glfw.MakeContextCurrent(window.handle)
    gl.load_up_to(3, 3, glfw.gl_set_proc_address)

    glfw.SetFramebufferSizeCallback(window.handle, framebuffer_size_callback)

    window.width, window.height = glfw.GetFramebufferSize(window.handle)
    ok = true
    return
}

destroy_window :: proc(window: ^Window) {
    glfw.DestroyWindow(window.handle)
    glfw.Terminate()
}

framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
    context = runtime.default_context()
    gl.Viewport(0, 0, width, height)
}

update_window :: proc(window: ^Window) {
    glfw.SwapBuffers(window.handle)
    glfw.PollEvents()
    window.width, window.height = glfw.GetFramebufferSize(window.handle)
}

window_should_close :: proc(window: ^Window) -> bool {
    return bool(glfw.WindowShouldClose(window.handle))
}