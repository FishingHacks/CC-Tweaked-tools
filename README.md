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

### Custom Commands

By using `register_command` called with the command name and a function that'll be triggered when the command is executed and called with the interaction id and player name, you can register your custom commands. Please make sure to use coroutine.yield() or sleep(0) in heavy computations to give the other commands time to execute as well. Use `get_event` to pull an event out of the eventloop and `wait_for_event_of_type` to wait for an event of a particular type. You also have the `broadcast` function with which you can print something on the players console. Careful tho, you have to call it with the playername and interaction id. The same is true for `read_user_input`. Call it with the playername, interaction id, the prompt, a unique input id and a timeout after which u wanna return nil (or dont specify it/specify nil to last forever). Make sure to use the `event_claim()` function if you want to prevent any other commands from receiving that event. Using the `call_on_all_devices` function you can call a specific function on a wired modem for all devices on it, iex. for an alarm system with a few wired up speakers. The arguments for `call_on_all_devices` are the wired modem, the device type (`speaker` iex), the function name and its arguments. The `dbg` function can be used to print out arbitrary tables

### Background Threads

By calling `register_coroutine` with a function and its arguments (iex. `register_coroutine(function(id) end, 1)` or `register_coroutine(print, "a")`), you can launch background threads. NOTE: THESE WILL PERSIST UNTIL THE **NEXT** RESTART OF THE COMPUTER ITSELF, AND THUS SHOULD **NOT** BE USED INSIDE COMMANDS. USE THEM FOR CONTROLLING YOUR SYSTEM OR SOMETHING ALIKE. MAKE SURE TO `coroutine.yield()` AFTER EACH ITERATION THROUGH A `while true do` LOOP TO GIVE THE OTHER THREADS TIME FOR COMPUTATIONS.
