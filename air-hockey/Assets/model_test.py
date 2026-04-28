from stable_baselines3 import PPO
import numpy as np
#python training.py --save_model_path=model_second_it --timesteps=50000 resume_model_path=model_second_it --onnx_export_path=model_second_it
model=PPO.load("model_second_it.zip")
np.random.seed(117)
obs=np.random.random(size=12)
obs = {"obs": obs}
action, _ = model.predict(obs,deterministic=True)
print(f'obs: {obs},output: {action}')
'''
print('pol',model.policy,'\nthen\n')
print(model.policy.mlp_extractor)
print(model.policy.action_net)
print(model.policy.value_net)
for name, param in model.policy.named_parameters():
    print(name, param.shape)
for name, module in model.policy.named_modules():
    print(name, module)
'''
