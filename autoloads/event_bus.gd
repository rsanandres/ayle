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
signal agent_spawned_dynamic(agent: Node2D)
signal agent_removed(agent_name: String)

# Relationship signals
signal relationship_changed(agent_name: String, target_name: String, relationship: RefCounted)

# Conversation signals
signal conversation_started(agent_a: String, agent_b: String)
signal conversation_ended(agent_a: String, agent_b: String)
signal conversation_line(speaker: String, line: String)

# Object signals
signal object_occupied(object: Node2D, agent: Node2D)
signal object_freed(object: Node2D, agent: Node2D)
signal object_placed(object: Node2D, position: Vector2)
signal object_removed(object: Node2D)

# Time signals
signal time_tick(game_minutes: float)
signal day_changed(day: int)
signal time_speed_changed(speed_index: int)
signal time_paused()
signal time_resumed()

# Health & Life signals
signal agent_died(agent_name: String, cause: String)
signal agent_sick(agent_name: String, condition: String)
signal agent_life_stage_changed(agent_name: String, stage: int)

# Event signals
signal event_triggered(event_id: String, affected_agents: Array)
signal event_ended(event_id: String)

# Romance signals
signal romance_started(agent_a: String, agent_b: String)
signal romance_ended(agent_a: String, agent_b: String)
signal confession_made(confessor: String, target: String, accepted: bool)

# Narrative signals
signal narrative_event(text: String, agents: Array, importance: float)

# Game signals
signal game_ready()
signal game_paused()
signal game_resumed()
signal god_mode_toggled(enabled: bool)
