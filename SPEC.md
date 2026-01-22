# Macos Smart Sequencer

## core
target user scenario: automate an action

example:
in video stabilizing software user does a loop of actions that it repetitive
1. right arrow press
2. click a button (opens a dropdown)
3. click a dropdown item (new page opens)
4. click another button (opens a progress bar modal, autocloses)
5. click another button (switches tabs)
6. click another button (starts processing, progress bar runs until it's green)
7. end

in the example there are actions and transitions
action = click/keypress
transition = a condition when to start the next action

actions:
- click (coordinates, LMB/RMB)
- keypress ([mod]+key)

transition condition can be:
- delay (time spent)
- pixel state (color of a single pixel on the screen by coordinates x/y) (has a threshold for comparison - how different the color can be)
- pixel zone (if a zone of pixels contains at least one pixel of particular color, to account for small pixel shifts) (with the threshold as well)

scenario is a sequence of actions/transitions/scenarios
e.g. action-trans-trans-action-scen-action-scen or action-trans-action

## app
2 parts:
- bunjs controller contains logic and terminal ui written via (https://raw.githubusercontent.com/anomalyco/opentui/refs/heads/main/packages/react/README.md)
- swift helper to interact with macos: do the recording of steps + firing of scenarios. but exposes only raw methods to interact with the macos. acts as a low-level macos ui lib. connects to the controller via events of a scheme: request/response (transforms to a promise on the controller side)

## controller ui
vim-motions navigation (hjkl), <C-l> to "enter", <C-h> to "esc" (navigation between layers)

a list of all scenarios column to the left, sorted chronologically by last usage.
a scenario steps viewer column in the center.
a scenario step preview column to the right.

scenario view column shows the list of steps (step = action/transition)
preview column shows details about the current selected scenario selected step.

h/l navigates between columns
j/k between rows
C-l selects scenario, or goes into sub-scenario
C-h deselects scenario, or goes back to the parent of the current scenario step
C-j swaps the selected row with one below
C-k swaps the selected row with one above
n when a scenario is selected to update the name: record all the next characters as a new name until Enter is hit

preview column visuals:
- delay = no preview, just a human-readable duration in the step itself
- pixel state = coordinates + color code + ascii drawing of a reasonably sized pixel position in a screen frame
- pixel zone = same as pixel state but with an additional ascii drawing of the zone frame size with the target pixel color viz

pressing "r" in the terminal:
- when no scenario selected: creates an empty scenario, inline name of the scenario shows "input the name" - records all next keypresses as the name until Enter is hit, selects it and launches the recorder ui
- when a scenario is selected: starts adding new steps after the currently selected step (if in abCd C is selected, "r" pressed, efg recordered, result = adCefgd)
- when a recording is running: stops the recording
- new steps are live-added to the scenario steps list
- recording status displayed in in the scenario column row

pressing "p" in the terminal:
- when a scenario is selected: shows a modal saying "input a keystroke which will be used to fire the scenario", users does a keycomb (like "p" or "P" or "Ctrl+I"), modal starts saying "press the <KEYCOMB> to fire the scenario, press ESC to abort". when pressing the keycomb - executes the scenario

## recorder ui 
a movable overlay, default position is in the bottom
a horizontal list of icon-buttons with an outline (the list), can be clicked&dragged when clicked outside the icons

only shown when recording ("r") is running

3 states:
- idle (just processes clicks on the icons)
- action record (waits for the next hotkey/iconpress/mouseclick)
- transition record (waits for the next hotkey/iconpress/mouseclick)

action/transition record states has a sub-state what's the next action/transition they're expecting (mouse/keyboard/time etc)

icons:
- action state status (record red circle = waiting for the next action; record gray circle = idle)
- transition state status (horizontal arrow red = waiting for the next transition; gray = idle)
- mouse click (waits for the next mouse click)
    - idle: disabled
    - action: create a click action
    - transition: create a pixel state/zone condition
- keyboard press (waits for the next keyboard click)
    - idle: disabled
    - action: create a keyboard action
    - transition: disabled
- time clock (waits for a sequence of key presses + enter to finish the entering. parses the sequence as ms. saves as a transition)

## state&settings
scenario:
- current steps
- history of changes

scenarios:
- history of scenarios execution (id ref)

recorder:
- last overlay position
