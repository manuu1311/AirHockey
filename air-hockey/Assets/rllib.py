# Rllib Example for single and multi-agent training for GodotRL with onnx export,
# needs rllib_config.yaml in the same folder or --config_file argument specified to work.

import argparse
import os
import pathlib
import ray
import yaml
from ray import train, tune
from ray.rllib.algorithms.algorithm import Algorithm
from ray.rllib.env.wrappers.pettingzoo_env import ParallelPettingZooEnv
from ray.rllib.policy.policy import PolicySpec
from ray.rllib.algorithms.callbacks import DefaultCallbacks

import gymnasium as gym

from godot_rl.core.godot_env import GodotEnv
from godot_rl.wrappers.petting_zoo_wrapper import GDRLPettingZooEnv
from godot_rl.wrappers.ray_wrapper import RayVectorGodotEnv
import random

MAX_POOL_SIZE = 10




if __name__ == "__main__":
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--config_file", default="rllib_config.yaml", type=str, help="The yaml config file")
    parser.add_argument("--restore", default=None, type=str, help="the location of a checkpoint to restore from")
    parser.add_argument(
        "--experiment_dir",
        default="logs/rllib",
        type=str,
        help="The name of the the experiment directory, used to store logs.",
    )
    args, extras = parser.parse_known_args()

    # Get config from file
    with open(args.config_file) as f:
        exp = yaml.safe_load(f)

    is_multiagent = exp["env_is_multiagent"]

    # Register env
    env_name = "godot"
    env_wrapper = None

    #TODO: handmade bandaid
    exp["config"]["api_stack"] = {
        "enable_rl_module_and_learner": False,
        "enable_env_runner_and_connector_v2": False,
    }

    def env_creator(env_config):
        index = env_config.worker_index * exp["config"]["num_envs_per_runner"] + env_config.vector_index
        port = index + GodotEnv.DEFAULT_PORT
        seed = index
        if is_multiagent:
            #TODO:homemade bandaid
            # Create the Godot PettingZoo env
            pz_env = GDRLPettingZooEnv(config=env_config, port=port, seed=seed)
            
            # This is the "Bandaid": 
            # We wrap it so RLlib only sees the vector, not the GodotRL dict
            from ray.rllib.env.wrappers.pettingzoo_env import ParallelPettingZooEnv
            
            class FilterObs(gym.Wrapper):
                def reset(self, **kwargs):
                    obs, info = self.env.reset(**kwargs)
                    # For every agent, return ONLY the "obs" vector
                    return {k: v["obs"] for k, v in obs.items()}, info
                
                def step(self, action_dict):
                    obs, rew, term, trunc, info = self.env.step(action_dict)
                    # Again, strip away the dictionary, keep the vector
                    new_obs = {k: v["obs"] for k, v in obs.items()}
                    return new_obs, rew, term, trunc, info

            return ParallelPettingZooEnv(FilterObs(pz_env))
        #   TODO: no bandaid
            #return ParallelPettingZooEnv(GDRLPettingZooEnv(config=env_config, port=port, seed=seed))
        else:
            return RayVectorGodotEnv(config=env_config, port=port, seed=seed)

    tune.register_env(env_name, env_creator)

    policy_names = None
    num_envs = None
    tmp_env = None
    
    if is_multiagent:  # Make temp env to get info needed for multi-agent training config
        print("Starting a temporary multi-agent env to get the policy names")
        tmp_env = GDRLPettingZooEnv(config=exp["config"]["env_config"], show_window=False)
        policy_names = tmp_env.agent_policy_names
        print("Policy names for each Agent (AIController) set in the Godot Environment", policy_names)
    else:  # Make temp env to get info needed for setting num_workers training config
        print("Starting a temporary env to get the number of envs and auto-set the num_envs_per_worker config value")
        tmp_env = GodotEnv(env_path=exp["config"]["env_config"]["env_path"], show_window=False)
        num_envs = tmp_env.num_envs

    tmp_env.close()


    #callback: add policy to policy pool
    class SelfPlayCallback(DefaultCallbacks):
        def __init__(self):
            super().__init__()
            self.policy_pool = ['main']
            self.add_freq = 10  # iterations

        def on_train_result(self, *, algorithm, result, **kwargs):
            if result["training_iteration"] % 250 == 0:
                new_id = f"opponent_{result['training_iteration']}"
                main_policy = algorithm.get_policy("main")

                algorithm.add_policy(
                    policy_id=new_id,
                    policy=type(main_policy),
                    policy_state=main_policy.get_state(),
                    policies_to_train=["main"],
                )

                self.policy_pool.append(new_id)
                if len(self.policy_pool) > MAX_POOL_SIZE:
                    #keep main (0)
                    removed = self.policy_pool.pop(1)  
                    algorithm.remove_policy(removed)
            algorithm.workers.local_worker().set_global_vars(
                    {"policy_pool": self.policy_pool}
                )
                
        #reload policy pool on resume
        def on_algorithm_init(self, *, algorithm, **kwargs):
            state = algorithm.workers.local_worker().get_global_vars()
            if "policy_pool" in state:
                self.policy_pool = state["policy_pool"]
                print(f"Resumed with policy pool: {self.policy_pool}")
                


    def policy_mapping_fn(agent_id, episode, worker, **kwargs):
        pool = worker.callbacks.policy_pool
        if agent_id == 0:
            return "main"
        else:
            return random.choice(pool)
        

    ray.init(_temp_dir=os.path.abspath(args.experiment_dir))

    #TODO: homemade bandaid
    exp["config"]["model"] = {
        "fcnet_hiddens": [128, 128, 128],
        "fcnet_activation": "relu",
        "flatten_observations": True, #tell RLlib to ignore the 'obs' key and just grab the data
    }

    if is_multiagent:
        exp["config"]["multiagent"] = {
            "policies": {
                "main": PolicySpec(),
            },
        "policy_mapping_fn": policy_mapping_fn,
        "policies_to_train": ["main"],
        }
        exp["config"]["callbacks"] = SelfPlayCallback
    else:
        exp["config"]["num_envs_per_runner"] = num_envs

    exp["config"]["checkpoint_config"] = {
        "num_to_keep": 5, 
        "checkpoint_frequency": exp["checkpoint_frequency"],
        "checkpoint_at_end": True,
    }

    #TODO: homemade bandaid
    exp["config"]["_enable_rl_module_api"] = False
    exp["config"]["_enable_learner_api"] = False
    # Also ensure you aren't using the new EnvRunner
    exp["config"]["enable_env_runner_and_connector_v2"] = False
    tuner = None
    if not args.restore:
        tuner = tune.Tuner(
            trainable=exp["algorithm"],
            param_space=exp["config"],
            run_config=tune.RunConfig(
                storage_path=os.path.abspath(args.experiment_dir),
                stop=exp["stop"],
                #checkpoint_config=train.CheckpointConfig(checkpoint_frequency=exp["checkpoint_frequency"]),
            ),

        )
    else:
        tuner = tune.Tuner.restore(
            trainable=exp["algorithm"],
            path=args.restore,
            resume_unfinished=True,
        )
    result = tuner.fit()

    # Onnx export after training if a checkpoint was saved
    checkpoint = result.get_best_result().checkpoint

    if checkpoint:
        result_path = result.get_best_result().path
        sac = Algorithm.from_checkpoint(checkpoint)
        if is_multiagent:
            for policy_name in set(policy_names):
                sac.get_policy(policy_name).export_model(f"{result_path}/onnx_export/{policy_name}_onnx", onnx=12)
                print(
                    f"Saving onnx policy to {pathlib.Path(f'{result_path}/onnx_export/{policy_name}_onnx').resolve()}"
                )
        else:
            sac.get_policy().export_model(f"{result_path}/onnx_export/single_agent_policy_onnx", onnx=12)
            print(
                f"Saving onnx policy to {pathlib.Path(f'{result_path}/onnx_export/single_agent_policy_onnx').resolve()}"
            )