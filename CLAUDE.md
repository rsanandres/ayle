# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Ayle — AI Agent Office Simulation. A top-down 2D pixel art game where AI agents with distinct personalities live together in an office. The player observes and rearranges the environment as emergent social behavior unfolds. Built with Godot 4 (GDScript) and Ollama for local LLM inference.

## Build & Development

- **Engine**: Godot 4.6 (GDScript)
- **LLM Backend**: Ollama (localhost:11434) with smollm2:1.7b (default)
- Open project in Godot editor: `godot --editor project.godot`
- Run from CLI: `godot --path /Users/raph/Documents/ayle`

## Architecture

### Autoloads (singletons)
- `EventBus` — Global signal bus decoupling all systems (~40 signals)
- `TimeManager` — Game clock (1 real sec = 1 game minute at 1x), pause/1x/2x/3x, day tracking
- `Config` — Constants (need decay rates, speeds, thresholds, conversation settings)
- `AgentManager` — Agent registry, staggered round-robin think ticks, spawn/remove
- `LLMManager` — Async HTTP queue to Ollama with health checking
- `GameManager` — Top-level game state, selected agent tracking
- `ConversationManager` — Tracks active conversations, prevents double-booking agents
- `EventManager` — Random/triggered life events with probabilities and cooldowns
- `SaveManager` — Serializes full world state to JSON, auto-saves every 5 game-days

### Key Directories
- `autoloads/` — Singleton scripts
- `scenes/agents/` — Agent scene, needs, brain, memory, relationships
- `scenes/objects/` — InteractableObject base + 9 object types
- `scenes/conversations/` — ConversationInstance (multi-turn LLM dialogues)
- `scenes/events/` — EventManager, EventDefinition
- `scenes/world/` — Office layout with navigation
- `scenes/ui/` — HUD, god toolbar, agent inspector, narrative log, relationship web
- `scenes/main/` — Root scene
- `scripts/enums/` — AgentState, NeedType, ActionType, LifeStage
- `scripts/data/` — MemoryEntry, PersonalityProfile, RelationshipEntry, HealthState
- `scripts/utils/` — SpriteFactory, Palette, PromptBuilder
- `resources/` — Personalities (JSON), prompts (TXT), events (JSON)

### Agent Systems
- **Needs**: energy, hunger, social, productivity, health — decay over game time
- **Brain**: LLM-powered (Ollama) with heuristic fallback
- **Memory**: Scored retrieval, emotional metadata, narrative threads, life summaries (max 300)
- **Relationships**: Per-pair affinity/trust/familiarity/romantic_interest, personality compatibility
- **Health**: Aging through life stages (young→adult→senior→dying→dead), conditions, grief
- **State machine**: IDLE → DECIDING → WALKING → INTERACTING / TALKING → IDLE

### Objects (9 types)
- desk, couch, coffee_machine (original)
- water_cooler (2 occupants, triggers conversation), whiteboard (3 occupants, meeting bonus)
- bookshelf (creative breakthrough chance), plant (passive mood), radio (passive social, toggleable), bed

### God Mode (Tab key)
Toolbar with object palette, agent spawn/remove, event triggers. Agent inspector shows full internal state.

### Conversation System
Multi-turn LLM dialogues (3-4 exchanges), speech bubbles, post-conversation reflection updates relationships. Special confession mode for romance.

### Life Events
17 events across 5 categories (social, work, health, environment, personal). Random rolls per game-day with probability tables and cooldowns.

### Save/Load
Full world state serialized to JSON: agent positions, needs, memories, relationships, health, objects, game time.
