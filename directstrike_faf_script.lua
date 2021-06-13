--------------------------------------------------------------------------------
--Made by Paralon ©

--see also https://github.com/P4r4lon/directstrike

--------------------------------------------------------------------------------

local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local ScenarioFramework = import('/lua/ScenarioFramework.lua')
local Utilities = import('/lua/utilities.lua')
local OpStrings = import('/maps/directstrike_faf.v0045/directstrike_faf_strings.lua')
local restrictions = (categories.BUILTBYTIER1ENGINEER - categories.DIRECTFIRE) + (categories.BUILTBYTIER2ENGINEER - categories.DIRECTFIRE) + (categories.BUILTBYTIER3ENGINEER - categories.DIRECTFIRE - (categories.LAND - categories.ARTILLERY * categories.CYBRAN))
-- local Objectives = import('/lua/ScenarioFramework.lua').Objectives

function OnPopulate()
	ScenarioInfo.Options.Victory = 'sandbox'
    	ScenarioUtils.InitializeArmies()
    	ScenarioFramework.SetPlayableArea('AREA_1' , false)
	fixSpreadAttack()
	import('/lua/selfdestruct.lua').ToggleSelfDestruct = function(data) end
	import('/lua/SimUtils.lua').GiveUnitsToPlayer = function() end
	for index,army in ListArmies() do 
		if not (army == 'ARMY_17' or army == 'ParagonArmy1' or army == 'ParagonArmy2' or army == 'SupportArmy1') then 
			ScenarioFramework.AddRestriction(army, restrictions)
		end
	end 
	
	-- ScenarioInfo.CampaignMode = true
    	-- Sync.CampaignMode = true
	-- import('/lua/sim/simuistate.lua').IsCampaign(true)

end

function OnStart(scenario)
	--Utilities.UserConRequest("ui_RenderCustomNames 1") doesnt works	
	ForkThread(mainchain)
end

local StartPoints = ScenarioInfo.Options.StartCash or 100 --how many points will u have at the start to buy your first unit

local WaveTimer =  ScenarioInfo.Options.WaveTimer or 30 --how many seconds will you wait before the next wave

local income = ScenarioInfo.Options.Income or 1	--how many points will u gain every seconds from the 00:00

local WipeWave = ScenarioInfo.Options.Wipe or 10 --how many waves will you buy one unit for

local ExpWipeWave = ScenarioInfo.Options.ExpWipe or 1 --same but for exp

local Language = ScenarioInfo.Options.Language or 'EN' --loc

local Manual = ScenarioInfo.Options.Manual or 'true' --start taunts with short manual 

local HeroesOn = ScenarioInfo.Options.HeroesOn or 0 --feel the pain

if Manual == 'true' then Manual = true else Manual = false end 
local gameEnd = false 
local wt = WaveTimer
local Factions = {'UEF', 'AEON', 'CYBRAN', 'SERAPHIM'}
local SupArmies = {}
local Bunkers = {[1] = {unit = nil, pds = {}, pds2 = {}}, [2] = {unit = nil, pds = {}, pds2 = {}}} 
 
local WaveCounter = 0

----------------------------------------------------------------------------------------------------------------------------------------
local Humans = {
	['player1'] = {ArmySet = {bp=nil, buyWave=nil}},
	['player2'] = {ArmySet = {bp=nil, buyWave=nil}},
	['player3'] = {ArmySet = {bp=nil, buyWave=nil}},
	['player4'] = {ArmySet = {bp=nil, buyWave=nil}}, 
	['player5'] = {ArmySet = {bp=nil, buyWave=nil}},
	['player6'] = {ArmySet = {bp=nil, buyWave=nil}},
}

local DefaultData = {
	ArmyId = nil,
	cashpoints = 0,
	pos = {},
	rallypointunit = {},
	rallypoint = {},
	unit = {},
	index = nil,
	multiplier = income,
	cashextractor = nil,
	exinc = 0,
	structs = {},
	numstructs = 0,
	teamindex = 1,
	coeff = 0.1,
	omni = nil,
	IsBot = false
}

local ArmyTable = {}
local CashexCost = 1000
local OmniCost = 5000

local Rulesdialogue = nil 
local Playerdialogue = nil 
local ObsDialogue = nil

local timer = nil
local strings = {}
local dialogueargs = {}

local Rutaunts = {OpStrings.part0RU, OpStrings.part1RU, OpStrings.part2RU}
local Entaunts = {OpStrings.part0EN, OpStrings.part1EN, OpStrings.part2EN}
local taunts = {}


-------------------units that can be purchased--------------------------------------------------------------------------------------------------------------------
local CybranArmySet = {
'URL0101',
'URL0106',
'URL0107',
'URL0104',
'URL0103',
'DRL0204',
'URL0202',
'URL0203',
'URL0205',
'URL0111',
'URL0306',
'XRL0302',
'URL0303',
'XRL0305',
'DRLK001',
'URL0304',
'URL0402',
'XRL0403',
'URA0101',
'URA0302',
'URA0103',
'DRA0202',
}

local AeonArmySet = {
'UAL0101',
'UAL0106',
'UAL0201',
'UAL0104',
'UAL0103',
'UAL0202',
'XAL0203',
'UAL0205',
'UAL0111',
'UAL0307',
'XAL0305',
'UAL0303',
'DALK003',
'UAL0304',
'DAL0310',
'UAL0401',
'UAA0101',
'UAA0302',
'UAA0103',
'DAA0206',
'XAA0202'
}

local UefArmySet = {
'UEL0101',
'UEL0106',
'UEL0201',
'UEL0104',
'UEL0103',
'DEL0204',
'UEL0202',
'UEL0203',
'UEL0205',
'UEL0111',
'UEL0307',
'UEL0303',
'DELK002',
'UEL0304',
'XEL0305',
'XEL0306',
'UEL0401',
'UEA0101',
'UEA0302',
'UEA0103',
'DEA0202',
}

local SeraArmySet = {
'XSL0101',
'XSL0201',
'XSL0104',
'XSL0103',
'XSL0202',
'XSL0203',
'XSL0205',
'XSL0111',
'XSL0303',
'XSL0305',
'DSLK004',
'XSL0304',
'XSL0307',
'XSL0401',
'XSA0101',
'XSA0302',
'XSA0103',
'XSA0202',
}

local Heroes = {'URL0301', 'UAL0301_SIMPLECOMBAT', 'UEL0301_COMBAT', 'XSL0301'}

local Experimentals = {'xsl0401', 'ual0401', 'url0402', 'xrl0403', 'uel0401'} --nerf'em all

--------supplementing--------------------------------------------------------------------------------------------------------------------------------
PushData = function()
	for i, h in Humans do
		for j, val in DefaultData do 
			h[j] = val
		end
	end
end

function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function LOC(s)
	if s != nil then  
		return (string.gsub(s, '^<[^>]*>', ''))
	end
end

function GetStringFromArray(arr)
local str = '' 
	for i,a in arr do
		str = str..""..a.."\n"
	end
	return str 
end

function comparepositions(pos1, pos2)
	local counter = 0
	for i = 1, 3 do 
		if pos1[i] == pos2[i] then 
			counter = counter + 1 
		end
	end
	if counter == 3 then 
		return true 
	else 
		return false 
	end
end

RandomizePosition = function(pos)
	local nx = Random(-15,15)
	local nz = Random(-15,15)
	local flag = Random(0,1)
	local newpos = {}
	newpos[2] = pos[2]
	if flag then 
		newpos[1] = pos[1] + nx 
		newpos[3] = pos[3] + nz
	else 
		newpos[1] = pos[1] - nx 
		newpos[3] = pos[3] - nz
	end
	return newpos 
end

function fillSupArmies()
	for i = 1, 6 do 
		local army = 'SupportArmy'..i 
		SupArmies[i] = army
	end
end

function ArmyToPlayer(army)
	for i, a in ArmyTable do
		if ArmyTable[i] == army then return i end
	end
end

function returnTeammates(i)
	local nums = {}
	for j, h in Humans do 
		if Humans[i].teamindex == Humans[j].teamindex then		
			table.insert(nums, j)
		end
	end
	return nums
end


ResetTargets = function(units)
	while true do 
		for i, u in units do
			if not u:IsDead() then 
				WaitSeconds(0.45)
				u:GetWeapon(1):ResetTarget()
			end
		end
	end
end
----------------------------------------------------------


----rural localization----
function LanguageSettings()     
	if Language == 'EN' then 
		strings = {['cashextractor'] = 'U have CashExtractor now! Сan only be purchased 1 time', ['nomoney'] = 'not enough money', ['inurcoll'] = ' in ur collection for ',['wave'] = ' wave(s)', ['wrunit'] = 'Wrong unit', ['murder'] = ' For murder'}
		dialogueargs =  {['cashpoints'] = 'cashpoints = ', ['income'] = 'income = ', ['wavetimer'] = 'next wave in ', ['wavecounter'] = 'wave № '}
		taunts = Entaunts
		PrintText('"Always Render Custom Names" must be on (Options-> interface)',28,"FF5F01A7",5,'center') 
	else 
		strings = {['cashextractor'] = 'Теперь у вас есть кеш-экстрактор, который можно купить только 1 раз', ['nomoney'] = 'недостаточно денег', ['inurcoll'] = ' в вашем наборе на ', ['wave'] = ' волн(ы)', ['wrunit'] = 'Неподходящий юнит', ['murder'] = ' За убийство'}
		dialogueargs =  {['cashpoints'] = 'деньги = ', ['income'] = 'добыча = ', ['wavetimer'] = 'след волна: ', ['wavecounter'] = 'волна №'}
		taunts = Rutaunts
		PrintText('"Включите настройку "Всегда показывать имена" во вкладке интерфейс',28,"FF5F01A7",5,'center') 
	end
end
-------players init-------------------
function GetPlayersOnline()
	PushData()
	for i, Army in ListArmies() do
		if (Army == "ARMY_1" or Army == "ARMY_2" or Army == "ARMY_3" or Army == "ARMY_4" or Army == "ARMY_5" or Army == "ARMY_6") then
			index = GetArmyBrain(Army):GetArmyIndex()
			ArmyTable[index] = Army	
			for k, player in Humans do 
				local name = 'player'..index
				if name == k then
					if not (GetArmyBrain(Army).BrainType == 'Human') then Humans[k].IsBot = true end
					Humans[k].ArmyId = index
				--	LOG('army id', Humans[k].ArmyId)
					Humans[k].pos = ScenarioUtils.GetMarker(Army).position
					Humans[k].cashpoints = StartPoints							
				end
			end			
		end
	end  
	
	local ally = 0
	for i, h in Humans do 
		if Humans[i].ArmyId != nil then 
			if IsAlly(Humans['player1'].ArmyId, Humans[i].ArmyId) and ally == 0 then 
				ally = Humans[i].ArmyId
				break
			end
		end
	end
	
	for i, h in Humans do		
		if h.ArmyId != nil and not IsAlly(h.ArmyId, ally) then
			h.teamindex = 2				
		end	
	end	
	LOG(repr(Humans))
	ForkThread(CumBackSystem)
end

function dialoguemanager()
	if GetFocusArmy() == -1 then 
		ObsDialogue = CreateDialogue("",{'','','','','','','','','','','','','',''},'right')
	end
	--ForkThread(ftimer)
	for i, h in Humans do 
		if (GetFocusArmy() == h.ArmyId) then 
			Playerdialogue = CreateDialogue("",{dialogueargs['cashpoints']..math.floor(h.cashpoints), dialogueargs['income']..h.multiplier, dialogueargs['wavetimer']..WaveTimer, dialogueargs['wavecounter']..WaveCounter},'right')
			--Rulesdialogue = CreateDialogue("Buy units of your race for in-game currency-cashpoints using ur worker. Assist any unit u want and he will be added to ur collection. Collection will be spawned every wave. Kill side structures and get more cash. The bonus-structures will give u stable income just like cashextractor that u can buy on base. Structures will move from player to player when they are killed. The main objective is kill the enemy bunker after his death the game will be end. Good luck!",{"close window"},'left')
		end
	end	
	if Rulesdialogue != nil then 
		Rulesdialogue.OnButtonPressed = function(self, info)	
			if GetFocusArmy() == info.presser then
				Rulesdialogue:Destroy()
			end
		end	
	end
	
	local WipeCounter = 0
	while true do 
		WaitSeconds(1)
		if WipeCounter == 1 then 
			WipeThemAll()
			WipeCounter = 0
		end
		
		local namebut = 1
		local cashbut = 2

--			if GetFocusArmy() == h.ArmyId then 
				wt = wt - 1
				if wt == 0 then
					wt = WaveTimer 
					WipeCounter = WipeCounter + 1
					WaveCounter = WaveCounter + 1  
				end 	



		if ObsDialogue != nil then 
			for i, h in Humans do
				if (h.ArmyId != nil) then 
					ObsDialogue:UpdateButtonText(namebut, GetArmyBrain(h.ArmyId).Nickname)
					ObsDialogue:UpdateButtonText(cashbut,math.floor(h.cashpoints))
					namebut = namebut + 2
					cashbut = cashbut + 2
				end				
			end
			ObsDialogue:UpdateButtonText(13, dialogueargs['wavetimer']..wt)
			ObsDialogue:UpdateButtonText(14, dialogueargs['wavecounter']..WaveCounter)
		end



		for i, h in Humans do 	
			if (GetFocusArmy() == h.ArmyId) and (Playerdialogue != nil) then 
				Playerdialogue:UpdateButtonText(1, dialogueargs['cashpoints']..math.floor(Humans[i].cashpoints))
				Playerdialogue:UpdateButtonText(2, dialogueargs['income']..math.floor(Humans[i].multiplier + Humans[i].exinc + Humans[i].numstructs * math.pow(WaveCounter, 0.5) * 1.2 ))
				Playerdialogue:UpdateButtonText(3, dialogueargs['wavetimer']..wt) 
				Playerdialogue:UpdateButtonText(4, dialogueargs['wavecounter']..WaveCounter)
			end
		end
	end	
end

---the cleaner of your potential troop recruitment---
function WipeThemAll()  ---
	for i, h in Humans do
		for k, u in h.ArmySet do
			local wipe = WipeWave
			if table.contains(Experimentals, u.bp) then 
				wipe = ExpWipeWave
			elseif table.contains(Heroes, string.upper(u.bp)) then 
				wipe = 1
			end
			if (WaveCounter - (u.buyWave + wipe)) >= 0 then
				h.ArmySet[k] = nil
			end
		end
	end
end

---default shop units---
function CreateDefSet()
	if HeroesOn == 1 then 
		table.insert(AeonArmySet, 'UAL0301_SIMPLECOMBAT')
		table.insert(CybranArmySet, 'URL0301')
		table.insert(UefArmySet, 'UEL0301_COMBAT')
		table.insert(SeraArmySet, 'XSL0301')
	end
	
	for i = 1, 2 do
		local alignment = 0
		local pos = ScenarioUtils.MarkerToPosition('MainBunker'..i)
		if i == 1 then 
			alignment = 20
		else 
			alignment = -20
		end
		local cashextractor = CreateUnitHPR('urc1902','ParagonArmy'..i, pos[1], pos[2], pos[3] + alignment, 0,0,0);
		cashextractor:SetCustomName('cashextractor '..CashexCost)
		cashextractor:SetCanBeKilled(false)
		cashextractor:HideBone(0, true)
		cashextractor.Big = import('/lua/sim/Entity.lua').Entity({Owner = cashextractor,})
       		cashextractor.Big:SetMesh(cashextractor:GetBlueprint().Display.MeshBlueprint, true)
       		cashextractor.Big:SetScale(0.3)
       		cashextractor.Big:AttachBoneTo(0, cashextractor, 0)
			
		local omni = CreateUnitHPR('UEB3104','ParagonArmy'..i, pos[1], pos[2], pos[3] + alignment + alignment/2, 0,0,0);	
		omni:SetCustomName('OMNI sensor '..OmniCost)
		omni:SetCanBeKilled(false)
		omni:SetIntelRadius('Radar', 1)
		omni:SetIntelRadius('Omni', 1)
		omni.Big = import('/lua/sim/Entity.lua').Entity({Owner = omni,})
       		omni.Big:SetMesh(omni:GetBlueprint().Display.MeshBlueprint, true)
       		omni.Big:SetScale(0.3)
       		omni.Big:AttachBoneTo(0, omni, 0)
	end
	
	MakeSomeRallyPoints()
	for i,h in Humans do 
		if  Humans[i].ArmyId != nil then 
			--if not i < HumansQuantity then 
			
			local index = GetArmyBrain(Humans[i].ArmyId):GetFactionIndex()	
			GetArmyBrain(Humans[i].ArmyId):GiveStorage('Energy', 5000)
			Humans[i].index = index
			Humans[i].unit = CreateUnitHPR('UAL0105', ArmyTable[Humans[i].ArmyId], Humans[i].pos[1] - 15, Humans[i].pos[2], Humans[i].pos[3], 0,0,0);
			Humans[i].unit:SetSpeedMult(0)
			Humans[i].unit:SetCustomName(Humans[i].cashpoints)
			Humans[i].unit:SetProductionPerSecondEnergy(10000)
			Humans[i].unit:UpdateConsumptionValues()
			Humans[i].unit:SetCanBeKilled(false)
			Humans[i].unit:HideBone(0, true)
			Humans[i].unit.Big = import('/lua/sim/Entity.lua').Entity({Owner = Humans[i].unit,})
			Humans[i].unit.Big:SetMesh(Humans[i].unit:GetBlueprint().Display.MeshBlueprint, true)
			Humans[i].unit.Big:SetScale(0.3)
			Humans[i].unit.Big:AttachBoneTo(0, Humans[i].unit, 0)
			local nset = Factions[index]
		
			if nset == 'UEF' then 
				UnitManager(UefArmySet, i)
			elseif nset == 'AEON' then 
				UnitManager(AeonArmySet, i)
			elseif nset == 'SERAPHIM' then 
				UnitManager(SeraArmySet, i)
			elseif nset == 'CYBRAN' then 
				UnitManager(CybranArmySet, i)
			end
			---special stuff

		end
	end
	--ForkThread(MakeAIsAlive)
end 

function UnitManager(set, i)
	local counter = 0
	local column = Humans[i].pos[3]
	for k, u in set do 
		if counter == 6 then column = column + 7.5 counter = 0 end 
		SetAlliance('SupportArmy'..Humans[i].ArmyId, ArmyTable[Humans[i].ArmyId], 'Ally')
		local newunit = CreateUnitHPR(u, 'SupportArmy'..Humans[i].ArmyId, Humans[i].pos[1] + 7.5 * counter, Humans[i].pos[2], column, 0,0,0);
		newunit:SetCanBeKilled(false)
		local cost = CostFix(newunit)
		newunit:SetCustomName(cost)
		if table.contains(Heroes, u) then 
			newunit:SetCustomName('HERO '..cost)
		end
		
		newunit:SetIntelRadius('Vision', 1)
		newunit:SetIntelRadius('Radar', 1)
		newunit:SetIntelRadius('Omni', 1)
		
		newunit.OnMotionVertEventChange = function(self, new, old) end
		counter = counter + 1
	end
end

CostFix = function(unit)
	if unit != nil then 
		local bp = unit:GetBlueprint()
		local fix = 1
		if EntityCategoryContains(categories.ARTILLERY - categories.EXPERIMENTAL, unit) or EntityCategoryContains(categories.SNIPER - categories.EXPERIMENTAL, unit) or EntityCategoryContains(categories.SILO * categories.TECH3, unit) then fix = 5 end 
		if EntityCategoryContains(categories.ARTILLERY * categories.EXPERIMENTAL, unit)  then fix = 2 end 
		if EntityCategoryContains(categories.SNIPER * categories.EXPERIMENTAL, unit)  then fix = 1.3 end 
		if EntityCategoryContains(categories.BOMBER, unit) then fix = 3 end 
		if EntityCategoryContains(categories.TECH2, unit) then fix = 2 end 
		if EntityCategoryContains(categories.TECH3 - categories.ARTILLERY - categories.SNIPER - categories.SILO, unit) then fix = 3 end 	
		if EntityCategoryContains(categories.SHIELD - categories.DIRECTFIRE, unit) then fix = 3 end 
		if EntityCategoryContains(categories.SUBCOMMANDER - categories.SERAPHIM - categories.AEON, unit) then fix = 30 end
		if EntityCategoryContains(categories.AIR * categories.TECH2, unit) then fix = 4 end 
		if EntityCategoryContains(categories.SUBCOMMANDER * categories.SERAPHIM, unit) then fix = 54 end
		if EntityCategoryContains(categories.SUBCOMMANDER * categories.AEON, unit) then fix = 35 end
		if EntityCategoryContains(categories.SUBCOMMANDER * categories.CYBRAN, unit) then fix = 53 end
		
	return bp.Economy.BuildCostMass * fix 
	end
end
---------------------------------------------------


-------The more control points u have the less cash provided from kills--------
CumBackSystem = function() 
	while true do
	local counter1 = 0
	local counter2 = 0
		WaitSeconds(1)
		for i, h in Humans do 
			if h.teamindex == 1 then			
				counter1 = counter1 + h.numstructs 
			else 
				counter2 = counter2 + h.numstructs 
			end
		end
		
		for i, h in Humans do 
			if h.teamindex == 1 then
				if counter1 == 0 then counter1 = 0.8 end
				local perem = 1/(counter1*((WipeWave/10)+0.5))
				if perem > 0.5 then perem = 0.5 end
				h.coeff = perem
			else 
				if counter2 == 0 then counter2 = 0.8 end
				local perem = 1/(counter2*((WipeWave/10)+0.5))
				if perem > 0.5 then perem = 0.5 end
				h.coeff = perem
			end
		end		
	end
end

-----------------------shop-listener-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function shopchecker()
	while gameEnd == false do 
		coroutine.yield(1)
		for i, hum in Humans do 
			if Humans[i].ArmyId != nil then 
				GetArmyBrain(Humans[i].ArmyId):TakeResource('Mass', GetArmyBrain(Humans[i].ArmyId):GetEconomyStored('Mass')) -- crutch for fuckers who wanna build city 
				local unit = Humans[i].unit
				if not unit:IsDead() then 
					unit:SetCustomName(math.floor(Humans[i].cashpoints))
					Humans[i].cashpoints = Humans[i].cashpoints +0.1*Humans[i].multiplier + 0.1*Humans[i].exinc
	
					
					local str = strings['nomoney']
					local guarded = unit:GetGuardedUnit()
					if guarded != nil then 

						
						local bp = guarded:GetBlueprint()
						local id = bp.BlueprintId
						
						if id == 'urc1902' then 					
							if Humans[i].cashextractor == nil then
								if CashexCost <= Humans[i].cashpoints then 
									CreateCashExtractor(i)
									if GetFocusArmy() == Humans[i].ArmyId then 
										PrintText(strings['cashextractor'], 28, "FF5F01A7",5,'center') 
									end
								end
							end
						elseif id == 'ueb3104' then 
							if Humans[i].omni == nil or (Humans[i].omni:IsDead()) then 
								if OmniCost <= Humans[i].cashpoints then
									CreateOmni(i)
								else
									print(str)
								end
							end			
						else
							local FlagToResp = false 
							local factionname = (string.upper(bp.General.FactionName))
							local cost = CostFix(guarded)
							local name = LOC(bp.General.UnitName)
							if factionname == Factions[Humans[i].index] and CheckUnit(string.upper(id)) == true then 
								if cost != nil and id != nil then 
									if cost <= Humans[i].cashpoints then 
										ItsNowUrUnit(Humans[i].ArmyId, cost, id)
										local text = ''

										if name != nil or (id == 'xsl0301') then 
											local w = WipeWave..strings['wave']
											if table.contains(Experimentals, id) == true then 
												w = ExpWipeWave..'wave(s)'
											end
											
											if name then text = '+ '..name..strings['inurcoll']..w end 
											
											if table.contains(Heroes, string.upper(id)) then 
												text = 'HERO incoming'
											end
											
											if GetFocusArmy() == Humans[i].ArmyId then 
												PrintText(text, 28, "FF5F01A7", 5, 'center')
											end
											
										end
									elseif GetFocusArmy() == Humans[i].ArmyId and cost != 99999999 then
										print (str)	
									end
								end
								
							else FlagToResp = true 
								if GetFocusArmy() == Humans[i].ArmyId then PrintText(strings['wrunit'], 28, "FF5F01A7", 5, 'center')	end
								if FlagToResp == true then 
									HumanUnitRespawn(Humans[i].ArmyId)
								end
							end							
						end
					end
				end
			end 
		end
	end
end

function CheckUnit(bid) --you can only buy units of ur race 
	local flag = false 
	if table.contains(AeonArmySet, bid) then flag = true end 
	if table.contains(CybranArmySet, bid) then flag = true end 
	if table.contains(UefArmySet, bid) then flag = true end 
	if table.contains(SeraArmySet, bid) then flag = true end 
	return flag
end

function CreateCashExtractor(i)
	Humans[i].cashextractor = CreateUnitHPR('urc1902',ArmyTable[Humans[i].ArmyId], Humans[i].pos[1] - 20, Humans[i].pos[2], Humans[i].pos[3] + 15, 0,0,0);
	Humans[i].cashextractor:SetCanBeKilled(false)
	Humans[i].cashpoints = Humans[i].cashpoints - CashexCost
	ForkThread(morecash, i)
end

function CreateOmni(i)
	local POS = ScenarioUtils.MarkerToPosition('SpawnPoint'..ArmyTable[Humans[i].ArmyId])
	Humans[i].omni = CreateUnitHPR('UEB3104', 'ParagonArmy'..Humans[i].teamindex, POS[1],  POS[2], POS[3], 0,0,0);
	Humans[i].omni:SetMaxHealth(1000)
	Humans[i].omni:SetHealth(nil, 1000)	
	Humans[i].cashpoints = Humans[i].cashpoints - OmniCost
	HumanUnitRespawn(Humans[i].ArmyId)
	Humans[i].omni.CreateWreckageProp = function(self, overkillRatio) end
end


morecash = function(i) --you now have extra cash income from cashextractor
	local inc = math.pow(WaveCounter, 0.5)
	if Humans[i].cashextractor != nil then 
		Humans[i].cashextractor:SetCustomName('+ '..math.floor(inc))
		Humans[i].exinc = inc	
		while true do 
			WaitSeconds(1)
			if wt == WaveTimer then  
				inc = math.pow(WaveCounter, 0.5) * 4
				Humans[i].cashextractor:SetCustomName('+ '..math.floor(inc))
				Humans[i].exinc = inc
			end
		end
	end
end
---------adds the unit you bought to your pack and takes your money-------
function ItsNowUrUnit(ArmyId, cost, id) 
	for i, h in Humans do 

		if (h.ArmyId == ArmyId) then 
		
			h.cashpoints = h.cashpoints - cost
			local m = {}
			m.bp = id
			m.buyWave = WaveCounter
		--	LOG(repr(h.cashpoints))
		
			table.insert(h.ArmySet, m)
			LOG('INSERTED')
			--LOG('u are in army now', repr(h.ArmySet))
		end
	end
	HumanUnitRespawn(ArmyId)

end

function HumanUnitRespawn(ArmyId) --to reset current goal kill the buddy 
	for i, h in Humans do 
		if h.ArmyId == ArmyId then 
			h.unit:SetCanBeKilled(true)
			h.unit:Destroy()
			h.unit.Big:Destroy()
			h.unit = nil 
			h.unit = CreateUnitHPR('UAL0105', ArmyTable[Humans[i].ArmyId], Humans[i].pos[1] - 15, Humans[i].pos[2], Humans[i].pos[3], 0,0,0);
			h.unit:SetSpeedMult(0)
			h.unit:SetCustomName(Humans[i].cashpoints)
			h.unit:SetProductionPerSecondEnergy(10000)
			h.unit:UpdateConsumptionValues()
			h.unit:SetCanBeKilled(false)
			h.unit:PlayTeleportInEffects()
			h.unit:HideBone(0, true)
			h.unit.Big = import('/lua/sim/Entity.lua').Entity({Owner = h.unit,})
			h.unit.Big:SetMesh(h.unit:GetBlueprint().Display.MeshBlueprint, true)
			h.unit.Big:SetScale(0.3)
			h.unit.Big:AttachBoneTo(0, h.unit, 0)			
		end
	end
end
-----------------------future things-----------------------
-- function MakeAIsAlive()
	-- while true do
	-- WaitSeconds(0.5)
		-- for i, h in Humans do
	
			-- if (h.IsBot == true) and (h.ArmyId != nil) then
				-- local trajectory = 0
				-- local mainpos = {}
				-- if h.teamindex == 1 then 
					-- trajectory = 300
					-- mainpos = ScenarioUtils.MarkerToPosition('MainBunker2')
				-- else
					-- trajectory = -300
					-- mainpos = ScenarioUtils.MarkerToPosition('MainBunker1')
				-- end
				
				-- local units = GetArmyBrain(h.ArmyId):GetListOfUnits(categories.ALLUNITS, false)
			
				-- for k, u in units do 
					-- if not u:IsMoving() then 
						-- local upos = u:GetPosition()
						-- upos[3] = upos[3] + trajectory
						-- IssueAggressiveMove({u}, upos)
						-- LOG(repr(upos))
						-- IssueAggressiveMove({u}, mainpos)
					-- end	
				-- end
				
			-- end
		-- end
	-- end
-- end
----------------------------------------------------------------------------------------------------------------------------------------------------------

findBonusStruct = function()
	local allUnits=GetUnitsInRect({x0 = 0, x1 = 512, y0 = 0, y1 = 512})
	if allUnits then
		local structs = EntityCategoryFilterDown(categories.MASSSTORAGE, allUnits)
		for id, unit in structs do
			if not unit:IsDead() and Humans['player'..unit:GetArmy()].structs[unit:GetEntityId()] == nil then
				if ArmyTable[unit:GetArmy()] then
					Humans['player'..unit:GetArmy()].structs[unit:GetEntityId()] = unit 		
					unit.OldOnKilled = unit.OnKilled
					unit.OnKilled = function(self, instigator, type, overkillRatio)
						Humans['player'..self:GetArmy()].structs[self:GetEntityId()] = nil
						unit.OldOnKilled(self, instigator, type, overkillRatio)
					end
				end
			end
		end
	end
	
	while true do
		coroutine.yield(1)
		for i, h in Humans do 
		local nums = returnTeammates(i)
			local counter = 0
			local flag = true 
			for j, s in Humans[i].structs do
				if not s:IsDead() then
					counter = counter + 1 
					local cp = math.pow(WaveCounter, 0.5) * 0.12
					s:SetCustomName('+ '..math.floor(cp*12)..' p/s')
					for n, _ in nums do 
						Humans[nums[n]].cashpoints = Humans[nums[n]].cashpoints + cp
					end				
				elseif s:IsDead() then				
					Humans[i].structs[j] = nil 
				end
				for n, _ in nums do 
					Humans[nums[n]].numstructs = counter 
				end
				
			end
		end	
	end	
end	
-----------------------delete unnecessary things from the map-------------------
clearAcus = function()
	local acus=GetUnitsInRect({x0 = 0, x1 = 512, y0 = 0, y1 = 512})
	if acus then
		local tmpUnits=EntityCategoryFilterDown(categories.COMMAND, acus)
		for id, unit in tmpUnits do
			if (ArmyTable[unit:GetArmy()] == nil) then
				unit:SetCanBeKilled(false)
			else 
				if not unit:IsDead() then 	
					unit.DeathWeaponEnabled = false
					unit.PlayDeathAnimation = false
					unit:GetBlueprint().Audio = {}
					unit:Destroy()
				end
			end
		end
	end
end

clearAllUnits = function()
	local allUnits=GetUnitsInRect({x0 = 0, x1 = 512, y0 = 0, y1 = 512})
	if allUnits then
		local tmpUnits=EntityCategoryFilterDown(categories.ALLUNITS, allUnits)
		for id, unit in tmpUnits do
			if not unit:IsDead() then
				unit.DeathWeaponEnabled = false
				unit.PlayDeathAnimation = false
				unit:GetBlueprint().Audio = {}
				unit:Destroy()
				if unit.Big then unit.Big:Destroy() end
			end
		end
	end
end
----------------------------------------------------------------------------------------------------------------------------------------------------------

-- function awspawnwave()
	-- while gameEnd == false do
	-- WaitSeconds(WaveTimer)	
		-- for i, h in Humans do 
			-- if h.ArmyId != nil then 
			-- --LOG(Humans[i].ArmyId)
				-- local POS = ScenarioUtils.MarkerToPosition('SpawnPoint'..ArmyTable[Humans[i].ArmyId])
				-- local point = 0
				-- local column = 0
				-- local checker = 0
				-- for k, u in h.ArmySet do
					-- local bp = u.bp
					-- if checker == 10 then checker = 0  column = column + 2 point = 0 end 
					-- newunit = CreateUnitHPR(bp, ArmyTable[Humans[i].ArmyId], POS[1] + point*2, POS[2], POS[3] + column, 0,0,0);								
					
					-- if h.rallypoint[1] then 						
						-- IssueMove({newunit}, {h.rallypoint[1], h.rallypoint[2], h.rallypoint[3]})
					-- end
					
					-- newunit.CreateWreckageProp = function(self, overkillRatio) end
					-- newunit.OldOnKilled = newunit.OnKilled
					-- newunit.OnKilled = function(self, instigator, type, overkillRatio)
						-- if instigator != nil then 
							-- local KillerArmy = instigator:GetArmy()
							-- if ArmyTable[KillerArmy] != nil then 
								-- cost = CostFix(self) * Humans['player'..KillerArmy].coeff
								-- if Humans['player'..KillerArmy].cashpoints and KillerArmy < 7 then
									-- Humans['player'..KillerArmy].cashpoints = Humans['player'..KillerArmy].cashpoints + cost
								-- end
								-- if GetFocusArmy() == KillerArmy then 
									-- local text = '+ '..math.floor(cost)..' points for murder'
									-- print(text)
								-- end						
							-- end
						-- end
						-- newunit.OldOnKilled(self, instigator, type, overkillRatio)
					-- end
					-- point = point + 1
					-- checker = checker + 1
				-- end
			-- end 
		-- end
	-- end
-- end

----------------------unit delivery--------------------------------------------
function spawnwave()
	while gameEnd == false do
		WaitSeconds(WaveTimer)	
		for i, h in Humans do 
			if h.ArmyId != nil then 
			--LOG(Humans[i].ArmyId)
		
				local POS = ScenarioUtils.MarkerToPosition('spawn'..ArmyTable[Humans[i].ArmyId])
				
				local transports = {}
				local placecounter = 0
				local unitsfordrop = {}
				local air = {} 
				if table.getn(h.ArmySet) == 0 then 
					continue 
				end
			
				for k, u in h.ArmySet do
					local bp = u.bp
					
					local newunit = CreateUnitHPR(bp, 'ParagonArmy'..Humans[i].teamindex, POS[1], POS[2], POS[3], 0,0,0);		
						newunit:SetCanBeKilled(false)
						if  EntityCategoryContains(categories.AIR, newunit) then placecounter = placecounter + 1
						elseif  EntityCategoryContains(categories.AIR * categories.TECH2, newunit) then placecounter = placecounter + 2
						elseif EntityCategoryContains(categories.TECH1, newunit) then placecounter = placecounter + 1
						elseif EntityCategoryContains(categories.TECH2, newunit) then placecounter = placecounter + 2
						elseif EntityCategoryContains(categories.TECH3, newunit) then placecounter = placecounter + 2
						elseif EntityCategoryContains(categories.EXPERIMENTAL, newunit) then placecounter = placecounter + 1 
						end
					
					
						table.insert(unitsfordrop, newunit)
					
					--elseif h.rallypoint[1] then 	
						--ScenarioFramework.GiveUnitToArmy(newunit, h.ArmyId);		
						--local ppos = ScenarioUtils.MarkerToPosition('SpawnPoint'..ArmyTable[Humans[i].ArmyId])						
					--	Warp( newunit, Vector(ppos[1], ppos[2], ppos[3]))
						--ScenarioFramework.GiveUnitToArmy(a, armyindex);
						--IssueMove({newunit}, {h.rallypoint[1], h.rallypoint[2], h.rallypoint[3]})
						--table.insert(air, newunit)
					--else 
						table.insert(air, newunit)
						--ScenarioFramework.GiveUnitToArmy(newunit, h.ArmyId);
					--	local ppos = ScenarioUtils.MarkerToPosition('SpawnPoint'..ArmyTable[Humans[i].ArmyId])
					--	Warp( newunit, Vector(ppos[1], ppos[2], ppos[3]))
					--end
				--	if h.rallypoint[1] then 						
					--	IssueMove({newunit}, {h.rallypoint[1], h.rallypoint[2], h.rallypoint[3]})
					--end
					

				end
					
				local num = math.floor(placecounter/24)
				
				-- local bp = GetUnitBlueprintByName('XEA0306')
				local perem = placecounter/24 - math.floor(placecounter/24)
				
				-- local num = math.floor(table.getn(h.ArmySet)/10)
				 if perem > 0 then num = num + 1 end 
				-- if table.getn(h.ArmySet) < 10 then num = 1 end 
			
				for j = 1, num do
					transports[j] = CreateUnitHPR('XEA0306', 'ParagonArmy'..Humans[i].teamindex, POS[1], POS[2], POS[3], 0,0,0);	
					transports[j]:SetCanBeKilled(false)
					transports[j]:SetSpeedMult(3)
					transports[j]:SetIntelRadius('Vision', 1)
					transports[j].OnMotionVertEventChange = function(self, new, old) end
				end
				ScenarioFramework.AttachUnitsToTransports(unitsfordrop, transports);
				local position = ScenarioUtils.MarkerToPosition('SpawnPoint'..ArmyTable[Humans[i].ArmyId])
				IssueTransportUnload(transports, position);
				ForkThread(OnDetached, transports, unitsfordrop, POS, Humans[i].ArmyId, Humans[i].teamindex)			
			end 
		end
	end
end

	
function OnDetached(transports, units, pos, armyindex, case)
       local attached = true;
	
       while attached do
           WaitSeconds(1)
           attached = false
           for k, unit in units do
               if not unit:IsDead()  then
                   if unit:IsUnitState('Attached') then
                       -- keep checking until they are _all_ free.
                       attached = true
                   end
               end                
           end
       end

	   
	WaitSeconds(1.7)
	local newunits = {}
       -- all unattached, gift them!
		for k, unit in units do
			
			local bpid = unit:GetBlueprint().BlueprintId 
			local upos = unit:GetPosition()
			
			
			local nunit = CreateUnitHPR(bpid, ArmyTable[armyindex], upos[1], upos[2], upos[3], 0, 0, 0)
				if table.contains(Heroes, string.upper(bpid)) then HeroUp(nunit) end
					nunit.CreateWreckageProp = function(self, overkillRatio) end
					nunit.OldOnKilled = nunit.OnKilled
					nunit.OnKilled = function(self, instigator, type, overkillRatio)
						if instigator != nil then 
							local KillerArmy = instigator:GetArmy()
							if ArmyTable[KillerArmy] != nil then 
								cost = CostFix(self) * Humans['player'..KillerArmy].coeff
								if Humans['player'..KillerArmy].cashpoints and KillerArmy < 7 and (KillerArmy != self:GetArmy()) and not (IsAlly(KillerArmy, self:GetArmy())) then
									Humans['player'..KillerArmy].cashpoints = Humans['player'..KillerArmy].cashpoints + cost
								end
								if GetFocusArmy() == KillerArmy then 
									local text = '+ '..math.floor(cost)..strings['murder']
									print(text)
								end						
							end
							if self.turrets then 
								for i, t in self.turrets do 
									t:Destroy()
								end
							end
							if self.pods then 
								for i, p in self.pods do 
									p.pd:Destroy()
								end
							end
						
					end
					nunit.OldOnKilled(self, instigator, type, overkillRatio)
				end
			--ScenarioFramework.GiveUnitToArmy(unit, armyindex);
			unit:Destroy()
			table.insert(newunits, nunit)
		end
		WaitSeconds(0.1)
		if Humans['player'..armyindex].rallypoint[1] then 
			for i, u in newunits do
				IssueMove({u}, {Humans['player'..armyindex].rallypoint[1] + Random(-5,5), Humans['player'..armyindex].rallypoint[2], Humans['player'..armyindex].rallypoint[3] + Random(-5,5)})
			end
			ForkThread(checkforbug, newunits, Humans['player'..armyindex].rallypoint)
		end   
		local backposition = ScenarioUtils.MarkerToPosition('Beacon'..case)
       -- move away again!
       WaitSeconds(0.5)
       IssueMove(transports, backposition);
	   WaitSeconds(15)
	for i, t in transports do
		t:Destroy()
	end
end
---------dont blame me, blame pathfinding-------------
function checkforbug(units, rallypoint)	--units still losing their goals i dunno why 
	WaitSeconds(5)	
	positions = {}
	local tolerance = 10
	
	for i, u in units do
		if not u:IsDead() and not u:IsMoving() then 
			IssueMove({u}, {rallypoint[1], rallypoint[2], rallypoint[3]})
			ForkThread(fumove, u, rallypoint)		
		end
		positions[i] = u:GetPosition()
	end
	
	-- WaitSeconds(10)
	-- for i, u in units do 
		-- if not u:IsDead() and not u:IsMoving() then
			-- local checker = 0
			-- local pos = u:GetPosition()
			-- for j = 1, 3 do 
				-- if j == 2 then continue end 
				-- if math.abs(positions[i][j] - pos[j]) < tolerance then 
					-- LOG('true')
					-- checker = checker + 1
				-- end
			-- end
			-- if (checker == 2) then 
				-- IssueMove({u}, {rallypoint[1], rallypoint[2], rallypoint[3]})
			-- end	
		-- end
	-- end
end

fumove = function(u, rallypoint)
	local c = 8
	while c >= 0 do 
		WaitSeconds(1)
		c = c - 1 
		
		if table.empty(u:GetCommandQueue()) then 	
			IssueMove({u}, {rallypoint[1], rallypoint[2], rallypoint[3]})
		end
	end
end

function MakeSomeRallyPoints()
	for i, h in Humans do 
		if h.ArmyId != nil then
			h.rallypointunit = CreateUnitHPR('uec0001', ArmyTable[h.ArmyId], h.pos[1] - 25, h.pos[2], h.pos[3], 0,0,0);
			h.rallypointunit:SetSpeedMult(0)
			h.rallypointunit:SetCustomName('rallypoint = ASSIST order on the ground')
			h.rallypointunit:SetCanBeKilled(false)	
		end
	end
	ForkThread(GetRallyPoint)
end

function GetRallyPoint()
	while true do
		WaitSeconds(1)
		for i, h in Humans do 
			if (Humans[i].rallypointunit != nil) and not (Humans[i].rallypointunit:IsDead()) then
				local rp = h.rallypointunit:GetNavigator():GetGoalPos() 
				local upos = h.rallypointunit:GetPosition()
				if not comparepositions(rp, upos) then 		 
					for j = 1, 3 do 
						h.rallypoint[j] = rp[j]
					end	
				end
			end
		end
	end
end




----------------------------------------------------------------------------------------------------------------------------------------------------------

function SetAlliances(flag)
	fillSupArmies()
	for i, sup in SupArmies do
		for j, Army in ListArmies() do
			SetAlliance(sup, Army, 'Ally')	
		end
	end
	SetAlliance('ARMY_17', 'ParagonArmy1', 'Ally')
	SetAlliance('ARMY_17', 'ParagonArmy2', 'Ally')
	
	for i, h in Humans do 
		if h.ArmyId != nil then 
			if h.teamindex == 1 then 
				SetAlliance(ArmyTable[h.ArmyId], 'ParagonArmy1', 'Ally')	
			elseif h.teamindex == 2 then 
				SetAlliance(ArmyTable[h.ArmyId], 'ParagonArmy2', 'Ally')	
			end
		end
	end	
end


--~~~~~~~~~~~~~wtf is this~~~~~~~~~~~~~--unbalanced thread below
function HeroUp(hero)
	local bp = hero:GetBlueprint()
	hero.DoVeterancyHealing = function(self, level) end
	hero.SetVeteranLevel = function(self, level) end
	local faction = (string.upper(bp.General.FactionName))
	hero:SetCustomName('infernal bi-ba-boo')	
	local ShieldSpecs = {
        ImpactEffects = 'AeonShieldHit01',
        ImpactMesh = '/effects/entities/ShieldSection01/ShieldSection01_mesh',
        Mesh = '/effects/entities/AeonShield01/AeonShield01_mesh',
        MeshZ = '/effects/entities/Shield01/Shield01z_mesh',
        PersonalBubble = true,
        RegenAssistMult = 60,
        ShieldEnergyDrainRechargeTime = 5,
        ShieldMaxHealth = 20000,
        ShieldRechargeTime = 50,
        ShieldRegenRate = 400,
        ShieldRegenStartTime = 2,
        ShieldSize = 2.5,
        ShieldVerticalOffset = 0,
    }
		
		
	if faction == 'AEON' then
		hero:SetSpeedMult(2)
		hero:CreateShield(ShieldSpecs)
		hero:SetEnergyMaintenanceConsumptionOverride(10)
		hero:SetMaxHealth(100000)
		hero:SetHealth(nil, 100000)
		
		
		
		for i = 1, hero:GetWeaponCount() do
			local wep = hero:GetWeapon(i)
			wep:ChangeProjectileBlueprint('/projectiles/ADFOblivionCannon05/ADFOblivionCannon05_proj.bp')
			--wep:ChangeProjectileBlueprint('/projectiles/AIFQuantumWarhead01/AIFQuantumWarhead01_proj.bp')	
			
			--wep:ChangeProjectileBlueprint('/projectiles/CIFArtilleryProton03/CIFArtilleryProton03_proj.bp')
			local v = 1500
			wep:AddDamageMod(v)
			v = 4
			wep:ChangeRateOfFire(v)
			
		end

	elseif faction == 'CYBRAN' then 
		hero:CreateEnhancement('EMPCharge')
		hero:GetWeapon(1):ChangeProjectileBlueprint('/projectiles/CDFProtonCannon05/CDFProtonCannon05_proj.bp')
		
		hero:SetSpeedMult(100)
		
		hero:SetEnergyMaintenanceConsumptionOverride(10)
		hero:SetMaxHealth(50000)
		hero:SetHealth(nil, 50000)
		hero:SetRegen(1000)
  		for i = 1, hero:GetWeaponCount() do
			local wep = hero:GetWeapon(i)
			
			local v = 7000
			wep:AddDamageMod(v)
			v = 45
			
			wep:ChangeProjectileBlueprint('/projectiles/CIFArtilleryProton01/CIFArtilleryProton01_proj.bp')
			wep:AddDamageRadiusMod(12)
			v = 0.5
			wep:ChangeRateOfFire(v)
			
		end
		local wep = hero:GetWeaponByLabel('RightDisintegrator')
		wep:ChangeMaxRadius(50)

		
	elseif faction == 'UEF' then 
	
		
		hero.CreateMyEnhancement = function(self, enh, amount)
			if not bp then return end
			if enh == 'Pod' then
				for i = 1, amount do 
					local location = self:GetPosition('AttachSpecial01')
					local pod = CreateUnitHPR('UEA0003', self.Army, location[1], location[2], location[3], 0, 0, 0)
					pod:SetParent(self, 'Pod')
					pod:SetCreator(self)
					self.Trash:Add(pod)
					self.HasPod = true
					self.Pod = pod
					self.pods = {}
					table.insert(self.pods, pod)
					PodUp(pod)
				
					pod.OnKilled = function(self, instigator, type, overkillRatio)
						if not (self.Parent:IsDead()) then 
							self.Parent:CreateMyEnhancement('Pod', 1)				
						end 
						self.pd:Destroy()		
						self:Destroy()
						
						--TConstructionUnit.OnKilled(self, instigator, type, overkillRatio)
					end
					
				end
				
			end
		
		end
	
		
			hero:CreateMyEnhancement('Pod', 60)
			
		local ShieldSpecs = {
		ImpactEffects = 'UEFShieldHit01',
		ImpactMesh = '/effects/entities/ShieldSection01/ShieldSection01_mesh',
		Mesh = '/effects/entities/Shield01/Shield01_mesh',
		MeshZ = '/effects/entities/Shield01/Shield01z_mesh',
        PersonalBubble = true,
        RegenAssistMult = 60,
        ShieldEnergyDrainRechargeTime = 5,
        ShieldMaxHealth = 200000,
        ShieldRechargeTime = 200,
        ShieldRegenRate = 1000,
        ShieldRegenStartTime = 2,
        ShieldSize = 15,
        ShieldVerticalOffset = 15,
		}
		--hero:CreateShield(ShieldSpecs)
		hero:SetEnergyMaintenanceConsumptionOverride(5)
	
	
	elseif faction == 'SERAPHIM' then
		
		
		hero:SetSpeedMult(3)
		hero:SetMaxHealth(150000)
		hero:SetHealth(nil, 150000)
		hero:SetRegen(800)
		value = 25
		local weapon = hero:GetWeapon(1)
		weapon:ChangeMaxRadius(value-10)
		weapon:AddDamageRadiusMod(6)
		local v = 3
		weapon:ChangeRateOfFire(v)
		weapon:AddDamageMod(value*50)
		weapon:ChangeFiringTolerance(100)
		weapon:ChangeMaxHeightDiff(600)
		weapon:ChangeProjectileBlueprint('/projectiles/SIFZthuthaamArtilleryShell02/SIFZthuthaamArtilleryShell02_proj.bp')
		
	end
	

end

PodUp = function(p)

		local ShieldSpecs = {
		ImpactEffects = 'UEFShieldHit01',
		ImpactMesh = '/effects/entities/ShieldSection01/ShieldSection01_mesh',
		Mesh = '/effects/entities/Shield01/Shield01_mesh',
		MeshZ = '/effects/entities/Shield01/Shield01z_mesh',
        PersonalBubble = true,
        RegenAssistMult = 60,
        ShieldEnergyDrainRechargeTime = 5,
        ShieldMaxHealth = 500,
        ShieldRechargeTime = 50,
        ShieldRegenRate = 400,
        ShieldRegenStartTime = 2,
        ShieldSize = 1.5,
        ShieldVerticalOffset = 0,
    }
	p:SetEnergyMaintenanceConsumptionOverride(1)
	p:SetMaxHealth(2000)
	p:SetHealth(nil, 2000)
	p:SetSpeedMult(2)
	p.pd = CreateUnitHPR('ueb2101', p.Army, 0, 0, 0, 0,0,0)
	p.pd:SetCanTakeDamage(false)
	p.pd:GetWeapon(1):AddDamageRadiusMod(3)
	p.pd:GetWeapon(1):ChangeProjectileBlueprint('/projectiles/TDPhalanx01/TDPhalanx01_proj.bp')
	p.pd:AttachTo(p, p:GetBoneName(1))
	p:CreateShield(ShieldSpecs)
	p.pd:SetReclaimable(false)

end

function CreateBunkers()
	for i = 1, 2 do 
		local pos = ScenarioUtils.MarkerToPosition('MainBunker'..i)
		Bunkers[i].unit = CreateUnitHPR('XAB1401', 'ParagonArmy'..i, pos[1], pos[2], pos[3], 0,0,0)
		Bunkers[i].unit:SetMaxHealth(10000)
		Bunkers[i].unit:SetHealth(nil, 10000)
		Bunkers[i].unit:SetIntelRadius('Vision', 150)
		Bunkers[i].unit:SetRegen(50)
		local zinya = CreateUnitHPR('DALK003', 'ParagonArmy'..i, pos[1], pos[2], pos[3], 0,0,0)		
		zinya:SetCanBeKilled(false)
		zinya:AttachTo(Bunkers[i].unit, Bunkers[i].unit:GetBoneName(1))
		local storage = CreateUnitHPR('UAB1105', 'ParagonArmy'..i, pos[1], pos[2], pos[3], 0,0,0)		
		storage:SetCanBeKilled(false)
		Bunkers[i].unit:SetEnergyMaintenanceConsumptionOverride(30)
		Bunkers[i].unit:SetProductionPerSecondEnergy(1000)
		Bunkers[i].unit:UpdateConsumptionValues()
		Bunkers[i].unit:HideBone(0, true)
		Bunkers[i].unit.Big = import('/lua/sim/Entity.lua').Entity({Owner = Bunkers[i].unit,})
		Bunkers[i].unit.Big:SetMesh(Bunkers[i].unit:GetBlueprint().Display.MeshBlueprint, true)
		Bunkers[i].unit.Big:SetScale(0.13)
		Bunkers[i].unit.Big:AttachBoneTo(0, Bunkers[i].unit, 0)
		local ShieldSpecs = {
			ImpactEffects = 'SeraphimShieldHit01',
			ImpactMesh = '/effects/entities/ShieldSection01/ShieldSection01_mesh',
			Mesh = '/effects/entities/SeraphimShield01/SeraphimShield01_mesh',
			MeshZ = '/effects/entities/Shield01/Shield01z_mesh',
			RegenAssistMult = 60,
			ShieldEnergyDrainRechargeTime = 60,
			ShieldMaxHealth = 21000,
			ShieldRechargeTime = 15,
			ShieldRegenRate = 600,
			ShieldRegenStartTime = 1,
			ShieldSize = 30,
			ShieldVerticalOffset = -9,
		};
		Bunkers[i].unit:CreateShield(ShieldSpecs);
		for j = 1, 3 do 
			Bunkers[i].pds[j] = CreateUnitHPR('UAB2301', 'ParagonArmy'..i, pos[1], pos[2], pos[3], 0,0,0)
			Bunkers[i].pds[j]:SetCanBeKilled(false)
			Bunkers[i].pds[j]:HideBone(0, true)
			Bunkers[i].pds2[j] = CreateUnitHPR('XSB2301', 'ParagonArmy'..i, pos[1], pos[2], pos[3], 0,0,0)
			Bunkers[i].pds2[j]:SetCanBeKilled(false)
			--Bunkers[i].pds2[j]:GetWeapon(1):ChangeRateOfFire(2)
			Bunkers[i].pds2[j]:HideBone(0, true)
		end 
	end
	ForkThread(CheckVictoryConditions)
	ForkThread(PdPowerFix)
end

function PdPowerFix()
	while true do
		WaitSeconds(1)
		local Rate = WaveCounter * 0.3 + 1
		local hp = WaveCounter * 1000
		local dmg = WaveCounter * 1.5
		
		for i = 1, 2 do
			Bunkers[i].unit:SetMaxHealth(10000 + hp)
			for k = 1, 3 do 
				Bunkers[i].pds[k]:GetWeapon(1):ChangeRateOfFire(Rate)
				Bunkers[i].pds2[k]:GetWeapon(1):ChangeRateOfFire(Rate)
				Bunkers[i].pds2[k]:GetWeapon(1):AddDamageMod(dmg)
			end
		end
	end
end

function CheckVictoryConditions()
	local loser = nil
	

	while gameEnd == false do
		WaitSeconds(1)
		if not Bunkers[1].unit:IsDead() and not Bunkers[2].unit:IsDead() 
			then gameEnd = false		
		elseif Bunkers[1].unit:IsDead() 
			then gameEnd = true loser = 1 
		elseif Bunkers[2].unit:IsDead() 
			then gameEnd = true loser = 2 	
		end		
		local winners = {}
		local losers = {}
		if gameEnd then
		clearAllUnits()
			if loser == 1 then
				for i, hum in Humans do 
					if hum.ArmyId != nil then 
						if hum.teamindex == 2 then 
							table.insert(winners, GetArmyBrain(hum.ArmyId).Nickname)
						elseif hum.teamindex == 1 then 
							table.insert(losers, GetArmyBrain(hum.ArmyId).Nickname)
						end
					end
				end
			elseif loser == 2 then 
				for i, hum in Humans do 
					if hum.ArmyId != nil then 
						if hum.teamindex == 2 then 
							table.insert(losers, GetArmyBrain(hum.ArmyId).Nickname)
						elseif hum.teamindex == 1 then 
							table.insert(winners, GetArmyBrain(hum.ArmyId).Nickname)
						end
					end
				end
			end
			
			local winnerslist = GetStringFromArray(winners)
			local loserlist = GetStringFromArray(losers)
			

			local text = 'Game Ended!\n>>>>>>Congratulations:<<<<<<\n'..winnerslist..' >>>Maybe next time:<<<\n'..loserlist
			
			local lastdialogue = CreateDialogue(text,{'close'},'center')
			lastdialogue.OnButtonPressed = function(self, info)
				if GetFocusArmy() == info.presser then 
					lastdialogue:Destroy()
				end
			end			

			clearAllUnits()
		end
	end
end

-----------------------------------------------------------------------------------------------------structures to up cash income-----------------------------------------------------------------------------------------------------------------------------------------
function CreateStructures()
	---theres 5 levels of structures 
	---1 level 
	local respawn = false 
	local UnitID = nil
	local pos = nil
	--local mult = nil
	local hp = nil
	local cash = nil
	local OnetimeCash = true
	local army = 'ARMY_17'
	for i = 1, 4 do 
		pos = ScenarioUtils.MarkerToPosition('1Objective_0'..i)
		UnitID = 'urb3103'
	--	mult = 2
		cash = 100
		hp = 400
		spawnstruct(pos, UnitID, hp, OnetimeCash, cash, respawn, army)
	end
	---2 level
	for i = 1, 4 do 
		pos = ScenarioUtils.MarkerToPosition('2Objective_0'..i)
		UnitID = 'uab3102'
	--	mult = 2
		cash = 300
		hp = 1500
		spawnstruct(pos, UnitID, hp, OnetimeCash, cash, respawn, army)
	end
	---3 level 
	for i = 1, 4 do 
		pos = ScenarioUtils.MarkerToPosition('3Objective_0'..i)
		UnitID = 'ueb1302'
	--  mult = 2
		cash = 1500
		hp = 5000
		spawnstruct(pos, UnitID, hp, OnetimeCash, cash, respawn, army)
	end
	---4 level
	for i = 1, 4 do 
		pos = ScenarioUtils.MarkerToPosition('4Objective_0'..i)
		UnitID = 'xsb1302'
	--	mult = 2
		cash = 5000
		hp = 15000
		spawnstruct(pos, UnitID, hp, OnetimeCash, cash, respawn, army)
	end
	---5 level 
	for i = 1, 4 do 
		pos = ScenarioUtils.MarkerToPosition('5Objective_0'..i)
		UnitID = 'uab3104'
	--	mult = 4
		cash = 15000
		hp = 50000
		spawnstruct(pos, UnitID, hp, OnetimeCash, cash, respawn, army)
	end
	
	--- dont forget about middle players 
	for i = 1, 2 do 
		pos = ScenarioUtils.MarkerToPosition('1bunker'..i)
		UnitID = 'UEB2301'
		hp = 3000
		cash = 2000
		OnetimeCash = true 
		army = 'ParagonArmy'..i
		spawnstruct(pos, UnitID, hp, OnetimeCash, cash, respawn, army)
	end	
end

-- SpawnMiddleBonus = function(num)

-- local army = 'ARMY_17'

	-- for i = 1, 4 do
		-- local pos = ScenarioUtils.MarkerToPosition('CenterObjective_0'..i)
		-- pos = RandomizePosition(pos)
		-- UnitID = 'uab3102'
		-- hp = num * 200
		-- cash = math.floor((math.pow(num, 0.5))*50) + 10 --math.floor(math.log10(num)*200)+10
		-- local OnetimeCash = true  
		-- respawn = true 
		-- spawnstruct(pos, UnitID, nil, hp, OnetimeCash, cash, respawn, army)
	-- end
-- end

SpawnMiddleStructs = function()
	local army = 'ARMY_17'
	for i = 1, 15 do
		local pos = ScenarioUtils.MarkerToPosition('CenterObjective_0'..i)
		UnitID = 'urc1401'

		hp = 300
		hpCoeff = 1 
		--local mult = 1.5
		local OnetimeCash = false  
		respawn = true 
		spawnstruct(pos, UnitID, hp, OnetimeCash, nil, respawn, army, hpCoeff)
	end
end


function spawnstruct(pos, UnitID, hp, OnetimeCash, cash, respawn, sArmy, hpCoeff)
	
		local struct = CreateUnitHPR(UnitID, sArmy, pos[1], pos[2], pos[3], 0,0,0)
		
		if UnitID == 'UEB2301' then
			local ShieldSpecs = {
				ImpactEffects = 'SeraphimShieldHit01',
				ImpactMesh = '/effects/entities/ShieldSection01/ShieldSection01_mesh',
				Mesh = '/effects/entities/SeraphimShield01/SeraphimShield01_mesh',
				MeshZ = '/effects/entities/Shield01/Shield01z_mesh',
				RegenAssistMult = 60,
				ShieldEnergyDrainRechargeTime = 60,
				ShieldMaxHealth = 2000,
				ShieldRechargeTime = 40,
				ShieldRegenRate = 50,
				ShieldRegenStartTime = 1,
				ShieldSize = 5,
				ShieldVerticalOffset = 0,
			};		
			struct:GetWeapon(1):ChangeRateOfFire(2)
			struct:SetEnergyMaintenanceConsumptionOverride(10)
			struct:CreateShield(ShieldSpecs)
		
		end
		
		if sArmy != 'ARMY_17' and UnitID == 'urc1401' then 
			local nArmy = ArmyToPlayer(sArmy)
			Humans['player'..nArmy].structs[struct:GetEntityId()] = struct  		
		end
		struct.CreateWreckageProp = function(self, overkillRatio) end
		struct:SetReclaimable(false)
	if OnetimeCash then 
		struct:SetCustomName('+ '..cash..' to ur cash')
	else 
		struct:SetCustomName('BONUS')
	end
	struct:SetMaxHealth(hp)
	struct:SetHealth(nil, hp)
	struct.SelfDestruct = false
	
	oldOnDamage = struct.OnDamage
	struct.OnDamage = function(self, instigator, amount, vector, damageType)
        -- Disable all friendly and team damage	
		
			local InstigatorArmy = instigator:GetArmy()
		
			local MyArmy = self:GetArmy()
		
		if InstigatorArmy == MyArmy or IsAlly(MyArmy, InstigatorArmy) == true then
            return 
        end
        
       oldOnDamage(self, instigator, amount, vector, damageType)
    end
	struct.OnCaptured = function(self, captor) end
	struct.OldOnKilled = struct.OnKilled
		struct.OnKilled = function(self, instigator, type, overkillRatio)
		
			local army = instigator.Army 
			
			if OnetimeCash then 
				if ArmyTable[army] != nil then 
					Humans['player'..army].cashpoints = Humans['player'..army].cashpoints + cash 
				end
			--	Humans['player'..army].multiplier = Humans['player'..army].multiplier * mult
			end
			
			if respawn then 
				hpCoeff = hpCoeff + 0.05
				hp = hp * hpCoeff 
				--pos = RandomizePosition(pos)
				local resparmy = nil 
					if ArmyTable[army] != nil then 
						resparmy = ArmyTable[army] 
					else 
						resparmy = 'ARMY_17'
					end
					spawnstruct(pos, UnitID, hp, OnetimeCash, cash, respawn, resparmy, hpCoeff)
			end
		struct.OldOnKilled(self, instigator, type, overkillRatio)
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------
function mainchain()
	LanguageSettings()
	GetPlayersOnline()
	clearAcus()
	CreateUnitsForSponsors()
	SetAlliances()
	--InitArmy()
	CreateDefSet()
	CreateBunkers()
	StartCamera()
	ForkThread(dialoguemanager)
	SpawnMiddleStructs()
	ForkThread(shopchecker)
	ForkThread(spawnwave)	
	ForkThread(findBonusStruct)
	RainbowParty()
	CreateStructures()
end


function RainbowParty()
	for i = 1, 6 do 
		ForkThread(RainbowEffect, 'SupportArmy'..i)
	end
	ForkThread(RainbowEffect, 'ParagonArmy1')
	ForkThread(RainbowEffect, 'ParagonArmy2')
end

function RainbowEffect(Army)
    local i = 1
    local frequency = math.pi * 2 / 255

    while true do
        WaitSeconds(0.05)

        if i >= 255 then i = 255 end

        local red   = math.sin(frequency * i + 2) * 127 + 128
        local green = math.sin(frequency * i + 0) * 127 + 128
        local blue  = math.sin(frequency * i + 4) * 127 + 128

        SetArmyColor(Army, red, green, blue)

        if i >= 255 then i = 1 end

        i = i + 1
    end
end

local IssueOrderFunctions = nil
function fixSpreadAttack()
	import('/lua/spreadattack.lua').GiveOrders = function(Data)
		if not IssueOrderFunctions then
			IssueOrderFunctions = {
			["Attack"]             = IssueAttack,
			["Move"]               = IssueMove,
			["Guard"]              = IssueGuard,
			["Tactical"]           = IssueTactical,
			--["AggressiveMove"]     = IssueAggressiveMove,
			--["Capture"]            = IssueCapture,
			--["Nuke"]               = IssueNuke,
			--["OverCharge"]         = IssueOverCharge,
			--["Patrol"]             = IssuePatrol,
			--["Repair"]             = IssueRepair,
			--["Reclaim"]            = IssueReclaim,
			}
		end
		
		if OkayToMessWithArmy(Data.From) then --Check for cheats/exploits
			local unit = GetEntityById(Data.unit_id)
			-- Skip units with no valid shadow orders.
			if unit == nil or not Data.unit_orders or not Data.unit_orders[1] then
				return
			end
			local bp = unit:GetBlueprint()
			if bp!=nil and bp.CategoriesHash.BOMBER then
				for key, order in Data.unit_orders or {} do
					if order.CommandType == "Move" then
						local bomberPosition = unit:GetPosition()
						
						--reject all move orders that are closer than 20
						if VDist2(bomberPosition[1], bomberPosition[3], order.Position[1], order.Position[3]) < 20 then
							table.remove (Data.unit_orders, key)
						end
					end
				end
			end
	
			-- All orders will be re-issued, so all existing orders have to be cleared first.
			IssueClearCommands({ unit })
	
			-- Re-issue all orders.
			for _,order in ipairs(Data.unit_orders) do
				local Function = IssueOrderFunctions[order.CommandType]
				if not Function then
					continue
				end
				
				local target = order.Position
				if order.EntityId then
					target = GetEntityById(order.EntityId)
				end
				if target then
					Function({ unit }, target)
				end
			end
		end
	end
end

local donators  = {['TT.iro'] = 'url0107', ['maTpoc118'] = 'url0107', ['Stas_Pyatnica'] = 'url0107', ['Pryanichek'] = 'url0107', ['Lemigard'] = 'url0107', ['Zero_Phantom'] = 'url0107', ['Nikerochek'] = 'XSL0103', ['mtchk'] = 'url0107', ['Berezovskiy'] = 'UAL0001', ['Valentine'] = 'url0107', ['PonySlavestation'] = 'url0107', ['KAIZER'] = 'url0107', ['velsevur'] = 'URL0208', ['Danger1225'] = 'XSB2401', ['Grievous_Nix'] = 'url0107', ['xReXx1998'] = 'url0107', ['[BIB]ClaudeLeLezard'] = 'url0107' }
function CreateUnitsForSponsors()
	for i, s in donators  do
		local pos = ScenarioUtils.MarkerToPosition(i)
		local u = CreateUnitHPR(s,'SupportArmy1', pos[1], pos[2], pos[3], 0,0,0)
		u:SetCanBeKilled(false)
		u:SetCustomName(i)
	end
end

local SimCamera = import('/lua/SimCamera.lua').SimCamera

function StartCamera()

	if Manual != false then 
		LockInput()
	
		
		for i, a in ArmyTable do
			
			SetAlliance(a, 'ParagonArmy1', 'Ally')	
			SetAlliance(a, ArmyTable[1], 'Ally')
		end
		
		
		local rect1 = ScenarioUtils.AreaToRect('arearules')
		local rect2 = ScenarioUtils.AreaToRect('arearules2')
		local rect3 = ScenarioUtils.AreaToRect('AREA_1')
		local cam = SimCamera('WorldCamera')
		cam:ScaleMoveVelocity(0.03)
		cam:MoveTo(rect1, 1)
		
	
		
		ScenarioFramework.Dialogue(taunts[1], nil, true)
		ScenarioFramework.Dialogue(taunts[2], nil, true)
		WaitSeconds(12)
		ScenarioFramework.Dialogue(taunts[3], nil, true)
		
		cam:MoveTo(rect2, 1)
		WaitSeconds(9)
		
		
		
		UnlockInput()
		cam:MoveTo(rect3, 1)
		for i, h in Humans do 
			if h.ArmyId != nil then 
				if h.teamindex == 2 then 
					SetAlliance(ArmyTable[h.ArmyId], 'ParagonArmy1', 'Enemy')	
					SetAlliance(ArmyTable[h.ArmyId], ArmyTable[1], 'Enemy')
				end
			end
		end
	end
end


