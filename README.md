# AirHockey
A fast-paced Air Hockey game built in Godot, created as a playground for programming and reinforcement learning experiments.  
## Features
Play against:  
| Mode | Description |
|---|---|
| ⚙️ Scripted AI | Scripted rule-based opponents |
| 🤖 RL Agent | Self-play trained reinforcement learning agent |
| 🌍 Online Multiplayer | Play with friends |

Try it in your browser here:  
[Air Hockey](https://manuu1311.github.io/AirHockey/)

## Training
### Early Exploration
The agent experimenting with basic puck control and learning how to interact with the environment.  
<img width="640" height="360" alt="parallel" src="https://github.com/user-attachments/assets/2ad5af9c-3717-453e-8fb9-026c43e161fa" />
### Parallel Self-Play Training
Parallel training through self-play with policy pool.  
<img width="640" height="360" alt="early" src="https://github.com/user-attachments/assets/c62b38ab-b36c-4827-9f11-c88e3fd0a205" />


## Credits
The multiplayer server implementation was adapted from [this example](https://github.com/Faless/gd-webrtc-signalling)
