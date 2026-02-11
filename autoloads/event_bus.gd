extends Node
## Global signal bus decoupling all systems.

# Agent signals
signal agent_spawned(agent: Node2D)
signal agent_state_changed(agent: Node2D, old_state: AgentState.Type, new_state: AgentState.Type)
signal agent_need_changed(agent: Node2D, need: NeedType.Type, value: float)
signal agent_need_critical(agent: Node2D, need: NeedType.Type)
signal agent_action_started(agent: Node2D, action: ActionType.Type, target: Node2D)
signal agent_action_completed(agent: Node2D, action: ActionType.Type, target: Node2D)
signal agent_selected(agent: Node2D)
signal agent_deselected()

# Object signals
signal object_occupied(object: Node2D, agent: Node2D)
signal object_freed(object: Node2D, agent: Node2D)
signal object_placed(object: Node2D, position: Vector2)
signal object_removed(object: Node2D)

# Time signals
signal time_tick(game_minutes: float)
signal time_speed_changed(speed_index: int)
signal time_paused()
signal time_resumed()

# Game signals
signal game_ready()
signal game_paused()
signal game_resumed()
