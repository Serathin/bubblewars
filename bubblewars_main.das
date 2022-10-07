require daslib/media
require daslib/decs_boost

[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

[export]
def draw
    decs_stage("draw")

[export]
def initialize(is_hard_reload: bool)
    if is_hard_reload
        let screen_width = get_screen_width()
        let screen_height = get_screen_height()
        let side_size = 32
        let column_count = screen_width / side_size
        let row_count = screen_height * 2 / (side_size * 3)
        let main_quad = create_entity <| @(eid, cmp)
            cmp |> set("eid", eid)
            cmp |> set("x", 0)
            cmp |> set("y", 0)
            cmp |> set("width", screen_width)
            cmp |> set("height", screen_height * 2 / 3)
            cmp |> set("color", 0xFFFF80)
            cmp |> set("inners", [[array <EntityId>]])
        commit()
        
        create_quads(main_quad, side_size)

[decs(stage = draw)]
def draw_quad_grid(x, y, width, height: int; color: uint)
    line(x, y, x + width, y, color)
    line(x + width, y, x + width, y + height, color)
    line(x, y + height, x + width, y + height, color)
    line(x, y, x, y + height, color)

def create_quads(quad: EntityId; side_size: int)
    var first_quad = INVALID_ENTITY_ID
    var second_quad = INVALID_ENTITY_ID
    query(quad) <| $(x, y, width, height: int; var inners: array <EntityId>)
        if width < height && height > side_size
            let top_height = height / 2
            let bottom_height = height - top_height
            first_quad = create_entity <| @(eid, cmp)
                cmp |> set("eid", eid)
                cmp |> set("x", x)
                cmp |> set("y", y)
                cmp |> set("width", width)
                cmp |> set("height", top_height)
                cmp |> set("color", 0x259C6A)
                cmp |> set("inners", [[array <EntityId>]])
            second_quad = create_entity <| @(eid, cmp)
                cmp |> set("eid", eid)
                cmp |> set("x", x)
                cmp |> set("y", y + top_height)
                cmp |> set("width", width)
                cmp |> set("height", bottom_height)
                cmp |> set("color", 0x259C6A)
                cmp |> set("inners", [[array <EntityId>]])
            push(inners, first_quad)
            push(inners, second_quad)
        elif width >= height && width > side_size
            let left_width = width / 2
            let right_width = width - left_width
            first_quad = create_entity <| @(eid, cmp)
                cmp |> set("eid", eid)
                cmp |> set("x", x)
                cmp |> set("y", y)
                cmp |> set("width", left_width)
                cmp |> set("height", height)
                cmp |> set("color", 0x259C6A)
                cmp |> set("inners", [[array <EntityId>]])
            second_quad = create_entity <| @(eid, cmp)
                cmp |> set("eid", eid)
                cmp |> set("x", x + left_width)
                cmp |> set("y", y)
                cmp |> set("width", right_width)
                cmp |> set("height", height)
                cmp |> set("color", 0x259C6A)
                cmp |> set("inners", [[array <EntityId>]])
            push(inners, first_quad)
            push(inners, second_quad)
    commit()
    if first_quad != INVALID_ENTITY_ID
        create_quads(first_quad, side_size)
    if second_quad != INVALID_ENTITY_ID
        create_quads(second_quad, side_size)
