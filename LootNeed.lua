if not LootNeed_DB then
	LootNeed_DB = {};
end

local instances = {};
instances.HFC = {difficulties = {"N","H","M"}, name = "Hellfire Citadel", bossnumber = 13, bosses = {"Hellfire Assault", "Iron Reaver", "Kormrok", "Hellfire Council", "Kilrogg Deadeye", "Gorefiend", "Shadowlord Iskar", "Sorcrethar", "Tyrant Velhari", "Xhul'horac", "Zakuun", "Mannoroth", "Archimonde"}};
instances.BRF = {difficulties = {"N","H","M"}, name = "Blackrock Foundry", bossnumber = 10, bosses = {"Gruul", "Oregorger", "Blast Furnace", "Hansgar and Franzok", "Flamebender", "Kromog", "Darmac", "Thogar", "Iron Maidens", "Blackhand"}};
instances.HM = {difficulties = {"N","H","M"}, name = "Highmaul", bossnumber = 7, bosses = {"Bladefist", "Butcher", "Tectus", "Spore", "Twins", "Koragh", "Imperator"}};
local standardinstance = "HFC";

local selectedinstance;
local selecteddifficulty;
local selectedboss;

local dataupdated = false;

local padding = 10;
local checkboxheight = 30;
local scrollbutton_height = 20;

local mainframe;
local needlist = {};
local noneedlist = {};
local noinfolist = {};


local function LootNeed_DataUpdated()
	dataupdated = true;
end

-- slash handler
SLASH_LOOTNEED1 = '/lootneed';
local function slashhandler(msg, editbox)
	if string.find(msg, "collect") == 1 then
		LootNeed_ToggleCollectorUI();
		return;
	end
	
	if string.find(msg, "clear") == 1 then
		local t = LootNeed_DB.player;
		wipe(LootNeed_DB);
		LootNeed_DB.player = t;
		return;
	end
	
	if string.find(msg, "get") == 1 then
		SendAddonMessage("LootNeed", "Get", "GUILD");
		return;
	end
	
	LootNeed_ToggleUI();
end

SlashCmdList["LOOTNEED"] = slashhandler;


local function LootNeed_SetNeed(boss, need)
	if not LootNeed_DB.player then
		LootNeed_DB.player = {};
	end
	if not LootNeed_DB.player[selectedinstance] then
		LootNeed_DB.player[selectedinstance] = {};
	end
	if not LootNeed_DB.player[selectedinstance][selecteddifficulty] then
		LootNeed_DB.player[selectedinstance][selecteddifficulty] = {};
		for i=1,instances[selectedinstance].bossnumber,1 do
			LootNeed_DB.player[selectedinstance][selecteddifficulty][i] = 0;
		end
	end
	
	LootNeed_DB.player[selectedinstance][selecteddifficulty][boss] = need;
end



function LootNeed_ProcessRequest(sender)
	if LootNeed_DB.player then
		for instance, v in pairs(LootNeed_DB.player) do 
			for difficulty, w in pairs(v) do
				local lootneed = "";
				for boss, need in ipairs(w) do
					lootneed = lootneed .. need;
				end
				lootneed = instance .. "," .. difficulty .. lootneed .. ";";
				
				SendAddonMessage("LootNeed", lootneed, "WHISPER", sender);
				SendAddonMessage("LootNeed", lootneed, "GUILD");
			end
		end
	end
end

function LootNeed_ProcessLootData(instance, difficulty, lootneed, sender)
	if instance and difficulty and lootneed and sender then
		if not instances[instance] or not instances[instance].bossnumber then
			return;
		end
		if not LootNeed_DB[instance] then
			LootNeed_DB[instance] = {};
		end
		if not LootNeed_DB[instance][difficulty] then
			LootNeed_DB[instance][difficulty] = {};
		end
		
		-- dissipate lootneed string into table
		for i = 1,instances[instance].bossnumber,1 do
			if not LootNeed_DB[instance][difficulty][i] then
				LootNeed_DB[instance][difficulty][i] = {};
			end
			
			local startchar, endchar, firstWord = string.find(lootneed,"(%d)",i);
			if startchar then
				LootNeed_DB[instance][difficulty][i][sender] = firstWord;
			else
				LootNeed_DB[instance][difficulty][i][sender] = "0";
			end
		end
		LootNeed_DataUpdated();
	end
end

LootNeed_OnEvent = function(self, event, arg1, arg2, arg3, arg4, arg5)
	if event == "CHAT_MSG_ADDON" then
		if arg1 == "LootNeed" then
			local startchar, endchar, firstWord, restOfString = string.find(arg2, "Get");
			if startchar == 1 then
				LootNeed_ProcessRequest(arg4);
				return;
			end
			
			local startchar, endchar, instance, difficulty, lootneed  = string.find(arg2, "(%w+)[,](%a)(%d+);");
			if startchar then
				LootNeed_ProcessLootData(instance, difficulty, lootneed, arg4);
			end
		end
	end
end

function LootNeed_UpdateIndividualWindow()
	if dataupdated then
		if selecteddifficulty and selectedinstance then
			local f = mainframe.individual;
			f:SetHeight(f.TitleBg:GetHeight() + padding + f.instanceselection:GetHeight() + padding + instances[selectedinstance].bossnumber * (checkboxheight));
			for k, v in pairs(f.checkboxes) do
				if k <= instances[selectedinstance].bossnumber then
					v:Show();
					if LootNeed_DB.player and LootNeed_DB.player[selectedinstance] and LootNeed_DB.player[selectedinstance][selecteddifficulty] then
						if LootNeed_DB.player[selectedinstance][selecteddifficulty][k] == 1 then
							v:SetChecked(true);
						else
							v:SetChecked(false);
						end
					else
						v:SetChecked(false);
					end
				else
					v:Hide();
				end
			end
			for k, v in pairs(f.bosslabels) do
				if k <= instances[selectedinstance].bossnumber then
					v:SetText(instances[selectedinstance].bosses[k]);
					v:Show();
				else
					v:Hide();
				end
			end
			UIDropDownMenu_SetText(f.instanceselection, selectedinstance);
			UIDropDownMenu_SetText(f.difficultyselection, selecteddifficulty);
		end
	end
end

function LootNeed_UpdateCollectorWindow()
	if dataupdated then
		if selecteddifficulty and selectedinstance and selectedboss then
			local f = mainframe.collector;
			
			wipe(noinfolist);
			wipe(noneedlist);
			wipe(needlist);

			local t = {};
			for i=1,GetNumGroupMembers(),1 do
				t[UnitName("raid" .. i)] = true;
			end
			
			if LootNeed_DB[selectedinstance] and LootNeed_DB[selectedinstance][selecteddifficulty] and LootNeed_DB[selectedinstance][selecteddifficulty][selectedboss] then
				for k, v in pairs(LootNeed_DB[selectedinstance][selecteddifficulty][selectedboss]) do
					if t[k] then
						t[k] = nil;
					end
					if v == "1" then
						table.insert(needlist, k);
					elseif v == "0" then
						table.insert(noneedlist, k);
					else
						table.insert(noinfolist, k);
					end
				end
			end
			
			for k, v in pairs(t) do
				table.insert(noinfolist,k);
			end
			
			
			UIDropDownMenu_SetText(f.instanceselection, selectedinstance);
			UIDropDownMenu_SetText(f.difficultyselection, selecteddifficulty);
		end
		if not selectedboss then
			wipe(noinfolist);
			wipe(noneedlist);
			wipe(needlist);
			UIDropDownMenu_SetText(mainframe.collector.bossselection);
		end
		
		LootNeed_NeedScrollFrameUpdate();
		LootNeed_NoNeedScrollFrameUpdate();
		LootNeed_NoInfoScrollFrameUpdate();
		dataupdated = false;
	end
end

function LootNeed_SetInstance(self, instance, frame)
	if not instances[instance] then
		print("no such instance available");
	end
	selectedinstance = instance;
	UIDropDownMenu_SetText(frame, instance);
	
	if selecteddifficulty then
		local difficultyavailable = false;
		for k, v in pairs(instances[instance].difficulties) do
			if v == selecteddifficulty then
				difficultyavailable = true;
			end
		end
		if not difficultyavailable then
			selecteddifficulty = nil;
			UIDropDownMenu_SetText(frame:GetParent().difficultyselection);
		end
	end
	
	if selectedboss then
		local bossavailable = false;
		for k, v in pairs(instances[instance].bosses) do
			if v == selectedboss then
				bossavailable = true;
			end
		end
		if not bossavailable then
			selectedboss = nil;
		end
	end
	
	LootNeed_DataUpdated();
end

function LootNeed_SetDifficulty(self, difficulty, frame)
	selecteddifficulty = difficulty;
	UIDropDownMenu_SetText(frame, difficulty);
	
	LootNeed_DataUpdated();
end

function LootNeed_SetBoss(self, boss, frame)
	selectedboss = boss;
	UIDropDownMenu_SetText(frame, instances[selectedinstance].bosses[boss]);
	
	LootNeed_DataUpdated();
end

function LootNeed_InstanceSelection(frame, level, menu)
	local info = UIDropDownMenu_CreateInfo();
	for k, v in pairs(instances) do
		info.text = v.name or k;
		info.value = k
		info.func = LootNeed_SetInstance;
		info.arg1 = k;
		info.arg2 = frame;
		UIDropDownMenu_AddButton(info);
	end
	
	if selectedinstance then
		UIDropDownMenu_SetSelectedValue(frame, selectedinstance);
	end
end

function LootNeed_DifficultySelection(frame, level, menu)
	local info = UIDropDownMenu_CreateInfo();
	if not selectedinstance or not instances[selectedinstance] then
		--print("No difficulties available");
		return;
	end
	for k, v in ipairs(instances[selectedinstance].difficulties) do
		info.text = v;
		info.func = LootNeed_SetDifficulty;
		info.arg1 = v;
		info.arg2 = frame;
		UIDropDownMenu_AddButton(info);
	end
	
	if selecteddifficulty then
		UIDropDownMenu_SetSelectedValue(frame, selecteddifficulty);
	end
end

function LootNeed_BossSelection(frame, level, menu)
	local info = UIDropDownMenu_CreateInfo();
	if not selectedinstance or not instances[selectedinstance] then
		--print("No bosses available");
		return;
	end
	for k, v in ipairs(instances[selectedinstance].bosses) do
		info.text = v;
		info.value = k;
		info.func = LootNeed_SetBoss;
		info.arg1 = k;
		info.arg2 = frame;
		UIDropDownMenu_AddButton(info);
	end
	
	if selecteddifficulty then
		UIDropDownMenu_SetSelectedValue(frame, selectedboss);
	end
end

function LootNeed_InitUI()
	local f = CreateFrame("Frame", "lootneed_individual", UIParent, "BasicFrameTemplate");
	f:SetSize(210, 60);
	f:SetPoint("CENTER", 0, 0);
	f.TitleText:SetText("Loot Need");
	f:EnableMouse(true);
	f:Show();
	f:SetScript("OnUpdate", function(s) LootNeed_UpdateIndividualWindow(); end);
	mainframe.individual = f;
	
	local titleregion = f:CreateTitleRegion();
	titleregion:SetPoint("TOPLEFT", 0, 0);
	titleregion:SetWidth(f.TitleBg:GetWidth());
	titleregion:SetHeight(f.TitleBg:GetHeight());
	
	
	local width = 80;
	f.instanceselection = CreateFrame("Frame", "lootneed_individual_instanceselection", f, "UIDropDownMenuTemplate");
	f.instanceselection:SetPoint("TOPLEFT", -2, -padding - 20);
	f.instanceselection:SetHeight(20);
	UIDropDownMenu_SetWidth(f.instanceselection, width);
	UIDropDownMenu_Initialize(f.instanceselection, LootNeed_InstanceSelection);
	
	f.difficultyselection = CreateFrame("Frame", "lootneed_individual_difficultyselection", f, "UIDropDownMenuTemplate");
	f.difficultyselection:SetPoint("LEFT", f.instanceselection, "RIGHT", -20, 0);
	f.difficultyselection:SetHeight(20);
	UIDropDownMenu_SetWidth(f.difficultyselection, 50);
	UIDropDownMenu_Initialize(f.difficultyselection, LootNeed_DifficultySelection);
	
	local maxbosses = 0;
	for k, v in pairs(instances) do
		if v.bossnumber and v.bossnumber > maxbosses then
			maxbosses = v.bossnumber;
		end
	end
	
	f.checkboxes = {};
	f.bosslabels = {};
	for i=1,maxbosses,1 do
		f.checkboxes[i] = CreateFrame("CheckButton", "lootneed_individual_checkbox" .. i, f, "UICheckButtonTemplate");
		f.bosslabels[i] = f:CreateFontString("lootneed_bosslabel" .. i);
		f.checkboxes[i]:SetPoint("TOPRIGHT", -padding, -padding * 3 - f.instanceselection:GetHeight() - (i-1) * (checkboxheight));
		f.bosslabels[i]:SetPoint("TOPLEFT", padding, -padding * 3 - f.instanceselection:GetHeight() - (i-1) * (checkboxheight));
		f.checkboxes[i]:SetHeight(checkboxheight);
		f.bosslabels[i]:SetHeight(checkboxheight);
		f.checkboxes[i]:SetWidth(checkboxheight);
		f.bosslabels[i]:SetWidth(f:GetWidth() - f.checkboxes[i]:GetWidth() - padding * 3);
		f.checkboxes[i].number = i;
		if not f.bosslabels[i]:SetFont("Fonts\\FRIZQT__.TTF", 12, "") then
			print("Font not valid");
		end
		f.bosslabels[i]:SetJustifyH("LEFT");
		
		f.checkboxes[i]:SetScript("OnClick", function(s,event,arg1) if s:GetChecked() then LootNeed_SetNeed(s.number, 1); else LootNeed_SetNeed(s.number, 0); end end);
		
		f.checkboxes[i]:Hide();
		f.bosslabels[i]:Hide();
	end
end

function LootNeed_ScrollFrameUpdate(self, list)
	
	local offset = HybridScrollFrame_GetOffset(self);
	local buttons = self.buttons;
	
	for i=1, #buttons do
		local index = i + offset;
		local button = buttons[i];
		button:Hide();
		if index <= (#list or 0) then
			button:SetID(index);
			button.text:SetText(list[index]);
			local class, fileName = UnitClass(list[index]);
			if fileName then
				button.text:SetTextColor(unpack(RAID_CLASS_COLORS[fileName]));
			else
				button.text:SetTextColor(0.8,0.8,0.8,1);
			end
			button.text:Show();
			button:Show();
		end
	end
	
	HybridScrollFrame_Update(self, (scrollbutton_height * #list) or 0, scrollbutton_height);
end

function LootNeed_NeedScrollFrameUpdate()
	LootNeed_ScrollFrameUpdate(mainframe.collector.needscrollframe, needlist);
end

function LootNeed_NoNeedScrollFrameUpdate()
	LootNeed_ScrollFrameUpdate(mainframe.collector.noneedscrollframe, noneedlist);
end

function LootNeed_NoInfoScrollFrameUpdate()
	LootNeed_ScrollFrameUpdate(mainframe.collector.noinfoscrollframe, noinfolist);
end


function LootNeed_InitCollectorUI()
	local f = CreateFrame("Frame", "lootneed_collector", UIParent, "BasicFrameTemplate");
	f:SetSize(410, 300);
	f:SetPoint("CENTER", 0, 0);
	f.TitleText:SetText("Loot Need Collector");
	f:EnableMouse(true);
	f:Show();
	f:SetScript("OnUpdate", function(s) LootNeed_UpdateCollectorWindow(); end);
	mainframe.collector = f;
	
	local titleregion = f:CreateTitleRegion();
	titleregion:SetPoint("TOPLEFT", 0, 0);
	titleregion:SetWidth(f.TitleBg:GetWidth());
	titleregion:SetHeight(f.TitleBg:GetHeight());
	
	
	local width = 80;
	f.instanceselection = CreateFrame("Frame", "lootneed_collector_instanceselection", f, "UIDropDownMenuTemplate");
	f.instanceselection:SetPoint("TOPLEFT", -2, -padding - 20);
	f.instanceselection:SetHeight(20);
	UIDropDownMenu_SetWidth(f.instanceselection, width);
	UIDropDownMenu_Initialize(f.instanceselection, LootNeed_InstanceSelection);
	
	f.difficultyselection = CreateFrame("Frame", "lootneed_collector_difficultyselection", f, "UIDropDownMenuTemplate");
	f.difficultyselection:SetPoint("LEFT", f.instanceselection, "RIGHT", -20, 0);
	f.difficultyselection:SetHeight(20);
	UIDropDownMenu_SetWidth(f.difficultyselection, 50);
	UIDropDownMenu_Initialize(f.difficultyselection, LootNeed_DifficultySelection);
	
	f.bossselection = CreateFrame("Frame", "lootneed_collector_bossselection", f, "UIDropDownMenuTemplate");
	f.bossselection:SetPoint("LEFT", f.difficultyselection, "RIGHT", -20, 0);
	f.bossselection:SetHeight(20);
	UIDropDownMenu_SetWidth(f.bossselection, 120);
	UIDropDownMenu_Initialize(f.bossselection, LootNeed_BossSelection);
	
	local button = CreateFrame("Button", "lootneed_collector_getbutton", f, "UIPanelButtonTemplate");
	button:SetText("Get");
	button:SetPoint("TOPRIGHT", -15, -padding - 23);
	button:SetSize(42, 24);
	button:SetScript("OnClick", function() SendAddonMessage("LootNeed", "Get", "RAID"); SendAddonMessage("LootNeed", "Get", "GUILD"); end);

	
	-- Creating Scroll Frames
	local padding = 12;
	local width = (f:GetWidth() - 4 * padding) / 3;
	
	-- need scroll frame
	f.needscrollframeborder = CreateFrame("Frame", "lootneed_collector_needscrollborder", f, "InsetFrameTemplate");
	f.needscrollframeborder:SetPoint("TOPLEFT", padding, -83);
	f.needscrollframeborder:SetSize(width, 200);
	
	f.needscrollframeborder.header = f.needscrollframeborder:CreateFontString("lootneed_collector_needscrollborder_header", nil, "GameFontHighlight");
	f.needscrollframeborder.header:SetPoint("BOTTOMLEFT", f.needscrollframeborder, "TOPLEFT", 0, 0);
	f.needscrollframeborder.header:SetPoint("TOPRIGHT", f.needscrollframeborder, "TOPRIGHT", 0, 20);
	f.needscrollframeborder.header:SetText("Need");
	
	f.needscrollframe = CreateFrame("ScrollFrame", "lootneed_collector_needscrollframe", f.needscrollframeborder, "HybridScrollFrameTemplate");
	f.needscrollframe:SetPoint("TOPLEFT", 2, -2);
	f.needscrollframe:SetSize(width - 24, 200);
	
	f.needscrollframe.scrollBar = CreateFrame("Slider", "lootneed_collector_needscrollframe_slider", f.needscrollframe, "HybridScrollBarTemplate");
	f.needscrollframe.scrollBar:SetPoint("TOPLEFT", f.needscrollframeborder, "TOPRIGHT", -24, -20);
	f.needscrollframe.scrollBar:SetPoint("BOTTOMRIGHT", f.needscrollframeborder, "BOTTOMRIGHT", -4, 0);
	
	f.needscrollframe.stepSize = scrollbutton_height;
	f.needscrollframe.update = LootNeed_ScrollFrameUpdate;
	HybridScrollFrame_CreateButtons(f.needscrollframe, "LootNeedScrollButtonTemplate", 4, 20, "TOP", "BOTTOM", 0, 0);
	
	LootNeed_NeedScrollFrameUpdate();
	
	-- No need scroll frame
	f.noneedscrollframeborder = CreateFrame("Frame", "lootneed_collector_needscrollborder", f, "InsetFrameTemplate");
	f.noneedscrollframeborder:SetPoint("TOPLEFT", padding * 2 + width, -83);
	f.noneedscrollframeborder:SetSize(width, 200);
	
	f.noneedscrollframeborder.header = f.noneedscrollframeborder:CreateFontString("lootneed_collector_needscrollborder_header", nil, "GameFontHighlight");
	f.noneedscrollframeborder.header:SetPoint("BOTTOMLEFT", f.noneedscrollframeborder, "TOPLEFT", 0, 0);
	f.noneedscrollframeborder.header:SetPoint("TOPRIGHT", f.noneedscrollframeborder, "TOPRIGHT", 0, 20);
	f.noneedscrollframeborder.header:SetText("No Need");
	
	f.noneedscrollframe = CreateFrame("ScrollFrame", "lootneed_collector_noneedscrollframe", f.noneedscrollframeborder, "HybridScrollFrameTemplate");
	f.noneedscrollframe:SetPoint("TOPLEFT", 2, -2);
	f.noneedscrollframe:SetSize(width - 24, 200);
	
	f.noneedscrollframe.scrollBar = CreateFrame("Slider", "lootneed_collector_noneedscrollframe_slider", f.noneedscrollframe, "HybridScrollBarTemplate");
	f.noneedscrollframe.scrollBar:SetPoint("TOPLEFT", f.noneedscrollframeborder, "TOPRIGHT", -24, -20);
	f.noneedscrollframe.scrollBar:SetPoint("BOTTOMRIGHT", f.noneedscrollframeborder, "BOTTOMRIGHT", -4, 0);
	
	f.noneedscrollframe.stepSize = scrollbutton_height;
	f.noneedscrollframe.update = LootNeed_NoNeedScrollFrameUpdate;
	HybridScrollFrame_CreateButtons(f.noneedscrollframe, "LootNeedScrollButtonTemplate", 4, 20, "TOP", "BOTTOM", 0, 0);
	
	LootNeed_NoNeedScrollFrameUpdate();
	
	-- no information scrollframe
	f.noinfoscrollframeborder = CreateFrame("Frame", "lootneed_collector_noinfoscrollborder", f, "InsetFrameTemplate");
	f.noinfoscrollframeborder:SetPoint("TOPLEFT", padding * 3 + width * 2, -83);
	f.noinfoscrollframeborder:SetSize(width, 200);
	
	f.noinfoscrollframeborder.header = f.noinfoscrollframeborder:CreateFontString("lootneed_collector_noinfoscrollborder_header", nil, "GameFontHighlight");
	f.noinfoscrollframeborder.header:SetPoint("BOTTOMLEFT", f.noinfoscrollframeborder, "TOPLEFT", 0, 0);
	f.noinfoscrollframeborder.header:SetPoint("TOPRIGHT", f.noinfoscrollframeborder, "TOPRIGHT", 0, 20);
	f.noinfoscrollframeborder.header:SetText("No Information");
	
	f.noinfoscrollframe = CreateFrame("ScrollFrame", "lootneed_collector_noinfoscrollframe", f.noinfoscrollframeborder, "HybridScrollFrameTemplate");
	f.noinfoscrollframe:SetPoint("TOPLEFT", 2, -2);
	f.noinfoscrollframe:SetSize(width - 24, 200);
	
	f.noinfoscrollframe.scrollBar = CreateFrame("Slider", "lootneed_collector_noinfoscrollframe_slider", f.noinfoscrollframe, "HybridScrollBarTemplate");
	f.noinfoscrollframe.scrollBar:SetPoint("TOPLEFT", f.noinfoscrollframeborder, "TOPRIGHT", -24, -20);
	f.noinfoscrollframe.scrollBar:SetPoint("BOTTOMRIGHT", f.noinfoscrollframeborder, "BOTTOMRIGHT", -4, 0);
	
	f.noinfoscrollframe.stepSize = scrollbutton_height;
	f.noinfoscrollframe.update = LootNeed_NoInfoScrollFrameUpdate;
	HybridScrollFrame_CreateButtons(f.noinfoscrollframe, "LootNeedScrollButtonTemplate", 4, 20, "TOP", "BOTTOM", 0, 0);
	
	LootNeed_NoInfoScrollFrameUpdate();
end

function LootNeed_ToggleUI()
	if mainframe.collector then
		mainframe.collector:Hide();
	end
	if not mainframe.individual then
		LootNeed_InitUI();
	else
		if mainframe.individual:IsShown() then
			mainframe.individual:Hide();
		else
			mainframe.individual:Show();
		end
	end
end

function LootNeed_ToggleCollectorUI()
	if mainframe.individual then
		mainframe.individual:Hide();
	end
	if not mainframe.collector then
		LootNeed_InitCollectorUI();
	else
		if mainframe.collector:IsShown() then
			mainframe.collector:Hide();
		else
			mainframe.collector:Show();
		end
	end
end


-- Init --
mainframe = CreateFrame("Frame", "lootneed_mainframe", UIParent);
mainframe:RegisterEvent("CHAT_MSG_ADDON");
mainframe:RegisterEvent("PLAYER_STARTED_MOVING");
mainframe:SetScript("OnEvent", LootNeed_OnEvent);