require daslib/media
require daslib/decs_boost

struct Position
    x: int
    y: int

let COLLISION_QUAD_SIDE_SIZE = 32
let CIRCLE_RADIUS = COLLISION_QUAD_SIDE_SIZE / 2 - 1

var main_collision_quad = INVALID_ENTITY_ID

[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    if get_mouse_button_down(MB_LEFT)
        query() <| $(var target: Position&)
            target.x = int(get_mouse_position().x)
            target.y = int(get_mouse_position().y)
    decs_stage("move")


[export]
def draw
    decs_stage("draw")


[export]
def initialize(is_hard_reload: bool)
    if is_hard_reload
        let screen_width = get_screen_width()
        let screen_height = get_screen_height()
        let column_count = screen_width / COLLISION_QUAD_SIDE_SIZE
        let row_count = screen_height * 2 / (COLLISION_QUAD_SIDE_SIZE * 3)
        main_collision_quad = create_collision_quad(0, 0, screen_width, screen_height * 2 / 3)
        commit()
        create_collision_quads(main_collision_quad, COLLISION_QUAD_SIDE_SIZE)
        let circle_x = screen_width / 4 + 1
        let circle_y = screen_height / 3 - 15
        let circle = create_circle(circle_x, circle_y, CIRCLE_RADIUS)
        let rects <- find_rects_intersect_circle(circle_x, circle_y, CIRCLE_RADIUS, main_collision_quad)
        for rect in rects
            update_entity(rect) <| @(eid, cmp)
                cmp |> set("fill", true)


[decs(stage = draw, REQUIRE_NOT = fill)]
def draw_quad_grid(x, y, width, height: int; color: uint)
    rect(x, y, width, height, color)

[decs(stage = draw, REQUIRE = fill)]
def draw__fill_quad_grid(x, y, width, height: int; color: uint)
    fill_rect(x, y, width, height, color)


[decs(stage = draw)]
def draw_circle(x, y, radius: int; color: uint)
    fill_circle(x + radius, y + radius, radius, color)


def create_collision_quad(x, y, width, height: int)
    return create_entity <| @(eid, cmp)
        cmp |> set("eid", eid)
        cmp |> set("x", x)
        cmp |> set("y", y)
        cmp |> set("width", width)
        cmp |> set("height", height)
        cmp |> set("color", 0x259C6A)
        cmp |> set("inners", [[array <EntityId>]])


def create_circle(x, y, r: int)
    return create_entity <| @(eid, cmp)
        cmp |> set("eid", eid)
        cmp |> set("x", x)
        cmp |> set("y", y)
        cmp |> set("radius", r)
        cmp |> set("speed", 500.f)
        cmp |> set("target", [[Position x = x, y = y]])
        cmp |> set("color", 0x3877C3)


def create_collision_quads(quad: EntityId; side_size: int)
    var first_quad = INVALID_ENTITY_ID
    var second_quad = INVALID_ENTITY_ID
    query(quad) <| $(x, y, width, height: int; var inners: array <EntityId>)
        if width < height && height > side_size
            let half_height = height / 2
            let top_height = half_height + (half_height % side_size)
            let bottom_height = height - top_height
            first_quad = create_collision_quad(x, y, width, top_height)
            second_quad = create_collision_quad(x, y + top_height, width, bottom_height)
            push(inners, first_quad)
            push(inners, second_quad)
        elif width >= height && width > side_size
            let half_width = width / 2
            let left_width = half_width + (half_width % side_size)
            let right_width = width - left_width
            first_quad = create_collision_quad(x, y, left_width, height)
            second_quad = create_collision_quad(x + left_width, y, right_width, height)
            push(inners, first_quad)
            push(inners, second_quad)
    commit()
    if first_quad != INVALID_ENTITY_ID
        create_collision_quads(first_quad, side_size)
    if second_quad != INVALID_ENTITY_ID
        create_collision_quads(second_quad, side_size)


def circle_intersects_quad(x, y, radius: int; quad: EntityId)
    var quad_x, quad_y, quad_width, quad_height: int
    query(quad) <| $(x, y, width, height: int):bool
        quad_x = x
        quad_y = y
        quad_width = width
        quad_height = height

    let half_quad_width = float(quad_width) * 0.5f
    let half_quad_height = float(quad_height) * 0.5f
    let circle_distance_x = abs(float(x + radius - quad_x) - half_quad_width)
    let circle_distance_y = abs(float(y + radius - quad_y) - half_quad_height)

    if circle_distance_x > half_quad_width + float(radius)
        return false
    if circle_distance_y > half_quad_height + float(radius)
        return false

    if circle_distance_x <= half_quad_width
        return true
    if circle_distance_y <= half_quad_height
        return true

    let distance_x = circle_distance_x - half_quad_width
    let distance_y = circle_distance_y - half_quad_height
    let corner_distance_sq = distance_x * distance_x + distance_y * distance_y
    return corner_distance_sq <= float(radius * radius)


def find_rects_intersect_circle(x, y, radius: int; quad: EntityId)
    var intersected_quads: array <EntityId>
    if circle_intersects_quad(x, y, radius, quad)
        var need_to_check_quads: array <EntityId>
        query(quad) <| $(eid: EntityId; width, height: int; inners: array <EntityId>)
            if width > COLLISION_QUAD_SIDE_SIZE || height > COLLISION_QUAD_SIDE_SIZE
                for inner in inners
                    push(need_to_check_quads, inner)
            else
                push(intersected_quads, eid)
        for need_to_check_quad in need_to_check_quads
            push(intersected_quads, find_rects_intersect_circle(x, y, radius, need_to_check_quad))
    return <- intersected_quads


[decs(stage = move)]
def move_circle(var x, y: int&; speed: float; target: Position)
    let dt = get_delta_time()
    let direction_x = target.x - x
    let direction_y = target.y - y
    let direction_length_sq = direction_x * direction_x + direction_y * direction_y
    let direction_length_sqrt_mult = direction_length_sq == 0? 0.f : 1.f / sqrt(float(direction_length_sq))
    let direction_x_norm = float(direction_x) * direction_length_sqrt_mult
    let direction_y_norm = float(direction_y) * direction_length_sqrt_mult
    x = x + int(speed * dt * direction_x_norm)
    y = y + int(speed * dt * direction_y_norm)
