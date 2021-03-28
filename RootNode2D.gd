"""Simple implementation of Conway's Game of Life.

Leland E. Vakarian
27 March, 2021
"""

extends Node2D


## Globals


var EDIT_MODE = false
"""Tracks whether the simulation is in edit mode, which allows users to set initial state of
cells.
"""

var MAX_COORDS = null
"""Tracks the maximum cell coordinates of the grid, based on the viewport size. Initialized by
_ready().
"""

var GRID = []
"""Tracks the state of the cells in the grid, initialized by _ready()."""

var SPEED = 1
"""Number of processed generations per second, defaults to 1."""

var TIMER = null
"""Regulates the frequency of generation iterations, initialized by _ready()."""


## Init


func _ready():
    """Initialization entrypoint."""

    # show pause menu on init
    self.get_node("MenuPanel").show()
    print("[DEBUG] EDIT_MODE is " + str(EDIT_MODE))

    # get viewport
    MAX_COORDS = pos2cell(get_viewport().size)
    print("[DEBUG] MAX_CELL_COORDS = ", MAX_COORDS)

    init_cell_states()

    # initialize the timer
    TIMER = Timer.new()
    add_child(TIMER)
    TIMER.connect("timeout", self, "iterate")
    TIMER.set_wait_time(1.0/SPEED)
    TIMER.set_one_shot(false) # Make sure it loops


## Utility Functions


func iterate():
    """Processes all cells to proceed to the next generation."""

    print("[DEBUG] Updating grid.")

    # The update matrix holds the next generation so the current generation isn't polluted by
    # updates in the middle of processing.
    var update_matrix = []
    for _i in range(MAX_COORDS.x):
        var row = []
        for _j in range(MAX_COORDS.y):
            row.append(false)
        update_matrix.append(row)

    for i in range(MAX_COORDS.x):
        for j in range(MAX_COORDS.y):
            update_matrix[i][j] = process_cell(i, j)

    GRID = update_matrix
    update_tiles()


func init_cell_states():
    """Initializes the grid by setting all cells to the dead state."""
    GRID = []
    for _i in range(MAX_COORDS.x):
        var row = []
        for _j in range(MAX_COORDS.y):
            row.append(false)
        GRID.append(row)
    print("[DEBUG] Grid initialized.")
    update_tiles()


func pos2cell(position):
    """Converts a position from a mouse event into cell coordinates.

    Args:
        position (Vector2): the mouse event's position.

    Returns:
        Vector2: the coordinates of the cell the event occurred within..
    """

    assert(position is Vector2)
    return Vector2(int(position.x)/16, int(position.y)/16)


func process_cell(row, col):
    """Determines what a cell's state should be in the next generation.

    Rules:
        - If a live cell has 2 or 3 neighbors, it stays alive. Otherwise, it dies.
        - If a dead cell has 3 live neighbors, it becomes alive. Otherwise, it stays dead.
        - 'Neighbors' refers to the 8 cells surrounding a given cell.
        - Cells outside the bounds of the grid are imaginary, and are considered dead.

    Args:
        row (int): the row index in the ``GRID``.
        col (int): the column index in the ``GRID``.

    Returns:
        bool: ``true`` if the state should be alive, or ``false`` if not.
    """

    var num_alive = 0
    var cell = GRID[row][col]

    for i in [row-1, row, row+1,]:

        if i < 0 or i >= MAX_COORDS.x:
            continue

        for j in [col-1, col, col+1,]:

            if j < 0 or j >= MAX_COORDS.y:
                continue

            if i == row and j == col:
                continue

            if GRID[i][j]:
                num_alive += 1

    if cell and num_alive in [2, 3,]:
        return true
    elif not cell and num_alive == 3:
        return true
    else:
        return false


func set_start():
    """Sets the state of the simulation to running."""

    TIMER.start()

    self.get_node("MenuPanel").hide()

    if EDIT_MODE:
        print("[DEBUG] EDIT_MODE: " + str(EDIT_MODE) + " -> " + str(not EDIT_MODE))
    EDIT_MODE = false

    self.get_node("MenuPanel/VBoxContainer/ButtonEdit").text = "Edit"
    self.get_node("MenuPanel/VBoxContainer/ButtonStart").text = "Stop"


func set_stop():
    """Sets the state of the simulation to stopped."""

    TIMER.stop()
    self.get_node("MenuPanel/VBoxContainer/ButtonStart").text = "Start"


func toggle_cell_state(coords):
    """Toggles the cell's state (alive or dead). Used in Edit mode to set states via MouseEvent.

    Args:
        coords (Vector2): the coordinates of the cell to toggle.
    """

    assert(coords.x >= 0, "X coord too small: " + str(coords.x))
    assert(coords.y >= 0, "Y coord too small: " + str(coords.y))
    assert(coords.x < MAX_COORDS.x, "X coord too big: " + str(coords.x))
    assert(coords.y < MAX_COORDS.y, "Y coord too big: " + str(coords.y))

    GRID[coords.x][coords.y] = not GRID[coords.x][coords.y]
    print(
        "[DEBUG] Toggled state of cell at ",
        str(coords),
        " from ",
        str(not GRID[coords.x][coords.y]),
        " to ",
        GRID[coords.x][coords.y]
    )
    update_tile(coords.x, coords.y)


func update_tiles():
    """Updates the entire tilemap to the current state of ``GRID``."""

    for i in range(MAX_COORDS.x):
        for j in range(MAX_COORDS.y):
            update_tile(i, j)


func update_tile(row, col):
    """Updates the tile in the tilemap at the given indices.

    Args:
        row (int): the x coord of the tile to update.
        col (int): the y coord of the tile to update.
    """

    # set_cell() takes indices of the cell in the tilemap as the first two arguments and the index
    # of the tile sprite in the tileset to apply. In this case, `0` refers to the alive cell sprite
    # and `1` refers to the dead cell sprite.
    self.get_node("TileMap").set_cell(row, col, 0 if GRID[row][col] else 1)


func _input(event):
    """Catch-all function for handling or routing Events.

    Args:
        event (InputEvent): any InputEvent (or its descendants).
    """

    # toggle pause menu on pressing escape key
    if event is InputEventKey and event.pressed:
        if event.scancode == KEY_ESCAPE:
            if self.get_node("MenuPanel").is_visible():
                self.get_node("MenuPanel").hide()
            else:
                self.get_node("MenuPanel").show()

    # handle mouse clicks when in edit mode
    elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
        if not self.get_node("MenuPanel").is_visible() and EDIT_MODE:

            print("[DEBUG] Got mouse click in edit mode at ", event.position)
            toggle_cell_state(pos2cell(event.position))


## Button Controls


func _on_ButtonStart_pressed():
    """Starts or stops the simulation."""

    set_start() if TIMER.is_stopped() else set_stop()


func _on_ButtonEdit_pressed():
    """Toggle edit mode, and hide the menu panel if edit mode is turned on."""

    set_stop()

    EDIT_MODE = not EDIT_MODE

    if EDIT_MODE:
        self.get_node("MenuPanel").hide()
        self.get_node("MenuPanel/VBoxContainer/ButtonEdit").text = "Stop Editing"
    else:
        self.get_node("MenuPanel/VBoxContainer/ButtonEdit").text = "Edit"


func _on_ButtonClear_pressed():
    """Reinitialized grid to the default state."""

    set_stop()
    init_cell_states()


func _on_ButtonQuit_pressed():
    """Gracefully quit the game."""
    get_tree().quit()


func _on_CheckBoxFast_toggled(button_pressed):
    """Toggles the speed of the iteration process.

    Args:
        button_pressed (bool): if ``true``, sets the speed to 'fast'. Otherwise, sets it to 'slow'.
    """

    if button_pressed:
        SPEED = 4
    else:
        SPEED = 1

    TIMER.set_wait_time(1.0/SPEED)
    print("[DEBUG] SPEED set to ", str(SPEED))

