1|To use Freebuff in Zellij:
```sh
# 1. Note Hermes Agent pane
HERMES_PANE=$ZELLIJ_PANE_ID

# 2. Create a new pane (handle stale instance)
FREEBUFF_PANE=$(zellij action new-pane --direction right --cwd $PROJECT_ROOT_DIR --close-on-exit -- freebuff)

# 3. Return focus to Hermes
zellij action focus-pane-id $HERMES_PANE
zellij action fullscreen-panes

zellij action dump-screen --pane-id $FREEBUFF_PANE

# 4. Navigate the menu to select a model
zellij action send-keys --pane-id $FREEBUFF_PANE <direction> # placeholder, use Down or Up
##### Example #####
zellij action send-keys --pane-id $FREEBUFF_PANE "Up"
zellij action send-keys --pane-id $FREEBUFF_PANE "Down"


# 4a. To submit
zellij action send-keys --pane-id $FREEBUFF_PANE "Enter"

zellij action dump-screen --pane-id $FREEBUFF_PANE

# 5. After chat opens, type the prompt & submit
zellij action paste --pane-id $FREEBUFF_PANE <prompt>
zellij action send-keys --pane-id $FREEBUFF_PANE "Enter"

zellij action dump-screen --pane-id $FREEBUFF_PANE
sleep 5

# 6. To gracefully exit out of freebuff (upon user confirmation of task completion)
zellij action paste --pane-id $FREEBUFF_PANE "/exit"
zellij action send-keys --pane-id $FREEBUFF_PANE "Enter"
```

<!-- For additional context, read  -->
<!-- <!-- - ./frontend/docs/Project-Document.pdf --> -->
<!-- <!-- - Add agent specific information here only, the general information should be read from readme, keep both conceise --> -->
<!-- - ./README.md -->
