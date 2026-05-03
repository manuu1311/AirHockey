from stable_baselines3 import PPO,SAC
import numpy as np
import json
#python training.py --save_model_path=model_second_it --timesteps=50000 resume_model_path=model_second_it --onnx_export_path=model_second_it
#name of model to convert
name='sac1m'
mode='sac'
debug=1

#save the weights in json
def save_weights(model):
    if mode=='ppo':
        #get the policy
        policy = model.policy
        # Extract state_dict (all weights + biases)
        state_dict = policy.state_dict()
    elif mode == 'sac':
        #get the actor policy
        state_dict = model.actor.state_dict()

    # Convert tensors to plain Python lists
    weights_dict = {k: v.detach().cpu().numpy().tolist() for k, v in state_dict.items()}

    # Save to JSON
    with open(name+".json", "w") as f:
        json.dump(weights_dict, f)
 
    
#load the weights from json
def load_weights():
    with open(name + ".json", "r") as f:
        return json.load(f)

#manual nn output starting from loaded params
def forward(obs, params):
    if mode=='ppo':
        W0, b0 = np.array(params["mlp_extractor.policy_net.0.weight"]), np.array(params["mlp_extractor.policy_net.0.bias"])
        W1, b1 = np.array(params["mlp_extractor.policy_net.2.weight"]), np.array(params["mlp_extractor.policy_net.2.bias"])
        W2, b2 = np.array(params["action_net.weight"]), np.array(params["action_net.bias"])

        Z1 = obs @ W0.T + b0
        A1 = np.tanh(Z1)

        Z2 = A1 @ W1.T + b1
        A2 = np.tanh(Z2)

        Z3 = A2 @ W2.T + b2

        return Z3

    elif mode == 'sac':
        # Layer 1
        W0 = np.array(params["latent_pi.0.weight"])
        b0 = np.array(params["latent_pi.0.bias"])

        # Layer 2
        W1 = np.array(params["latent_pi.2.weight"])
        b1 = np.array(params["latent_pi.2.bias"])

        # Layer 3
        W2 = np.array(params["latent_pi.4.weight"])
        b2 = np.array(params["latent_pi.4.bias"])

        # Output layers
        W_mu = np.array(params["mu.weight"])
        b_mu = np.array(params["mu.bias"])

        W_logstd = np.array(params["log_std.weight"])
        b_logstd = np.array(params["log_std.bias"])

        # Forward pass
        Z1 = obs @ W0.T + b0
        #relu
        A1 = np.maximum(0, Z1)  

        Z2 = A1 @ W1.T + b1
        #relu
        A2 = np.maximum(0, Z2)

        Z3 = A2 @ W2.T + b2
        #relu
        A3 = np.maximum(0, Z3)

        mu = A3 @ W_mu.T + b_mu

        # Deterministic action
        action = np.tanh(mu)

        return action


#load model
model=SAC.load("checkpoints/"+name+".zip")

if debug:
    if mode=='ppo':
        for name, param in model.policy.named_parameters():
            print(name, param.shape)
        for name, module in model.policy.named_modules():
            print(name, module)
    elif mode=='sac':
        for name, param in model.actor.named_parameters():
            print(name, param.shape)
        for name, module in model.actor.named_modules():
            print(name, module)


save_weights(model)
params = load_weights()

for i in [13,17,12,0,15,25,111]:
    #random observation
    np.random.seed(i)
    obs=np.random.random(size=23)
    obs = {"obs": obs}
    #deterministic predict with sb3
    action, _ = model.predict(obs,deterministic=True)
    #manual predict and comparison
    manual_logits = forward(obs['obs'], params)
    manual_logits = np.clip(manual_logits, -1, 1)
    print(f'SB output: {action}\nNN output: {manual_logits}\n')

