local flib_locale = require("__flib__.locale")
local n_tiers = settings.startup["procedural-modules-highest-tier"].value - 3 --[[@as number]]
local recipe_exponent = settings.startup["procedural-modules-recipe-exponent"].value --[[@as number]]
local allow_prod = settings.startup["procedural-modules-allow-module-crafting-productivity"].value --[[@as boolean]]

--- Approximates the next number in the sequence using some dumb algorithm
---@param y1 number
---@param y2 number
---@param y3 number
---@return number
local function next_bonus(y1, y2, y3)
	local d1 = y2 - y1
	local d2 = y3 - y2
	if math.abs(d2) < math.abs(d1) then
		-- try ssomething different
		return y3 + d2
	end
	local d3 = d2 + (d2 - d1)
	return y3 + d3
end

local function find_unlock_tech(recipe)
	if recipe == nil then
		return nil
	end
	for _, tech in pairs(data.raw["technology"]) do
		if tech.effects ~= nil then
			for _, eff in pairs(tech.effects) do
				if eff.type == "unlock-recipe" and eff.recipe == recipe then
					return tech
				end
			end
		end
	end
	return nil
end

--- @class ModuleGenParams
--- @field name string
--- @field ordering string
--- @field t1 string
--- @field t2 string
--- @field t3 string
--- @field amount number
--- @field custom_scaling {[string]: MathExpression}

local effects = { "consumption", "speed", "productivity", "pollution", "quality" }
local cap = {
	consumption = 327,
	speed = 327,
	productivity = 327,
	pollution = 327,
	quality = 327,
}

---@param params ModuleGenParams
local function generate_modules(params)
	local t1_data = data.raw["module"][params.t1]
		or error("Some mod removed the module `" .. params.t1 .. "`, unable to compute future levels")
	local t2_data = data.raw["module"][params.t2]
		or error("Some mod removed the module `" .. params.t2 .. "`, unable to compute future levels")
	local t3_data = data.raw["module"][params.t3]
		or error("Some mod removed the module `" .. params.t3 .. "`, unable to compute future levels")

	local mods = {}
	local recipes = {}

	local item_name = flib_locale.of_item(t1_data)
	local icon = t3_data.icon
	local icon_size = t3_data.icon_size or 64
	local expected_icon_size = 64
	local default_scale = (expected_icon_size / 2) / icon_size
	local recipe = data.raw["recipe"][params.t3]
	local unlock_tech = find_unlock_tech(params.t3)

	if allow_prod then
		for _, id in pairs({params.t1, params.t2, params.t3}) do
			local mod_recipe = data.raw["recipe"][id]
			if mod_recipe ~= nil then
				mod_recipe.allow_productivity = true
			end
		end
	end

	local stop = false
	for i = 1, params.amount do
		local next_module = table.deepcopy(t3_data)
		next_module.name = string.format(params.name, i + 3)
		next_module.order = string.format(params.ordering, i + 3)
		next_module.localised_name = { "item-name.proc-mod-name-template", tostring(i + 3), item_name }
		if recipe ~= nil then
			local new_recipe = table.deepcopy(recipe)
			new_recipe.name = next_module.name
			for _, result in pairs(new_recipe.results) do
				if result.name == params.t3 then
					result.name = next_module.name
				end
			end
			local detected_exponent = recipe_exponent
			for _, ing in pairs(new_recipe.ingredients) do
				if ing.name == params.t2 then
					ing.name = t3_data.name
					if recipe_exponent ~= -1 then
						ing.amount = recipe_exponent
					else
						detected_exponent = ing.amount
					end
				end
			end
			if new_recipe.main_product == params.t3 then
				new_recipe.main_product = next_module.name
			end
			recipes[#recipes + 1] = new_recipe
			if allow_prod then
				new_recipe.allow_productivity = true
				new_recipe.maximum_productivity = detected_exponent - 1
			end

			if unlock_tech ~= nil then
				table.insert(unlock_tech.effects, {
					type = "unlock-recipe",
					recipe = new_recipe.name,
				})
			end
		end
		if icon ~= nil then
			next_module.icon = nil
			next_module.icons = {}
			if i <= 11 then
				for n = 1, (i + 1) do
					local t = (2 * math.pi * n / (i + 1) + 0.25 * math.pi) % (2 * math.pi)
					local x = math.cos(t)
					local y = math.sin(t)
					next_module.icons[#next_module.icons + 1] = {
						icon = icon,
						icon_size = icon_size,
						draw_background = true,
						shift = { x * (i ^ 0.75 + 3), y * (i ^ 0.75 + 3) },
						scale = default_scale / math.sqrt(i),
					}
				end
			else
				for n = 1, (i + 1) do
					local t = (2 * math.pi * n / (i + 1) + 0.5 * math.pi) % (2 * math.pi)
					local a = 1.5
					local x = (a * math.sqrt(2) * math.cos(t)) / (math.sin(t) ^ 2 + 1)
					local y = (a * math.sqrt(2) * math.cos(t) * math.sin(t)) / (math.sin(t) ^ 2 + 1)
					next_module.icons[#next_module.icons + 1] = {
						icon = icon,
						icon_size = icon_size,
						draw_background = true,
						shift = { x * (i ^ 0.75 + 1), y * (i ^ 0.75 + 1) },
						scale = default_scale / math.sqrt(i),
					}
				end
			end
		end
		for _, effect in pairs(effects) do
			local y1 = t1_data.effect[effect]
			local y2 = t2_data.effect[effect]
			local y3 = t3_data.effect[effect]
			if y1 ~= nil and y2 ~= nil and y3 ~= nil then
				local next_effect
				if params.custom_scaling[effect] then
					next_effect = helpers.evaluate_expression(
						params.custom_scaling[effect],
						{ y1 = y1, y2 = y2, y3 = y3, T = (i + 3) }
					)
				else
					next_effect = next_bonus(y1, y2, y3)
				end
				if math.abs(next_effect) > cap[effect] then
					stop = true
					if next_effect < 0 then
						next_effect = -cap[effect]
					else
						next_effect = cap[effect]
					end
				end
				next_module.effect[effect] = next_effect
			end
		end
		t1_data = t2_data
		t2_data = t3_data
		t3_data = next_module
		mods[#mods + 1] = next_module
		if stop then
			break
		end
	end
	data:extend(mods)
	data:extend(recipes)
end

generate_modules({
	name = "proc-speed-module-%s",
	ordering = "a[speed]-d[speed-module-%06d]",
	t1 = "speed-module",
	t2 = "speed-module-2",
	t3 = "speed-module-3",
	amount = n_tiers,
	custom_scaling = {},
})

generate_modules({
	name = "proc-efficiency-module-%s",
	ordering = "c[efficiency]-d[efficiency-module-%06d]",
	t1 = "efficiency-module",
	t2 = "efficiency-module-2",
	t3 = "efficiency-module-3",
	amount = n_tiers,
	custom_scaling = {},
})

generate_modules({
	name = "proc-productivity-module-%s",
	ordering = "c[productivity]-d[productivity-module-%06d]",
	t1 = "productivity-module",
	t2 = "productivity-module-2",
	t3 = "productivity-module-3",
	amount = n_tiers,
	custom_scaling = {},
})

if mods["quality"] then
	generate_modules({
		name = "proc-quality-module-%s",
		ordering = "d[quality]-d[quality-module-%06d]",
		t1 = "quality-module",
		t2 = "quality-module-2",
		t3 = "quality-module-3",
		amount = n_tiers,
		custom_scaling = {},
	})
end
