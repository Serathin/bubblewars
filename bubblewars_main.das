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
        for i in range(row_count)
            for j in range(column_count)
                create_entity <| @(eid, cmp)
                    cmp |> set("eid", eid)
                    cmp |> set("x", j * side_size)
                    cmp |> set("y", i * side_size)
                    cmp |> set("width", side_size)
                    cmp |> set("height", side_size)
                    cmp |> set("color", 0xFFFF80)
                    cmp |> set("inners", [[array <EntityId>]])

[decs(stage = draw)]
def draw_quad_grid(x, y, width, height: int; color: uint)
    line(x, y, x + width, y, color)
    line(x + width, y, x + width, y + height, color)
    line(x, y + height, x + width, y + height, color)
    line(x, y, x, y + height, color)