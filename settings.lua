data:extend({
    {
        type = "int-setting",
        name = "procedural-modules-highest-tier",
        setting_type = "startup",
        default_value = 20,
        minimum_value = 4
    },
    {
        type = "int-setting",
        name = "procedural-modules-recipe-exponent",
        setting_type = "startup",
        default_value = -1,
        allowed_values = {-1, 1, 2, 3, 4}
    },
    {
        type = "bool-setting",
        name = "procedural-modules-allow-module-crafting-productivity",
        setting_type = "startup",
        default_value = false,
    },
})