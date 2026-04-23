extends Node

@export var model_paths: String='res://Assets/'
var params
var paths: Array=['model.json','model150.json','model500.json','model600.json']
var weights=[0.1,0.2,0.3,0.4]

#load json weights
func initialise():
	print('TODO:change')
	weights=[0,0,0,1]
	var id=weighted_random_index(weights)
	print('inference using model ',id)
	var file = FileAccess.open(model_paths+paths[id], FileAccess.READ)
	params = JSON.parse_string(file.get_as_text())
	
#random distribution function
func weighted_random_index(weights_dist: Array) -> int:
	var total := 0.0
	for w in weights_dist:
		total += w

	var r := randf() * total
	var cumulative := 0.0

	for i in range(weights_dist.size()):
		cumulative += weights_dist[i]
		if r < cumulative:
			return i

	return weights_dist.size() - 1  
#define basic mlp functions
func matvec(W, x):
	var out = []
	for i in range(W.size()): # rows
		var sum = 0.0
		for j in range(x.size()):
			sum += W[i][j] * x[j]
		out.append(sum)
	return out


func add_bias(v, b):
	var out = []
	for i in range(v.size()):
		out.append(v[i] + b[i])
	return out


func tanh_vec(v):
	var out = []
	for i in range(v.size()):
		out.append(tanh(v[i]))
	return out
#inference
func forward(obs):
	var W0 = params["mlp_extractor.policy_net.0.weight"]
	var b0 = params["mlp_extractor.policy_net.0.bias"]

	var W1 = params["mlp_extractor.policy_net.2.weight"]
	var b1 = params["mlp_extractor.policy_net.2.bias"]

	var W2 = params["action_net.weight"]
	var b2 = params["action_net.bias"]
	# Layer 1: 12 -> 64
	var z1 = matvec(W0, obs['obs'])
	z1 = add_bias(z1, b0)
	var a1 = tanh_vec(z1)

	# Layer 2: 64 -> 64
	var z2 = matvec(W1, a1)
	z2 = add_bias(z2, b1)
	var a2 = tanh_vec(z2)

	# Output: 64 -> 2
	var z3 = matvec(W2, a2)
	z3 = add_bias(z3, b2)
	var action = []
	for x in z3:
		action.append(clamp(x, -1.0, 1.0))
	return action
