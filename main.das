require daslib/media
require daslib/random
require daslib/decs_boost

enum UnitType
    YELLOW //yellow > red
    RED    //red > blue
    BLUE   //blue > yellow

let top_offset = 4
let left_offset = 4
let cell_width = 50U
let cell_height = 50U
let cell_color = 0xFFFF80
var last_cell_number = 0U
let cooldown = 1.0f
let unit_radius = 12U
let unit_cost = 50U

var war_line_width: uint
var ui_line_height: uint

[decs_template]
struct Cell
    image: ImageHandle
    unit_type: UnitType
    unit_color: uint
    cell_number: uint

[decs_template]
struct House
    owner_is_player: bool
    position: float2
    current_cooldown: float

[decs_template]
struct Building
    position: float2
    image: ImageHandle

[decs_template]
struct Unit
    owner_is_player: bool
    unit_type: UnitType
    unit_color: uint

var cells: array <EntityId>
var selected_cell = INVALID_ENTITY_ID

var player_units: array <array <EntityId> >
var bot_units: array <array <EntityId> >
var rules: table <UnitType; int>

var player_building = INVALID_ENTITY_ID
var bot_building = INVALID_ENTITY_ID

var field: array <bool>

var player_value = 50U
var bot_value = 50U
var value_time = 0.0f
let add_value_time = 2.0f
let added_value = 10U

let velocity = 100.0f

var seed: int4

def make_line(x1, y1, x2, y2: int; color: uint)
    create_entity <| @(eid, cmp)
        cmp |> set("eid", eid)
        cmp |> set("x1", x1)
        cmp |> set("y1", y1)
        cmp |> set("x2", x2)
        cmp |> set("y2", y2)
        cmp |> set("color", color)

def make_cell(icon_path: string; unit_type: UnitType; unit_color: uint)
    let cell_eid = create_entity <| @(eid, cmp)
        cmp |> set("eid", eid)
        apply_decs_template(cmp, [[Cell image = create_managed_image(icon_path),
                                        cell_number = last_cell_number++,
                                        unit_type = unit_type,
                                        unit_color = unit_color]])
    push(cells, cell_eid)

def make_house(owner_is_player: bool; position: float2; var cell_eid: EntityId)
    var botY: float
    var rightX: float
    query(cell_eid) <| $(cell: Cell)
        botY = position[1] + float(cell.image.height)
        rightX = position[0] + float(cell.image.width)
    for i in range(position[1], botY)
        for j in range(position[0], rightX)
            if field[i * get_screen_width() + j]
                return
    if owner_is_player
        if player_value < unit_cost
            return
        player_value -= unit_cost
    else
        if bot_value < unit_cost
            return
        bot_value -= unit_cost
    create_entity <| @(eid, cmp)
        cmp |> set("eid", eid)
        cmp |> set("cell_eid", cell_eid)
        apply_decs_template(cmp, [[House owner_is_player = owner_is_player,
                                         position = position,
                                         current_cooldown = cooldown]])
    for i in range(position[1], botY)
        for j in range(position[0], rightX)
            field[i * get_screen_width() + j] = true

def make_building(position: float2; hp: uint; icon_path: string)
    return create_entity <| @(eid, cmp)
        cmp |> set("eid", eid)
        cmp |> set("hp", hp)
        apply_decs_template(cmp, [[Building position = position,
                                            image = create_managed_image(icon_path)]])

def make_field()
    resize(field, get_screen_width() * int(ui_line_height))

def make_units_arrays()
    var len = 0
    let unit_type: UnitType
    for i in each_enum(unit_type)
        ++len
    resize(player_units, len)
    resize(bot_units, len)

def make_unit(owner_is_player: bool; position: float2; unit_type: UnitType; unit_color: uint)
    let unit_eid = create_entity <| @(eid, cmp)
        cmp |> set("eid", eid)
        cmp |> set("unit_aim_from_eid", INVALID_ENTITY_ID)
        cmp |> set("unit_aim_to_eid", INVALID_ENTITY_ID)
        cmp |> set("position", position)
        apply_decs_template(cmp, [[Unit owner_is_player = owner_is_player,
                                        unit_type = unit_type,
                                        unit_color = unit_color]])
    if owner_is_player
        push(player_units[int(unit_type)], unit_eid)
    else
        push(bot_units[int(unit_type)], unit_eid)

[decs(stage = draw)]
def draw_line(x1, y1, x2, y2: int; color: uint)
    line(x1, y1, x2, y2, color)

[decs(stage = draw)]
def draw_cell(cell: Cell)
    rect(int(cell.cell_number) * (left_offset + int(cell_width)),
         int(ui_line_height) + top_offset, int(cell_width),
         int(cell_height), cell_color)
    enable_alpha_blend()
    draw_image(cell.image, int(cell.cell_number) * (left_offset + int(cell_width)) + 1,
               int(ui_line_height) + top_offset + 1)
    disable_alpha_blend()

def draw_selected_cell()
    if selected_cell != INVALID_ENTITY_ID
        enable_alpha_blend()
        let mouse_position = int2(get_mouse_position())
        query(selected_cell) <| $(cell: Cell)
            draw_image(cell.image, mouse_position[0] - int(cell_width / 2U),
                       mouse_position[1] - int(cell_height / 2U))
        disable_alpha_blend()

[decs(stage = draw)]
def draw_house(house: House; cell_eid: EntityId)
    query(cell_eid) <| $(cell: Cell)
        enable_alpha_blend()
        draw_image(cell.image, house.position[0],
            house.position[1])
        disable_alpha_blend()

[decs(stage = draw)]
def draw_unit(unit: Unit; position: float2)
    fill_circle(position[0], position[1], float(unit_radius), unit.unit_color)

[decs(stage = draw)]
def draw_building(building: Building)
    enable_alpha_blend()
    draw_image(building.image, building.position[0], building.position[1])
    disable_alpha_blend()

[export]
def initialize(is_hard_reload: bool)
    randomize_seed(seed)
    if is_hard_reload
        let screen_width = get_screen_width()
        let screen_height = get_screen_height()
        war_line_width = uint(screen_width / 2)
        ui_line_height = uint(screen_height * 2 / 3)
        make_line(0, int(ui_line_height), screen_width, int(ui_line_height), 0xFFFF80)
        make_line(int(war_line_width), 0, int(war_line_width), int(ui_line_height), 0xFFF0000)
        make_cell("yellow.png", UnitType YELLOW, 0xFFFF00)
        make_cell("red.png", UnitType RED, 0xFF0000)
        make_cell("blue.png", UnitType BLUE, 0x0000FF)
        make_field()
        make_units_arrays()
        player_building = make_building(float2(0, int(ui_line_height / 2U) - int(cell_height / 2U)), 50U, "rect.png")
        bot_building = make_building(float2(screen_width - int(cell_width), int(ui_line_height / 2U) - int(cell_height / 2U)),
                      50U, "rect.png")

        rules[UnitType YELLOW] = int(UnitType RED)
        rules[UnitType RED] = int(UnitType BLUE)
        rules[UnitType BLUE] = int(UnitType YELLOW)

def find_enemy(enemy_units: array <EntityId>;
               our_unit_aim_eid: EntityId;
               our_unit_position: float2;
               var enemy_unit_index: int&;
               var len_sq: float&)
    if our_unit_aim_eid != INVALID_ENTITY_ID
        return

    for i in range(length(enemy_units))
        query(enemy_units[i]) <| $(unit_aim_from_eid: EntityId; unit: Unit; position: float2)
            let new_len_sq = length_sq(position - our_unit_position)
            if new_len_sq < len_sq && unit_aim_from_eid == INVALID_ENTITY_ID
                len_sq = new_len_sq
                enemy_unit_index = i

def find_aims(var units: array <EntityId>;
              var enemy_units: array <array <EntityId> >;
              enemy_building_eid: EntityId)
    var i = 0
    for unit_eid in units
        var our_unit_position: float2
        var our_unit_type: UnitType
        var our_unit_aim_eid: EntityId
        var enemy_building_position: float2
        query(unit_eid) <| $(unit_aim_to_eid: EntityId; unit: Unit; position: float2)
            our_unit_position = position
            our_unit_type = unit.unit_type
            our_unit_aim_eid = unit_aim_to_eid
        query(enemy_building_eid) <| $(building: Building)
            enemy_building_position = building.position
        
        var len_sq_for_kill = float(INT_MAX)
        var enemy_unit_index_for_kill = -1
        find_enemy(enemy_units[rules[our_unit_type]], our_unit_aim_eid, our_unit_position, enemy_unit_index_for_kill, len_sq_for_kill)

        var len_sq = float(INT_MAX)
        var enemy_unit_index = -1
        find_enemy(enemy_units[int(our_unit_type)], our_unit_aim_eid, our_unit_position, enemy_unit_index, len_sq)
        
        let len_sq_to_building = length_sq(enemy_building_position - our_unit_position)
        if enemy_unit_index_for_kill != -1 && len_sq_for_kill < len_sq && len_sq_for_kill < len_sq_to_building
            let enemy_eid = enemy_units[rules[our_unit_type]][enemy_unit_index_for_kill]
            query(enemy_eid) <| $(var unit_aim_from_eid: EntityId; position: float2)
                our_unit_position += normalize(position -
                                                  our_unit_position) * velocity * get_delta_time()
                unit_aim_from_eid = unit_eid
            query(unit_eid) <| $(var unit_aim_to_eid: EntityId; var position: float2)
                position = our_unit_position
                unit_aim_to_eid = enemy_eid
        elif enemy_unit_index != -1 && len_sq < len_sq_to_building
            let enemy_eid = enemy_units[int(our_unit_type)][enemy_unit_index]
            query(enemy_eid) <| $(var unit_aim_from_eid: EntityId; position: float2)
                our_unit_position += normalize(position -
                                                  our_unit_position) * velocity * get_delta_time()
                unit_aim_from_eid = unit_eid
            query(unit_eid) <| $(var unit_aim_to_eid: EntityId; var position: float2)
                position = our_unit_position
                unit_aim_to_eid = enemy_eid
        else
            query(unit_eid) <| $(var position: float2)
                position += normalize(enemy_building_position -
                                      position + float2(cell_width / 2U, cell_height / 2U)) * velocity * get_delta_time()
        ++i

[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()

    if get_mouse_button(MB_LEFT)
        let mouse_position = get_mouse_position()
        if int(get_mouse_position()[1]) >= int(ui_line_height)
            query() <| $(cell: Cell; eid: EntityId)
                let cellPosX = int(cell.cell_number) * (left_offset + int(cell_width))
                if (float(cellPosX) <= mouse_position[0] && float(cellPosX +
                    int(cell_width)) >= mouse_position[0] &&
                    float(int(ui_line_height) + top_offset) <= mouse_position[1] &&
                    float(int(ui_line_height) + top_offset + int(cell_height)) >= mouse_position[1])
                    selected_cell = eid
        elif (mouse_position[0] > float(cell_width / 2U) &&
              mouse_position[0] < float(int(war_line_width) - int(cell_width / 2U)) &&
              mouse_position[1] > float(cell_height / 2U) &&
              mouse_position[1] < float(int(ui_line_height) - int(cell_height / 2U)))
            make_house(true, mouse_position -
                       float2(cell_width / 2U, cell_height / 2U),
                       selected_cell)

    if random_int(seed) % 1000 > 995
        let x = random_int(seed) % (get_screen_width() - int(war_line_width) - int(cell_width)) + int(war_line_width) + int(cell_width / 2U)
        let y = random_int(seed) % (int(ui_line_height) - int(cell_height)) + int(cell_height / 2U)
        let cell_index = random_int(seed) % length(cells)
        make_house(false, float2(x, y) - float2(cell_width / 2U, cell_height / 2U),
                   cells[cell_index])

    value_time += dt
    if (value_time - add_value_time > 0.0001f)
        player_value += added_value
        bot_value += added_value
        value_time -= add_value_time
    
    query() <| $(var house: House; cell_eid: EntityId)
        house.current_cooldown -= dt
        house.current_cooldown = clamp(house.current_cooldown - dt, 0.0f, house.current_cooldown)
        if house.current_cooldown < 0.0001f
            query(cell_eid) <| $(cell: Cell)
                make_unit(house.owner_is_player, house.position +
                          float2(cell.image.width / 2, int(cell_height / 2U)),
                          cell.unit_type,
                          cell.unit_color)
            house.current_cooldown = cooldown

    for units in player_units
        find_aims(units, bot_units, bot_building)

    for units in bot_units
        find_aims(units, player_units, player_building)

    for units in player_units
        var i = 0
        while i < length(units)
            var unit_unit_type: UnitType
            var unit_position: float2
            query(units[i]) <| $(unit: Unit; position: float2)
                unit_unit_type = unit.unit_type
                unit_position = position
            var j = 0
            while j < length(bot_units[rules[unit_unit_type]])
                var found = false
                query(bot_units[rules[unit_unit_type]][j]) <| $(position: float2)
                    found = true
                    if length_sq(position - unit_position) < float(unit_radius * unit_radius * 4U)
                        delete_entity(bot_units[rules[unit_unit_type]][j])
                        query() <| $(var unit_aim_from_eid: EntityId;
                                     var unit_aim_to_eid: EntityId)
                            if unit_aim_from_eid == bot_units[rules[unit_unit_type]][j]
                                unit_aim_from_eid = INVALID_ENTITY_ID
                            if unit_aim_to_eid == bot_units[rules[unit_unit_type]][j]
                                unit_aim_to_eid = INVALID_ENTITY_ID
                        erase(bot_units[rules[unit_unit_type]], j)
                    else
                        ++j
                if !found
                    ++j
                ++j
            j = 0
            var need_break = false
            while j < length(bot_units[int(unit_unit_type)])
                var bot_position: float2
                query(bot_units[int(unit_unit_type)][j]) <| $(position: float2)
                    bot_position = position
                if length_sq(bot_position - unit_position) < float(unit_radius * unit_radius * 4U)
                    delete_entity(bot_units[int(unit_unit_type)][j])
                    delete_entity(units[i])
                    query() <| $(var unit_aim_from_eid: EntityId;
                                 var unit_aim_to_eid: EntityId)
                        if unit_aim_from_eid == bot_units[int(unit_unit_type)][j] || unit_aim_from_eid == units[i]
                            unit_aim_from_eid = INVALID_ENTITY_ID
                        if unit_aim_to_eid == bot_units[int(unit_unit_type)][j] || unit_aim_to_eid == units[i]
                            unit_aim_to_eid = INVALID_ENTITY_ID
                    erase(bot_units[int(unit_unit_type)], j)
                    erase(units, i)
                    --i
                    need_break = true
                    break
                else
                    ++j
            if need_break
                ++i
                continue
            query(bot_building) <| $(var building: Building; var hp: uint&)
                if length_sq(building.position - unit_position) < float(unit_radius * unit_radius * 4U)
                    hp -= 1U
                    if hp == 0U
                        schedule_pause()
                    delete_entity(units[i])
                    query() <| $(var unit_aim_from_eid: EntityId;
                                 var unit_aim_to_eid: EntityId)
                        if unit_aim_from_eid == units[i]
                            unit_aim_from_eid = INVALID_ENTITY_ID
                        if unit_aim_to_eid == units[i]
                            unit_aim_to_eid = INVALID_ENTITY_ID
                    erase(units, i)
                    --i
            ++i
    
    for units in bot_units
        var i = 0
        while i < length(units)
            var unit_unit_type: UnitType
            var unit_position: float2
            query(units[i]) <| $(unit: Unit; position: float2)
                unit_unit_type = unit.unit_type
                unit_position = position
            var j = 0
            while j < length(player_units[rules[unit_unit_type]])
                var found = false
                query(player_units[rules[unit_unit_type]][j]) <| $(position: float2)
                    found = true
                    if length_sq(position - unit_position) < float(unit_radius * unit_radius * 4U)
                        delete_entity(player_units[rules[unit_unit_type]][j])
                        query() <| $(var unit_aim_from_eid: EntityId;
                                     var unit_aim_to_eid: EntityId)
                            if unit_aim_from_eid == player_units[rules[unit_unit_type]][j]
                                unit_aim_from_eid = INVALID_ENTITY_ID
                            if unit_aim_to_eid == player_units[rules[unit_unit_type]][j]
                                unit_aim_to_eid = INVALID_ENTITY_ID
                        erase(player_units[rules[unit_unit_type]], j)
                    else
                        ++j
                if !found
                    ++j
                ++j
            j = 0
            var need_break = false
            while j < length(player_units[int(unit_unit_type)])
                var bot_position: float2
                query(player_units[int(unit_unit_type)][j]) <| $(position: float2)
                    bot_position = position
                if length_sq(bot_position - unit_position) < float(unit_radius * unit_radius * 4U)
                    delete_entity(player_units[int(unit_unit_type)][j])
                    delete_entity(units[i])
                    query() <| $(var unit_aim_from_eid: EntityId;
                                 var unit_aim_to_eid: EntityId)
                        if unit_aim_from_eid == player_units[int(unit_unit_type)][j] || unit_aim_from_eid == units[i]
                            unit_aim_from_eid = INVALID_ENTITY_ID
                        if unit_aim_to_eid == player_units[int(unit_unit_type)][j] || unit_aim_to_eid == units[i]
                            unit_aim_to_eid = INVALID_ENTITY_ID
                    erase(player_units[int(unit_unit_type)], j)
                    erase(units, i)
                    --i
                    need_break = true
                    break
                else
                    ++j
            if need_break
                ++i
                continue
            query(player_building) <| $(var building: Building; var hp: uint&)
                if length_sq(building.position - unit_position) < float(unit_radius * unit_radius * 4U)
                    hp -= 1U
                    if hp == 0U
                        schedule_pause()
                    delete_entity(units[i])
                    query() <| $(var unit_aim_from_eid: EntityId;
                                 var unit_aim_to_eid: EntityId)
                        if unit_aim_from_eid == units[i]
                            unit_aim_from_eid = INVALID_ENTITY_ID
                        if unit_aim_to_eid == units[i]
                            unit_aim_to_eid = INVALID_ENTITY_ID
                    erase(units, i)
                    --i
            ++i

[export]
def draw
    decs_stage("draw")
    draw_selected_cell()
    text_out(0, 0, "money: {int(player_value)}", 0xF0F0F0)
    query() <| $(building: Building; hp: uint)
        text_out(building.position[0], building.position[1] - 10.0f, "hp:{int(hp)}", 0xF0F0F0)