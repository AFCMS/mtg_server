nuke = {} -- mod-global table

local all_tnt = {}

local creative_is_enabled_for = 
	rawget(_G, "creative") and creative.is_enabled_for or function(name)
	return minetest.settings:get_bool("creative_mode")
end

nuke.spawn_tnt = function(pos, entname)
	assert(table.indexof(all_tnt, entname) ~= -1, "attempting to spawn non-tnt")
	minetest.sound_play("nuke_ignite", {pos = pos, gain = 1.0, max_hear_distance = 16})
	return minetest.add_entity(pos, entname)
end

local function expand_tiles(tiles)
	if #tiles >= 6 then
		return tiles
	end
	local t = table.copy(tiles)
	repeat
		t[#t + 1] = t[#t]
	until #t == 6
	return t
end

local function calculate_velocity(distance, tntradius, mult)
	-- d is the distance vector
	--            tntradius - | d |
	-- vel = d * ------------------- * mult
	--              tntradius - 1
	local q = (tntradius - vector.length(distance)) / (tntradius - 1)
	return vector.multiply(vector.multiply(distance, q), mult)
end

local function activate_if_tnt(nodename, nodepos, tntpos, tntradius)
	local explodetime_short = 4 -- seconds
	local explodetime_vary = 1.5
	if table.indexof(all_tnt, nodename) == -1 then
		return
	end

	local obj = nuke.spawn_tnt(nodepos, nodename)
	obj:setvelocity(calculate_velocity(vector.subtract(nodepos, tntpos), tntradius, {x=3, y=5, z=3}))
	obj:get_luaentity().timer = explodetime_short + math.random(-explodetime_vary, explodetime_vary)
end

local function apply_tnt_physics(tntpos, tntradius)
	local objs = minetest.get_objects_inside_radius(tntpos, tntradius)
	for _, obj in ipairs(objs) do
		local mult = {x=1.5, y=2.5, z=1.5}
		local vel = calculate_velocity(vector.subtract(obj:getpos(), tntpos), tntradius, mult)

		if obj:is_player() then
			if obj:get_hp() > 0 then
				obj:set_hp(obj:get_hp() - 1)
			end
			if obj.add_player_velocity then
				vel = vector.multiply(vel, 10)
				obj:add_player_velocity(vel)
			end
		else
			if table.indexof(all_tnt, obj:get_entity_name()) ~= -1 then
				vel = vector.multiply(vel, 2) -- apply more knockback to tnt entities
			end
			obj:setvelocity(vector.add(obj:getvelocity(), vel))
		end
	end
end


nuke.register_tnt = function(nodename, def)
	def.explodetime = def.explodetime or 10 -- seconds
	if type(def.tiles) ~= "table" then
		local t = def.tiles
		def.tiles = {t .. "_top.png", t .. "_bottom.png", t .. "_side.png"}
	end

	-- register node
	minetest.register_node(nodename, {
		tiles = def.tiles,
		diggable = false,
		description = def.description,
		mesecons = {
			effector = {
				action_on = function(pos, node)
					minetest.remove_node(pos)
					nuke.spawn_tnt(pos, node.name)
					minetest.check_for_falling(pos)
				end,
				action_off = function(pos, node) end,
				action_change = function(pos, node) end,
			},
		},
		on_punch = function(pos, node, puncher)
			minetest.remove_node(pos)
			nuke.spawn_tnt(pos, node.name)
			minetest.check_for_falling(pos)
		end,
	})

	-- register entity
	local entity = {
		physical = true, -- collision
		collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		visual = "cube",
		textures = expand_tiles(def.tiles),
		health = 1, -- number of punches required to defuse

		timer = 0,
		blinktimer = 0,
		blinkstatus = true,
	}
	function entity:on_activate(staticdata)
		self.object:setvelocity({x=0, y=4, z=0})
		self.object:setacceleration({x=0, y=-10, z=0}) -- gravity
		self.object:settexturemod("^[brighten")
	end
	function entity:on_step(dtime)
		self.timer = self.timer + dtime
		local mult = 1
		if self.timer > def.explodetime * 0.8 then -- blink faster before explosion
			mult = 4
		elseif self.timer > def.explodetime * 0.5 then
			mult = 2
		end
		self.blinktimer = self.blinktimer + mult * dtime

		if self.blinktimer > 0.5 then -- actual blinking
			self.blinktimer = self.blinktimer - 0.5
			self.object:settexturemod(self.blinkstatus and "^[brighten" or "")
			self.blinkstatus = not self.blinkstatus
		end

		if self.timer > def.explodetime then -- boom!
			minetest.sound_play("nuke_explode", {pos = pos, gain = 0.8, max_hear_distance = 32})
			def.on_explode(vector.round(self.object:get_pos()))
			self.object:remove()
		end
	end
	function entity:on_punch(hitter)
		self.health = self.health - 1
		if self.health == 0 then -- give tnt node back if defused
			self.object:remove()
			if not creative_is_enabled_for(hitter:get_player_name()) then
				hitter:get_inventory():add_item("main", nodename)
			end
		end
	end
	minetest.register_entity(nodename, entity)

	-- save tnt name
	all_tnt[#all_tnt + 1] = nodename
end


local function on_explode_normal(pos, range)
	local ndef = minetest.registered_nodes[minetest.get_node(pos).name]
	if ndef ~= nil and ndef.groups.water ~= nil then
		apply_tnt_physics(pos, range)
		return -- cancel explosion
	end

	for x=-range, range do
	for y=-range, range do
	for z=-range, range do
		if x*x+y*y+z*z <= range * range + range then

			local nodepos = {x=pos.x+x, y=pos.y+y, z=pos.z+z}
			local n = minetest.get_node(nodepos)
			if n.name ~= "air" and n.name ~= "ignore" then
				activate_if_tnt(n.name, nodepos, pos, range)
				minetest.remove_node(nodepos)
			end

		end
	end
	end
	end
	apply_tnt_physics(pos, range)
end

local function on_explode_split(pos, range, entname)
	for x=-range, range do
	for z=-range, range do
		if x*x+z*z <= range * range then

			local nodepos = vector.add(pos, {x=x, y=0, z=z})
			minetest.add_entity(nodepos, entname)

		end
	end
	end
end


-- Iron TNT

nuke.register_tnt("nuke:iron_tnt", {
	description = "Iron TNT",
	tiles = "nuke_iron_tnt",
	on_explode = function(pos)
		on_explode_normal(pos, 6)
	end,
})

minetest.register_craft({
	output = "nuke:iron_tnt 4",
	recipe = {
		{"", "group:wood", ""},
		{"default:steel_ingot", "default:coal_lump", "default:steel_ingot"},
		{"", "group:wood", ""},
	}
})


nuke.register_tnt("nuke:iron_tntx", {
	description = "Extreme Iron TNT",
	tiles = {"nuke_iron_tnt_top.png", "nuke_iron_tnt_bottom.png", "nuke_iron_tnt_side_x.png"},
	on_explode = function(pos)
		on_explode_split(pos, 3, "nuke:iron_tnt")
	end,
})

minetest.register_craft({
	output = "nuke:iron_tntx 1",
	recipe = {
		{"", "default:coal_lump", ""},
		{"default:coal_lump", "nuke:iron_tnt", "default:coal_lump"},
		{"", "default:coal_lump", ""},
	}
})

-- Mese TNT

nuke.register_tnt("nuke:mese_tnt", {
	description = "Mese TNT",
	tiles = "nuke_mese_tnt",
	on_explode = function(pos)
	on_explode_normal(pos, 12)
	end,
})

minetest.register_craft({
	output = "nuke:mese_tnt 4",
	recipe = {
		{"", "group:wood", ""},
		{"default:mese_crystal", "default:coal_lump", "default:mese_crystal"},
		{"", "group:wood", ""},
	}
})


nuke.register_tnt("nuke:mese_tntx", {
	description = "Extreme Mese TNT",
	tiles = {"nuke_mese_tnt_top.png", "nuke_mese_tnt_bottom.png", "nuke_mese_tnt_side_x.png"},
	on_explode = function(pos)
		on_explode_split(pos, 3, "nuke:mese_tnt")
	end,
})

minetest.register_craft({
	output = "nuke:mese_tntx 1",
	recipe = {
		{"", "default:coal_lump", ""},
		{"default:coal_lump", "nuke:mese_tnt", "default:coal_lump"},
		{"", "default:coal_lump", ""},
	}
})

-- Compatibility aliases

minetest.register_alias("nuke:hardcore_iron_tnt", "nuke:iron_tntx")
minetest.register_alias("nuke:hardcore_mese_tnt", "nuke:mese_tntx")


if minetest.settings:get_bool("log_mods") then
	print("[Nuke] Loaded")
end
