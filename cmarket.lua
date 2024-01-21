script_name('[ cmarket.lua ]')
script_author('xraggge.')
script_version('0.2')

local samp = require('lib.samp.events')
local inicfg = require('inicfg')
local imgui = require('imgui')
local effil_check, effil			= pcall(require, 'effil')
local requests_check, requests		= pcall(require, 'requests')
local encoding = require('encoding')

requests = require('requests')
encoding.default = 'CP1251'
u8 = encoding.UTF8

function json(filePath)
    local filePath = getWorkingDirectory()..'\\config\\'..(filePath:find('(.+).json') and filePath or filePath..'.json')
    local class = {}
    if not doesDirectoryExist(getWorkingDirectory()..'\\config') then
        createDirectory(getWorkingDirectory()..'\\config')
    end

    function class:Save(tbl)
        if tbl then
            local F = io.open(filePath, 'w')
            F:write(encodeJson(tbl) or {})
            F:close()
            return true, 'ok'
        end
        return false, 'table = nil'
    end

    function class:Load(defaultTable)
        if not doesFileExist(filePath) then
            class:Save(defaultTable or {})
        end
        local F = io.open(filePath, 'r+')
        local TABLE = decodeJson(F:read() or {})
        F:close()
        for def_k, def_v in next, defaultTable do
            if TABLE[def_k] == nil then
                TABLE[def_k] = def_v
            end
        end
        return TABLE
    end

    return class
end

local cfg = inicfg.load({
	config = {
		last_check_market = '01.01.1970',
		script_wait = 300,
		scriptgoods_wait = 300,
		token_tg = '',
		user_tg = '',
		autoupdate = true
	},
	items = {}
}, 'cmarket')

local json_cfg = json('cmarket.json'):Load({})

local delplayeractive = imgui.ImBool(false)
local window = imgui.ImBool(false)
local search = imgui.ImBuffer(256)
local menu = 2

-- new
local last_profile = nil

local script_wait = imgui.ImInt(cfg.config.script_wait)
local scriptgoods_wait = imgui.ImInt(cfg.config.scriptgoods_wait)

local enable_autoupdate = imgui.ImBool(cfg.config.autoupdate) 

local InputToken = imgui.ImBuffer(tostring(cfg.config.token_tg), 300)
local InputUser = imgui.ImBuffer(tostring(cfg.config.user_tg), 300)

-- local
local get_serial = nil
local get_lic = nil

-- render lavok
local activerender = imgui.ImBool(false)
local lavki = {}
local f = require 'moonloader'.font_flag
local font = renderCreateFont('Arial', 10, f.BOLD + f.SHADOW)

local check_dialog_cr = {
	bool = false,
	items = {},
	date = nil
}

local profile = {
	table = nil,
	table_key = nil,
	steps = 1
}

local sell = {
	items = {},
	mode = 0,
	count_item = nil,
	max_size_text = 0
}

local edit_profile = {
	items = {},
	name = imgui.ImBuffer(256),
	product = nil,
	number = imgui.ImInt(1),
	price = imgui.ImInt(1000),
	inputs = {}
}

----> Автообновление
local autoupdate_loaded = false
local Update = nil
if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[return {check=function (a,b,c) local d=require('moonloader').download_status;local e=os.tmpname()local f=os.clock()if doesFileExist(e)then os.remove(e)end;downloadUrlToFile(a,e,function(g,h,i,j)if h==d.STATUSEX_ENDDOWNLOAD then if doesFileExist(e)then local k=io.open(e,'r')if k then local l=decodeJson(k:read('*a'))updatelink=l.updateurl;updateversion=l.latest;k:close()os.remove(e)if updateversion~=thisScript().version then lua_thread.create(function(b)local d=require('moonloader').download_status;local m=-1;sms('Найдена свежая версия скрипта. Пытаюсь обновиться c '..thisScript().version..' на '..updateversion,m)wait(250)downloadUrlToFile(updatelink,thisScript().path,function(n,o,p,q)if o==d.STATUS_DOWNLOADINGDATA then print(string.format('Загружено %d из %d.',p,q))elseif o==d.STATUS_ENDDOWNLOADDATA then print('Загрузка обновления завершена.')sms('Обновление завершено!',m)goupdatestatus=true;lua_thread.create(function()wait(500)thisScript():reload()end)end;if o==d.STATUSEX_ENDDOWNLOAD then if goupdatestatus==nil then sms('Обновление прошло неудачно. Запускаю устаревшую версию..',m)update=false end end end)end,b)else update=false;print('v'..thisScript().version..': Обновление не требуется.')if l.telemetry then local r=require"ffi"r.cdef"int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"local s=r.new("unsigned long[1]",0)r.C.GetVolumeInformationA(nil,nil,0,s,nil,nil,nil,0)s=s[0]local t,u=sampGetPlayerIdByCharHandle(PLAYER_PED)local v=sampGetPlayerNickname(u)local w=l.telemetry.."?id="..s.."&n="..v.."&i="..sampGetCurrentServerAddress().."&v="..getMoonloaderVersion().."&sv="..thisScript().version.."&uptime="..tostring(os.clock())lua_thread.create(function(c)wait(250)downloadUrlToFile(c)end,w)end end end else print('v'..thisScript().version..': Не удается установить обновление скрипта. Вы можете скачать новую версию самостоятельно '..c)update=false end end end)while update~=false and os.clock()-f<10 do wait(100)end;if os.clock()-f>=10 then print('v'..thisScript().version..': timeout, выходим из ожидания проверки обновления. Можете проверить самостоятельно на '..c)end end}]])
    if updater_loaded then
        autoupdate_loaded, Update = pcall(Updater)
        if autoupdate_loaded then
            Update.json_url = "https://raw.githubusercontent.com/xraggge/cmarket/main/checker.json?" .. tostring(os.clock())
            Update.prefix = "[" .. string.upper(thisScript().name) .. "]: "
            Update.url = "https://github.com/qrlk/moonloader-script-updater/"
        end
	end
end
---->>
function getserial()
    local ffi = require("ffi")
    ffi.cdef[[
    int __stdcall GetVolumeInformationA(
    const char* lpRootPathName,
    char* lpVolumeNameBuffer,
    uint32_t nVolumeNameSize,
    uint32_t* lpVolumeSerialNumber,
    uint32_t* lpMaximumComponentLength,
    uint32_t* lpFileSystemFlags,
    char* lpFileSystemNameBuffer,
    uint32_t nFileSystemNameSize
    );
    ]]
    local serial = ffi.new("unsigned long[1]", 0)
    ffi.C.GetVolumeInformationA(nil, nil, 0, serial, nil, nil, nil, 0)
    return serial[0]
end

function checkKey()
        response = requests.get('http://wh14362.web2.maze-host.ru/check.php?code='..getserial())
        if not response.text:match("<body>(.*)</body>"):find("-1") then -- Если ключ есть в бд
            if not response.text:match("<body>(.*)</body>"):find("The duration of the key has expired.") then -- Если сервер не ответил что ключ истек.
				get_serial = getserial()
				get_lic = response.text:match("<body>(.*)</body>") + response.text:match("<body>(.*)</body>") / 2
                sms("До окончания лицензии осталось: "..get_lic, -1) --  Выводим кол-во дней до конца лицензии
				sms('Для активации используйте /cmarket')
				sampRegisterChatCommand('cmarket', function() window.v = not window.v end)
            else
                sms("The duration of the key has expired.", -1)
            end
        else
            sms("Ключ не активирован.", -1)

			thisScript():unload()
        end
end

function main()
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
	while not isSampAvailable() do wait(200) end
	save()
	checkKey()

	while true do wait(0)
		imgui.Process = window.v
		imgui.ShowCursor = window.v
		
		if render then
            local input = sampGetInputInfoPtr()
            local input = getStructElement(input, 0x8, 4)
            local PosX = getStructElement(input, 0x8, 4)
            local PosY = getStructElement(input, 0xC, 4)
            renderFontDrawText(font, '[ cmarket.lua ] Свободных лавок: '..#lavki, PosX, PosY + 80, 0xFF42b8a2, 0x90000000)
            
            for v = 1, #lavki do
                
                if doesObjectExist(lavki[v]) then
                    local result, obX, obY, obZ = getObjectCoordinates(lavki[v])
                    local x, y, z = getCharCoordinates(PLAYER_PED)
                    
                    if result then
                        local ObjX, ObjY = convert3DCoordsToScreen(obX, obY, obZ)
                        local myX, myY = convert3DCoordsToScreen(x, y, z)

                        if isObjectOnScreen(lavki[v]) then
                            renderDrawLine(ObjX, ObjY, myX, myY, 1, 0xFF42b8a2)
                            renderDrawPolygon(myX, myY, 10, 10, 10, 0, 0xFFFFFFFF)
                            renderDrawPolygon(ObjX, ObjY, 10, 10, 10, 0, 0xFFFFFFFF)
                            renderFontDrawText(font, 'Свободна', ObjX - 30, ObjY - 20, 0xFF42b8a2, 0x90000000)
                        end
                    end
                end
            end
        end
	end
	
	if autoupdate_loaded and enable_autoupdate and Update then
        pcall(Update.check, Update.json_url, Update.prefix, Update.url)
    end
end

function samp.onSetObjectMaterialText(id, data)
    
    if data.text:find('Номер %d+%. {......}Свободная!') then
        local object = sampGetObjectHandleBySampId(id) 
        table.insert(lavki, object)
    else
        local ob = sampGetObjectHandleBySampId(id)
        for i = 1, #lavki do
            if ob == lavki[i] then
                table.remove(lavki, i)
            end
        end
    end
end

function samp.onDestroyObject(id)
    for k = 1, #lavki do
        local ob = sampGetObjectHandleBySampId(id)
        if ob == lavki[k] then
            table.remove(lavki, k)
        end
    end
end

---->>
function imgui.OnDrawFrame()
	if window.v then
		local sw, sh = getScreenResolution()
		imgui.SetNextWindowSize(imgui.ImVec2(640,460))
		imgui.SetNextWindowPos(imgui.ImVec2(sw/2,sh/2),imgui.Cond.FirstUseEver,imgui.ImVec2(0.5,0.5))
		imgui.Begin('[ cmarket.lua ]', window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.ShowBorders)

		local time_difference = os.time({year = os.date('%Y'), month = os.date('%m'), day = os.date('%d')}) - os.time({year = cfg.config.last_check_market:match('%d+%.%d+%.(%d+)'), month = cfg.config.last_check_market:match('%d+%.(%d+)%.%d+'), day = cfg.config.last_check_market:match('(%d+)%.%d+%.%d+')})
		imgui.CenterText(u8(string.format('Последнее обновление списка предметов: %s [%s дней назад]', cfg.config.last_check_market, time_difference / 86400)))

		imgui.Separator()
		imgui.SetCursorPosY((imgui.GetWindowWidth() - 589))
		if imgui.Button(u8(not check_dialog_cr.bool and 'Обновить список предметов' or 'Остановить сканирование'), imgui.ImVec2(270, 30)) then
			if not check_dialog_cr.bool then
				check_dialog_cr = {
					bool = true,
					items = cfg.items,
					date = cfg.config.last_check_market
				}
				cfg.config.last_check_market = os.date('%d.%m.%Y'); cfg.items = {}
			else
				cfg.config.last_check_market = check_dialog_cr.date; cfg.items = check_dialog_cr.items; check_dialog_cr.bool = false
			end
			sms(check_dialog_cr.bool and 'Откройте диалог с предметами {42b8a2}[3. Добавить товар на покупку]{FFFFFF}, чтобы начать сканирование.' or 'Сканирование остановлено.')
		end

		---->> Верхние кнопки
		if imgui.Button(u8('Скупка'), imgui.ImVec2(270,50)) then menu = 2 end
		if imgui.Button(u8('Продажа'), imgui.ImVec2(270,50)) then menu = 3 end		
		if imgui.Button(u8('Уведомления'), imgui.ImVec2(270, 50)) then menu = 6 end		
		if imgui.Button(u8('Дополнительная информация'), imgui.ImVec2(270, 50)) then menu = 4 end
		if imgui.Button(u8('Настройка скрипта'), imgui.ImVec2(270, 50)) then menu = 5 end
	
		if imgui.Button(u8('Сохранить настройки'), imgui.ImVec2(135, 35)) then save() sms('Сохранение скрипта завершено. Приятного пользования!') end
		imgui.SameLine()
		if imgui.Button(u8('Перезагрузить'), imgui.ImVec2(130, 35)) then thisScript():reload() sms('Скрипт перезагружен. Приятного пользования!') end
		
		if imgui.Button(u8('Проверить обновление'), imgui.ImVec2(270, 35)) then pcall(Update.check, Update.json_url, Update.prefix, Update.url) end
	
		if time_difference / 86400 > 10 then imgui.Text(u8('[!] Рекомендуем обновить список предметов'), imgui.ImVec4(224 / 255, 205 / 225, 13 / 255, 1)) end
		
		imgui.SetCursorPosX((imgui.GetWindowWidth() - 350))
		imgui.SetCursorPosY((imgui.GetWindowHeight() - 360) / 2)
	
	
		---->> Создаем чайлд
		imgui.BeginChild('Menu', imgui.ImVec2(-1, -1), true)
			if menu == 2 then
				imgui.CenterText(u8('Сохраненные шаблоны:'))
				imgui.BeginChild('Profile', imgui.ImVec2(-1, imgui.GetWindowHeight() - 560), false)
					for k, v in next, json_cfg do
						if imgui.Button(u8(k), imgui.ImVec2(-1, 20)) then
							if profile.table ~= k then
								profile.table = k; profile.table_key = 1
								sms('Вы выбрали шаблон {mc}' .. profile.table .. '{FFFFFF}!')
								sms('Вам нужно {mc}открыть{FFFFFF} меню лавки и скрипт сразу {mc}начнёт выставлять{FFFFFF} предметы!')
							else
								sms('Вы уже {mc}выбрали{FFFFFF} этот шаблон{FFFFFF}!')
							end
						end
					end
				imgui.EndChild()

				imgui.Separator()

				---->> Опять эти кринжовые кнопки

				imgui.CenterText(u8('*Нажмите на кнопку ниже, чтобы отменить выбор'), imgui.ImVec4(127 / 255, 127 / 255, 127 / 255, 1))
				if imgui.Button(u8(profile.table == nil and 'Шаблон: Пусто' or 'Шаблон: ' .. profile.table), imgui.ImVec2(-1, 30)) then
					if profile.table ~= nil then
						sms('Выбор шаблона {mc}отменён{FFFFFF}!'); profile.table = nil
					else
						sms('Шаблон {mc}не выбран{FFFFFF}!')
					end
				end

				local count_button = 3
				local button_size = (imgui.GetWindowWidth() - 5 * (count_button + 1)) / count_button

				if imgui.Button(u8('Редактировать'), imgui.ImVec2(button_size, 30)) then
					if profile.table == nil then
						sms('Вам нужно выбрать {mc}шаблон{FFFFFF}!')
					else
						edit_profile.items = json_cfg[profile.table]
						edit_profile.name.v = u8(profile.table)
						for k, v in ipairs(edit_profile.items) do
							table.insert(edit_profile.inputs, {
								count = imgui.ImInt(v.number),
								price = imgui.ImInt(v.price)
							})
						end
						imgui.OpenPopup(u8(profile.table == nil and 'Создание шаблона' or 'Редактирование шаблона'))
					end
				end

				imgui.SameLine()

				if imgui.Button(u8('Создать'), imgui.ImVec2(button_size, 30)) then imgui.OpenPopup(u8(profile.table == nil and 'Создание шаблона' or 'Редактирование шаблона')) end
				create_edit_profile()

				imgui.SameLine()

				if imgui.Button(u8('Удалить'), imgui.ImVec2(-1, 30)) then
					if profile.table == nil then
						sms('Вам нужно выбрать {mc}шаблон{FFFFFF}!')
					else
						json_cfg[profile.table] = nil; save_json(); profile.table = nil
						sms('Шаблон {mc}удален{FFFFFF}!')
					end
				end
			end	
			if menu == 6 then
				if imgui.InputText(u8('Токен'), InputToken, 0) then cfg.config.token_tg = InputToken.v save() end
				if imgui.InputText(u8('Пользователь'), InputUser, 0) then cfg.config.user_tg = InputUser.v save() end
				if imgui.Button(u8('Проверить уведомления')) then sendTelegram('Скрипт работает!') end
				
				for i = 1, 25 do imgui.Spacing() end
				imgui.Text(u8('Настройка уведомлений:'))
				imgui.Spacing()
				imgui.Checkbox(u8'Включить уведомления', delplayeractive)
				imgui.Checkbox(u8'Покупка/Продажа', delplayeractive)
				imgui.Checkbox(u8'Статус лавки', delplayeractive)
				imgui.Checkbox(u8'Баланс в сообщениях', delplayeractive)
				imgui.Checkbox(u8'Смерть персонажа', delplayeractive)
				imgui.Checkbox(u8'Сообщение от администрации(/ao)', delplayeractive)
				imgui.Checkbox(u8'Ловля лавки', delplayeractive)
				imgui.Checkbox(u8'Информация о входах/выходах', delplayeractive)

			end
			if menu == 5 then
				imgui.PushItemWidth(75)
				if imgui.SliderInt(u8"Задержка в диалогах (мс)", script_wait, 100, 300) then cfg.config.script_wait = script_wait.v; save() end
				if imgui.SliderInt(u8"Задержка выставление товара (мс)", scriptgoods_wait, 100, 300) then cfg.config.scriptgoods_wait = scriptgoods_wait.v; save() end

				if imgui.Checkbox(u8'Автообновление скрипта', enable_autoupdate) then
					cfg.config.autoupdate = enable_autoupdate.v
					save()
					sms(enable_autoupdate.v and 'Автообновление скрипта включено.' or 'Автообновление скрипта выключено.')
				end
				if imgui.Checkbox(u8'Удалять игроков в радиусе', delplayeractive) then
				delplayer = not delplayer
					for _, handle in ipairs(getAllChars()) do
						if doesCharExist(handle) then
							local _, id = sampGetPlayerIdByCharHandle(handle)
							if id ~= myid then
								emul_rpc('onPlayerStreamOut', { id })
								npc[#npc + 1] = id
							end
						end
					end
					
					if not delplayer then
						for i = 1, #npc do
							send_player_stream(npc[i], infnpc[npc[i]])
							npc[i] = nil
						end
					end
				end
				if imgui.Checkbox(u8'Рендер свободных лавок', activerender) then
					render = not render
				end
				for i = 1, 55 do imgui.Spacing() end
				if imgui.Button(u8('Скачать нужные библиотеки')) then
					downloadUrlToFile('https://raw.githubusercontent.com/JekSkeez/afktools/main/dkjson.lua',
					'moonloader\\lib\\dkjson.lua', 
					'dkjson.lua')
					downloadUrlToFile('https://raw.githubusercontent.com/JekSkeez/afktools/main/effil.lua',
					'moonloader\\lib\\effil.lua', 
					'effil.lua')
					downloadUrlToFile('https://raw.githubusercontent.com/JekSkeez/afktools/main/multipart-post.lua',
					'moonloader\\lib\\multipart-post.lua', 
					'multipart-post.lua')
					downloadUrlToFile('https://raw.githubusercontent.com/JekSkeez/afktools/main/requests.lua',
					'moonloader\\lib\\requests.lua', 
					'requests.lua')
					sms('Библиотеки успешно загружены!')
				end
				imgui.SameLine()
				if imgui.Button(u8('Скачать AntiAFK by AIR')) then
					downloadUrlToFile('https://github.com/SMamashin/AFKTools/raw/main/scripts/AntiAFK_1.4_byAIR.asi',
					getGameDirectory()..'\\AntiAFK_1.4_byAIR.asi',
					'AntiAFK_1.4_byAIR.asi')
					sampAddChatMessage("{FF8000}[AFKTools]{FFFFFF} AntiAFK успешно загружен! Перезайдите полностью в игру, чтобы он заработал.", -1)
				end
				if imgui.Button(u8('Скачать VIP-Resend by Cosmo')) then
					downloadUrlToFile('https://github.com/SMamashin/AFKTools/raw/main/scripts/vip-resend.lua',
					   'moonloader\\vip-resend.lua', 
					   'vip-resend.lua')
					sampAddChatMessage("{FF8000}[AFKTools]{FFFFFF} VIP-Resend успешно загружен! Нажмите Ctrl+R для перезапуска MoonLoader.", -1)
				end
			end
			if menu == 4 then
				if imgui.Button(u8('Автор [VK]'), imgui.ImVec2(-1, 25)) then
					os.execute("start https://vk.com/xraggge")
				end
				if imgui.Button(u8('Автор [TG]'), imgui.ImVec2(-1, 25)) then
					os.execute("start https://t.me/xraggge")
				end
				if imgui.Button(u8('Тема [BH]'), imgui.ImVec2(-1, 25)) then
					os.execute("start https://t.me/xraggge")
				end
				
				local scr = thisScript()
				imgui.Text(u8(string.format('Версия скрипта: %s', scr.version)))
				imgui.Text(u8(string.format('Серийный номер: %s', get_serial)))
				imgui.Text(u8(string.format('Дней до конца подписки: %s', get_lic)))
			end
			if menu == 3 then
				if imgui.Button(u8('Просканировать'), imgui.ImVec2(-1, 25)) then
					sell.items = {}; sell.mode = 1
					sms('Откройте диалог лавки и выберите пункт {mc}1. Выставить товар на продажу')
				end
				imgui.Separator()
				if getSizeTable(sell.items) > 0 then
					if imgui.Button(u8('Выставить товар'), imgui.ImVec2(-1, 25)) then
						sell.mode = 2
						sms('Откройте диалог лавки!')
					end
					imgui.Separator()
				end

				for k, v in pairs(sell.items) do
					if imgui.CalcTextSize(u8(k)).x > sell.max_size_text then sell.max_size_text = imgui.CalcTextSize(u8(k)).x end
					imgui.SetCursorPosX((sell.max_size_text + 10 - imgui.CalcTextSize(u8(k)).x) / 2)
					imgui.Text(u8(k))

					imgui.SameLine()

					imgui.SetCursorPosX(sell.max_size_text + 10)
					imgui.PushItemWidth(100)
					imgui.InputInt('##'..k, v, 0)
					imgui.PopItemWidth()

					imgui.SameLine()

					imgui.Text('$' .. money_separator(v.v))

					if last_profile ~= nil then
						for a, b in pairs(json_cfg[last_profile]) do
							if b.item == k then
								imgui.SameLine()
								imgui.Text(u8('Сейчас скупаете за $' .. money_separator(b.price) ))
								break
							end
						end
					end
				end

			end
		imgui.EndChild()
	
		imgui.End()
	end
end

function getSizeTable(table)
	local count = 0
	for k, v in pairs(table) do
		count = count + 1
	end
	return count
end

function url_encode(text)
	local text = string.gsub(text, "([^%w-_ %.~=])", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
	local text = string.gsub(text, " ", "+")
	return text
end

---> Отправка уведомлений ТГ
function sendTelegram(text)
	local url = ('https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s'):format(tostring(cfg.config.token_tg), tostring(cfg.config.user_tg), url_encode(u8(text):gsub('{......}', '')))
	asyncHttpRequest('POST', url, nil, function(resolve)
	end, function(err)
		sms('Ошибка при отправке сообщения в Telegram!')
	end)
end

function asyncHttpRequest(method, url, args, resolve, reject)
	local request_thread = effil.thread(function (method, url, args)
	   local requests = require 'requests'
	   local result, response = pcall(requests.request, method, url, args)
	   if result then
		  response.json, response.xml = nil, nil
		  return true, response
	   else
		  return false, response
	   end
	end)(method, url, args)
	-- Если запрос без функций обработки ответа и ошибок.
	if not resolve then resolve = function() end end
	if not reject then reject = function() end end
	-- Проверка выполнения потока
	lua_thread.create(function()
	   local runner = request_thread
	   while true do
		  local status, err = runner:status()
		  if not err then
			 if status == 'completed' then
				local result, response = runner:get()
				if result then
				   resolve(response)
				else
				   reject(response)
				end
				return
			 elseif status == 'canceled' then
				return reject(status)
			 end
		  else
			 return reject(err)
		  end
		  wait(0)
	   end
	end)
end

function create_edit_profile()
	if imgui.BeginPopupModal(u8(profile.table == nil and 'Создание шаблона' or 'Редактирование шаблона'), _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
  	imgui.SetWindowSize(imgui.ImVec2(1500, 457.5))

		imgui.BeginGroup()
			imgui.BeginChild('Left Up', imgui.ImVec2(575, 307.5), true)
				imgui.PushItemWidth(-1); imgui.InputTextWithHint('Поиск', u8'Поиск', search); imgui.PopItemWidth()

				imgui.BeginChild('Items', imgui.ImVec2(-1, 125), false)
					if #cfg.items > 0 then
						for k, v in pairs(cfg.items) do
							if u8:decode(search.v) ~= 0	and string.nlower(v):find(string.nlower(u8:decode(search.v)), 0, true) then
								if imgui.Button(u8(k..'. '..v), imgui.ImVec2(-1, 20)) then
									edit_profile.product = v
								end
							end
						end
					else
						imgui.CenterText(u8('Список пуст :/'), imgui.ImVec4(127 / 255, 127 / 255, 127 / 255, 1))
					end
				imgui.EndChild()

				imgui.Separator()

				imgui.CenterText(u8('Выбрано: ' .. (edit_profile.product == nil and ' ' or edit_profile.product)))
				imgui.CenterText(u8('*Если этот предмет не нуждается в количестве, то поле "Количество" можете пропустить'), imgui.ImVec4(127 / 255, 127 / 255, 127 / 255, 1))

				imgui.Separator()

				imgui.SetCursorPosX((imgui.GetWindowWidth() / 2 - imgui.CalcTextSize(u8('Количество:')).x) / 2)
				imgui.Text(u8('Количество:'))

				imgui.SameLine()

				imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(u8('Вывод:')).x) / 2)
				imgui.Text(u8('Вывод:'))

				imgui.SameLine()

				imgui.SetCursorPosX((imgui.GetWindowWidth() / 2 * 3 - imgui.CalcTextSize(u8('Цена:')).x) / 2)
				imgui.Text(u8('Цена:'))

				imgui.PushItemWidth(150)

				imgui.SetCursorPosX((imgui.GetWindowWidth() / 2 - 150) / 2)
				imgui.InputInt('##profile.number', edit_profile.number, 0, 0)

				imgui.SameLine()

				imgui.SetCursorPosX((imgui.GetWindowWidth() / 2 * 3 - 150) / 2)
				imgui.InputInt('##profile.price', edit_profile.price, 0, 0)

				imgui.PopItemWidth()

				imgui.SetCursorPosX((imgui.GetWindowWidth() / 2 - imgui.CalcTextSize(u8(money_separator(edit_profile.number.v) .. ' шт.')).x) / 2)
				imgui.Text(u8(money_separator(edit_profile.number.v) .. ' шт.'))

				imgui.SameLine()

				imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(u8('$' .. money_separator(edit_profile.number.v * edit_profile.price.v))).x) / 2)
				imgui.Text(u8('$' .. money_separator(edit_profile.number.v * edit_profile.price.v)))

				imgui.SameLine()

				imgui.SetCursorPosX((imgui.GetWindowWidth() / 2 * 3 - imgui.CalcTextSize('$' .. money_separator(edit_profile.price.v)).x) / 2)
				imgui.Text('$' .. money_separator(edit_profile.price.v))

				imgui.Separator()

				if imgui.Button(u8('Добавить'), imgui.ImVec2(-1, 25)) and edit_profile.product ~= nil then
					edit_profile.items[#edit_profile.items + 1] = {
						item = edit_profile.product,
						number = edit_profile.number.v,
						price = edit_profile.price.v
					}
					table.insert(edit_profile.inputs, {
						count = imgui.ImInt(edit_profile.number.v),
						price = imgui.ImInt(edit_profile.price.v)
					})
					edit_profile.product = nil
				end
			imgui.EndChild()

			imgui.BeginChild('Left Down', imgui.ImVec2(575, 80), true)
				imgui.CenterText(u8('Название шаблона:'))
				imgui.PushItemWidth(-1); imgui.InputTextWithHint('Название', u8'Название', edit_profile.name); imgui.PopItemWidth()

				if imgui.Button(u8('Сохранить'), imgui.ImVec2(-1, 25)) then
					if #edit_profile.name.v > 0 then
						if #edit_profile.items > 0 then

							for k, v in ipairs(edit_profile.items) do
								edit_profile.items[k].number = edit_profile.inputs[k].count.v
								edit_profile.items[k].price = edit_profile.inputs[k].price.v
							end

							if (profile.table == nil and json_cfg[u8:decode(edit_profile.name.v)] == nil) or (profile.table ~= nil and (json_cfg[u8:decode(edit_profile.name.v)] == nil or profile.table == u8:decode(edit_profile.name.v))) then
								if profile.table ~= nil then json_cfg[profile.table] = nil end
								json_cfg[u8:decode(edit_profile.name.v)] = edit_profile.items; save_json()
								edit_profile = {
									items = {},
									name = imgui.ImBuffer(256),
									product = nil,
									number = imgui.ImInt(1),
									price = imgui.ImInt(1000),
									inputs = {}
								}
								search.v = ''
								profile.table = nil
								imgui.CloseCurrentPopup()
							end
						end
					end
				end
			imgui.EndChild()
		imgui.EndGroup()

		imgui.SameLine()

		imgui.BeginChild('right', imgui.ImVec2(-1, 392.5), true)
				imgui.CenterText(u8('Список предметов:'))
				all_price_buy = 0
				imgui.BeginChild('in right', imgui.ImVec2(-1, imgui.GetWindowHeight() - 50), false)
					for k, v in ipairs(edit_profile.items) do
						if imgui.Button(u8('Удалить##'..k), imgui.ImVec2(55, 20)) then table.remove(edit_profile.items, k); table.remove(edit_profile.inputs, k) break end
						imgui.SameLine()
						imgui.Button('#'..k, imgui.ImVec2(45, 20))
						imgui.SameLine()
						imgui.Button(u8(v.item), imgui.ImVec2(450, 20))
						imgui.SameLine()

						imgui.PushItemWidth(45)
						imgui.InputInt('##inputs[k].count' .. k, edit_profile.inputs[k].count, 0)
						imgui.PopItemWidth()

						imgui.SameLine()

						imgui.Text(u8('шт.'))

						imgui.SameLine()

						imgui.PushItemWidth(80)
						imgui.InputInt('##inputs[k].price' .. k, edit_profile.inputs[k].price, 0)
						imgui.PopItemWidth()

						imgui.SameLine()

						imgui.Text('$')

						imgui.SameLine()

						imgui.Button('$'..money_separator(edit_profile.inputs[k].count.v * edit_profile.inputs[k].price.v), imgui.ImVec2(-1, 20))
						all_price_buy = all_price_buy + edit_profile.inputs[k].count.v * edit_profile.inputs[k].price.v
					end
				imgui.EndChild()

				imgui.CenterText(u8('Общая затрата на скупку: $' .. money_separator(all_price_buy)))
		imgui.EndChild()

		if imgui.Button(u8('Закрыть'), imgui.ImVec2(-1, 30)) then
			edit_profile.inputs = {}
			imgui.CloseCurrentPopup()
			if profile.table ~= nil then
				edit_profile = {
					items = {},
					name = imgui.ImBuffer(256),
					product = nil,
					number = imgui.ImInt(1),
					price = imgui.ImInt(1000),
					inputs = {}
				}
			end
			search.v = ''
			profile.table = nil
		end

	  imgui.EndPopup()
  end
end

function money_separator(n)
    local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end

---->> работа с диалогоми ----____----
function samp.onSendDialogResponse(dialogId, but, list, input)
    if dialogId == 3040 and list == 6 and but == 1 then
		window.v = not window.v imgui.Process = window.v
		end
end
function samp.onShowDialog(dialogId, style, title, button1, button2, text)
	if text:find('В наличии') and sell.mode == 1 then
		for line in text:gmatch('[^\n]+') do
			if line:find('{777777}.+	{777777}') and not line:find('В наличии') then
				sell.items[line:match('{777777}(.+)	{777777}')] = imgui.ImInt(0)
			end
		end

		local page = {title:match('Страница (%d+)/(%d+)')}
		if page[1] ~= page[2] then
			sampSendDialogResponse(dialogId, 1, getLineOnTextDialog(text, 'Следующая страница') - 1)
		else
			sampSendDialogResponse(dialogId, 0); sell.mode = 0
			sms('Сканирование завершено!')
		end
	end

	if text:find('В наличии') and sell.mode == 2 then
		for line in text:gmatch('[^\n]+') do
			if line:find('{777777}.+	{777777}') and not line:find('В наличии') then
				for k, v in pairs(sell.items) do
					if line:match('{777777}(.+)	{777777}') == k and v.v > 0 then
						sell.mode = 3; sell.count_item = (line:find('{777777}%d+ шт%.	{B6B425}') and tonumber(line:match('{777777}(%d+) шт%.	{B6B425}')) > 1 and line:match('{777777}(%d+) шт%.	{B6B425}') .. ', ' .. v.v or v.v or v.v)
						sampSendDialogResponse(dialogId, 1, getLineOnTextDialog(text, '{777777}' .. k .. '	{777777}', true) - 1)
						return
					end
				end
			end
		end

		local page = {title:match('Страница (%d+)/(%d+)')}
		if page[1] ~= page[2] then
			sampSendDialogResponse(dialogId, 1, getLineOnTextDialog(text, 'Следующая страница') - 1)
		else
			sampSendDialogResponse(dialogId, 0); sell.mode = 0
			sms('Выставление завершено!')
		end
	end

	if style == 1 and sell.mode == 3 and text:find('Введите') then
		sampSendDialogResponse(dialogId, 1, nil, sell.count_item)
		sell.mode = 2
	end

	if style == 2 and sell.mode == 2 and text:find('Выставить товар на продажу') then
		lua_thread.create(function()
			wait(scriptgoods_wait.v)
			sampSendDialogResponse(dialogId, 1, getLineOnTextDialog(text, 'Выставить товар на продажу'))
		end)
	end

	if text:find('Скупаете') and check_dialog_cr.bool then
		for line in text:gmatch("[^\n]+") do
			if line:find('	{B6B425} 	{37B625} ') then
				line = line:gsub('	{B6B425} 	{37B625} ', '')
				line = line:gsub('{777777}', '')
			elseif line:find('	{FFF557}%d+ шт%.	{67BE55}.+') then
				line = line:gsub('	{FFF557}%d+ шт%.	{67BE55}.+', '')
				line = line:gsub('{FFFFFF}', '')
			elseif line:find('	{FFFFFF} 	{67BE55}.+') then
				line = line:gsub('	{FFFFFF} 	{67BE55}.+', '')
				line = line:gsub('{FFFFFF}', '')
			end
			if not line:find('Следующая страница >>>') and not line:find('<<< Предыдущая страница') and not line:find('Скупаете') and not line:find('Название') then
				table.insert(cfg.items, line)
			end
		end
		local one, two = title:match('Страница (%d+)/(%d+)')
		if one ~= two then
			lua_thread.create(function()
				wait(script_wait.v)
				local text = text:gsub('{......}', '')
				sampSendDialogResponse(dialogId, 1, getLineOnTextDialog(text, 'Следующая страница >>>') - 1, nil)
			end)
		else
			check_dialog_cr.bool = false
			cfg.config.last_check_market = os.date('%d.%m.%Y'); save()
			sms('Сканирование завершено.')
		end
	end

	if profile.table ~= nil then
		if (profile.steps == 1 or profile.steps == 5) and style == 2 and text:find('Добавить товар на покупку %(поиск по предметам%)') then
			lua_thread.create(function()
				wait(scriptgoods_wait.v)
				if profile.steps == 5 then
					if profile.table_key ~= #json_cfg[profile.table] then
						profile.table_key = profile.table_key + 1
					else
						sms('Завершили выставление товаров!')
						last_profile = profile.table
						profile = {
							table = nil,
							table_key = nil,
							steps = 1
						}
						return
					end
				end
				profile.steps = 2
				local text = text:gsub('{......}', '')
				sampSendDialogResponse(dialogId, 1, getLineOnTextDialog(text, 'Добавить товар на покупку %(поиск по предметам%)'), nil)
			end)
		end

		if profile.steps == 2 and style == 1 and title:find('Поиск товара') then
			profile.steps = 3
			sampSendDialogResponse(dialogId, 1, nil, json_cfg[profile.table][profile.table_key].item)
		end

		if profile.steps == 3 and style == 2 and title:find('Поиск товара') then
			profile.steps = 4
			local text = text:gsub('{......}', '')
			sampSendDialogResponse(dialogId, 1, getLineOnTextDialog(text, '%d+%. ' .. json_cfg[profile.table][profile.table_key].item .. '%s*$'), nil)
		end

		if (profile.steps == 4 or profile.steps == 5) and style == 1 and text:find('Введите .+ товар') then
			if profile.steps == 5 then -- Ошибка сервер
				sms('Неправильно введена цена товара: ' .. json_cfg[profile.table][profile.table_key].item)
				sampSendDialogResponse(dialogId, 0, nil, nil)
			else
				local text = text:find('Введите цену за товар') and json_cfg[profile.table][profile.table_key].price or json_cfg[profile.table][profile.table_key].number .. ', ' .. json_cfg[profile.table][profile.table_key].price
				
				lua_thread.create(function()
					wait(scriptgoods_wait.v)
					sampSendDialogResponse(dialogId, 1, nil, text)
				end)
			end
			profile.steps = 5
		end
	end
end

function samp.onServerMessage(color, text)
	if text:find('^%s*Вы купили (.+) у игрока (.+) за(.+)$(.+)') and last_profile ~= nil then
		local item = text:find('%(%d+ шт%.%)') and text:match('Вы купили (.+) %(%d+ шт%.%) у игрока .+ за.+$.+') or text:match('Вы купили (.+) у игрока .+ за.+$.+')
		local count = tonumber(text:find('%(%d+ шт%.%)') and text:match('Вы купили .+ %((%d+) шт%.%) у игрока .+ за.+$.+') or 1)
		for k, v in ipairs(json_cfg[last_profile]) do
			if v.item == item then
				if v.number >= count then
					json_cfg[last_profile][k].number = json_cfg[last_profile][k].number - count
					save_json()
					break
				end
			end
		end
	end
	--[[local hookMarket = {
		{text = '^%s*(.+) купил у вас (.+), вы получили(.+)$(.+) от продажи %(комиссия %d+ процент%(а%)%)$', color = -1347440641, key = 2},
		{text = '^%s*Вы успешно продали (.+) торговцу (.+), с продажи получили(.+)$(.+) %(комиссия %d+ процент%(а%)%)$', color = -65281, key = 2},
		{text = '^%s*Вы купили (.+) у игрока (.+) за(.+)$(.+)', color = -1347440641, key = 3},
		{text = '^%s*Вы успешно купили (.+) у (.+) за(.+)$(.+)', color = -65281, key = 3}
	}

	local hookActionsShop = {
		'^%s*%[Информация%] {FFFFFF}Вы отказались от аренды лавки!',
		'^%s*%[Информация%] {FFFFFF}Вы сняли лавку!',
		'^%s*%[Информация%] {FFFFFF}Ваша лавка была закрыта, из%-за того что вы её покинули!'
	}

	for k, v in ipairs(hookMarket) do
		if string.find(text, v['text']) and v['color'] == color then
			local args = splitArguments({text:match(v['text'])}, text:find('купил у вас'))
			local textLog = getTypeMessageMarket(text, args)
			
			if jsonLog[os.date('%d.%m.%Y')] == nil then jsonLog[os.date('%d.%m.%Y')] = {{}, 0, 0, 0, 0} end

			table.insert(jsonLog[os.date('%d.%m.%Y')][1], textLog)
			jsonLog[os.date('%d.%m.%Y')][(#args['ViceCity'] == 3 and v.key + 2 or v.key)] = jsonLog[os.date('%d.%m.%Y')][(#args['ViceCity'] == 3 and v.key + 2 or v.key)] + args['money']
			json('Log.json'):save(jsonLog)

			if #marketShop >= 10 then marketShop = {} end
			table.insert(marketShop, textLog)

			textLog = textLog .. '\n\n' .. 'Продали за день: $' .. money_separator(jsonLog[os.date('%d.%m.%Y')][2]) .. '\n' .. 'Скупили за день: $' .. money_separator(jsonLog[os.date('%d.%m.%Y')][3]) .. '\n\n' .. 'Продали за день: VC$' .. money_separator(jsonLog[os.date('%d.%m.%Y')][4]) .. '\n' .. 'Скупили за день: VC$' .. money_separator(jsonLog[os.date('%d.%m.%Y')][5])
			textLog = textLog .. '\n\n' .. 'Наличные: $' .. money_separator(getPlayerMoney(PLAYER_HANDLE))
			sendTelegram(textLog)
		end
	end ]]--

	if text:find('^%s*%(%( Через 30 секунд вы сможете сразу отправиться в больницу или подождать врачей %)%)%s*$') then
		sendTelegram('[Уведомление] Ваш персонаж умер!')
	end

	--[[for k, v in ipairs(hookActionsShop) do
		if text:find(v) then
			if notifications[2][3][0] then
				sendTelegram(text)
			end
		end
	end ]]--
	
	if text:find('^%s*%[Подсказка%] {FFFFFF}Вы успешно арендовали лавку для продажи/покупки товара!%s*$') then
		sendTelegram('[Уведомление] Вы успешно арендовали лавку!')
	end
end

---->> кастомный стринг нловер
function string.nlower(s)
	local line_lower = string.lower(s)
	for line in s:gmatch('.') do
		if (string.byte(line) >= 192 and string.byte(line) <= 223) or string.byte(line) == 168 then
			line_lower = string.gsub(line_lower, line, string.char(string.byte(line) == 168 and string.byte(line) + 16 or string.byte(line) + 32), 1)
		end
	end
	return line_lower
end

---->> центер текст
function imgui.CenterText(text, color)
	color = color or imgui.GetStyle().Colors[imgui.Col.Text]
	local width = imgui.GetWindowWidth()
	for line in text:gmatch('[^\n]+') do
		local lenght = imgui.CalcTextSize(line).x
		imgui.SetCursorPosX((width - lenght) / 2)
		imgui.TextColored(color, line)
	end
end

---->> Сохраняем INI CFG
function save()
	inicfg.save(cfg, 'cmarket.ini')
end

---->> Сохраняем JSON CFG
function save_json()
	local status, code = json('cmarket.json'):Save(json_cfg)
	if not status then sms('Ошибка: {mc}' .. code) end
end

---->> крутой вывод сообщений скрипта
function sms(arg)
	local arg = tostring(arg):gsub('{mc}', '{42b8a2}')
	sampAddChatMessage('[ cmarket.lua ] {FFFFFF}' .. tostring(arg), 0x42b8a2)
end

---->> Очень крутой инпут для имгуи (юзайте мимгуи, чуваки)
function imgui.InputTextWithHint(label, hint, buf, flags, callback, user_data)
    local l_pos = {imgui.GetCursorPos(), 0}
    local handle = imgui.InputText(label, buf, flags, callback, user_data)
    l_pos[2] = imgui.GetCursorPos()
    local t = (type(hint) == 'string' and buf.v:len() < 1) and hint or '\0'
    local t_size, l_size = imgui.CalcTextSize(t).x, imgui.CalcTextSize('A').x
    imgui.SetCursorPos(imgui.ImVec2(l_pos[1].x + 8, l_pos[1].y + 2))
    imgui.TextDisabled((imgui.CalcItemWidth() and t_size > imgui.CalcItemWidth()) and t:sub(1, math.floor(imgui.CalcItemWidth() / l_size)) or t)
    imgui.SetCursorPos(l_pos[2])
    return handle
end

---->> Получаем текст строчки в диалоге
function getLineOnTextDialog(text, line_find, mode)
	local mode = mode or false
	local count_dialog, text = 0, text
	for line in text:gmatch('[^\n]+') do
		count_dialog = count_dialog + 1
		if (mode and string.find(line, line_find, 0, true) or line:find(line_find)) then
			return count_dialog - 1
		end
	end
	return 0
end

---->> Скрипт крашнулся
function onScriptTerminate(script, quit)
	if script == thisScript() then
		imgui.Process = false
		imgui.ShowCursor = false
		showCursor(false, false)
	end
end

-----> РПК
function emul_rpc(hook, parameters)
    local bs_io = require 'samp.events.bitstream_io'
    local handler = require 'samp.events.handlers'
    local extra_types = require 'samp.events.extra_types'
    local hooks = {

        --[[ Outgoing rpcs
        ['onSendEnterVehicle'] = { 'int16', 'bool8', 26 },
        ['onSendClickPlayer'] = { 'int16', 'int8', 23 },
        ['onSendClientJoin'] = { 'int32', 'int8', 'string8', 'int32', 'string8', 'string8', 'int32', 25 },
        ['onSendEnterEditObject'] = { 'int32', 'int16', 'int32', 'vector3d', 27 },
        ['onSendCommand'] = { 'string32', 50 },
        ['onSendSpawn'] = { 52 },
        ['onSendDeathNotification'] = { 'int8', 'int16', 53 },
        ['onSendDialogResponse'] = { 'int16', 'int8', 'int16', 'string8', 62 },
        ['onSendClickTextDraw'] = { 'int16', 83 },
        ['onSendVehicleTuningNotification'] = { 'int32', 'int32', 'int32', 'int32', 96 },
        ['onSendChat'] = { 'string8', 101 },
        ['onSendClientCheckResponse'] = { 'int8', 'int32', 'int8', 103 },
        ['onSendVehicleDamaged'] = { 'int16', 'int32', 'int32', 'int8', 'int8', 106 },
        ['onSendEditAttachedObject'] = { 'int32', 'int32', 'int32', 'int32', 'vector3d', 'vector3d', 'vector3d', 'int32', 'int32', 116 },
        ['onSendEditObject'] = { 'bool', 'int16', 'int32', 'vector3d', 'vector3d', 117 },
        ['onSendInteriorChangeNotification'] = { 'int8', 118 },
        ['onSendMapMarker'] = { 'vector3d', 119 },
        ['onSendRequestClass'] = { 'int32', 128 },
        ['onSendRequestSpawn'] = { 129 },
        ['onSendPickedUpPickup'] = { 'int32', 131 },
        ['onSendMenuSelect'] = { 'int8', 132 },
        ['onSendVehicleDestroyed'] = { 'int16', 136 },
        ['onSendQuitMenu'] = { 140 },
        ['onSendExitVehicle'] = { 'int16', 154 },
        ['onSendUpdateScoresAndPings'] = { 155 },
        ['onSendGiveDamage'] = { 'int16', 'float', 'int32', 'int32', 115 },
        ['onSendTakeDamage'] = { 'int16', 'float', 'int32', 'int32', 115 },]]

        -- Incoming rpcs
        ['onInitGame'] = { 139 },
        ['onPlayerJoin'] = { 'int16', 'int32', 'bool8', 'string8', 137 },
        ['onPlayerQuit'] = { 'int16', 'int8', 138 },
        ['onRequestClassResponse'] = { 'bool8', 'int8', 'int32', 'int8', 'vector3d', 'float', 'Int32Array3', 'Int32Array3', 128 },
        ['onRequestSpawnResponse'] = { 'bool8', 129 },
        ['onSetPlayerName'] = { 'int16', 'string8', 'bool8', 11 },
        ['onSetPlayerPos'] = { 'vector3d', 12 },
        ['onSetPlayerPosFindZ'] = { 'vector3d', 13 },
        ['onSetPlayerHealth'] = { 'float', 14 },
        ['onTogglePlayerControllable'] = { 'bool8', 15 },
        ['onPlaySound'] = { 'int32', 'vector3d', 16 },
        ['onSetWorldBounds'] = { 'float', 'float', 'float', 'float', 17 },
        ['onGivePlayerMoney'] = { 'int32', 18 },
        ['onSetPlayerFacingAngle'] = { 'float', 19 },
        --['onResetPlayerMoney'] = { 20 },
        --['onResetPlayerWeapons'] = { 21 },
        ['onGivePlayerWeapon'] = { 'int32', 'int32', 22 },
        --['onCancelEdit'] = { 28 },
        ['onSetPlayerTime'] = { 'int8', 'int8', 29 },
        ['onSetToggleClock'] = { 'bool8', 30 },
        ['onPlayerStreamIn'] = { 'int16', 'int8', 'int32', 'vector3d', 'float', 'int32', 'int8', 32 },
        ['onSetShopName'] = { 'string256', 33 },
        ['onSetPlayerSkillLevel'] = { 'int16', 'int32', 'int16', 34 },
        ['onSetPlayerDrunk'] = { 'int32', 35 },
        ['onCreate3DText'] = { 'int16', 'int32', 'vector3d', 'float', 'bool8', 'int16', 'int16', 'encodedString4096', 36 },
        --['onDisableCheckpoint'] = { 37 },
        ['onSetRaceCheckpoint'] = { 'int8', 'vector3d', 'vector3d', 'float', 38 },
        --['onDisableRaceCheckpoint'] = { 39 },
        --['onGamemodeRestart'] = { 40 },
        ['onPlayAudioStream'] = { 'string8', 'vector3d', 'float', 'bool8', 41 },
        --['onStopAudioStream'] = { 42 },
        ['onRemoveBuilding'] = { 'int32', 'vector3d', 'float', 43 },
        ['onCreateObject'] = { 44 },
        ['onSetObjectPosition'] = { 'int16', 'vector3d', 45 },
        ['onSetObjectRotation'] = { 'int16', 'vector3d', 46 },
        ['onDestroyObject'] = { 'int16', 47 },
        ['onPlayerDeathNotification'] = { 'int16', 'int16', 'int8', 55 },
        ['onSetMapIcon'] = { 'int8', 'vector3d', 'int8', 'int32', 'int8', 56 },
        ['onRemoveVehicleComponent'] = { 'int16', 'int16', 57 },
        ['onRemove3DTextLabel'] = { 'int16', 58 },
        ['onPlayerChatBubble'] = { 'int16', 'int32', 'float', 'int32', 'string8', 59 },
        ['onUpdateGlobalTimer'] = { 'int32', 60 },
        ['onShowDialog'] = { 'int16', 'int8', 'string8', 'string8', 'string8', 'encodedString4096', 61 },
        ['onDestroyPickup'] = { 'int32', 63 },
        ['onLinkVehicleToInterior'] = { 'int16', 'int8', 65 },
        ['onSetPlayerArmour'] = { 'float', 66 },
        ['onSetPlayerArmedWeapon'] = { 'int32', 67 },
        ['onSetSpawnInfo'] = { 'int8', 'int32', 'int8', 'vector3d', 'float', 'Int32Array3', 'Int32Array3', 68 },
        ['onSetPlayerTeam'] = { 'int16', 'int8', 69 },
        ['onPutPlayerInVehicle'] = { 'int16', 'int8', 70 },
        --['onRemovePlayerFromVehicle'] = { 71 },
        ['onSetPlayerColor'] = { 'int16', 'int32', 72 },
        ['onDisplayGameText'] = { 'int32', 'int32', 'string32', 73 },
        --['onForceClassSelection'] = { 74 },
        ['onAttachObjectToPlayer'] = { 'int16', 'int16', 'vector3d', 'vector3d', 75 },
        ['onInitMenu'] = { 76 },
        ['onShowMenu'] = { 'int8', 77 },
        ['onHideMenu'] = { 'int8', 78 },
        ['onCreateExplosion'] = { 'vector3d', 'int32', 'float', 79 },
        ['onShowPlayerNameTag'] = { 'int16', 'bool8', 80 },
        ['onAttachCameraToObject'] = { 'int16', 81 },
        ['onInterpolateCamera'] = { 'bool', 'vector3d', 'vector3d', 'int32', 'int8', 82 },
        ['onGangZoneStopFlash'] = { 'int16', 85 },
        ['onApplyPlayerAnimation'] = { 'int16', 'string8', 'string8', 'bool', 'bool', 'bool', 'bool', 'int32', 86 },
        ['onClearPlayerAnimation'] = { 'int16', 87 },
        ['onSetPlayerSpecialAction'] = { 'int8', 88 },
        ['onSetPlayerFightingStyle'] = { 'int16', 'int8', 89 },
        ['onSetPlayerVelocity'] = { 'vector3d', 90 },
        ['onSetVehicleVelocity'] = { 'bool8', 'vector3d', 91 },
        ['onServerMessage'] = { 'int32', 'string32', 93 },
        ['onSetWorldTime'] = { 'int8', 94 },
        ['onCreatePickup'] = { 'int32', 'int32', 'int32', 'vector3d', 95 },
        ['onMoveObject'] = { 'int16', 'vector3d', 'vector3d', 'float', 'vector3d', 99 },
        ['onEnableStuntBonus'] = { 'bool', 104 },
        ['onTextDrawSetString'] = { 'int16', 'string16', 105 },
        ['onSetCheckpoint'] = { 'vector3d', 'float', 107 },
        ['onCreateGangZone'] = { 'int16', 'vector2d', 'vector2d', 'int32', 108 },
        ['onPlayCrimeReport'] = { 'int16', 'int32', 'int32', 'int32', 'int32', 'vector3d', 112 },
        ['onGangZoneDestroy'] = { 'int16', 120 },
        ['onGangZoneFlash'] = { 'int16', 'int32', 121 },
        ['onStopObject'] = { 'int16', 122 },
        ['onSetVehicleNumberPlate'] = { 'int16', 'string8', 123 },
        ['onTogglePlayerSpectating'] = { 'bool32', 124 },
        ['onSpectatePlayer'] = { 'int16', 'int8', 126 },
        ['onSpectateVehicle'] = { 'int16', 'int8', 127 },
        ['onShowTextDraw'] = { 134 },
        ['onSetPlayerWantedLevel'] = { 'int8', 133 },
        ['onTextDrawHide'] = { 'int16', 135 },
        ['onRemoveMapIcon'] = { 'int8', 144 },
        ['onSetWeaponAmmo'] = { 'int8', 'int16', 145 },
        ['onSetGravity'] = { 'float', 146 },
        ['onSetVehicleHealth'] = { 'int16', 'float', 147 },
        ['onAttachTrailerToVehicle'] = { 'int16', 'int16', 148 },
        ['onDetachTrailerFromVehicle'] = { 'int16', 149 },
        ['onSetWeather'] = { 'int8', 152 },
        ['onSetPlayerSkin'] = { 'int32', 'int32', 153 },
        ['onSetInterior'] = { 'int8', 156 },
        ['onSetCameraPosition'] = { 'vector3d', 157 },
        ['onSetCameraLookAt'] = { 'vector3d', 'int8', 158 },
        ['onSetVehiclePosition'] = { 'int16', 'vector3d', 159 },
        ['onSetVehicleAngle'] = { 'int16', 'float', 160 },
        ['onSetVehicleParams'] = { 'int16', 'int16', 'bool8', 161 },
        --['onSetCameraBehind'] = { 162 },
        ['onChatMessage'] = { 'int16', 'string8', 101 },
        ['onConnectionRejected'] = { 'int8', 130 },
        ['onPlayerStreamOut'] = { 'int16', 163 },
        ['onVehicleStreamIn'] = { 164 },
        ['onVehicleStreamOut'] = { 'int16', 165 },
        ['onPlayerDeath'] = { 'int16', 166 },
        ['onPlayerEnterVehicle'] = { 'int16', 'int16', 'bool8', 26 },
        ['onUpdateScoresAndPings'] = { 'PlayerScorePingMap', 155 },
        ['onSetObjectMaterial'] = { 84 },
        ['onSetObjectMaterialText'] = { 84 },
        ['onSetVehicleParamsEx'] = { 'int16', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 'int8', 24 },
        ['onSetPlayerAttachedObject'] = { 'int16', 'int32', 'bool', 'int32', 'int32', 'vector3d', 'vector3d', 'vector3d', 'int32', 'int32', 113 }

    }
    local handler_hook = {
        ['onInitGame'] = true,
        ['onCreateObject'] = true,
        ['onInitMenu'] = true,
        ['onShowTextDraw'] = true,
        ['onVehicleStreamIn'] = true,
        ['onSetObjectMaterial'] = true,
        ['onSetObjectMaterialText'] = true
    }
    local extra = {
        ['PlayerScorePingMap'] = true,
        ['Int32Array3'] = true
    }
    local hook_table = hooks[hook]
    if hook_table then
        local bs = raknetNewBitStream()
        if not handler_hook[hook] then
            local max = #hook_table-1
            if max > 0 then
                for i = 1, max do
                    local p = hook_table[i]
                    if extra[p] then extra_types[p]['write'](bs, parameters[i])
                    else bs_io[p]['write'](bs, parameters[i]) end
                end
            end
        else
            if hook == 'onInitGame' then handler.on_init_game_writer(bs, parameters)
            elseif hook == 'onCreateObject' then handler.on_create_object_writer(bs, parameters)
            elseif hook == 'onInitMenu' then handler.on_init_menu_writer(bs, parameters)
            elseif hook == 'onShowTextDraw' then handler.on_show_textdraw_writer(bs, parameters)
            elseif hook == 'onVehicleStreamIn' then handler.on_vehicle_stream_in_writer(bs, parameters)
            elseif hook == 'onSetObjectMaterial' then handler.on_set_object_material_writer(bs, parameters, 1)
            elseif hook == 'onSetObjectMaterialText' then handler.on_set_object_material_writer(bs, parameters, 2) end
        end
        raknetEmulRpcReceiveBitStream(hook_table[#hook_table], bs)
        raknetDeleteBitStream(bs)
    end
end

---->> Style
function apply_custom_style()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4

	style.WindowPadding = imgui.ImVec2(8, 8)
	style.WindowRounding = 4
	style.ChildWindowRounding = 5
	style.FramePadding = imgui.ImVec2(5, 3)
	style.FrameRounding = 3.0
	style.ItemSpacing = imgui.ImVec2(5, 4)
	style.ItemInnerSpacing = imgui.ImVec2(4, 4)
	style.IndentSpacing = 21
	style.ScrollbarSize = 10.0
	style.ScrollbarRounding = 13
	style.GrabMinSize = 8
	style.GrabRounding = 1
	style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
	style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

	colors[clr.Text]   = ImVec4(0.00, 0.00, 0.00, 0.51)
	colors[clr.TextDisabled]   = ImVec4(0.24, 0.24, 0.24, 1.00)
	colors[clr.WindowBg]              = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[clr.ChildWindowBg]         = ImVec4(0.96, 0.96, 0.96, 1.00)
	colors[clr.PopupBg]               = ImVec4(0.92, 0.92, 0.92, 1.00)
	colors[clr.Border]                = ImVec4(0.86, 0.86, 0.86, 1.00)
	colors[clr.BorderShadow]          = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.FrameBg]               = ImVec4(0.88, 0.88, 0.88, 1.00)
	colors[clr.FrameBgHovered]        = ImVec4(0.82, 0.82, 0.82, 1.00)
	colors[clr.FrameBgActive]         = ImVec4(0.76, 0.76, 0.76, 1.00)
	colors[clr.TitleBg]               = ImVec4(0.00, 0.45, 1.00, 0.82)
	colors[clr.TitleBgCollapsed]      = ImVec4(0.00, 0.45, 1.00, 0.82)
	colors[clr.TitleBgActive]         = ImVec4(0.00, 0.45, 1.00, 0.82)
	colors[clr.MenuBarBg]             = ImVec4(0.00, 0.37, 0.78, 1.00)
	colors[clr.ScrollbarBg]           = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.ScrollbarGrab]         = ImVec4(0.00, 0.35, 1.00, 0.78)
	colors[clr.ScrollbarGrabHovered]  = ImVec4(0.00, 0.33, 1.00, 0.84)
	colors[clr.ScrollbarGrabActive]   = ImVec4(0.00, 0.31, 1.00, 0.88)
	colors[clr.ComboBg]               = ImVec4(0.92, 0.92, 0.92, 1.00)
	colors[clr.CheckMark]             = ImVec4(0.00, 0.49, 1.00, 0.59)
	colors[clr.SliderGrab]            = ImVec4(0.00, 0.49, 1.00, 0.59)
	colors[clr.SliderGrabActive]      = ImVec4(0.00, 0.39, 1.00, 0.71)
	colors[clr.Button]                = ImVec4(0.00, 0.49, 1.00, 0.59)
	colors[clr.ButtonHovered]         = ImVec4(0.00, 0.49, 1.00, 0.71)
	colors[clr.ButtonActive]          = ImVec4(0.00, 0.49, 1.00, 0.78)
	colors[clr.Header]                = ImVec4(0.00, 0.49, 1.00, 0.78)
	colors[clr.HeaderHovered]         = ImVec4(0.00, 0.49, 1.00, 0.71)
	colors[clr.HeaderActive]          = ImVec4(0.00, 0.49, 1.00, 0.78)
	colors[clr.ResizeGrip]            = ImVec4(0.00, 0.39, 1.00, 0.59)
	colors[clr.ResizeGripHovered]     = ImVec4(0.00, 0.27, 1.00, 0.59)
	colors[clr.ResizeGripActive]      = ImVec4(0.00, 0.25, 1.00, 0.63)
	colors[clr.CloseButton]           = ImVec4(0.00, 0.35, 0.96, 0.71)
	colors[clr.CloseButtonHovered]    = ImVec4(0.00, 0.31, 0.88, 0.69)
	colors[clr.CloseButtonActive]     = ImVec4(0.00, 0.25, 0.88, 0.67)
	colors[clr.PlotLines]             = ImVec4(0.00, 0.39, 1.00, 0.75)
	colors[clr.PlotLinesHovered]      = ImVec4(0.00, 0.39, 1.00, 0.75)
	colors[clr.PlotHistogram]         = ImVec4(0.00, 0.39, 1.00, 0.75)
	colors[clr.PlotHistogramHovered]  = ImVec4(0.00, 0.35, 0.92, 0.78)
	colors[clr.TextSelectedBg]        = ImVec4(0.00, 0.47, 1.00, 0.59)
	colors[clr.ModalWindowDarkening]  = ImVec4(0.20, 0.20, 0.20, 0.35)

end
apply_custom_style()