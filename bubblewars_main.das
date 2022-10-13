require daslib/media
require daslib/decs_boost

options debugger
require daslib/debug

let COLLISION_QUAD_SIDE_SIZE = 32
let CIRCLE_RADIUS = float(COLLISION_QUAD_SIDE_SIZE / 2 - 1)

var main_collision_quad = INVALID_ENTITY_ID

[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    if get_mouse_button_down(MB_LEFT)
        query() <| $(var target: float2&)
            target = get_mouse_position()
    decs_stage("move")


[export]
def draw
    decs_stage("draw")


[export]
def initialize(is_hard_reload: bool)
    if is_hard_reload
        let screen_width = get_screen_width()
        let screen_height = get_screen_height()
        main_collision_quad = create_collision_quad(0, 0, screen_width, screen_height * 2 / 3)
        commit()
        create_collision_quads(main_collision_quad, COLLISION_QUAD_SIDE_SIZE)
        let circle_x = float(screen_width / 4 + 1)
        let circle_y = float(screen_height / 3 - 15)
        let circle = create_circle(circle_x, circle_y, CIRCLE_RADIUS)
        let rects <- find_rects_intersect_circle(float2(circle_x, circle_y), CIRCLE_RADIUS, main_collision_quad)
        for rect in rects
            update_entity(rect) <| @(eid, cmp)
                cmp |> set("fill", true)
        commit()
        query(circle) <| $(var inners: array <EntityId>)
            inners |> push(rects)


[decs(stage = draw, REQUIRE_NOT = fill)]
def draw_quad_grid(x, y, width, height: int; color: uint)
    rect(x, y, width, height, color)

[decs(stage = draw, REQUIRE = fill)]
def draw__fill_quad_grid(x, y, width, height: int; color: uint)
    fill_rect(x, y, width, height, color)


[decs(stage = draw)]
def draw_circle(position: float2; radius: float; color: uint)
    fill_circle(position.x + radius, position.y + radius, radius, color)


def create_collision_quad(x, y, width, height: int)
    return create_entity <| @(eid, cmp)
        cmp |> set("eid", eid)
        cmp |> set("x", x)
        cmp |> set("y", y)
        cmp |> set("width", width)
        cmp |> set("height", height)
        cmp |> set("color", 0x259C6A)
        cmp |> set("inners", [[array <EntityId>]])


def create_circle(x, y, r: float)
    return create_entity <| @(eid, cmp)
        cmp |> set("eid", eid)
        cmp |> set("position", [[float2 x = x, y = y]])
        cmp |> set("radius", r)
        cmp |> set("speed", 500.f)
        cmp |> set("target", [[float2 x = x, y = y]])
        cmp |> set("color", 0x3877C3)
        cmp |> set("inners", [[array <EntityId>]])


def create_collision_quads(quad: EntityId; side_size: int)
    var first_quad = INVALID_ENTITY_ID
    var second_quad = INVALID_ENTITY_ID
    var quad_inners : array <EntityId>
    var quad_x, quad_y, quad_width, quad_height: int
    query(quad) <| $(x, y, width, height: int)
        quad_x = x
        quad_y = y
        quad_width = width
        quad_height = height
    if quad_width < quad_height && quad_height > side_size
        let half_height = quad_height / 2
        let r = half_height % side_size
        let top_height = half_height + (r == 0? 0 : side_size - r)
        let bottom_height = quad_height - top_height
        first_quad = create_collision_quad(quad_x, quad_y, quad_width, top_height)
        second_quad = create_collision_quad(quad_x, quad_y + top_height, quad_width, bottom_height)
        commit()
        quad_inners |> push(first_quad)
        quad_inners |> push(second_quad)
    elif quad_width >= quad_height && quad_width > side_size
        let half_width = quad_width / 2
        let r = half_width % side_size
        let left_width = half_width + (r == 0? 0 : side_size - r)
        let right_width = quad_width - left_width
        first_quad = create_collision_quad(quad_x, quad_y, left_width, quad_height)
        second_quad = create_collision_quad(quad_x + left_width, quad_y, right_width, quad_height)
        commit()
        quad_inners |> push(first_quad)
        quad_inners |> push(second_quad)
    query(quad) <| $(var inners: array <EntityId>)
        inners |> push(quad_inners)
    if first_quad != INVALID_ENTITY_ID
        create_collision_quads(first_quad, side_size)
    if second_quad != INVALID_ENTITY_ID
        create_collision_quads(second_quad, side_size)


def circle_intersects_quad(position: float2; radius: float; quad: EntityId)
    var quad_x, quad_y, quad_width, quad_height: int
    query(quad) <| $(x, y, width, height: int)
        quad_x = x
        quad_y = y
        quad_width = width
        quad_height = height

    let half_quad_width = float(quad_width) * 0.5f
    let half_quad_height = float(quad_height) * 0.5f
    let circle_distance_x = abs(position.x + radius - float(quad_x) - half_quad_width)
    let circle_distance_y = abs(position.y + radius - float(quad_y) - half_quad_height)

    if circle_distance_x > half_quad_width + radius
        return false
    if circle_distance_y > half_quad_height + radius
        return false

    if circle_distance_x <= half_quad_width
        return true
    if circle_distance_y <= half_quad_height
        return true

    let distance_x = circle_distance_x - half_quad_width
    let distance_y = circle_distance_y - half_quad_height
    let corner_distance_sq = distance_x * distance_x + distance_y * distance_y

    return corner_distance_sq <= radius * radius


def find_rects_intersect_circle(position: float2; radius: float; quad: EntityId)
    var intersected_quads: array <EntityId>
    if circle_intersects_quad(position, radius, quad)
        var need_to_check_quads: array <EntityId>
        query(quad) <| $(eid: EntityId; width, height: int; inners: array <EntityId>)
            if width > COLLISION_QUAD_SIDE_SIZE || height > COLLISION_QUAD_SIDE_SIZE
                for inner in inners
                    push(need_to_check_quads, inner)
            else
                push(intersected_quads, eid)
        for need_to_check_quad in need_to_check_quads
            push(intersected_quads, find_rects_intersect_circle(position, radius, need_to_check_quad))
    return <- intersected_quads


[decs(stage = move)]
def move_circle(eid: EntityId; var position: float2&; radius: float; speed: float; target: float2; var inners: array <EntityId>)
    let dt = get_delta_time()
    let direction_x = target.x - position.x + radius
    let direction_y = target.y - position.y + radius
    if abs(direction_x) < 1e-5 && abs(direction_y) < 1e-5
        return
    let direction_length_sq = direction_x * direction_x + direction_y * direction_y
    let direction_length_sqrt_mult = direction_length_sq == 0.f? 0.f : 1.f / sqrt(direction_length_sq)
    let direction_x_norm = float(direction_x) * direction_length_sqrt_mult
    let direction_y_norm = float(direction_y) * direction_length_sqrt_mult
    if abs(speed * dt * direction_x_norm) > abs(direction_x)
        position.x = target.x
    else
        position.x = position.x + speed * dt * direction_x_norm
    if abs(speed * dt * direction_y_norm) > abs(direction_y)
        position.y = target.y
    else
        position.y = position.y + speed * dt * direction_y_norm
    for inner in inners
        query(inner) <| $(var inners: array <EntityId>)
            for i in range(length(inners))
                if inners[i] == eid
                    inners |> erase(i)
                    break
        update_entity(inner) <| @(eid, cmp)
            cmp |> remove("fill")
    inners |> clear()
    let rects <- find_rects_intersect_circle(position, radius, main_collision_quad)
    for rect in rects
        update_entity(rect) <| @(eid, cmp)
            cmp |> set("fill", true)
    inners |> push(rects)
