# CC: Tweaked Tools

## Smart Home System

You can use this to remote control your computers. Simply use `wget https://raw.githubusercontent.com/FishingHacks/CC-Tweaked-tools/main/smarthomesystem.lua startup.lua` on the computer you wanna remote control and then customize using `startup.lua`.

You have to configure a few things, most importantly the `device_name`, which lets you identify the device and the `players` variable to set which players are allowed to access it. The `players` variable is a table where the keys are the playernames and the values are their passwords. NOTE: THIS CAN BE SPOOFED. THIS INFO IS NOT SECURE. YOUR PASSWORDS ARE TRANSMITTED **PLAIN TEXT**. DO **NOT** PUT ANY PERSONAL INFO IN YOUR PASSWORDS

Lastly, you have to configure the `modem_side`. Set this to the side you have your modem on. You probably want a wireless modem, even tho wired modems _should_ work. This - however - isn't tested yet.

### Setting up Commands

You of course want to also set up some commands for the computer. There are three default pre-made behaviors: `trigger_redstone`, `toggle_redstone` and `set_redstone`. `trigger_redstone` changes the state of the output for a specific amount of time after it got activated. `toggle_redstone` toggles between 2 states each time its activated. `set_redstone` sets the output to whatever value the user specified. `set_redstone` and `toggle_redstone` can be used together to make something like `toggle machine` and `turn machine on` and `turn machine off`.

- `trigger_redstone` accepts the command name, the side it'll output the signal, the length it should be triggered, the redstone strength for the idling position and the redstone strength for the triggered position as arguments.
- `toggle_redstone` accepts the command name, the side it'll output the signal, the turned on redstone strength, the turned off redstone strength and the initial value that'll be set when the computer turns on.
- `set_redstone` accepts the command name, the side it'll output the signal and the strength it'll set the redstone to.
