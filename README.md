# Chem Lab

A breaking bad inspired cooking simulator where players race against the time to "cook" (almost) chemically accurate crystals before the night ends. This is a 3D first-person game made in Godot.

## Gameplay

The game begins with a start screen reminiscent of the show's intro with the first two letters of each word replacede by chemical elements Carbon and Lanthanum. On pressing start, the game pans to an exterior view of the RV in a desert/plains environment. After a few seconds, the game pans to the inside of the van, explains the gameplay in a few sentences to the player, before initiating the cooking cycle. The player follows the on-screen instructions, fetching the proper lab equipment and ingredients. If complete within 4 minutes, they continue on to the next round.

## Images

| Gameplay                       | --                            |
| ------------------------------ | ----------------------------- |
| ![Intro](/images/Title.png)    | ![Intro](/images/Van.png)     |
| ![Intro](/images/LabIntro.png) | ![Intro](/images/Cooking.png) |

## Credits

| Inspo                                                                                                                                                     | --                                                                              |
| --------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| ![Royale high baking classroom](https://static.wikia.nocookie.net/royale-high/images/5/5b/Baking_Class_RH1_%26_RH2.png/revision/latest?cb=20240810185835) | The baking clas from Royale high (which apparently has a physical playset now?) |
| ![Breaking bad opening credits](https://i.ytimg.com/vi/ilfYnhXD-bE/maxresdefault.jpg)                                                                     | UI from Breaking Bad intro                                                      |
| ![Breaking bad van](https://static.wikia.nocookie.net/breakingbad/images/d/d6/RV.jpg/revision/latest?cb=20130724193305)                                   | The RV/Van from Breaking bad                                                    |

<div>Icons made from <a href="https://www.onlinewebfonts.com/icon">svg icons</a> licensed by CC BY 4.0</div>


advice for amoolie

keep learning how to integrate AI - using godot mcp, install
```
claude mcp add godot -- npx @coding-solo/godot-mcp
claude mcp add godot -e GODOT_PATH=/path/to/godot -e DEBUG=true -- npx @coding-solo/godot-mcp

claude mcp add godot -e /Users/emilyahmad/Desktop/projects/chem-lab=/path/to/godot -e DEBUG=true -- npx @coding-solo/godot-mcp

```
where 
| Variable |	Description |
| -- | -- |
| GODOT_PATH |	Path to the Godot executable (overrides automatic detection) |
| DEBUG	| Set to "true" to enable detailed server-side debug logging |
