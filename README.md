# AirHockey
A fast-paced Air Hockey game built in Godot, created as a playground for programming and reinforcement learning experiments. 
## 🎮 Play Online
Try it directly in your browser here:  
👉 **[Air Hockey](https://manuu1311.github.io/AirHockey/)**
## 🚀 Features
Play against:  
| Mode | Description |
| :--- | :--- |
| **⚙️ Scripted AI** | Scripted rule-based opponents |
| **🤖 RL Agent** | Self-play trained reinforcement learning agent |
| **🌍 Online Multiplayer** | Online with friends |

## 🛠️ Tools
* **Game Engine:** Godot 4.6  
* **Networking:** WebRTC  
* **RL Framework:** Godot RL Agents, Stable Baselines3

## 🌐 Web Deployment & Optimization
To export the game in a standard web browser, the inference was manually reimplemented in GDScript.  
* **Model Size:** To guarantee a smooth experience on the web, various network architectures were assessed. The final model has a modest size of **2 hidden layers with 128 units each** (~19k parameters).  

## Training
The RL agent was trained using **curriculum learning** and **self-play with a policy pool**, starting with simple objectives (puck tracking, basic control) and progressively scaling to full matches. From there, it trained against past versions of itself. Combined with reward shaping, these techniques helped the network converge faster and develop more robust strategies.  

### Early Exploration
The agent experimenting with basic puck control and learning how to interact with the environment.  
<img src="https://github.com/user-attachments/assets/2ad5af9c-3717-453e-8fb9-026c43e161fa" alt="Early Exploration" style="max-width: 100%; height: auto;" />

### Parallel Self-Play Training
Parallel training through self-play with policy pool.  
<img src="https://github.com/user-attachments/assets/c62b38ab-b36c-4827-9f11-c88e3fd0a205" alt="Parallel Self-Play" style="max-width: 100%; height: auto;" />


## Credits
The multiplayer signaling server implementation was adapted from [this example](https://github.com/Faless/gd-webrtc-signalling)
