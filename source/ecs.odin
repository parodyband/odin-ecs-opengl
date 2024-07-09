package game

import m "core:math/linalg"

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

Color :: struct { r, g, b: f32 }

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

init_world :: proc() -> World {
    return World{
        components = Components{
            mask      = make([dynamic]ComponentMask),
            transform = make([dynamic]Transform),
            velocity  = make([dynamic]Velocity),
            color     = make([dynamic]Color),
        },
        next_entity = 0,
        entities = make(map[Entity]bool),
        entities_to_remove = make([dynamic]Entity),
        time = 0,
        delta_time = 0,
    }
}

destroy_world :: proc(w: ^World) {
    delete(w.components.mask)
    delete(w.components.transform)
    delete(w.components.velocity)
    delete(w.components.color)
    delete(w.entities)
    delete(w.entities_to_remove)
}