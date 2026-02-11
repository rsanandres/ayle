# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Ayle — AI Agent Office Simulation. A top-down 2D pixel art game where AI agents with distinct personalities live together in an office. The player observes and rearranges the environment as emergent social behavior unfolds. Built with Godot 4 (GDScript) and Ollama for local LLM inference.

## Build & Development

- **Engine**: Godot 4.3+ (GDScript)
- **LLM Backend**: Ollama (localhost:11434) with Llama 3.2 3B
- Open project in Godot editor: `godot --editor project.godot`
- Run from CLI: `godot --path /Users/raph/Documents/ayle`

## Architecture

### Autoloads (singletons)
- `EventBus` — Global signal bus decoupling all systems
- `TimeManager` — Game clock (1 real sec = 1 game minute at 1x), pause/1x/2x/3x
- `Config` — Constants (need decay rates, speeds, thresholds)
- `AgentManager` — Agent registry, staggered round-robin think ticks
- `GameManager` — Top-level game state, selected agent tracking

### Key Directories
- `autoloads/` — Singleton scripts
- `scenes/agents/` — Agent scene, needs, brain scripts
- `scenes/objects/` — InteractableObject base + desk/coffee_machine/couch
- `scenes/world/` — Office layout with navigation
- `scenes/ui/` — HUD, camera
- `scenes/main/` — Root scene
- `scripts/enums/` — AgentState, NeedType, ActionType
- `resources/` — Data files (personalities, prompts, objects, events)

### Core Loop
Agents have needs (energy, hunger, social, productivity) that decay over game time. A brain (heuristic fallback, later LLM) picks actions. Agent state machine: IDLE → DECIDING → WALKING → INTERACTING → IDLE.

### Development Phases
- Phase 1 (current): Foundation — single room, heuristic brain, needs, pathfinding
- Phase 2: LLM integration via Ollama
- Phase 3: Memory & personality system
- Phase 4: Multi-agent conversations
- Phase 5: Relationships & god mode
- Phase 6: Polish & content
- Phase 7: Steam release
