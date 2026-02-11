extends Node
## Detects emergent social groups from relationship clustering.

var groups: Array[SocialGroup] = []
var _analyze_timer: float = 0.0
var _next_group_id: int = 0

const ANALYZE_INTERVAL := 60.0  # real seconds


func _process(delta: float) -> void:
	if AgentManager.agents.size() < Config.GROUP_MIN_SIZE:
		return
	_analyze_timer += delta
	if _analyze_timer >= ANALYZE_INTERVAL:
		_analyze_timer = 0.0
		_detect_groups()


func get_agent_groups(agent_name: String) -> Array[SocialGroup]:
	var result: Array[SocialGroup] = []
	for group in groups:
		if agent_name in group.members:
			result.append(group)
	return result


func get_agent_group_names(agent_name: String) -> String:
	var agent_groups := get_agent_groups(agent_name)
	if agent_groups.is_empty():
		return "(none)"
	var names: PackedStringArray = []
	for g in agent_groups:
		names.append(g.group_name)
	return ", ".join(names)


func _detect_groups() -> void:
	# Build adjacency graph: edge if mutual affinity > threshold
	var adjacency: Dictionary = {}  # agent_name -> Array[String]
	for agent in AgentManager.agents:
		if not is_instance_valid(agent) or not agent.relationships:
			continue
		var name_a: String = agent.agent_name
		if not adjacency.has(name_a):
			adjacency[name_a] = []
		var rels: Dictionary = agent.relationships.get_all_relationships()
		for other_name in rels:
			var rel: RelationshipEntry = rels[other_name]
			if rel.affinity > Config.GROUP_AFFINITY_THRESHOLD and rel.familiarity > 15.0:
				# Check if mutual
				var other_agent := AgentManager.get_agent_by_name(other_name)
				if other_agent and other_agent.relationships:
					var reverse_rel: RelationshipEntry = other_agent.relationships.get_relationship(name_a)
					if reverse_rel.affinity > Config.GROUP_AFFINITY_THRESHOLD:
						if other_name not in adjacency[name_a]:
							adjacency[name_a].append(other_name)
						if not adjacency.has(other_name):
							adjacency[other_name] = []
						if name_a not in adjacency[other_name]:
							adjacency[other_name].append(name_a)

	# BFS to find connected components
	var visited: Dictionary = {}
	var clusters: Array[Array] = []
	for agent_name in adjacency:
		if visited.has(agent_name):
			continue
		var cluster: Array[String] = []
		var queue: Array[String] = [agent_name]
		while not queue.is_empty():
			var current: String = queue.pop_front()
			if visited.has(current):
				continue
			visited[current] = true
			cluster.append(current)
			for neighbor in adjacency.get(current, []):
				if not visited.has(neighbor):
					queue.append(neighbor)
		if cluster.size() >= Config.GROUP_MIN_SIZE:
			clusters.append(cluster)

	# Match clusters to existing groups by member overlap
	var new_groups: Array[SocialGroup] = []
	for cluster in clusters:
		var best_match: SocialGroup = null
		var best_overlap: float = 0.0
		for existing in groups:
			var overlap := _calculate_overlap(cluster, existing.members)
			if overlap > best_overlap:
				best_overlap = overlap
				best_match = existing
		if best_match and best_overlap > 0.5:
			# Update existing group
			best_match.members.clear()
			for m in cluster:
				best_match.members.append(m)
			_update_group_stats(best_match)
			new_groups.append(best_match)
		else:
			# Create new group
			var group := SocialGroup.new()
			group.group_id = "group_%d" % _next_group_id
			_next_group_id += 1
			for m in cluster:
				group.members.append(m)
			group.formed_day = TimeManager.day
			group.group_type = _classify_group(cluster)
			group.group_name = _generate_group_name(group)
			_update_group_stats(group)
			new_groups.append(group)
			EventBus.group_formed.emit(group)

	# Detect dissolved groups
	for old_group in groups:
		if old_group not in new_groups:
			EventBus.group_dissolved.emit(old_group)

	groups = new_groups

	# Detect rivalries
	_detect_rivalries()


func _calculate_overlap(cluster: Array, members: Array[String]) -> float:
	if members.is_empty() or cluster.is_empty():
		return 0.0
	var shared := 0
	for m in cluster:
		if m in members:
			shared += 1
	return float(shared) / max(cluster.size(), members.size())


func _classify_group(members: Array) -> String:
	# "family" if any pair is DATING or PARTNERS
	for name_a in members:
		var agent_a := AgentManager.get_agent_by_name(name_a)
		if not agent_a or not agent_a.relationships:
			continue
		for name_b in members:
			if name_a == name_b:
				continue
			var rel: RelationshipEntry = agent_a.relationships.get_relationship(name_b)
			if rel.relationship_status == RelationshipEntry.Status.DATING or rel.relationship_status == RelationshipEntry.Status.PARTNERS:
				return "family"
	return "faction"


func _generate_group_name(group: SocialGroup) -> String:
	if group.members.is_empty():
		return "Unknown Group"
	# Find member with highest total affinity (leader)
	var leader := group.members[0]
	var best_affinity: float = -100.0
	for name_a in group.members:
		var total: float = 0.0
		var agent := AgentManager.get_agent_by_name(name_a)
		if not agent or not agent.relationships:
			continue
		for name_b in group.members:
			if name_a == name_b:
				continue
			var rel: RelationshipEntry = agent.relationships.get_relationship(name_b)
			total += rel.affinity
		if total > best_affinity:
			best_affinity = total
			leader = name_a

	match group.group_type:
		"family": return "%s's Family" % leader
		"faction": return "%s's Circle" % leader
		_: return "%s's Group" % leader


func _update_group_stats(group: SocialGroup) -> void:
	var total_affinity: float = 0.0
	var pair_count: int = 0
	for i in range(group.members.size()):
		var agent_a := AgentManager.get_agent_by_name(group.members[i])
		if not agent_a or not agent_a.relationships:
			continue
		for j in range(i + 1, group.members.size()):
			var rel: RelationshipEntry = agent_a.relationships.get_relationship(group.members[j])
			total_affinity += rel.affinity
			pair_count += 1
	group.average_affinity = total_affinity / max(pair_count, 1)
	group.cohesion = clampf(group.average_affinity, 0.0, 100.0)


func _detect_rivalries() -> void:
	for i in range(groups.size()):
		groups[i].rival_groups.clear()
		for j in range(groups.size()):
			if i == j:
				continue
			var cross_affinity := _cross_group_affinity(groups[i], groups[j])
			if cross_affinity < -20.0:
				groups[i].rival_groups.append(groups[j].group_id)
				if not groups[j].rival_groups.has(groups[i].group_id):
					EventBus.group_rivalry_detected.emit(groups[i], groups[j])


func _cross_group_affinity(a: SocialGroup, b: SocialGroup) -> float:
	var total: float = 0.0
	var count: int = 0
	for name_a in a.members:
		var agent := AgentManager.get_agent_by_name(name_a)
		if not agent or not agent.relationships:
			continue
		for name_b in b.members:
			var rel: RelationshipEntry = agent.relationships.get_relationship(name_b)
			total += rel.affinity
			count += 1
	return total / max(count, 1)
