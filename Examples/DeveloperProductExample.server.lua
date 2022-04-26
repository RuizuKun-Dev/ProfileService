local SETTINGS = {
	ProfileTemplate = { Cash = 0 },
	Products = {
		[97662780] = function(profile)
			profile.Data.Cash += 100
		end,
		[97663121] = function(profile)
			profile.Data.Cash += 1000
		end,
	},
	PurchaseIdLog = 50,
}
local ProfileService = require(game.ServerScriptService.ProfileService)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local GameProfileStore = ProfileService.GetProfileStore("PlayerData", SETTINGS.ProfileTemplate)
local Profiles = {}

local function PlayerAdded(player)
	local profile = GameProfileStore:LoadProfileAsync("Player_" .. player.UserId, "ForceLoad")

	if profile ~= nil then
		profile:Reconcile()
		profile:ListenToRelease(function()
			Profiles[player] = nil

			player:Kick()
		end)

		if player:IsDescendantOf(Players) == true then
			Profiles[player] = profile
		else
			profile:Release()
		end
	else
		player:Kick()
	end
end

function PurchaseIdCheckAsync(profile, purchase_id, grant_product_callback)
	if profile:IsActive() ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	else
		local meta_data = profile.MetaData
		local local_purchase_ids = meta_data.MetaTags.ProfilePurchaseIds

		if local_purchase_ids == nil then
			local_purchase_ids = {}
			meta_data.MetaTags.ProfilePurchaseIds = local_purchase_ids
		end
		if table.find(local_purchase_ids, purchase_id) == nil then
			while #local_purchase_ids >= SETTINGS.PurchaseIdLog do
				table.remove(local_purchase_ids, 1)
			end

			table.insert(local_purchase_ids, purchase_id)
			task.spawn(grant_product_callback)
		end

		local result = nil

		local function check_latest_meta_tags()
			local saved_purchase_ids = meta_data.MetaTagsLatest.ProfilePurchaseIds

			if saved_purchase_ids ~= nil and table.find(saved_purchase_ids, purchase_id) ~= nil then
				result = Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end

		check_latest_meta_tags()

		local release_connection = profile:ListenToRelease(function()
			result = result or Enum.ProductPurchaseDecision.NotProcessedYet
		end)
		local meta_tags_connection = profile.MetaTagsUpdated:Connect(function()
			check_latest_meta_tags()
		end)

		while result == nil do
			RunService.Heartbeat:Wait()
		end

		release_connection:Disconnect()
		meta_tags_connection:Disconnect()

		return result
	end
end

local function GetPlayerProfileAsync(player)
	local profile = Profiles[player]

	while profile == nil and player:IsDescendantOf(Players) == true do
		RunService.Heartbeat:Wait()

		profile = Profiles[player]
	end

	return profile
end
local function GrantProduct(player, product_id)
	local profile = Profiles[player]
	local product_function = SETTINGS.Products[product_id]

	if product_function ~= nil then
		product_function(profile)
	else
		warn("ProductId " .. tostring(product_id) .. " has not been defined in Products table")
	end
end
local function ProcessReceipt(receipt_info)
	local player = Players:GetPlayerByUserId(receipt_info.PlayerId)

	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local profile = GetPlayerProfileAsync(player)

	if profile ~= nil then
		return PurchaseIdCheckAsync(profile, receipt_info.PurchaseId, function()
			GrantProduct(player, receipt_info.ProductId)
		end)
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerAdded, player)
end

MarketplaceService.ProcessReceipt = ProcessReceipt

Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]

	if profile ~= nil then
		profile:Release()
	end
end)
