extends Node

@export var model_path: String='res://Assets/weights.json'
var params

#load json weights
func initialise():
	var file = FileAccess.open(model_path, FileAccess.READ)
	params = JSON.parse_string(file.get_as_text())
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

	return z3
