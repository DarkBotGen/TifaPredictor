-- Read-only Beequip simulation core. No remotes, inventory writes, or wax use.
-- Replays recovered client-side rules on detached data.
local RS = game:GetService("ReplicatedStorage")
local BeequipTypes = require(RS.Beequips.BeequipTypes)
local WaxTypes = require(RS.WaxTypes)
local RQValue = require(RS.RQValue)
local RandomPools = require(RS.RandomPools)
local BeeStatMods = require(RS.BeeStats.BeeStatMods)
local Engine = {}

local function clone(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[clone(key, seen)] = clone(item, seen) end
    return result
end

local function detached(data, options)
    assert(type(data) == "table", "Expected Beequip file data")
    assert(type(data.T) == "string" and BeequipTypes.Get(data.T), "Unknown Beequip T")
    assert(type(data.S) == "number" and data.S == data.S and data.S > 0
        and data.S < math.huge and data.S % 1 == 0, "Expected a positive integer seed S")
    assert(type(data.Q) == "number" and data.Q == data.Q and data.Q >= 0 and data.Q <= 1,
        "Quality Q must be in [0,1]")
    local file = clone(data)
    options = options or {}
    if options.UseOriginalSeed then file.S = file.OS or file.S end
    if options.ShowBase then file.W = nil; file.RC = 0 end
    if options.ResetWaxes then file.W=nil;file.RC=file.UC or file.RC or 0 end
    if options.BaseOffset~=nil then file.PredictorBaseOffset=options.BaseOffset end
    local baseOffset=file.PredictorBaseOffset or 0
    assert(type(baseOffset)=="number" and baseOffset%1==0 and baseOffset>=0 and baseOffset<=100000,
        "Base offset must be an integer from 0 to 100000")
    if options.Offset ~= nil then
        assert(type(options.Offset) == "number" and options.Offset % 1 == 0
            and options.Offset >= 0 and options.Offset <= 100000,
            "Offset must be an integer from 0 to 100000")
        file.RC = options.Offset
    end
    assert(type(file.RC or 0) == "number" and (file.RC or 0) % 1 == 0
        and (file.RC or 0) >= 0 and (file.RC or 0) <= 100000, "Invalid RC")
    assert(file.W == nil or (type(file.W) == "table" and #file.W <= 5), "Invalid W history")
    for _, wax in ipairs(file.W or {}) do
        assert(type(wax) == "table" and WaxTypes.TypeByID[wax[1]], "Unknown wax history ID")
        assert(type(wax[2]) == "boolean", "Wax history success flag must be boolean")
        assert(wax[3] == nil or (type(wax[3]) == "number" and wax[3] % 1 == 0
            and wax[3] >= 0 and wax[3] <= 32), "Invalid wax history RNG skip")
    end
    return file
end

local function tag(def)
    local key
    if def.BeeStat then key = "B:" .. def.BeeStat
    elseif def.HiveBonusStat then key = "H:" .. def.HiveBonusStat .. "|O:" .. (def.Op or "Add")
    elseif def.BeeAbility then key = "A:" .. def.BeeAbility
    elseif def.BeeAbilityPool then
        key = "AP:"
        for _, item in ipairs(def.BeeAbilityPool) do key ..= item[1] .. "/" end
    end
    assert(key, "Unknown upgrade definition")
    if def.Params then
        key ..= "|P:"
        for k, v in pairs(def.Params) do key ..= k .. ":" .. tostring(v) .. "|" end
    end
    return key
end

local function generate(file)
    local rng = Random.new(file.S)
    local draws = 0
    local function nextNumber() draws += 1; return rng:NextNumber() end
    local baseOffset=file.PredictorBaseOffset or 0
    for _=1,baseOffset do nextNumber() end
    local def, quality = BeequipTypes.Get(file.T), file.Q
    local function resolve(value) return RQValue.Resolve(value, quality, nextNumber, def.OldRNG) end
    local bee, hive, abilities, added = {}, {}, {}, {}
    for _, item in ipairs(def.Modifiers or {}) do
        local value = resolve(item)
        if value then bee[#bee + 1] = {Stat = item.Stat, Value = value} end
    end
    for _, item in ipairs(def.HiveBonuses or {}) do
        local value = resolve(item)
        if value then hive[#hive + 1] = {Type = item.Type, Op = item.Op,
            Params = item.Params, Value = value} end
    end
    for _ = 1, file.RC or 0 do nextNumber() end
    local afterTurp=draws
    local function addAbility(name, upgraded)
        if name and not added[name] then
            added[name] = true; abilities[#abilities + 1] = {name, upgraded}
        end
    end
    for _, item in ipairs(def.Abilities or {}) do
        local name = item.Name
        if item.NamePool then name = RandomPools.SelectFromOrderedList(item.NamePool, nextNumber) end
        addAbility(name, false)
    end
    local upgradeCount = 0
    for _, wax in ipairs(file.W or {}) do
        if wax[2] then upgradeCount += WaxTypes.TypeByID[wax[1]].Upgrades or 0 end
    end
    if def.Upgrades and upgradeCount > 0 then
        local definitions, counts, values, order, normal, caustic = {}, {}, {}, {}, {}, {}
        for _, item in ipairs(def.Upgrades) do
            local key = tag(item)
            definitions[key], counts[key], values[key] = item, 0, 0
            order[#order + 1] = key
            local chance = resolve(item.Chance) or 0
            if not item.CausticOnly then normal[#normal + 1] = {key, chance} end
            caustic[#caustic + 1] = {key, chance}
        end
        local function remove(pool, key)
            for i, item in ipairs(pool) do
                if item[1] == key then table.remove(pool, i); return end
            end
        end
        for _, wax in ipairs(file.W or {}) do
            if wax[2] then
                for _ = 1, wax[3] or 0 do nextNumber() end
                local waxDef = WaxTypes.TypeByID[wax[1]]
                for _ = 1, waxDef.Upgrades or 0 do
                    local pool = (waxDef.Name == "Caustic" or waxDef.Name == "Debug") and caustic or normal
                    assert(#pool > 0, "Upgrade pool exhausted")
                    local key = RandomPools.SelectFromOrderedList(pool, nextNumber)
                    if key then
                        local item = definitions[key]
                        values[key] += resolve(item.Value)
                        counts[key] += 1
                        if counts[key] >= item.Max then remove(normal, key); remove(caustic, key) end
                    end
                end
            end
        end
        local existing = {}
        for _, item in ipairs(bee) do existing[tag({BeeStat = item.Stat, Params = item.Params})] = item end
        for _, item in ipairs(hive) do existing[tag({HiveBonusStat = item.Type,
            Op = item.Op, Params = item.Params})] = item end
        for _, key in ipairs(order) do
            local value, item = values[key], definitions[key]
            if value > 0 then
                local current = existing[key]
                if current then
                    current.UpgradeValue, current.FromUpgrade = value, value
                    current.Value += value
                elseif item.BeeStat then
                    local total = value
                    if BeeStatMods.GetType(item.BeeStat).Op == "Mul" then total += 1 end
                    bee[#bee + 1] = {Stat = item.BeeStat, Value = total, FromUpgrade = value}
                elseif item.HiveBonusStat then
                    hive[#hive + 1] = {Type = item.HiveBonusStat, Op = item.Op,
                        Params = item.Params, Value = value, FromUpgrade = value}
                elseif item.BeeAbility then addAbility(item.BeeAbility, true)
                elseif item.BeeAbilityPool then
                    addAbility(RandomPools.SelectFromOrderedList(item.BeeAbilityPool, nextNumber), true)
                end
            end
        end
    end
    return bee, hive, abilities, draws, afterTurp
end

local function snapshot(file)
    local bee, hive, abilities, draws, afterTurp = generate(file)
    return {Bee = bee or {}, Hive = hive or {}, Abilities = abilities or {},
        Seed = file.S, OriginalSeed = file.OS or file.S, Quality = file.Q,
        TurpentineOffset = file.RC or 0, WaxHistory = clone(file.W or {}), RNGDraws = draws,
        BaseOffset=file.PredictorBaseOffset or 0,OffsetAfterTurp=afterTurp,CurrentOffset=draws}
end

local function waxDefinition(name)
    assert(type(name) == "string", "Wax name must be a string")
    name = name:gsub("Wax$", "")
    local wax = WaxTypes.Get(name)
    assert(wax and (wax.Upgrades or 0) > 0, "Only upgrade waxes are supported")
    return wax
end

function Engine.Evaluate(data, options)
    return snapshot(detached(data, options))
end

-- One possible successful application, not a guarantee of wax success.
function Engine.Single(data, waxName, skip, options)
    assert(type(skip) == "number" and skip % 1 == 0 and skip >= 1 and skip <= 32,
        "Successful wax skip must be 1..32")
    local file = detached(data, options)
    assert(#(file.W or {}) < 5, "No wax slots remaining")
    local wax = waxDefinition(waxName)
    file.W = file.W or {}
    table.insert(file.W, {wax.ID, true, skip})
    local result = snapshot(file)
    result.WaxSuccessRate = wax.SuccessRate
    result.DestroyOnFailure = wax.DestroyOnFail == true
    return result
end

-- Exact batch search. Equivalent RNG/count/value states are merged with integer
-- multiplicities; no samples or guessed probabilities are used.
function Engine.Batch(data, chain, predicate, groupBy, options)
    options=options or {}
    assert(type(chain)=="table" and #chain>=1 and #chain<=5,"Choose one to five future waxes")
    local file=detached(data,options)
    file.W=file.W or {}
    assert(#file.W+#chain<=5,"Not enough wax slots. Enable RESET FIRST for a simulated reset.")
    local total=32^#chain
    assert(total<=(options.MaxPredictions or 33554432),"Batch exceeds MaxPredictions")
    local allSuccess,waxes=1,{}
    for i,name in ipairs(chain) do waxes[i]=waxDefinition(name);allSuccess*=waxes[i].SuccessRate or 1 end
    local def=BeequipTypes.Get(file.T)
    local rng=Random.new(file.S)
    local draws=0
    local function nextNumber() draws+=1;return rng:NextNumber() end
    for _=1,file.PredictorBaseOffset or 0 do nextNumber() end
    local function resolve(value) return RQValue.Resolve(value,file.Q,nextNumber,def.OldRNG) end
    local baseBee,baseHive,baseAbilities,baseAdded={},{},{},{}
    for _,v in ipairs(def.Modifiers or {}) do local value=resolve(v);if value then baseBee[#baseBee+1]={Stat=v.Stat,Value=value} end end
    for _,v in ipairs(def.HiveBonuses or {}) do local value=resolve(v);if value then baseHive[#baseHive+1]={Type=v.Type,Op=v.Op,Params=v.Params,Value=value} end end
    for _=1,file.RC or 0 do nextNumber() end
    local afterTurp=draws
    for _,v in ipairs(def.Abilities or {}) do
        local name=v.Name
        if v.NamePool then name=RandomPools.SelectFromOrderedList(v.NamePool,nextNumber) end
        if name and not baseAdded[name] then baseAdded[name]=true;baseAbilities[#baseAbilities+1]={name,false} end
    end
    local upgrades,weights,keys={},{},{}
    for i,v in ipairs(def.Upgrades or {}) do upgrades[i]=v;weights[i]=resolve(v.Chance) or 0;keys[i]=tag(v) end
    local initial={Rng=rng,Draws=draws,Counts={},Values={},Weight=1,Path={}}
    for i=1,#upgrades do initial.Counts[i]=0;initial.Values[i]=0 end
    local started,lastYield=os.clock(),os.clock()
    local function checkpoint()
        if options.Cancelled and options.Cancelled() then error("Prediction cancelled",0) end
        if os.clock()-started>(options.MaxSeconds or 120) then error("Search time limit reached; shorten the chain or increase MaxSeconds",0) end
        if os.clock()-lastYield>=0.012 then task.wait();lastYield=os.clock() end
    end
    local function applyWax(state,wax,skip,appendPath)
        local child={Rng=state.Rng:Clone(),Draws=state.Draws,Counts=table.clone(state.Counts),
            Values=table.clone(state.Values),Weight=state.Weight,Path=table.clone(state.Path)}
        if appendPath then child.Path[#child.Path+1]=skip end
        if #upgrades==0 then return child end
        local function draw() child.Draws+=1;return child.Rng:NextNumber() end
        for _=1,skip or 0 do draw() end
        for _=1,wax.Upgrades or 0 do
            local pool={}
            local special=wax.Name=="Caustic" or wax.Name=="Debug"
            for i,u in ipairs(upgrades) do
                if child.Counts[i]<u.Max and (special or not u.CausticOnly) then pool[#pool+1]={i,weights[i]} end
            end
            assert(#pool>0,"Upgrade pool exhausted")
            local i=RandomPools.SelectFromOrderedList(pool,draw)
            child.Values[i]+=RQValue.Resolve(upgrades[i].Value,file.Q,draw,def.OldRNG)
            child.Counts[i]+=1
        end
        return child
    end
    for _,w in ipairs(file.W) do if w[2] then initial=applyWax(initial,WaxTypes.TypeByID[w[1]],w[3] or 0,false) end end
    local function stateKey(state)
        local parts={tostring(state.Draws)}
        for i=1,#upgrades do parts[#parts+1]=tostring(state.Counts[i]);parts[#parts+1]=string.format("%.17g",state.Values[i]) end
        return table.concat(parts,",")
    end
    local states={initial}
    for depth,wax in ipairs(waxes) do
        local merged,nextStates={},{}
        for index,state in ipairs(states) do
            for skip=1,32 do
                local child=applyWax(state,wax,skip,true)
                local key=stateKey(child)
                local prior=merged[key]
                if prior then prior.Weight+=child.Weight
                else merged[key]=child;nextStates[#nextStates+1]=child end
                checkpoint()
            end
            if options.OnStage and index%64==0 then options.OnStage(string.format("Wax %d/%d: %d/%d states",depth,#chain,index,#states)) end
            assert(#nextStates<=(options.MaxStates or 200000),"Exact-state memory limit reached; shorten the chain")
        end
        states=nextStates
        if options.OnStage then options.OnStage(string.format("Wax %d/%d: %d distinct states",depth,#chain,#states)) end
    end
    local function finish(state)
        local bee,hive,abilities,added=clone(baseBee),clone(baseHive),clone(baseAbilities),table.clone(baseAdded)
        local resultRng=state.Rng:Clone();local finalDraws=state.Draws
        local function draw() finalDraws+=1;return resultRng:NextNumber() end
        local function addAbility(name) if name and not added[name] then added[name]=true;abilities[#abilities+1]={name,true} end end
        local existing={}
        for _,v in ipairs(bee) do existing[tag({BeeStat=v.Stat,Params=v.Params})]=v end
        for _,v in ipairs(hive) do existing[tag({HiveBonusStat=v.Type,Op=v.Op,Params=v.Params})]=v end
        for i,u in ipairs(upgrades) do
            local value=state.Values[i]
            if value>0 then
                local v=existing[keys[i]]
                if v then v.UpgradeValue=value;v.FromUpgrade=value;v.Value+=value
                elseif u.BeeStat then
                    local valueWithBase=value+(BeeStatMods.GetType(u.BeeStat).Op=="Mul" and 1 or 0)
                    bee[#bee+1]={Stat=u.BeeStat,Value=valueWithBase,FromUpgrade=value}
                elseif u.HiveBonusStat then hive[#hive+1]={Type=u.HiveBonusStat,Op=u.Op,Params=u.Params,Value=value,FromUpgrade=value}
                elseif u.BeeAbility then addAbility(u.BeeAbility)
                elseif u.BeeAbilityPool then addAbility(RandomPools.SelectFromOrderedList(u.BeeAbilityPool,draw)) end
            end
        end
        local history=clone(file.W)
        for i,skip in ipairs(state.Path) do history[#history+1]={waxes[i].ID,true,skip} end
        return {Bee=bee,Hive=hive,Abilities=abilities,Seed=file.S,OriginalSeed=file.OS or file.S,Quality=file.Q,
            WaxHistory=history,RNGDraws=finalDraws,BaseOffset=file.PredictorBaseOffset or 0,
            OffsetAfterTurp=afterTurp,CurrentOffset=finalDraws,TurpentineOffset=file.RC or 0,FutureSkips=state.Path}
    end
    local before=snapshot(file)
    local report={Total=total,Evaluated=0,Matched=0,Groups={},Examples={},AllWaxesSuccessRate=allSuccess,
        ConditionalOnAllSuccess=true,DistinctStates=#states,Before=before,ResetFirst=options.ResetWaxes==true}
    for _,state in ipairs(states) do
        local result=finish(state)
        report.Evaluated+=state.Weight
        if not predicate or predicate(result,before,state.Weight) then
            report.Matched+=state.Weight
            if groupBy then
                local key=tostring(groupBy(result,before))
                report.Groups[key]=(report.Groups[key] or 0)+state.Weight
                if not report.Examples[key] then report.Examples[key]={FutureSkips=clone(state.Path),CurrentOffset=result.CurrentOffset} end
            end
        end
        checkpoint()
    end
    assert(report.Evaluated==total,"Exact branch count mismatch")
    report.ConditionalMatchRate=report.Matched/total
    report.SuccessAndMatchRate=allSuccess*report.ConditionalMatchRate
    report.Seconds=os.clock()-started
    if options.OnProgress then options.OnProgress(total,total) end
    return report
end

-- Lists only the current player's locally replicated inventory, without IDs.
function Engine.Inventory()
    local stats = require(RS.ClientStatCache):Get()
    local result = {}
    local function add(location, index, file)
        if type(file) ~= "table" or not file.T then return end
        result[#result + 1] = {Location = location, Index = index, Data = {
            T = file.T, Q = file.Q, S = file.S, OS = file.OS,
            RC = file.RC, UC = file.UC, W = clone(file.W)}}
    end
    for _, location in ipairs({"Storage", "Inbox", "Permanents"}) do
        for index, file in ipairs(stats and stats.Beequips and stats.Beequips[location] or {}) do
            add(location, index, file)
        end
    end
    local equipped, visited = {}, {}
    local function idKey(ids)
        if type(ids) ~= "table" then return nil end
        local parts = {}
        for i, value in ipairs(ids) do parts[i] = tostring(value) end
        return table.concat(parts, ":")
    end
    local function scan(node, depth)
        if type(node) ~= "table" or visited[node] or depth > 8 then return end
        visited[node] = true
        for _, file in ipairs(node.Equips or {}) do
            local key = idKey(file.IDs)
            if key then equipped[key] = file end
        end
        for _, child in pairs(node) do if type(child) == "table" then scan(child, depth + 1) end end
    end
    scan(stats and stats.Honeycomb, 0)
    for index, entry in ipairs(stats and stats.Beequips and stats.Beequips.Case or {}) do
        local key = idKey(entry.IDs)
        add("Case", index, entry.File or (key and equipped[key]))
    end
    return result
end

-- Direct execution installs the core; this file contains no remote loadstring.
getgenv().TifaPredictorEngine = Engine
return Engine
