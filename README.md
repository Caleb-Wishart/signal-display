# Signal Display

Wish you could view the value of a signal on a display or programmable speaker alert? Now you can!

With this mod placing a pair of square brackets `[]` in the message of a Display will cause it to display the value of the signal currently selected as the icon. Only the first pair of square brackets will be replaced with the value of the signal.

You can also enable the use of rich text formatting in the mod settings to update any rich text item within the message. To get the value of a rich text item it must be immediately followed by a pair of square brackets `[]`, for example `[item=iron-plate][]`. You can have as many rich text items as you want in the message (up to the internal message length limit).

Only displays that are on active surfaces will be updated. Under the context of the mod, an active surface is any surface that a player is currently viewing.

## Examples

Using this mod you can create a quick at a glance display for your factory.

![At a glance fluid display](https://github.com/Caleb-Wishart/signal-display/raw/master/resources/at-a-glance.png)

These displays can also be have the "Show in chart" option enabled to display the signal value on the map.

![Map display](https://github.com/Caleb-Wishart/signal-display/raw/master/resources/map-view.png)

Using these features it is possible to create easy displays to see view your space platform's current speed, the amount of fuel, or whatever you desire.  
The possibilities are endless!

![Space Platform Display](https://github.com/Caleb-Wishart/signal-display/raw/master/resources/space-platform-example.mp4)
![Space Platform Configuration](https://github.com/Caleb-Wishart/signal-display/raw/master/resources/ship-config.png)

Using the rich text formatting you can view the amount of multiple key items using a single display.

![Rich text example](https://github.com/Caleb-Wishart/signal-display/raw/master/resources/key-items.png)

Rich text message:

> [item=automation-science-pack][][item=logistic-science-pack][][item=military-science-pack][][item=chemical-science-pack][][item=utility-science-pack][]

## Warnings

- Placing a large number of Displays at once can cause a noticeable lag spike as each Display is registered with the mod.
- Updating too many displays at once can cause lag, configure based on your computer's performance with the settings.