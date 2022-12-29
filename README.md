# DUMB-PONG
It's DUMB, it's PONG.

It's mostly playable. 


This is the first game I've ever programmed at all, but I think it's not too bad for sharing with everyone who may want to give it a shot! 

I've actually been working on this one for some time now, but left the project sleeping while I was beating myself trying to work on Raster Music Tracker.
Since I've been taking some time off RMT, I figured I could go back to this one, fix a bunch of things, and release it as soon as it worked well enough to my liking. 

It was honestly a lot of fun to make, even if I had a lot of troubles with collisions detection, or just the weird nature of Player/Missile sprites. 

I think I've done a pretty okay job for it being my first game program so far, of course you're all welcome to give feedback or criticism if you feel like it :) 

Features: 

- Programmed in 6502 Assembly, entirely from scratch, without any Pong reference whatsoever, mainly as a personal challenge, and just for the fun of it really 

- PAL and NTSC compatible, I have not thoroughly tested but I believe even the 16k Atari 400 will be able to run the game 

- Runs in ANTIC Mode 8, because a low resolution display is perfectly good for this kind of gameplay  

- Sound, the sound effects themselves were originally made by @pseudografx for the game Bunny Hop, and were borrowed with permission, until at least when I make some original SFXs later 

- Playable with 2 Human Players using Paddles through PORTA, or 2 CPU Players, any combination of Human/CPU will work 

- Many deliberate gameplay changes compared to the original Pong were made, such as the ball physics responding to certain conditions, or the way the ball could bounce back from any wall 

- Score system going from 00 to 99, and rolling back to 00, essentially playing infinitely if you're into that kind of passtime 

- Dumb CPU logic is in place, which is not very good but it's enough to have the CPU Player fully capable of playing all by itself, even in a CPU vs CPU game 

- It's Pong, what else could I say? :D 

 

Paddles Controls (Player 1 and Player 2): 

- Paddles Pots -> Move the Players on screen

- Paddles Trigger Buttons -> Action, for now, dedicated to throw the ball back in game 

 

Atari Keyboard Controls: 

- ESC Key -> Exit the game to DOS or Self-Test, I cannot promise this is actually working at all, so please let me know if it's doing anything weird 

- 1 or 2 Key -> Toggle between Human and CPU Players, for Player 1 and 2 respectively. The game will boot with 2 Human Players expecting Paddles input by default 

- R Key -> Reset the scoreboard 

- M Key -> Mute/Unmute sound 


Downloads:

- DUMB PONG v1 (first public release) https://github.com/VinsCool/DUMB-PONG/releases/tag/v1 
