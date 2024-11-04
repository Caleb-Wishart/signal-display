data:extend({
    {
        type = "int-setting",
        name = "sigd-update-nth-tick",
        order = "aa",
        setting_type = "runtime-global",
        default_value = 2,
        minimum_value = 1,
        maximum_value = 60, -- once per second
    },
    {
        type = "int-setting",
        name = "sigd-updates-per-tick",
        order = "ab",
        setting_type = "runtime-global",
        default_value = 10,
        minimum_value = 1,
        maximum_value = 100, -- processing too many displays per tick will produce lag spikes
    },
    {
        type = "bool-setting",
        name = "sigd-search-rich-text",
        order = "ac",
        setting_type = "runtime-global",
        default_value = false, -- disable this if you're experiencing lag spikes
    },
})
