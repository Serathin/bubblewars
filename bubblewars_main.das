require daslib/media
require daslib/decs_boost

//options debugger
//require daslib/debug

let COLLISION_QUAD_SIDE_SIZE = 32
let CIRCLE_RADIUS = float(COLLISION_QUAD_SIDE_SIZE / 2 - 1)

var collision_quads: array <array <EntityId> >
var collision_grid_height: int
var collision_grid_width: int

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
        collision_grid_width = screen_width
        collision_grid_height = screen_height * 2 / 3
        create_collision_quads()
        let circle_x = float(screen_width / 4 + 1)
        let circle_y = float(screen_height / 3 - 15)
        let circle = create_circle(circle_x, circle_y, CIRCLE_RADIUS)
        let rects <- find_rects_intersect_circle(float2(circle_x, circle_y), CIRCLE_RADIUS)
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


def create_collision_quads()
    let rows = collision_grid_height / COLLISION_QUAD_SIDE_SIZE
    let columns = collision_grid_width / COLLISION_QUAD_SIDE_SIZE
    let additional_row = collision_grid_height % COLLISION_QUAD_SIDE_SIZE > 0 ? 1 : 0
    let additional_column = collision_grid_width % COLLISION_QUAD_SIDE_SIZE > 0 ? 1 : 0
    collision_quads |> resize(rows + additional_row)
    for i in range(rows)
        collision_quads[i] |> reserve(columns + additional_column)
        let y = i * COLLISION_QUAD_SIDE_SIZE
        for j in range(columns)
            collision_quads[i] |> push(create_collision_quad(j * COLLISION_QUAD_SIDE_SIZE,
                                                             y,
                                                             COLLISION_QUAD_SIDE_SIZE,
                                                             COLLISION_QUAD_SIDE_SIZE))
    commit()


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


def find_rects_intersect_circle(position: float2; radius: float)
    var intersected_quads: array <EntityId>
    let row = length(collision_quads) * int(position.y) / (collision_grid_height + (COLLISION_QUAD_SIDE_SIZE - collision_grid_height % COLLISION_QUAD_SIDE_SIZE)) + 1
    let column = length(collision_quads[row]) * int(position.x) / (collision_grid_width + (COLLISION_QUAD_SIDE_SIZE - collision_grid_width % COLLISION_QUAD_SIDE_SIZE)) + 1
    for i in range(-1, 2)
        for j in range(-1, 2)
            if (row + i < length(collision_quads) &&
                row + i >= 0 &&
                column + j < length(collision_quads[row + i]) &&
                column + j >= 0)
                if circle_intersects_quad(position, radius, collision_quads[row + i][column + j])
                    intersected_quads |> push(collision_quads[row + i][column + j])
    return <- intersected_quads


[decs(stage = move)]
def move_circle(eid: EntityId; var position: float2&; radius: float; speed: float; target: float2; var inners: array <EntityId>)
    let dt = get_delta_time()
    let direction_x = target.x - position.x - radius
    let direction_y = target.y - position.y - radius
    if abs(direction_x) < 1e-5 && abs(direction_y) < 1e-5
        return
    let direction_length_sq = direction_x * direction_x + direction_y * direction_y
    let direction_length_sqrt_mult = direction_length_sq == 0.f? 0.f : 1.f / sqrt(direction_length_sq)
    let direction_x_norm = float(direction_x) * direction_length_sqrt_mult
    let direction_y_norm = float(direction_y) * direction_length_sqrt_mult
    if abs(speed * dt * direction_x_norm) > abs(direction_x)
        position.x = target.x - radius
    else
        position.x = position.x + speed * dt * direction_x_norm
    if abs(speed * dt * direction_y_norm) > abs(direction_y)
        position.y = target.y - radius
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
    let rects <- find_rects_intersect_circle(position, radius)
    for rect in rects
        update_entity(rect) <| @(eid, cmp)
            cmp |> set("fill", true)
    inners |> push(rects)
