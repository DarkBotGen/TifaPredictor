-- Predictor — readable local simulation UI
local core = (function()
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
    if options.ResetWaxes then file.W=nil;file.RC=file.UC or file.RC or 0;file.S=file.OS or file.S end
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
    local trace={ArtificialBaseSkip=baseOffset,ResetSkip=file.RC or 0,Waxes={}}
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
    trace.AfterBaseStats=draws
    for _ = 1, file.RC or 0 do nextNumber() end
    local afterTurp=draws
    trace.AfterResetSkip=draws
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
    trace.AfterBaseAbilities=draws
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
        trace.AfterUpgradeWeights=draws
        for index, wax in ipairs(file.W or {}) do
            local entry={Index=index,Wax=WaxTypes.TypeByID[wax[1]].Name,Success=wax[2],Skip=wax[2] and (wax[3] or 0) or 0,Start=draws}
            trace.Waxes[#trace.Waxes+1]=entry
            if wax[2] then
                for _ = 1, wax[3] or 0 do nextNumber() end
                entry.AfterSkip=draws
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
            entry.AfterSkip=entry.AfterSkip or draws
            entry.Finish=draws
        end
        trace.AfterWaxRolls=draws
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
    trace.AfterUpgradeWeights=trace.AfterUpgradeWeights or trace.AfterBaseAbilities
    trace.AfterWaxRolls=trace.AfterWaxRolls or trace.AfterBaseAbilities
    trace.Final=draws
    return bee, hive, abilities, draws, afterTurp, trace
end

local function snapshot(file)
    local bee, hive, abilities, draws, afterTurp, trace = generate(file)
    return {Bee = bee or {}, Hive = hive or {}, Abilities = abilities or {},
        Seed = file.S, OriginalSeed = file.OS or file.S, Quality = file.Q,
        TurpentineOffset = file.RC or 0, WaxHistory = clone(file.W or {}), RNGDraws = draws,OffsetTrace=trace,
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

-- Full snapshots for every legal next-wax skip. Final draw count is not a state key:
-- distinct upgrade histories can finish at the same absolute RNG position.
function Engine.OffsetOutcomes(data,waxName,predicate,options)
    options=options or {}
    local before=Engine.Evaluate(data,options)
    local wax=waxDefinition(waxName)
    local rows,byFinal,matched={},{},0
    local lastYield=os.clock()
    for skip=1,32 do
        if options.Cancelled and options.Cancelled() then error("Prediction cancelled",0) end
        local result=Engine.Single(data,waxName,skip,options)
        local match=not predicate or predicate(result,before)
        if match then matched+=1 end
        local row={Skip=skip,FinalOffset=result.CurrentOffset,Result=result,Matched=match,
            ConditionalProbability=1/32,SuccessAndBranchProbability=(wax.SuccessRate or 1)/32}
        rows[#rows+1]=row
        local bucket=byFinal[row.FinalOffset] or {};byFinal[row.FinalOffset]=bucket
        bucket[#bucket+1]=row
        if os.clock()-lastYield>=0.008 then
            if options.OnProgress then options.OnProgress(skip,32) end
            task.wait();lastYield=os.clock()
        end
    end
    if options.OnProgress then options.OnProgress(32,32) end
    return {Before=before,Rows=rows,ByFinalOffset=byFinal,Matched=matched,Total=32,
        ConditionalMatchRate=matched/32,SuccessAndMatchRate=(wax.SuccessRate or 1)*matched/32,
        WaxSuccessRate=wax.SuccessRate or 1,DestroyOnFailure=wax.DestroyOnFail==true}
end

-- Compact hive-offset browser: the current item plus explicit post-reset RC scenarios.
function Engine.HiveOffsetOutcomes(data,waxName,firstOffset,count,options)
    assert(type(firstOffset)=="number" and firstOffset%1==0 and firstOffset>=0,"Invalid reset offset")
    assert(type(count)=="number" and count%1==0 and count>=1 and count<=64,"Choose 1..64 offsets")
    assert(firstOffset+count-1<=100000,"Offset range exceeds 100000")
    options=table.clone(options or {})
    options.ShowBase=false;options.ResetWaxes=false;options.UseOriginalSeed=false;options.BaseOffset=0
    local file=detached(data,options)
    local rows={}
    local lastYield=os.clock()
    if #(file.W or {})<5 then
        rows[#rows+1]={Kind="Current",Offset=file.RC or 0,Outcomes=Engine.OffsetOutcomes(file,waxName,nil,options)}
    end
    for rc=firstOffset,firstOffset+count-1 do
        if options.Cancelled and options.Cancelled() then error("Prediction cancelled",0) end
        local reset=clone(file)
        reset.W=nil;reset.S=reset.OS or reset.S;reset.RC=rc
        rows[#rows+1]={Kind="Reset scenario",Offset=rc,
            Outcomes=Engine.OffsetOutcomes(reset,waxName,nil,options)}
        if options.OnStage then options.OnStage("Hive offsets: "..(rc-firstOffset+1).."/"..count) end
        if os.clock()-lastYield>=0.008 then task.wait();lastYield=os.clock() end
    end
    return {Rows=rows,CurrentOffset=file.RC or 0,CumulativeAttempts=file.UC,FirstOffset=firstOffset,Count=count}
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
    -- Optional exact projection: callers promise predicates/groups inspect only Targets.
    -- All upgrade counts remain in the key because they alter future upgrade pools.
    -- Ability upgrade values remain too, preserving late pool-roll behavior.
    local retained
    if options.Targets and #options.Targets>0 then
        retained={}
        local wanted={}
        for _,f in ipairs(options.Targets) do
            if f.kind=="Bee" then wanted[tag({BeeStat=f.name})]=true
            elseif f.kind=="Hive" then wanted[tag({HiveBonusStat=f.name,Op=f.op or "Add",Params=f.params})]=true end
        end
        for i,u in ipairs(upgrades) do retained[i]=wanted[keys[i]] or u.BeeAbility~=nil or u.BeeAbilityPool~=nil end
    end
    local initial={Rng=rng,Draws=draws,Counts={},Values={},Weight=1,Path={}}
    for i=1,#upgrades do initial.Counts[i]=0;initial.Values[i]=0 end
    local started,lastYield=os.clock(),os.clock()
    local progressDone,progressTick=0,0
    local checkTicks=0
    local function checkpoint()
        checkTicks+=1
        if checkTicks~=1 and checkTicks%64~=0 then return end
        if options.Cancelled and options.Cancelled() then error("Prediction cancelled",0) end
        if os.clock()-started>(options.MaxSeconds or 600) then error("Search time limit reached; shorten the chain or increase MaxSeconds",0) end
        if os.clock()-lastYield>=0.012 then task.wait();lastYield=os.clock() end
    end
    -- RNG transitions depend on draw position and upgrade counts, not accrued values.
    -- Keep a bounded cache; replay ordered increments to preserve floating-point addition.
    local transitionCache,transitionKeys={},{}
    local transitionLimit=options.TransitionCacheSize or 512
    local cacheCursor=1
    local cacheHits,cacheMisses=0,0
    local function transitions(state,wax)
        local key=tostring(wax.ID)..":"..state.Draws..":"..table.concat(state.Counts,",")
        local cached=transitionCache[key]
        if cached then cacheHits+=1;return cached end
        cacheMisses+=1
        local result={}
        local skippedRng=state.Rng:Clone()
        for skip=1,32 do
            skippedRng:NextNumber()
            local child={Rng=skippedRng:Clone(),Draws=state.Draws+skip,Counts=table.clone(state.Counts),Deltas={}}
            local function draw() child.Draws+=1;return child.Rng:NextNumber() end
            for _=1,wax.Upgrades or 0 do
                local pool={}
                local special=wax.Name=="Caustic" or wax.Name=="Debug"
                for i,u in ipairs(upgrades) do
                    if child.Counts[i]<u.Max and (special or not u.CausticOnly) then pool[#pool+1]={i,weights[i]} end
                end
                assert(#pool>0,"Upgrade pool exhausted")
                local i=RandomPools.SelectFromOrderedList(pool,draw)
                local value=RQValue.Resolve(upgrades[i].Value,file.Q,draw,def.OldRNG)
                child.Deltas[#child.Deltas+1]={i,value}
                child.Counts[i]+=1
            end
            result[skip]=child
        end
        if transitionLimit>0 then
            if #transitionKeys<transitionLimit then transitionKeys[#transitionKeys+1]=key
            else
                transitionCache[transitionKeys[cacheCursor]]=nil
                transitionKeys[cacheCursor]=key
                cacheCursor=cacheCursor%transitionLimit+1
            end
            transitionCache[key]=result
        end
        return result
    end
    local function applyWax(state,wax,skip,appendPath)
        local child={Values=table.clone(state.Values),Weight=state.Weight,Path=table.clone(state.Path)}
        if appendPath then child.Path[#child.Path+1]=skip end
        if #upgrades==0 then
            child.Rng=state.Rng;child.Draws=state.Draws;child.Counts=state.Counts
            return child
        end
        if skip and skip>=1 then
            local tr=transitions(state,wax)[skip]
            child.Rng=tr.Rng;child.Draws=tr.Draws;child.Counts=tr.Counts
            for _,delta in ipairs(tr.Deltas) do child.Values[delta[1]]+=delta[2] end
        else
            -- Legacy histories can store a zero skip. Preserve their exact replay.
            child.Rng=state.Rng:Clone();child.Draws=state.Draws;child.Counts=table.clone(state.Counts)
            local function draw() child.Draws+=1;return child.Rng:NextNumber() end
            for _=1,wax.Upgrades or 0 do
                local pool={}
                for i,u in ipairs(upgrades) do
                    if child.Counts[i]<u.Max and (wax.Name=="Caustic" or wax.Name=="Debug" or not u.CausticOnly) then pool[#pool+1]={i,weights[i]} end
                end
                assert(#pool>0,"Upgrade pool exhausted")
                local i=RandomPools.SelectFromOrderedList(pool,draw)
                child.Values[i]+=RQValue.Resolve(upgrades[i].Value,file.Q,draw,def.OldRNG)
                child.Counts[i]+=1
            end
        end
        return child
    end
    for _,w in ipairs(file.W) do if w[2] then initial=applyWax(initial,WaxTypes.TypeByID[w[1]],w[3] or 0,false) end end
    local function stateKey(state)
        local parts={tostring(state.Draws)}
        for i=1,#upgrades do
            parts[#parts+1]=tostring(state.Counts[i])
            if not retained or retained[i] then parts[#parts+1]=string.format("%.17g",state.Values[i]) end
        end
        return table.concat(parts,",")
    end
    local states={initial}
    local memoryFallback={}
    local fallbackDepth
    local mergedOK,mergeError=pcall(function()
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
            if #nextStates>(options.MaxStates or 50000) then fallbackDepth=depth;error(memoryFallback,0) end
        end
        states=nextStates
        if options.OnStage then options.OnStage(string.format("Wax %d/%d: %d distinct states",depth,#chain,#states)) end
    end
    end)
    if not mergedOK and mergeError~=memoryFallback then error(mergeError,0) end
    if not mergedOK then
        -- Keep the completed merged prefix. Discard only the unfinished next layer.
        if options.OnStage then options.OnStage("Counting remaining outcomes · keeping completed work") end
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
        ConditionalOnAllSuccess=true,TargetProjection=retained~=nil,DistinctStates=#states,Streaming=not mergedOK,Before=before,ResetFirst=options.ResetWaxes==true}
    local function consume(state)
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
        progressDone+=state.Weight
        if options.OnProgress and os.clock()-progressTick>=0.25 then
            progressTick=os.clock();options.OnProgress(progressDone,total,os.clock()-started)
        end
        checkpoint()
    end
    if mergedOK then
        for _,state in ipairs(states) do consume(state) end
    else
        -- Merge terminal states in bounded chunks before formatting snapshots.
        -- Weights remain integers; flushing does not discard or sample any path.
        local pending,pendingList={},{}
        local function flush()
            for _,state in ipairs(pendingList) do consume(state) end
            pending={};pendingList={}
        end
        local function visit(state,depth)
            if depth>#waxes then
                local key=stateKey(state)
                local prior=pending[key]
                if prior then prior.Weight+=state.Weight
                else pending[key]=state;pendingList[#pendingList+1]=state end
                if #pendingList>=(options.TerminalMergeSize or 8192) then flush() end
                return
            end
            for skip=1,32 do visit(applyWax(state,waxes[depth],skip,true),depth+1);checkpoint() end
        end
        for _,state in ipairs(states) do visit(state,fallbackDepth) end
        flush()
    end
    assert(report.Evaluated==total,"Exact branch count mismatch")
    report.ConditionalMatchRate=report.Matched/total
    report.SuccessAndMatchRate=allSuccess*report.ConditionalMatchRate
    report.TransitionCacheHits=cacheHits;report.TransitionCacheMisses=cacheMisses
    report.Seconds=os.clock()-started
    if options.OnProgress then options.OnProgress(total,total) end
    return report
end

-- Compare short setup chains for a target. Non-destructive Hard failures are
-- included; destructive failures contribute zero target probability.
local function shortGuide(data, finishingWax, matchesTarget, options)
    options=options or {}
    assert(type(matchesTarget)=="function","Choose at least one target")
    waxDefinition(finishingWax)
    local file=detached(data,options)
    local remaining=5-#(file.W or {})
    assert(remaining>0,"No slots left. Choose an unwaxed item or enable a simulated reset in Options.")
    local baseline=snapshot(file)
    local candidates={{finishingWax},{"SoftWax",finishingWax},{"HardWax",finishingWax},
        {"SoftWax","SoftWax",finishingWax},{"SoftWax","HardWax",finishingWax},
        {"HardWax","SoftWax",finishingWax}}
    local memo,seen,rows={},{},{}
    local function checkCancel()
        if options.Cancelled and options.Cancelled() then error("Guide cancelled",0) end
    end
    local function conditionalRate(successful)
        if #successful==0 then return matchesTarget(baseline,baseline) and 1 or 0 end
        local key=table.concat(successful,">")
        if memo[key]~=nil then return memo[key] end
        local opts=table.clone(options)
        local label=table.concat(successful," > ")
        opts.OnStage=function(message)if options.OnStage then options.OnStage(label.." · "..message) end end
        local batch=Engine.Batch(data,successful,function(result)return matchesTarget(result,baseline)end,nil,opts)
        memo[key]=batch.ConditionalMatchRate
        return memo[key]
    end
    for _,chain in ipairs(candidates) do
        checkCancel()
        local label=table.concat(chain," > ")
        if #chain<=remaining and not seen[label] then
            seen[label]=true
            if options.OnStage then options.OnStage("Comparing "..label) end
            local chance,survival=0,0
            local successful={}
            local function outcomes(index,mass)
                checkCancel()
                if index>#chain then
                    survival+=mass
                    chance+=mass*conditionalRate(successful)
                    return
                end
                local wax=waxDefinition(chain[index])
                local rate=wax.SuccessRate or 1
                if rate>0 then
                    successful[#successful+1]=chain[index]
                    outcomes(index+1,mass*rate)
                    successful[#successful]=nil
                end
                if rate<1 and not wax.DestroyOnFail then
                    -- A failed Hard wax occupies a slot but has no stat or
                    -- seeded-RNG effect. Its slot was counted by #chain above.
                    outcomes(index+1,mass*(1-rate))
                end
            end
            outcomes(1,1)
            rows[#rows+1]={Chain=table.clone(chain),Slots=#chain,TargetChance=chance,
                SurvivalChance=survival,TargetGivenSurvival=survival>0 and chance/survival or 0}
            task.wait()
        end
    end
    table.sort(rows,function(a,b)
        if math.abs(a.TargetChance-b.TargetChance)<1e-12 then
            if a.Slots~=b.Slots then return a.Slots<b.Slots end
            return table.concat(a.Chain,">")<table.concat(b.Chain,">")
        end
        return a.TargetChance>b.TargetChance
    end)
    return {Rows=rows,Baseline=baseline,RemainingSlots=remaining,FinishingWax=finishingWax,
        AllSelectedTargets=true,IncludesNonDestructiveFailures=true}
end

-- Reachable reset routes: upgrade-wax attempts increment UC once, even Hard failures.
-- Soft filler rolls are erased by the reset; no 32^filler enumeration is needed.
function Engine.Guide(data, finishingWax, matchesTarget, options)
    options=options or {}
    local startOptions=table.clone(options)
    startOptions.ResetWaxes=false;startOptions.ShowBase=false;startOptions.UseOriginalSeed=false
    startOptions.BaseOffset=0
    local original=detached(data,startOptions)
    local baseline=snapshot(original)
    local maxResets=options.MaxResets or 3
    assert(maxResets%1==0 and maxResets>=0 and maxResets<=10,"MaxResets must be 0..10")
    local rows,routes={},{}
    local function cancelled()
        if options.Cancelled and options.Cancelled() then error("Guide cancelled",0) end
    end
    local function evaluate(file,route)
        cancelled()
        if #(file.W or {})>=5 then return end
        local opts=table.clone(options)
        opts.ResetWaxes=false;opts.ShowBase=false;opts.UseOriginalSeed=false;opts.BaseOffset=0
        local report=shortGuide(file,finishingWax,function(result)return matchesTarget(result,baseline)end,opts)
        for _,row in ipairs(report.Rows) do
            row.Steps=clone(route.Steps)
            row.Steps[#row.Steps+1]=table.concat(row.Chain," > ")
            row.TurpentineCount=route.Turps;row.FillerSoftCount=route.Soft
            row.ResetOffset=file.RC or 0;row.TotalWaxCount=route.Soft+#row.Chain
            if #row.Chain==1 then
                row.MatchingBranches={}
                for skip=1,32 do
                    cancelled()
                    local result=Engine.Single(file,row.Chain[1],skip,opts)
                    if matchesTarget(result,baseline) then
                        row.MatchingBranches[#row.MatchingBranches+1]={Skip=skip,Result=result}
                    end
                end
            end
            rows[#rows+1]=row
        end
    end
    evaluate(original,{Steps={},Turps=0,Soft=0})
    local frontier={{File=original,Steps={},Turps=0,Soft=0}}
    for depth=1,maxResets do
        local nextRoutes={}
        for _,route in ipairs(frontier) do
            local file=route.File
            local remaining=5-#(file.W or {})
            for soft=0,remaining do
                cancelled()
                -- An empty reset cannot advance the counter or produce a new route.
                if soft>0 or #(file.W or {})>0 then
                    local counter=file.UC
                    if counter==nil then
                        -- Safe reconstruction for an untouched history only.
                        assert((file.RC or 0)==0,"Missing cumulative wax counter; refresh/import UC for reset planning")
                        counter=0
                        for _,w in ipairs(file.W or {}) do if w[1]~=4 then counter+=1 end end
                    end
                    local reset=clone(file)
                    reset.UC=counter+soft;reset.RC=reset.UC;reset.W=nil
                    reset.S=reset.OS or reset.S
                    local steps=clone(route.Steps)
                    if soft>0 then steps[#steps+1]="SoftWax ×"..soft end
                    steps[#steps+1]="Turpentine → reset offset "..reset.RC
                    local candidate={File=reset,Steps=steps,Turps=depth,Soft=route.Soft+soft}
                    local prior=nextRoutes[reset.RC]
                    if not prior or candidate.Soft<prior.Soft then nextRoutes[reset.RC]=candidate end
                end
            end
        end
        frontier={}
        for _,route in pairs(nextRoutes) do
            frontier[#frontier+1]=route
            local key=tostring(route.File.RC)
            if not routes[key] then
                routes[key]=true
                if options.OnStage then options.OnStage("Planning reset "..depth.."/"..maxResets.." · offset "..key) end
                evaluate(route.File,route)
            end
        end
    end
    table.sort(rows,function(a,b)
        if math.abs(a.TargetChance-b.TargetChance)>1e-12 then return a.TargetChance>b.TargetChance end
        if a.TurpentineCount~=b.TurpentineCount then return a.TurpentineCount<b.TurpentineCount end
        if a.TotalWaxCount~=b.TotalWaxCount then return a.TotalWaxCount<b.TotalWaxCount end
        return table.concat(a.Steps," > ")<table.concat(b.Steps," > ")
    end)
    return {Rows=rows,Baseline=baseline,RemainingSlots=5-#(original.W or {}),MaxResets=maxResets,
        FinishingWax=finishingWax,AllSelectedTargets=true,IncludesNonDestructiveFailures=true}
end

-- Bounded automatic search. Each completed candidate is exact; unfinished batches
-- contribute nothing. Rankings are only over completed fixed Soft-prefix/finisher plans.
function Engine.AutoPlan(data,targets,matchesTarget,groupBy,options)
    options=options or {}
    assert(type(targets)=="table" and #targets>0,"Select the ability or hive/stat target first")
    local maxResets=options.MaxResets or 1
    assert(maxResets%1==0 and maxResets>=0 and maxResets<=3,"Choose 0..3 resets")
    local budget=options.PlannerSeconds or 90
    assert(budget>=1 and budget<=600,"Planner budget must be 1..600 seconds")
    local opts=table.clone(options)
    opts.ResetWaxes=false;opts.ShowBase=false;opts.UseOriginalSeed=false;opts.BaseOffset=0;opts.Targets=targets
    local initial=detached(data,opts)
    local baseline=snapshot(initial)
    local started=os.clock()
    local stopped,timedOut=false,false
    local function stop()
        if options.Cancelled and options.Cancelled() then stopped=true;return true end
        if os.clock()-started>=budget then timedOut=true;return true end
        return false
    end
    opts.Cancelled=stop
    local routes={{File=initial,Steps={},Turps=0,Soft=0,Kind="Current"}}
    local frontier={routes[1]}
    local seen={}
    for depth=1,maxResets do
        local nextRoutes={}
        for _,r in ipairs(frontier) do
            local file=r.File
            local counter=file.UC
            if counter==nil then
                assert((file.RC or 0)==0,"Missing UC; refresh the item for reset planning")
                counter=0;for _,w in ipairs(file.W or {})do if w[1]~=4 then counter+=1 end end
            end
            for soft=0,5-#(file.W or {}) do
                if soft>0 or #(file.W or {})>0 then
                    local reset=clone(file)
                    reset.UC=counter+soft;reset.RC=reset.UC;reset.W=nil;reset.S=reset.OS or reset.S
                    local steps=clone(r.Steps)
                    if soft>0 then steps[#steps+1]="SoftWax ×"..soft end
                    steps[#steps+1]="Turpentine → RC "..reset.RC
                    local next={File=reset,Steps=steps,Turps=depth,Soft=r.Soft+soft,Kind="Reset"}
                    local prior=nextRoutes[reset.RC]
                    if not prior or next.Soft<prior.Soft then nextRoutes[reset.RC]=next end
                end
            end
        end
        frontier={}
        for rc,r in pairs(nextRoutes) do
            frontier[#frontier+1]=r
            if not seen[rc] then seen[rc]=true;routes[#routes+1]=r end
        end
    end
    -- A target requiring a Caustic-only upgrade cannot be created by Soft/Hard.
    local causticRequired=false
    local def=BeequipTypes.Get(initial.T)
    for _,f in ipairs(targets) do
        local found,normal=false,false
        for _,u in ipairs(def.Upgrades or {}) do
            local same=f.kind=="Ability" and u.BeeAbility==f.name
                or f.kind=="Bee" and u.BeeStat==f.name
                or f.kind=="Hive" and u.HiveBonusStat==f.name and tag(u)==tag({HiveBonusStat=f.name,Op=f.op,Params=f.params})
            if same then found=true;if not u.CausticOnly then normal=true end end
        end
        local alreadyPresent=false
        if f.kind=="Ability" then for _,a in ipairs(baseline.Abilities)do if a[1]==f.name then alreadyPresent=true end end end
        if found and not normal and not alreadyPresent then causticRequired=true end
    end
    local candidates={}
    for index,r in ipairs(routes)do
        local slots=5-#(r.File.W or {})
        local unique={}
        if r.Turps>0 then candidates[#candidates+1]={Route=index,Chain={},Prefix=0,Tail=0,Finisher="SoftWax",Priority=-1}end
        local finishers=causticRequired and {"CausticWax"} or {"SoftWax","HardWax","CausticWax"}
        for soft=0,slots-1 do
            for _,wax in ipairs(finishers)do
                for n=1,slots-soft do
                    local chain={}
                    for _=1,soft do chain[#chain+1]="SoftWax"end
                    for _=1,n do chain[#chain+1]=wax end
                    local key=table.concat(chain,">")
                    if not unique[key]then
                        unique[key]=true
                        local priority=#chain==1 and 0 or #chain<=3 and (.5+#chain*.1) or (index==1 and soft==0 and wax=="CausticWax" and n==slots) and 1 or 2+#chain*.1+r.Turps*.01
                        candidates[#candidates+1]={Route=index,Chain=chain,Prefix=soft,Tail=n,Finisher=wax,Priority=priority}
                    end
                end
            end
        end
    end
    table.sort(candidates,function(a,b)
        if a.Priority~=b.Priority then return a.Priority<b.Priority end
        if a.Route~=b.Route then return a.Route<b.Route end
        return table.concat(a.Chain,">")<table.concat(b.Chain,">")
    end)
    local rows,memo={},{}
    local groupedOverflow=false
    local function conditional(routeIndex,chain)
        local key=routeIndex..":"..table.concat(chain,">")
        if memo[key]then return memo[key]end
        local file=routes[routeIndex].File
        local report
        if #chain==0 then
            local result=snapshot(file)
            local hit=matchesTarget(result,baseline)
            report={Total=1,Matched=hit and 1 or 0,Groups={}}
            if hit and groupBy then report.Groups[tostring(groupBy(result,baseline))]=1 end
        else
            opts.MaxSeconds=math.max(.01,budget-(os.clock()-started))
            opts.OnProgress=nil
            opts.OnStage=nil
            local known,outcomes={},0
            local function summarize(result,before)
                local text=tostring(groupBy(result,before))
                if known[text]then return text end
                if outcomes>=128 then groupedOverflow=true;return "Other matching target outcomes (grouped)"end
                known[text]=true;outcomes+=1;return text
            end
            report=Engine.Batch(file,chain,function(result)return matchesTarget(result,baseline)end,groupBy and summarize or nil,opts)
        end
        memo[key]=report
        return report
    end
    for index,c in ipairs(candidates)do
        if stop()then break end
        local route=routes[c.Route]
        if options.OnStage then options.OnStage("Plan "..index.."/"..#candidates.." · RC "..(route.File.RC or 0).." · "..(#c.Chain>0 and table.concat(c.Chain," > ") or "reset alone"))end
        local ok,row=pcall(function()
            local chance,survival,groups=0,1,{}
            local function accumulate(report,mass)
                chance+=mass*report.Matched/report.Total
                for key,count in pairs(report.Groups)do groups[key]=(groups[key] or 0)+mass*count/report.Total end
            end
            if c.Finisher=="HardWax" then
                -- Hard failures occupy slots but do not advance seeded generation.
                -- All Hard applications are consecutive: sum binomial success counts.
                local choose=1
                for k=0,c.Tail do
                    if stop()then error("Planner interrupted",0)end
                    local chain={}
                    for _=1,c.Prefix do chain[#chain+1]="SoftWax"end
                    for _=1,k do chain[#chain+1]="HardWax"end
                    accumulate(conditional(c.Route,chain),choose*.6^k*.4^(c.Tail-k))
                    choose=choose*(c.Tail-k)/(k+1)
                end
            else
                if c.Finisher=="CausticWax"then survival=.25^c.Tail end
                accumulate(conditional(c.Route,c.Chain),survival)
            end
            local steps=clone(route.Steps)
            if #c.Chain>0 then steps[#steps+1]=table.concat(c.Chain," > ")end
            return {Chain=clone(c.Chain),Steps=steps,Kind=route.Kind,ResetOffset=route.File.RC or 0,
                TurpentineCount=route.Turps,FillerSoftCount=route.Soft,WaxCount=route.Soft+#c.Chain,
                TargetChance=chance,SurvivalChance=survival,ConditionalChance=survival>0 and chance/survival or 0,Groups=groups}
        end)
        if not ok then
            if stop() or tostring(row):find("time limit",1,true)then timedOut=not stopped;break end
            error(row,0)
        end
        rows[#rows+1]=row
        task.wait()
    end
    table.sort(rows,function(a,b)
        if math.abs(a.TargetChance-b.TargetChance)>1e-12 then return a.TargetChance>b.TargetChance end
        if a.TurpentineCount~=b.TurpentineCount then return a.TurpentineCount<b.TurpentineCount end
        if a.WaxCount~=b.WaxCount then return a.WaxCount<b.WaxCount end
        return table.concat(a.Steps,">")<table.concat(b.Steps,">")
    end)
    local offsets={}
    for _,row in ipairs(rows)do
        local key=row.Kind..":"..row.ResetOffset
        if not offsets[key]then offsets[key]=row end
    end
    local offsetRows={};for _,row in pairs(offsets)do offsetRows[#offsetRows+1]=row end
    table.sort(offsetRows,function(a,b)if a.ResetOffset==b.ResetOffset then return a.Kind<b.Kind end;return a.ResetOffset<b.ResetOffset end)
    return {Rows=rows,Offsets=offsetRows,Completed=#rows,Candidates=#candidates,Stopped=stopped,TimedOut=timedOut,
        Seconds=os.clock()-started,MaxResets=maxResets,CausticRequired=causticRequired,GroupedOverflow=groupedOverflow,Complete=#rows==#candidates}
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
    for _, location in ipairs({"Storage", "Inbox"}) do
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

end)()
-- Tifa's Predictor: local simulation UI. Never applies wax or fires inventory remotes.
local E = assert(getgenv().TifaPredictorEngine, "Load the predictor core first")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Http = game:GetService("HttpService")
local Types = require(RS.Beequips.BeequipTypes)
local StatMods = require(RS.BeeStats.BeeStatMods)
local WaxTypes = require(RS.WaxTypes)
local old = getgenv().TifaPredictorUI
if old and old.Destroy then old.Destroy() end
local C = {bg=Color3.fromRGB(18,18,18),panel=Color3.fromRGB(25,25,25),button=Color3.fromRGB(39,39,39),
    text=Color3.fromRGB(195,195,195),muted=Color3.fromRGB(130,130,130),green=Color3.fromRGB(147,255,126),
    active=Color3.fromRGB(40,99,38),blue=Color3.fromRGB(49,100,153),purple=Color3.fromRGB(65,55,117),red=Color3.fromRGB(119,48,51)}
local state={source="Storage",index=1,tab="BATCH",wax="SoftWax",chain={},filters={},showBase=false,currentSeed=true,resetFirst=false,
    busy=false,cancelled=false,alive=true,items={},result="Choose an item, then START.",imported=nil,showItems=true,advanced=false}
local connections={}
local function connect(signal,fn)
    if #connections>256 then
        for i=#connections,1,-1 do if not connections[i].Connected then table.remove(connections,i) end end
    end
    local c=signal:Connect(fn);connections[#connections+1]=c;return c
end
local function make(class,parent,props)
    local obj=Instance.new(class)
    for k,v in pairs(props or {}) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local function round(obj,r) make("UICorner",obj,{CornerRadius=UDim.new(0,r or 8)}) end
local function label(parent,name,text,x,y,w,h,size,color)
    return make("TextLabel",parent,{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundTransparency=1,TextColor3=color or C.text,Font=Enum.Font.Gotham,TextSize=size or 11,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,BorderSizePixel=0})
end
local function button(parent,name,text,x,y,w,h,color)
    local b=make("TextButton",parent,{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundColor3=color or C.button,TextColor3=C.text,Font=Enum.Font.GothamBold,TextSize=10,
        AutoButtonColor=true,TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0});round(b);return b
end
local function input(parent,name,text,x,y,w,h)
    local b=make("TextBox",parent,{Name=name,Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundColor3=C.bg,TextColor3=C.text,PlaceholderColor3=C.muted,Font=Enum.Font.Gotham,TextSize=11,
        ClearTextOnFocus=false,BorderSizePixel=0});round(b);return b
end
local parent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local gui=make("ScreenGui",parent,{Name="TifaPredictorGui",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=80,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local window=make("Frame",gui,{Name="Window",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(600,450),BackgroundColor3=C.bg,BorderSizePixel=0});round(window,12)
local scale=make("UIScale",window,{Scale=1})
local function resize()
    local v=workspace.CurrentCamera.ViewportSize
    scale.Scale=math.min(1,(v.X-24)/(state.showItems and 874 or 600),(v.Y-24)/450)
    window.Position=UDim2.new(.5,state.showItems and 137*scale.Scale or 0,.5,0)
end
resize();connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),resize)
local title=label(window,"Title","Predictor",10,6,420,22,11,C.green);title.Font=Enum.Font.GothamBold
local minimize=button(window,"Minimize","–",539,7,22,20)
local close=button(window,"Close","×",569,7,22,20)
local itemsToggle=button(window,"ToggleItems","☷",477,7,24,20);itemsToggle.TextSize=9
minimize.BackgroundTransparency=1;close.BackgroundTransparency=1;close.TextColor3=C.red
local sourceCaption=label(window,"SourceCaption","SOURCE",45,31,80,12,8,C.muted)
local waxCaption=label(window,"WaxCaption","WAX",315,31,80,12,8,C.muted)
local source=button(window,"Source","Storage",10,45,110,23)
local itemTrack=make("Frame",window,{Name="ItemSelector",Position=UDim2.fromOffset(130,45),Size=UDim2.fromOffset(120,23),BackgroundColor3=C.panel,BorderSizePixel=0});round(itemTrack)
local prev=button(window,"Previous","<",130,45,24,23)
local itemButton=button(window,"Item","1",154,45,72,23)
local nextButton=button(window,"Next",">",226,45,24,23)
prev.BackgroundColor3=C.panel;itemButton.BackgroundColor3=C.panel;nextButton.BackgroundColor3=C.panel
local wax=button(window,"Wax","SoftWax",270,45,110,23)
local skipTrack=make("Frame",window,{Name="SkipSelector",Position=UDim2.fromOffset(390,45),Size=UDim2.fromOffset(120,23),BackgroundColor3=C.panel,BorderSizePixel=0});round(skipTrack)
local skipPrev=button(window,"SkipPrevious","<",390,45,24,23)
local skip=input(window,"WaxCount","1",414,45,72,23)
local skipNext=button(window,"SkipNext",">",486,45,24,23)
label(window,"WaxQuantityCaption","",415,31,95,12,8,C.muted)
skipPrev.BackgroundColor3=C.panel;skip.BackgroundColor3=C.panel;skipNext.BackgroundColor3=C.panel
local baseButton=button(window,"ShowBase","○  Show base",520,45,72,23)
baseButton.BackgroundTransparency=1;baseButton.Font=Enum.Font.Gotham;baseButton.TextSize=9
local tabs={}
for i,name in ipairs({"SINGLE","BATCH","EXPLORE"}) do tabs[name]=button(window,name,name,10+(i-1)*65,75,60,25) end
local function pane(name,x,w)
    local p=make("Frame",window,{Name=name,Position=UDim2.fromOffset(x,106),Size=UDim2.fromOffset(w,280),
        BackgroundColor3=C.panel,BorderSizePixel=0});round(p);return p
end
local left=pane("CurrentPane",10,190);left.Size=UDim2.fromOffset(190,330)
local middle=pane("FilterPane",205,160)
local right=pane("ResultsPane",370,220)
local filterHeading=label(middle,"Heading","SELECT FILTERS:",7,7,147,15,9,C.muted)
local resultHeading=label(right,"Heading","MATCHED RESULTS",10,7,200,15,9,C.muted)
local function scroll(parent,name,x,y,w,h)
    return make("ScrollingFrame",parent,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.muted,
        CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.Y})
end
local currentScroll=scroll(left,"CurrentScroll",10,8,177,268)
local currentText=label(currentScroll,"CurrentStats","",0,0,168,268,11)
currentText.TextYAlignment=Enum.TextYAlignment.Top;currentText.TextWrapped=true
local filterScroll=scroll(middle,"FilterScroll",7,26,148,247)
local resultScroll=scroll(right,"ResultScroll",10,28,201,244)
local resultText=label(resultScroll,"Results",state.result,0,0,191,244,11)
resultText.TextYAlignment=Enum.TextYAlignment.Top;resultText.TextWrapped=true
resultText.RichText=true
local paste=input(window,"ImportJSON","",20,389,170,20);paste.PlaceholderText="Paste Beequip JSON…";paste.TextSize=9
local copyData=button(window,"CopyData","COPY DATA",20,413,80,22)
local import=button(window,"Import","IMPORT",106,413,84,22,C.blue)
local chainLabel=label(window,"Chain","CHAIN: empty",214,393,288,17,8,C.green)
local add=button(window,"Add","ADD",214,416,50,22,C.purple)
local remove=button(window,"Remove","REM",269,416,50,22,Color3.fromRGB(101,50,103))
local clear=button(window,"Clear","CLR",324,416,50,22,C.red)
local copy=button(window,"CopyResults","COPY",379,416,50,22,C.blue)
local viewStats=button(window,"ViewStats","VIEW STATS",214,416,77,22,C.blue)
viewStats.Size=UDim2.fromOffset(160,22)
viewStats.Text="VIEW CURRENT STATS"
local stepsLabel=label(window,"StepsCaption","STEPS",214,393,38,20,8,C.muted)
local steps=input(window,"Steps","16",253,393,43,21)
local offsetLabel=label(window,"OffsetCaption","OFFSET",303,393,42,20,8,C.muted)
local offset=input(window,"Offset","0",346,393,40,21)
local zoom=button(window,"ZoomIn","ZOOM IN",394,393,61,21,C.active)
local seed=button(window,"Seed","● Current / swirled seed",214,417,174,21)
local copyExplore=button(window,"CopyExplore","COPY ALL",394,417,61,21,C.blue)
local start=button(window,"Start","START",512,394,75,44,C.active)
local status=label(window,"Status","Simulation only · your items stay unchanged",10,438,580,11,9,C.muted)
local progressTrack=make("Frame",window,{Name="ProgressTrack",Position=UDim2.fromOffset(10,448),Size=UDim2.fromOffset(580,2),BackgroundColor3=C.panel,BorderSizePixel=0,Visible=false})
local progressFill=make("Frame",progressTrack,{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=C.green,BorderSizePixel=0})
local popup=scroll(window,"ItemPicker",130,72,280,210);popup.BackgroundTransparency=0;popup.BackgroundColor3=C.button
popup.Visible=false;popup.ZIndex=8;round(popup)
local selector=scroll(window,"SelectorMenu",10,72,180,155);selector.BackgroundTransparency=0;selector.BackgroundColor3=C.button
selector.Visible=false;selector.ZIndex=10;round(selector)
local inventoryPanel=make("Frame",window,{Name="BeequipInventory",Position=UDim2.fromOffset(-274,0),
    Size=UDim2.fromOffset(264,450),BackgroundColor3=C.bg,BorderSizePixel=0});round(inventoryPanel,10)
local inventoryHeading=label(inventoryPanel,"Heading","BEEQUIPS",11,7,216,22,11,C.green)
inventoryHeading.Font=Enum.Font.GothamBold
local hideItems=button(inventoryPanel,"HideItems","×",233,8,21,20);hideItems.BackgroundTransparency=1;hideItems.TextColor3=C.red
local inventoryScroll=scroll(inventoryPanel,"Cards",7,36,251,406)
local cardConnections={}
local renderInventory
local advancedButton=button(window,"Options","···",509,7,22,20);advancedButton.BackgroundTransparency=1
local turpPreview=button(window,"TurpPreview","○ After Turp",210,77,145,23)
turpPreview.Font=Enum.Font.Gotham;turpPreview.TextSize=10
local planningSummary=label(window,"PlanningSummary","Keep waxes",370,77,220,21,9,C.muted)
local advancedPanel=make("Frame",window,{Name="AdvancedPanel",Position=UDim2.fromOffset(275,104),
    Size=UDim2.fromOffset(235,234),BackgroundColor3=C.button,BorderSizePixel=0,ZIndex=12,Visible=false})
round(advancedPanel)
label(advancedPanel,"Title","Planning options",10,7,200,21,11,C.green)
local optionsClose=button(advancedPanel,"Close","×",207,7,19,21)
local resetFirst=button(advancedPanel,"ResetFirst","○ Reset before search",10,35,215,25)
resetFirst.Font=Enum.Font.Gotham;resetFirst.TextSize=10
local baseCaption=label(advancedPanel,"BaseOffsetCaption","Base RNG offset",10,70,130,23,10,C.muted)
local baseOffsetInput=input(advancedPanel,"BaseOffset","0",151,70,74,23)
seed.Parent=advancedPanel;seed.Position=UDim2.fromOffset(10,103);seed.Size=UDim2.fromOffset(215,24)
tabs.GUIDE=button(advancedPanel,"GUIDE","HIVE BONUSES AT OFFSETS",10,138,215,25,C.blue)
tabs.PLAN=button(advancedPanel,"PLAN","FIND BEST WAX PLAN",10,168,215,25,C.active)
local optionHint=label(advancedPanel,"Hint","Changes affect the simulation only.",10,198,215,28,9,C.muted)
optionHint.TextWrapped=true
local help=button(advancedPanel,"Help","?",183,7,20,21);help.BackgroundTransparency=1
local filterDefs={}
local function notify(text) if state.alive then status.Text=text end end
local function editable() if state.busy then notify("Press STOP before changing the simulation.");return false end;return true end
local function selected() return state.items[state.index] end
local function remainingSlots()
    local item=selected()
    return state.resetFirst and 5 or math.max(0,5-#(item and item.Data.W or {}))
end
local function options()
    return {UseOriginalSeed=not state.currentSeed,ResetWaxes=state.resetFirst,BaseOffset=tonumber(baseOffsetInput.Text) or -1}
end
local function fieldsEqual(a,b)
    for k,v in pairs(a or {}) do if (b or {})[k]~=v then return false end end
    for k,v in pairs(b or {}) do if (a or {})[k]~=v then return false end end
    return true
end
local function statValue(snapshot,f)
    if f.kind=="Ability" then for _,v in ipairs(snapshot.Abilities) do if v[1]==f.name then return 1 end end;return 0 end
    for _,v in ipairs(snapshot[f.kind]) do
        if (v.Stat or v.Type)==f.name and (f.kind~="Hive" or (v.Op or "Add")==f.op)
            and fieldsEqual(v.Params,f.params) then return v.Value end
    end
    if f.kind=="Bee" then local def=StatMods.GetType(f.name);if def and def.Op=="Mul" then return 1 end end
    return 0
end
local aliases={GatherRedMul="Red Gather Amount",GatherWhiteMul="White Gather Amount",GatherBlueMul="Blue Gather Amount",
    ConvertMul="Convert Amount",ConvertAtHiveMul="Convert At Hive",CriticalPower="Critical Power",CriticalChance="Critical Chance",
    SuperCritPower="Super-Crit Power",SuperCritChance="Super-Crit Chance",MovespeedMul="Movespeed",EnergyMul="Energy",
    BeeMovespeedMultiplier="Bee Movespeed",ConversionAtHive="Convert At Hive",ContainerSpaceMultiplier="Field Capacity"}
local function friendly(name) return aliases[name] or name:gsub("(%l)(%u)","%1 %2") end
local function beeDescription(item)
    local def=StatMods.GetType(item.Stat)
    if def and def.Desc then
        local ok,text=pcall(def.Desc,item)
        if ok and type(text)=="string" then
            if item.FromUpgrade and item.FromUpgrade>0 and text:find("%%") then
                local baseline=item.Value-item.FromUpgrade-(def.Op=="Mul" and 1 or 0)
                text=text:gsub("%s*%b()", "")..string.format(" (%.6g+%.6g)",baseline*100,item.FromUpgrade*100)
            end
            return text
        end
    end
    return friendly(item.Stat)..": "..string.format("%.4g",item.Value)
end
local function hiveDescription(item)
    local params=""
    for k,v in pairs(item.Params or {}) do params..=" "..tostring(v) end
    local percentages={CriticalPower=true,CriticalChance=true,SuperCritPower=true,SuperCritChance=true,
        ConversionAtHive=true,ContainerSpaceMultiplier=true,HoneyFromTokens=true,BeeMovespeedMultiplier=true,
        BaseProductionRate=true,PollenBonus=true,ConvertRate=true,AbilityTokenLifespan=true,BeeAbilityRate=true,
        BattleBondMultiplier=true,BeeAttackMultiplier=true,BombPollen=true,DamageReduction=true,DodgeChance=true,
        HoneyAtHive=true,HoneyFromInstantConversion=true,HoneyPerGoo=true,Luck=true,MarkDurationMultiplier=true,
        MaxBeeEnergy=true,MonsterCooldownReduction=true,PollenConversion=true,PollenPreserved=true,TicketChance=true,
        TreatBondMultiplier=true}
    local value
    if item.Op=="Mul" then value="x"..string.format("%.4g",item.Value)
    elseif percentages[item.Type] then value=string.format("%+.3g%%",item.Value*100)
    else value=string.format("%+.4g",item.Value) end
    local name=friendly(item.Type)..params
    if item.Type=="PollenBonus" and item.Params then
        name=(item.Params.Color or item.Params.Zone or (item.Params.Tag and friendly(item.Params.Tag)) or "").." Pollen"
    elseif item.Type=="BaseProductionRate" then name="Convert Rate"..params end
    local description="[Hive Bonus] "..value.." "..name
    if item.FromUpgrade and item.FromUpgrade>0 then
        local multiplier=percentages[item.Type] and item.Op~="Mul" and 100 or 1
        description..=string.format(" (%.6g+%.6g)",(item.Value-item.FromUpgrade)*multiplier,item.FromUpgrade*multiplier)
    end
    return description
end
local function describe(snapshot)
    local lines={}
    for _,v in ipairs(snapshot.Bee) do lines[#lines+1]=beeDescription(v) end
    for _,v in ipairs(snapshot.Abilities) do lines[#lines+1]="Ability: "..v[1] end
    if #snapshot.Hive>0 then lines[#lines+1]="" end
    for _,v in ipairs(snapshot.Hive) do lines[#lines+1]=hiveDescription(v) end
    return table.concat(lines,"\n")
end
local function filterDescription(snapshot,f)
    if f.kind=="Ability" then return "Ability: "..f.name end
    for _,v in ipairs(snapshot[f.kind]) do
        if (v.Stat or v.Type)==f.name and (f.kind~="Hive" or (v.Op or "Add")==f.op)
            and fieldsEqual(v.Params,f.params) then
            return f.kind=="Bee" and beeDescription(v) or hiveDescription(v)
        end
    end
    return f.label
end
local function setText(textObj,frame,text)
    textObj.Text=text
    local measure=textObj.RichText and text:gsub("<[^>]+>","") or text
    local measured=game:GetService("TextService"):GetTextSize(measure,textObj.TextSize,textObj.Font,Vector2.new(textObj.Size.X.Offset,100000))
    local height=math.max(frame.Size.Y.Offset,measured.Y+14)
    textObj.Size=UDim2.fromOffset(textObj.Size.X.Offset,height);frame.CanvasSize=UDim2.fromOffset(0,height)
end
local function setResults(text)
    state.result=text
    resultScroll.CanvasPosition=Vector2.zero
    local colored={}
    local visibleText=text
    local predictionStart=text:find("=== MATCHED PREDICTIONS ===",1,true)
    if text:find("=== BATCH MATCHES ===",1,true)==1 and predictionStart then
        visibleText=text:sub(predictionStart+#"=== MATCHED PREDICTIONS ==="+1)
    end
    for line in (visibleText.."\n"):gmatch("(.-)\n") do
        if #colored>=400 then colored[#colored+1]="… More results available with COPY.";break end
        local visual=line
        visual=visual:gsub("([%d]+%.[%d]+)%%",function(value)
            local n=tonumber(value)
            if n>0 and n<0.1 then return "<0.1%" end
            return string.format("%.1f%%",n)
        end)
        visual=visual:gsub("^Total predicts %-%-> ","Outcomes: "):gsub("^Matched %-%-> ","Matches: ")
        visual=visual:gsub("^%-%-%- INDIVIDUAL CHANCES %-%-%-$","STAT CHANCES")
            :gsub("^%-%-%- COMBINATIONS %-%-%-$","OUTCOMES")
        if visual:sub(1,1)=="[" and visual:sub(-1)=="]" then visual=visual:sub(2,-2) end
        local safe=visual:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
        if line:find("INDIVIDUAL CHANCES",1,true) or line:find("COMBINATIONS",1,true) then
            safe='<font color="#4386b8">'..safe..'</font>'
        elseif line:find("Total predicts",1,true) or line:find("Matches:",1,true) or line:find("Best choice:",1,true) then
            safe='<font color="#93ff7e">'..safe..'</font>'
        end
        colored[#colored+1]=safe
    end
    local display=table.concat(colored,"\n")
    if #display>55000 then display=display:sub(1,53000):gsub("<[^>]*$", "").."\n\nDisplay shortened. COPY REPORT contains the complete report." end
    setText(resultText,resultScroll,display);resultScroll.CanvasPosition=Vector2.zero
end
local function refreshCurrent()
    local item=selected()
    itemButton.Text=item and tostring(state.index) or "—"
    if renderInventory then renderInventory() end
    if not item then setText(currentText,currentScroll,"No Beequips in this source.\n\nChoose another source or import item JSON.");return end
    local displayOptions=options();displayOptions.ShowBase=state.showBase and not state.resetFirst
    local ok,s=pcall(E.Evaluate,item.Data,displayOptions)
    if not ok then setText(currentText,currentScroll,tostring(s));return end
    local waxLabels={[1]="Sf",[2]="Hd",[3]="Cs",[4]="Swrl",[5]="Db"}
    local history={}
    for _,w in ipairs(s.WaxHistory)do history[#history+1]=(waxLabels[w[1]] or tostring(w[1]))..":"..(w[2] and tostring(w[3] or 0) or "fail")end
    local lines={(state.resetFirst and "AFTER TURP | W: " or "CUR | W: ")..#s.WaxHistory.."/5",#history>0 and ("("..table.concat(history,", ")..")") or "","",
        "Base offset: "..s.BaseOffset,"Offset after turp: "..s.TurpentineOffset,"Current offset: "..s.CurrentOffset,"","-------------------------","",
        "Potential: "..string.format("%.3f",s.Quality*5),"","-------------------------","",describe(s)}
    setText(currentText,currentScroll,table.concat(lines,"\n"))
end
local function refreshFilters()
    for _,child in ipairs(filterScroll:GetChildren()) do child:Destroy() end
    filterDefs={};state.filters={}
    local item=selected();if not item then return end
    local def=Types.Get(item.Data.T)
    for _,upgrade in ipairs(def.Upgrades or {}) do
        local f
        if upgrade.BeeStat then f={kind="Bee",name=upgrade.BeeStat}
        elseif upgrade.HiveBonusStat then f={kind="Hive",name=upgrade.HiveBonusStat,op=upgrade.Op or "Add",params=upgrade.Params}
        elseif upgrade.BeeAbility then f={kind="Ability",name=upgrade.BeeAbility}
        end
        local candidates={}
        if f then candidates[1]=f elseif upgrade.BeeAbilityPool then
            for _,v in ipairs(upgrade.BeeAbilityPool) do candidates[#candidates+1]={kind="Ability",name=v[1]} end
        end
        for _,candidate in ipairs(candidates) do
            local i=#filterDefs+1;filterDefs[i]=candidate
            local prefix=candidate.kind=="Hive" and "[HIVE] " or candidate.kind=="Ability" and "Ability: " or ""
            local param="";for _,v in pairs(candidate.params or {}) do param..=" "..tostring(v) end
            candidate.label=prefix..friendly(candidate.name)..param.." (+)"
            local b=button(filterScroll,"Filter"..i,"[ ] "..candidate.label,0,(i-1)*25,141,22)
            b.TextSize=9;b.TextXAlignment=Enum.TextXAlignment.Left
            connect(b.Activated,function() if not editable() then return end;state.filters[i]=not state.filters[i];
                b.BackgroundColor3=state.filters[i] and C.active or C.button;b.Text=(state.filters[i] and "[✓] " or "[ ] ")..candidate.label end)
        end
    end
    filterScroll.CanvasSize=UDim2.fromOffset(0,#filterDefs*25)
end
local function reloadItems()
    state.items={}
    if state.source=="Import" then
        if state.imported then state.items[1]={Location="Import",Index=1,Data=state.imported} end
    elseif state.source=="Trade" then
        state.items=state.tradeItems or {}
    else
        for _,item in ipairs(E.Inventory()) do if item.Location==state.source then state.items[#state.items+1]=item end end
    end
    if not state.initialSelected and #state.items>0 then
        for i,item in ipairs(state.items) do if #(item.Data.W or {})<5 then state.index=i;break end end
        state.initialSelected=true
    end
    state.index=math.clamp(state.index,1,math.max(1,#state.items))
    source.Text=state.source;refreshCurrent();refreshFilters()
end
local function redraw()
    for name,b in pairs(tabs) do b.BackgroundColor3=name==state.tab and Color3.fromRGB(46,46,46) or C.panel end
    local explore=state.tab=="EXPLORE";local batch=state.tab=="BATCH";local guide=state.tab=="GUIDE";local planner=state.tab=="PLAN"
    chainLabel.Visible=batch or state.tab=="SINGLE";add.Visible=batch or state.tab=="SINGLE";remove.Visible=add.Visible;clear.Visible=add.Visible;copy.Visible=not explore
    viewStats.Visible=false
    stepsLabel.Visible=guide or planner;steps.Visible=guide or planner;offsetLabel.Visible=guide or planner;offset.Visible=guide or planner
    stepsLabel.Text=planner and "RESETS" or "COUNT";offsetLabel.Text=planner and "SECONDS" or "FROM RC"
    zoom.Visible=false;seed.Visible=true;copyExplore.Visible=explore
    seed.Parent=advancedPanel
    seed.Position=UDim2.fromOffset(10,103)
    seed.Size=UDim2.fromOffset(215,21)
    itemsToggle.Visible=not state.showItems
    if state.tab=="SINGLE" then chainLabel.Text="Choose wax/count → ADD or START" end
    resetFirst.Visible=true
    resetFirst.Text=(state.resetFirst and "●" or "○").." Reset before search"
    resetFirst.BackgroundColor3=state.resetFirst and C.active or C.panel
    turpPreview.Text=(state.resetFirst and "●" or "○").." After Turp"
    turpPreview.BackgroundColor3=state.resetFirst and C.active or C.panel
    turpPreview.Position=UDim2.fromOffset(state.source=="Trade" and 350 or 210,state.source=="Trade" and 7 or 77)
    turpPreview.Size=UDim2.fromOffset(state.source=="Trade" and 145 or 145,23)
    advancedPanel.Visible=state.advanced
    advancedButton.BackgroundColor3=state.advanced and C.active or C.button
    local baseValue=tonumber(baseOffsetInput.Text) or 0
    local remaining=remainingSlots()
    local added=state.tab=="BATCH" and #state.chain or state.tab=="EXPLORE" and 1 or tonumber(skip.Text) or 1
    if state.tab~="BATCH" and state.tab~="GUIDE" and not planner then
        skip.Text=tostring(math.clamp(tonumber(skip.Text) or 1,1,math.max(1,remaining)))
        added=state.tab=="EXPLORE" and 1 or tonumber(skip.Text)
    end
    planningSummary.Text="RC "..((selected() and selected().Data.RC) or 0).." · "..(state.resetFirst and "Reset " or "Keep ")..(5-remaining).."/5 → "..(5-remaining+added).."/5"
    planningSummary.TextColor3=state.resetFirst and C.green or C.muted
    wax.Visible=not planner;waxCaption.Visible=not planner
    turpPreview.Visible=not planner
    skipTrack.Visible=not guide and not planner;skipPrev.Visible=skipTrack.Visible;skip.Visible=skipTrack.Visible;skipNext.Visible=skipTrack.Visible
    window.WaxQuantityCaption.Visible=not guide and not planner
    filterHeading.Text=(explore or planner) and "TARGETS (ALL)" or "IMPROVEMENTS (ANY)"
    middle.Visible=not guide
    right.Position=UDim2.fromOffset(guide and 205 or 370,106)
    right.Size=UDim2.fromOffset(guide and 385 or 220,280)
    resultScroll.Size=UDim2.fromOffset(guide and 366 or 201,244)
    resultText.Size=UDim2.fromOffset(guide and 356 or 191,resultText.Size.Y.Offset)
    if guide then chainLabel.Visible=false;planningSummary.Text="Current RC: "..((selected() and selected().Data.RC) or 0) end
    if not state.busy then start.Text=planner and "FIND BEST" or guide and "SHOW" or "START" end
    if explore then
        copyExplore.Position=UDim2.fromOffset(214,416);copyExplore.Size=UDim2.fromOffset(100,22)
    end
    if batch then chainLabel.Text="CHAIN: "..(#state.chain>0 and table.concat(state.chain, " > ") or "ADD waxes to begin") end
    baseButton.Text=(state.showBase and not state.resetFirst and "●" or "○").."  Show base"
    seed.Text=explore and ((state.currentSeed and "●" or "○").." Use swirled seed") or (state.currentSeed and "● Current / swirled seed" or "○ Original seed")
    wax.Text=state.wax;resultHeading.Text=planner and "BEST TARGET PLANS" or guide and "OFFSETS + HIVE BONUSES" or explore and "NEXT WAX OUTCOMES" or "MATCHED RESULTS"
    tabs.EXPLORE.Text="NEXT WAX";tabs.EXPLORE.TextSize=8
    waxCaption.Text="WAX"
    local tradeLayout=state.source=="Trade"
    source.Size=UDim2.fromOffset(tradeLayout and 82 or 110,23)
    prev.Visible=not tradeLayout;nextButton.Visible=not tradeLayout;itemTrack.Visible=not tradeLayout
    itemButton.Position=UDim2.fromOffset(tradeLayout and 97 or 154,45)
    itemButton.Size=UDim2.fromOffset(tradeLayout and 25 or 72,23)
    if tradeLayout then itemButton.Text="▾" end
    baseButton.Position=UDim2.fromOffset(tradeLayout and 125 or 520,45)
    wax.Position=UDim2.fromOffset(tradeLayout and 350 or 270,45)
    waxCaption.Position=UDim2.fromOffset(tradeLayout and 395 or 315,31)
    skipTrack.Position=UDim2.fromOffset(tradeLayout and 470 or 390,45)
    skipPrev.Position=UDim2.fromOffset(tradeLayout and 470 or 390,45)
    skip.Position=UDim2.fromOffset(tradeLayout and 494 or 414,45)
    skipNext.Position=UDim2.fromOffset(tradeLayout and 566 or 486,45)
    for i,name in ipairs({"SINGLE","BATCH","EXPLORE"}) do
        tabs[name].Position=UDim2.fromOffset(tradeLayout and (10+(i-1)*195) or (10+(i-1)*65),75)
        tabs[name].Size=UDim2.fromOffset(tradeLayout and 190 or 60,25)
    end
    planningSummary.Visible=not tradeLayout
    left.Size=UDim2.fromOffset(190,explore and 280 or 330)
end
local function copyText(text)
    if type(setclipboard)=="function" then local ok,err=pcall(setclipboard,text);notify(ok and "Copied to clipboard." or tostring(err))
    else notify("Clipboard unavailable in this executor.") end
end
local function changed() state.chain={};popup.Visible=false;selector.Visible=false;state.advanced=false;advancedPanel.Visible=false;refreshCurrent();refreshFilters();redraw();setResults("Choose filters or press START.") end
local renderedItems,renderedCount
renderInventory=function()
    if renderedItems==state.items and renderedCount==#state.items then
        for index in ipairs(state.items) do
            local card=inventoryScroll:FindFirstChild("BeequipCard"..index)
            if card then
                card.BackgroundColor3=index==state.index and Color3.fromRGB(39,47,37) or Color3.fromRGB(37,39,37)
                local border=card:FindFirstChildOfClass("UIStroke")
                if border then border.Transparency=index==state.index and .05 or 1 end
            end
        end
        return
    end
    renderedItems=state.items;renderedCount=#state.items
    for _,c in ipairs(cardConnections) do c:Disconnect() end
    cardConnections={}
    local oldPosition=inventoryScroll.CanvasPosition
    for _,v in ipairs(inventoryScroll:GetChildren()) do v:Destroy() end
    inventoryHeading.Text="BEEQUIPS | "..state.source.." ("..#state.items..")"
    if #state.items==0 then label(inventoryScroll,"Empty","No Beequips in this source.",8,8,229,45,11,C.muted) end
    for index,item in ipairs(state.items) do
        local data=item.Data
        local card=button(inventoryScroll,"BeequipCard"..index,"",1,(index-1)*75+2,242,69)
        card.BackgroundColor3=index==state.index and Color3.fromRGB(39,47,37) or Color3.fromRGB(37,39,37)
        local border=make("UIStroke",card,{Color=C.green,Thickness=1,Transparency=index==state.index and .05 or 1})
        local iconBox=make("Frame",card,{Name="IconBox",Position=UDim2.fromOffset(5,5),Size=UDim2.fromOffset(54,59),
            BackgroundColor3=Color3.fromRGB(28,30,28),BorderSizePixel=0});round(iconBox,6)
        local definition=Types.Get(data.T)
        local image=definition and definition.Icon
        make("ImageLabel",iconBox,{Name="ItemImage",Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(50,55),
            BackgroundTransparency=1,Image=type(image)=="string" and image or "",ScaleType=Enum.ScaleType.Fit})
        if type(image)~="string" or image=="" then
            local fallback=label(iconBox,"Fallback",data.T:sub(1,2):upper(),0,0,58,62,18,C.green)
            fallback.TextXAlignment=Enum.TextXAlignment.Center
        end
        local name=label(card,"ItemName",data.T,66,5,170,17,11)
        name.Font=Enum.Font.GothamBold;name.TextTruncate=Enum.TextTruncate.AtEnd
        label(card,"Potential",string.format("%.2f potential",data.Q*5),66,22,170,15,9,C.muted)
        local history=data.W or {}
        for slot=1,5 do
            local w=history[slot]
            local box=make("Frame",card,{Name="WaxSlot"..slot,Position=UDim2.fromOffset(66+(slot-1)*24,39),
                Size=UDim2.fromOffset(22,22),BackgroundColor3=Color3.fromRGB(43,45,43),BorderSizePixel=0});round(box,4)
            if w then
                local waxDef=WaxTypes.TypeByID[w[1]]
                make("ImageLabel",box,{Name="WaxImage",Position=UDim2.fromOffset(1,1),Size=UDim2.fromOffset(21,21),
                    BackgroundTransparency=1,Image=waxDef and waxDef.Icon or "",ScaleType=Enum.ScaleType.Fit,
                    ImageTransparency=w[2] and 0 or .6})
                if not w[2] then
                    local mark=label(box,"Failed","×",0,0,23,23,16,C.red);mark.TextXAlignment=Enum.TextXAlignment.Center
                end
            end
        end
        local count=label(card,"WaxCount","",211,45,24,18,8,C.muted)
        count.TextXAlignment=Enum.TextXAlignment.Right
        cardConnections[#cardConnections+1]=card.Activated:Connect(function()
            if editable() then state.index=index;changed() end
        end)
    end
    inventoryScroll.CanvasSize=UDim2.fromOffset(0,#state.items*75+4)
    inventoryScroll.CanvasPosition=oldPosition
end
local function toggleInventory()
    state.showItems=not state.showItems;inventoryPanel.Visible=state.showItems;resize();redraw()
end
connect(itemsToggle.Activated,toggleInventory)
connect(hideItems.Activated,toggleInventory)
local function openSelector(kind,x,width,entries,choose)
    popup.Visible=false;state.advanced=false;advancedPanel.Visible=false
    if selector.Visible and selector:GetAttribute("Kind")==kind then selector.Visible=false;return end
    for _,v in ipairs(selector:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end
    selector:SetAttribute("Kind",kind);selector.Position=UDim2.fromOffset(x,72)
    selector.Size=UDim2.fromOffset(width,math.min(190,#entries*28+8));selector.Visible=true
    for i,entry in ipairs(entries) do
        local b=button(selector,kind.."Option"..i,entry,4,4+(i-1)*28,width-8,25)
        b.ZIndex=11
        connect(b.Activated,function() if not editable() then return end;selector.Visible=false;choose(entry) end)
    end
    selector.CanvasSize=UDim2.fromOffset(0,#entries*28+8)
end
connect(source.Activated,function()
    if not editable() then return end
    openSelector("Source",10,140,{"Storage","Case","Inbox","Trade","Import"},function(entry)
        state.source=entry;state.index=1;state.chain={};reloadItems();redraw();setResults("Choose filters or press START.")
    end)
end)
connect(prev.Activated,function()if editable() and #state.items>0 then state.index=(state.index-2)%#state.items+1;changed() end end)
connect(nextButton.Activated,function()if editable() and #state.items>0 then state.index=state.index%#state.items+1;changed() end end)
connect(itemButton.Activated,function()
    if not editable() then return end
    selector.Visible=false
    popup.Visible=not popup.Visible
    for _,v in ipairs(popup:GetChildren()) do if v:IsA("GuiObject") then v:Destroy() end end
    for i,item in ipairs(state.items) do
        local b=button(popup,"Pick"..i,tostring(i).." · "..item.Data.T.." · W "..#(item.Data.W or {}).."/5",5,(i-1)*28+5,266,25)
        b.ZIndex=9;connect(b.Activated,function()if editable() then state.index=i;changed() end end)
    end
    popup.CanvasSize=UDim2.fromOffset(0,#state.items*28+10)
end)
local showPlan
connect(wax.Activated,function()
    if not editable() then return end
    openSelector("Wax",state.source=="Trade" and 350 or 270,180,{"SoftWax","HardWax","CausticWax","DebugWax"},function(entry)state.wax=entry;redraw();if showPlan then showPlan() end end)
end)
connect(skipPrev.Activated,function()if editable() then skip.Text=tostring(((tonumber(skip.Text) or 1)-2)%math.max(1,remainingSlots())+1);redraw();if showPlan then showPlan()end end end)
connect(skipNext.Activated,function()if editable() then skip.Text=tostring((tonumber(skip.Text) or 1)%math.max(1,remainingSlots())+1);redraw();if showPlan then showPlan()end end end)
connect(baseButton.Activated,function()if editable() then state.showBase=not state.showBase;if state.showBase then state.resetFirst=false end;refreshCurrent();redraw() end end)
connect(seed.Activated,function()if editable() then state.currentSeed=not state.currentSeed;refreshCurrent();redraw() end end)
for name,b in pairs(tabs) do connect(b.Activated,function()if editable() then state.tab=name;if name=="PLAN" then steps.Text="1";offset.Text="90" end;if name=="SINGLE" then state.chain={} end;if name=="GUIDE" then local item=selected();offset.Text=tostring(item and (item.Data.UC or item.Data.RC) or 0);steps.Text="16" elseif name=="EXPLORE" then steps.Text="32";offset.Text="0" end;state.advanced=false;popup.Visible=false;selector.Visible=false;redraw() end end) end
local function risk(chain)
    local success,survival=1,1
    for _,name in ipairs(chain) do
        local wax=WaxTypes.Get(name:gsub("Wax$",""))
        success*=wax.SuccessRate or 1
        if wax.DestroyOnFail then survival*=wax.SuccessRate or 1 end
    end
    return success,survival
end
showPlan=function()
    local chain={}
    for _,name in ipairs(state.chain)do chain[#chain+1]=name end
    if #chain==0 then for _=1,math.clamp(math.floor(tonumber(skip.Text) or 1),1,5)do chain[#chain+1]=state.wax end end
    local success,survival=risk(chain)
    setResults("YOUR WAX PLAN\n"..table.concat(chain," → ").."\n\n"..
        string.format("All waxes succeed: %.4g%%\nBeequip destroyed: %.4g%%",success*100,(1-survival)*100)..
        "\n\nResults assume all planned waxes succeed. Hard failures can leave a surviving item with different stats."..
        "\n\nSelect improvements to measure, or START to see all outcomes.\nNo real wax is used.")
end
connect(skip.FocusLost,function()if editable()then redraw();showPlan()end end)
connect(add.Activated,function()if editable() then
    local quantity=tonumber(skip.Text)
    if not quantity or quantity%1~=0 or quantity<1 or quantity>5 then notify("Wax quantity must be 1–5.");return end
    if #state.chain+quantity>remainingSlots() then notify("Plan has "..#state.chain.." wax(es); "..remainingSlots().." slots free. Use REM/CLR, or After Turp for a 5/5 item.");return end
    for _=1,quantity do state.chain[#state.chain+1]=state.wax end
    state.tab="BATCH";redraw();showPlan();notify("Added "..quantity.." "..state.wax.." · "..#state.chain.." planned wax(es)") end end)
connect(remove.Activated,function()if editable() then table.remove(state.chain);redraw();showPlan() end end)
connect(clear.Activated,function()if editable() then state.chain={};redraw();showPlan() end end)
connect(copy.Activated,function()copyText(state.result)end)
connect(copyExplore.Activated,function()copyText(state.result)end)
connect(copyData.Activated,function()local item=selected();if item then copyText(Http:JSONEncode(item.Data)) end end)
connect(viewStats.Activated,function()
    if not editable() then return end
    local item=selected();if not item then notify("Choose a Beequip first.");return end
    local ok,result=pcall(E.Evaluate,item.Data)
    if not ok then notify(tostring(result));return end
    state.tab="SINGLE";state.showBase=false;popup.Visible=false;selector.Visible=false
    redraw();refreshCurrent()
    local history={}
    for _,w in ipairs(result.WaxHistory) do history[#history+1]=tostring(w[1])..(w[2] and " success" or " failed")..(w[3] and " · skip "..w[3] or "") end
    setResults("CURRENT ITEM · W: "..#result.WaxHistory.."/5\n"..item.Data.T.."\n\n"..describe(result)
        .."\n\nExisting wax effects are included.\n"..table.concat(history,"\n"))
    notify("Showing the item's actual stored wax history; no future waxes simulated.")
end)
connect(import.Activated,function()
    if not editable() then return end
    local ok,data=pcall(Http.JSONDecode,Http,paste.Text)
    if not ok or type(data)~="table" then notify("Invalid item JSON.");return end
    local valid,err=pcall(E.Evaluate,data)
    if not valid then notify(tostring(err));return end
    state.imported=data;state.source="Import";state.index=1;reloadItems();notify("Imported detached item data.")
end)
connect(zoom.Activated,function()
    if not editable() then return end
    local item=selected();if not item then return end
    local n=tonumber(offset.Text)
    if not n or n%1~=0 or n<0 or n>100000 then notify("Offset must be an integer from 0 to 100000.");return end
    local opts=options();opts.ShowBase=true;opts.ResetWaxes=false;opts.BaseOffset=n
    local ok,s=pcall(E.Evaluate,item.Data,opts)
    if not ok then notify(tostring(s));return end
    state.imported={T=item.Data.T,Q=item.Data.Q,S=s.Seed,OS=item.Data.OS,RC=0,PredictorBaseOffset=n}
    state.source="Import";state.index=1;state.showBase=false;baseOffsetInput.Text=tostring(n);reloadItems();redraw()
    notify("Zoomed copy: unwaxed, base RNG skip "..n..". Original item unchanged.")
end)
local function toggleTurpPreview()
    if not editable() then return end
    state.resetFirst=not state.resetFirst
    if state.resetFirst then state.showBase=false end
    refreshCurrent();redraw()
    notify(state.resetFirst and "Turpentine preview: waxes removed, original seed, reset offset. Real item unchanged." or "Showing current item with existing waxes.")
end
connect(resetFirst.Activated,toggleTurpPreview)
connect(turpPreview.Activated,toggleTurpPreview)
connect(baseOffsetInput.FocusLost,function()
    if editable() then refreshCurrent();redraw() end
end)
connect(advancedButton.Activated,function()if editable() then state.advanced=not state.advanced;popup.Visible=false;selector.Visible=false;redraw() end end)
connect(optionsClose.Activated,function()state.advanced=false;redraw()end)
connect(help.Activated,function()
    if not editable() then return end
    setResults("HOW TO USE\n\n1. Select a Beequip. Existing waxes stay in the simulation.\n2. Choose wax + quantity; ADD makes a mixed plan. REM undoes one; CLR starts over.\n3. Pick the stats you care about, then START. Selecting targets can make large exact searches much faster.\n\nNEXT WAX\nShows all 32 possible successful rolls for one extra wax. You cannot choose which roll the game gives you.\n\nAFTER TURP\nPreview the copied item with waxes removed and its reset seed/offset. Toggle off to return to the real current stats. Your item is unchanged.\n\nCHANCES\nOutcome percentages assume all planned waxes succeed. The results also show all-wax success, success plus target, and destruction risk. Failed Hard waxes can leave a surviving item with other results.\n\nAUTO PLAN\nSelect the target filters, then ··· → FIND BEST WAX PLAN. Set the reset limit and seconds budget. It compares exact completed plans and ranks target-plus-survival chance.\n\nHIVE BONUSES\nUnder ···: compare possible hive bonuses at reset-offset scenarios. These are simulations, not guaranteed resource routes.\n\nLong search? STOP is always available. No real waxes or items are used.")
end)
local function number(text,min,max,labelText)
    local n=tonumber(text);assert(n and n%1==0 and n>=min and n<=max,labelText.." must be "..min.."–"..max);return n
end
connect(start.Activated,function()
    if state.busy then state.cancelled=true;notify("Stopping…");return end
    local item=selected();if not item then notify("Choose or import a Beequip first.");return end
    if state.tab~="GUIDE" and state.tab~="PLAN" and remainingSlots()==0 then
        setResults("NO WAX SLOTS LEFT\n\nThis item already has five waxes. Turn on After Turp to preview a reset and predict additional waxes. Your real item stays unchanged.")
        notify("5/5 waxes · use After Turp for a reset preview")
        return
    end
    state.busy=true;state.cancelled=false;start.Text="STOP";popup.Visible=false;selector.Visible=false;state.advanced=false;advancedPanel.Visible=false
    local chosen={}
    for i,f in ipairs(filterDefs) do if state.filters[i] then chosen[#chosen+1]=f end end
    local opts=options()
    opts.Cancelled=function()return state.cancelled or not state.alive end
    local started=os.clock()
    local stage="Preparing exact search"
    local done,total=0,0
    state.job=(state.job or 0)+1
    local job=state.job
    progressTrack.Visible=true;progressFill.Size=UDim2.fromScale(0,1)
    opts.OnProgress=function(n,t)
        done=n;total=t
        progressFill.Size=UDim2.fromScale(math.clamp(n/math.max(1,t),0,1),1)
    end
    opts.OnStage=function(message)stage=message;notify(message)end
    setResults("Calculating exact outcomes…\nYou can STOP at any time.")
    task.spawn(function()
        while state.alive and state.busy and state.job==job do
            local elapsed=os.clock()-started
            local text=string.format("%s · %.0fs elapsed",stage,elapsed)
            if total>0 and state.tab~="GUIDE" and state.tab~="PLAN" then text=string.format("%.1f%% counted · %.0fs elapsed",done/total*100,elapsed) end
            notify(text)
            if elapsed>=1 then
                local message="CALCULATING\n"..text.."\n\n"
                if total>0 and done>total*.01 and elapsed>2 and state.tab=="BATCH" then
                    local remaining=elapsed*(total-done)/done
                    message..=string.format("Estimated remaining: ~%.0fs (may change).\n\n",remaining)
                end
                message..="Four/five-wax chains can take much longer. Completed work is retained when switching to a lower-memory search.\n\nSTOP cancels without using any items."
                setResults(message)
            end
            task.wait(1)
        end
    end)
    task.spawn(function()
        local ok,err=xpcall(function()
            if state.tab=="SINGLE" or state.tab=="BATCH" then
                local chain={}
                if state.tab=="SINGLE" or #state.chain==0 then
                    for _=1,number(skip.Text,1,5,"Wax quantity") do chain[#chain+1]=state.wax end
                else
                    for _,name in ipairs(state.chain) do chain[#chain+1]=name end
                end
                assert(#chain>0,"Choose a wax and press ADD, then START")
                assert(#chain<=remainingSlots(),"Only "..remainingSlots().." additional wax slot(s) remain; remove waxes from the planned chain.")
                local hits={};for i=1,#chosen do hits[i]=0 end
                local function predicate(result,before,weight)
                    local any=#chosen==0
                    for i,f in ipairs(chosen) do
                        if statValue(result,f)>statValue(before,f)+1e-9 then hits[i]+=weight;any=true end
                    end
                    return any
                end
                local function group(result,before)
                    if #chosen==0 then return describe(result) end
                    local descriptions={}
                    for _,f in ipairs(chosen) do
                        if statValue(result,f)>statValue(before,f)+1e-9 then descriptions[#descriptions+1]=filterDescription(result,f) end
                    end
                    return table.concat(descriptions," | ")
                end
                if #chosen>0 then opts.Targets=chosen end
                local cacheKey=Http:JSONEncode({Data=item.Data,Chain=chain,Targets=chosen,
                    Reset=opts.ResetWaxes,Original=opts.UseOriginalSeed,BaseOffset=opts.BaseOffset})
                local cached=state.batchCache and state.batchCache.Key==cacheKey
                local report
                if cached then
                    report=state.batchCache.Report;hits=table.clone(state.batchCache.Hits)
                else
                    report=E.Batch(item.Data,chain,predicate,group,opts)
                    local bytes,groups=0,0
                    for key in pairs(report.Groups)do bytes+=#key;groups+=1;if bytes>2000000 or groups>5000 then break end end
                    state.batchCache=bytes<=2000000 and groups<=5000 and {Key=cacheKey,Report=report,Hits=table.clone(hits)} or nil
                end
                local currentOptions=options();currentOptions.ResetWaxes=false
                local current=E.Evaluate(item.Data,currentOptions)
                local function percent(count,total)
                    return (string.format("%.6f",count/total*100):gsub("0+$",""):gsub("%.$","")).."%"
                end
                local lines={"=== BATCH MATCHES ===","Wax Chain: "..table.concat(chain," > "),"Beequip: "..item.Data.T,"",
                    "Simulation: "..(state.resetFirst and "after simulated Turpentine reset" or "keep existing wax history"),
                    "Additional waxes: "..#chain.." · W: "..#report.Before.WaxHistory.."/5 → "..(#report.Before.WaxHistory+#chain).."/5",
                    "=== CURRENT STATS ===","","CUR | W: "..#current.WaxHistory.."/5"}
                local history={};local names={[1]="Soft",[2]="Hd",[3]="Cs",[4]="Swirled",[5]="Db"}
                for _,w in ipairs(current.WaxHistory) do history[#history+1]=(names[w[1]] or tostring(w[1]))..":"..(w[2] and tostring(w[3] or 0) or "Failed") end
                if #history>0 then lines[#lines+1]="("..table.concat(history,", ")..")" end
                lines[#lines+1]="-------------------------";lines[#lines+1]=""
                lines[#lines+1]="Artificial base skip: "..current.BaseOffset
                lines[#lines+1]="Reset skip (RC): "..current.TurpentineOffset
                lines[#lines+1]="After reset (absolute draw): "..current.OffsetAfterTurp
                lines[#lines+1]="Final RNG draw: "..current.CurrentOffset
                lines[#lines+1]="";lines[#lines+1]="-------------------------"
                lines[#lines+1]="Potential: "..string.format("%.3f",current.Quality*5)
                lines[#lines+1]="-------------------------";lines[#lines+1]=""
                for _,v in ipairs(current.Bee) do lines[#lines+1]="- "..beeDescription(v) end
                if #current.Abilities>0 then
                    lines[#lines+1]="";lines[#lines+1]="[ABIL]"
                    for _,v in ipairs(current.Abilities) do lines[#lines+1]="- Ability: "..v[1]..(v[2] and " (from Wax)" or "") end
                end
                if #current.Hive>0 then
                    lines[#lines+1]="";lines[#lines+1]="[HIVE]"
                    for _,v in ipairs(current.Hive) do lines[#lines+1]="- "..hiveDescription(v) end
                end
                lines[#lines+1]="";lines[#lines+1]="=== MATCHED PREDICTIONS ==="
                lines[#lines+1]="Total predicts --> "..report.Total
                lines[#lines+1]="Matched --> "..report.Matched.." ("..percent(report.Matched,report.Total)..")"
                local _,survival=risk(chain)
                lines[#lines+1]="All waxes succeed: "..percent(report.AllWaxesSuccessRate,1)
                lines[#lines+1]=(#chosen>0 and "All succeed + selected improvement: " or "All succeed + any outcome: ")..percent(report.SuccessAndMatchRate,1)
                lines[#lines+1]="Beequip destroyed: "..percent(1-survival,1)
                lines[#lines+1]=string.format("Exact results · %.2fs%s",report.Seconds,cached and " (reused)" or "")
                lines[#lines+1]="Percentages below assume all planned waxes succeed."
                lines[#lines+1]=""
                lines[#lines+1]="--- INDIVIDUAL CHANCES ---"
                for i,f in ipairs(chosen) do lines[#lines+1]=f.label..": "..percent(hits[i],report.Total) end
                if #chosen==0 then lines[#lines+1]="All outcomes" end
                lines[#lines+1]="--- COMBINATIONS ---"
                local groups={};for text,count in pairs(report.Groups) do groups[#groups+1]={text=text,count=count} end
                table.sort(groups,function(a,b)if a.count==b.count then return a.text<b.text end;return a.count>b.count end)
                for _,g in ipairs(groups) do
                    lines[#lines+1]="["..g.text.."]"
                    lines[#lines+1]="Found: "..g.count.." ("..percent(g.count,report.Total)..")"
                    lines[#lines+1]=""
                end
                setResults(table.concat(lines,"\n"))
            elseif state.tab=="PLAN" then
                assert(#chosen>0,"Select Token Link, another ability, or a hive/stat target first")
                local current=E.Evaluate(item.Data)
                local allAbilities=true
                for _,f in ipairs(chosen)do if f.kind~="Ability" or statValue(current,f)==0 then allAbilities=false end end
                if allAbilities then setResults("TARGET ALREADY PRESENT\nThe selected abilities are already on this item. No extra wax is needed.");return end
                local function matches(result,baseline)
                    for _,f in ipairs(chosen)do
                        if f.kind=="Ability" then
                            if statValue(result,f)<1 then return false end
                        elseif statValue(result,f)<=statValue(baseline,f)+1e-9 then return false end
                    end
                    return true
                end
                local function group(result)
                    local details={}
                    for _,f in ipairs(chosen)do details[#details+1]=filterDescription(result,f)end
                    return table.concat(details," | ")
                end
                opts.MaxResets=number(steps.Text,0,3,"Resets")
                opts.PlannerSeconds=number(offset.Text,1,600,"Seconds")
                local report=E.AutoPlan(item.Data,chosen,matches,group,opts)
                local function pct(n)return (string.format("%.6f",n*100):gsub("0+$",""):gsub("%.$","")).."%"end
                local names={};for _,f in ipairs(chosen)do names[#names+1]=f.label end
                local lines={"AUTOMATIC WAX PLANNER",item.Data.T,"Targets: "..table.concat(names," + "),"",
                    "Completed exact plans: "..report.Completed.." / "..report.Candidates,
                    report.Complete and "All candidates in this bounded search completed." or "Search stopped or time budget reached. Ranking includes completed plans only.",
                    "Best means target + surviving item, then fewer resources.",
                    "Starts from the current item. Every planned reset is counted.",""}
                if report.CausticRequired then lines[#lines+1]="A selected target requires Caustic upgrades; Soft/Hard cannot grant it directly.";lines[#lines+1]=""end
                if report.Rows[1] and report.Rows[1].TargetChance>0 then
                    lines[#lines+1]="BEST FOUND: "..table.concat(report.Rows[1].Steps," → ")
                else lines[#lines+1]="No target hit found in the completed plans. This does not prove it is impossible at later offsets or longer searches."end
                lines[#lines+1]=""
                local ranked=0
                for _,row in ipairs(report.Rows)do
                    if row.TargetChance<=0 or ranked>=12 then break end
                    ranked+=1
                    local i=ranked
                    lines[#lines+1]=i..". "..table.concat(row.Steps," → ")
                    lines[#lines+1]="Target + surviving item: "..pct(row.TargetChance)
                    lines[#lines+1]="Target if item survives: "..pct(row.ConditionalChance)
                    lines[#lines+1]="Destruction: "..pct(1-row.SurvivalChance)
                    lines[#lines+1]="RC "..row.ResetOffset.." · "..row.TurpentineCount.." Turpentine · "..row.WaxCount.." waxes total"
                    lines[#lines+1]=""
                end
                lines[#lines+1]="TARGET OUTCOMES BY RESET OFFSET"
                for _,row in ipairs(report.Offsets)do
                    lines[#lines+1]="RC "..row.ResetOffset.." · "..row.Kind.." · "..table.concat(row.Chain," > ")
                    lines[#lines+1]="Best completed target chance: "..pct(row.TargetChance)
                    local groups={};for text,chance in pairs(row.Groups)do groups[#groups+1]={Text=text,Chance=chance}end
                    table.sort(groups,function(a,b)if a.Chance==b.Chance then return a.Text<b.Text end;return a.Chance>b.Chance end)
                    for _,g in ipairs(groups)do
                        lines[#lines+1]=g.Text
                        lines[#lines+1]=pct(g.Chance).." including risk · "..pct(row.SurvivalChance>0 and g.Chance/row.SurvivalChance or 0).." if item survives"
                    end
                    lines[#lines+1]=""
                end
                if report.GroupedOverflow then lines[#lines+1]="Large outcome lists group overflow combinations under Other; their full probability is retained."end
                lines[#lines+1]="Search family: 0–"..report.MaxResets.." Soft/Turpentine resets; Soft setup followed by 1–5 Soft, Hard or Caustic waxes within remaining slots. Hard failures included."
                lines[#lines+1]="Fixed plans, not a guarantee of chosen skips or a global optimum over every mixed/adaptive strategy. More Soft is not always better."
                lines[#lines+1]="Reset routes use the recovered UC/RC model. Re-check the actual item after every wax/reset. No real items used."
                setResults(table.concat(lines,"\n"))
            elseif state.tab=="GUIDE" then
                local first=number(offset.Text,0,100000,"From RC")
                local count=number(steps.Text,1,64,"Offset count")
                local report=E.HiveOffsetOutcomes(item.Data,state.wax,first,count,opts)
                local lines={"OFFSETS + POSSIBLE HIVE BONUSES",item.Data.T.." · "..state.wax,
                    "Current RC: "..report.CurrentOffset,
                    "Each row predicts ONE additional successful wax.",
                    "Reset scenarios remove existing waxes and use the original seed.",""}
                for _,row in ipairs(report.Rows) do
                    lines[#lines+1]=(row.Kind=="Current" and "CURRENT ITEM · RC " or "RESET OFFSET ")..row.Offset
                    local groups={}
                    for _,branch in ipairs(row.Outcomes.Rows) do
                        local bonuses={}
                        for _,v in ipairs(branch.Result.Hive) do bonuses[#bonuses+1]=hiveDescription(v) end
                        table.sort(bonuses)
                        local text=#bonuses>0 and table.concat(bonuses,"\n") or "No hive bonuses"
                        local g=groups[text]
                        if not g then g={Text=text,Skips={},MinSkip=branch.Skip};groups[text]=g end
                        g.Skips[#g.Skips+1]=branch.Skip
                    end
                    local sorted={};for _,g in pairs(groups)do sorted[#sorted+1]=g end
                    table.sort(sorted,function(a,b)return a.MinSkip<b.MinSkip end)
                    for _,g in ipairs(sorted) do
                        local skips={};for _,n in ipairs(g.Skips)do skips[#skips+1]=tostring(n)end
                        lines[#lines+1]=g.Text
                        lines[#lines+1]="Wax skips: "..table.concat(skips,", ")
                        lines[#lines+1]=string.format("Chance: %.3f%% if successful · %.3f%% including wax success",#g.Skips/32*100,#g.Skips/32*row.Outcomes.WaxSuccessRate*100)
                        lines[#lines+1]=""
                    end
                end
                lines[#lines+1]="RC scenarios are not resource instructions. Reaching an RC needs a valid Soft/Turpentine route. Wax skip is random."
                setResults(table.concat(lines,"\n"))
            else
                local from=0
                local count=32
                local report=E.OffsetOutcomes(item.Data,state.wax,function(result,before)
                    for _,f in ipairs(chosen) do
                        if statValue(result,f)<=statValue(before,f)+1e-9 then return false end
                    end
                    return true
                end,opts)
                local matched=0
                for _,row in ipairs(report.Rows)do
                    row.Matched=row.Matched and row.Skip>from and row.Skip<=math.min(32,from+count)
                    if row.Matched then matched+=1 end
                end
                report.Matched=matched;report.ConditionalMatchRate=matched/32
                report.SuccessAndMatchRate=report.ConditionalMatchRate*report.WaxSuccessRate
                local function pct(v)return string.format("%.4f%%",v*100)end
                local lines={"NEXT WAX: WHAT COULD HAPPEN",state.wax,
                    "Matches: "..report.Matched.." / 32",
                    "Target if wax succeeds: "..pct(report.ConditionalMatchRate),
                    "Wax succeeds + target: "..pct(report.SuccessAndMatchRate),
                    "Reset skip (RC): "..report.Before.TurpentineOffset,
                    "Showing skips "..(from+1).."–"..math.min(32,from+count).." (32 possible overall).",""}
                for _,row in ipairs(report.Rows) do
                    if row.Matched then
                        local result=row.Result
                        local trace=result.OffsetTrace
                        local w=trace.Waxes[#trace.Waxes]
                        lines[#lines+1]="POSSIBLE ROLL "..row.Skip.." · offset "..row.FinalOffset
                        if w then
                            lines[#lines+1]="Before skip "..w.Start.." → after skip "..w.AfterSkip.." → after wax rolls "..w.Finish
                            lines[#lines+1]="Upgrade-ability draws after wax: "..(trace.Final-trace.AfterWaxRolls)
                        end
                        lines[#lines+1]="This branch: 1/32 if successful; "..pct(row.SuccessAndBranchProbability).." including success."
                        lines[#lines+1]=describe(result).."\n"
                    end
                end
                lines[#lines+1]="The same final draw can have different stats. Seed, RC and full wax history determine the result."
                lines[#lines+1]="Wax skips are random, not controllable offsets. These chances describe this attempt, not repeated-retry odds."
                setResults(table.concat(lines,"\n"))
            end
        end,function(e)return tostring(e)end)
        state.busy=false
        if state.alive then
            start.Text=state.tab=="PLAN" and "FIND BEST" or state.tab=="GUIDE" and "SHOW" or "START"
            progressTrack.Visible=false
            if not ok then
                if state.cancelled then setResults("SEARCH STOPPED\n\nYour items are unchanged. Try fewer waxes for a faster exact result.")
                else setResults("SEARCH INCOMPLETE\n"..err.."\n\nTry a shorter chain. No partial probabilities are shown.") end
            end
            notify(ok and string.format("Finished · %.1fs · simulation only",os.clock()-started) or state.cancelled and "Stopped · your items are unchanged" or err)
        end
    end)
end)
local dragging=false;local dragOrigin;local windowOrigin
connect(title.InputBegan,function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
    dragging=true;dragOrigin=i.Position;windowOrigin=window.Position end end)
connect(UIS.InputChanged,function(i)if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
    local d=i.Position-dragOrigin;window.Position=windowOrigin+UDim2.fromOffset(d.X,d.Y) end end)
connect(UIS.InputEnded,function(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
local minimized=false
connect(minimize.Activated,function()
    minimized=not minimized
    for _,child in ipairs(window:GetChildren()) do
        if child:IsA("GuiObject") and child~=title and child~=minimize and child~=close then child.Visible=not minimized end
    end
    window.Size=UDim2.fromOffset(600,minimized and 34 or 450)
    if not minimized then popup.Visible=false;selector.Visible=false;redraw() end
    inventoryPanel.Visible=state.showItems and not minimized
end)
local function destroy()
    state.alive=false;state.cancelled=true
    for _,c in ipairs(connections) do c:Disconnect() end
    for _,c in ipairs(cardConnections) do c:Disconnect() end
    gui:Destroy()
end
connect(close.Activated,destroy)
getgenv().TifaPredictorUI={Destroy=destroy,GetReport=function()return state.result end}
-- Observe native inspectors without replacing game functions or changing inventory.
local function selectNative(file,location)
    if state.busy or type(file)~="table" or not file.T then return end
    local data={T=file.T,Q=file.Q,S=file.S,OS=file.OS,RC=file.RC,UC=file.UC,W={}}
    for i,w in ipairs(file.W or {}) do data.W[i]=table.clone(w) end
    local function same(a,b) return a.T==b.T and a.S==b.S and a.Q==b.Q end
    state.source=location;state.index=1
    if location=="Trade" then state.tradeItems={{Location="Trade",Index=1,Data=data}} end
    reloadItems()
    local found=false
    for i,item in ipairs(state.items) do if same(item.Data,data) then state.index=i;found=true;break end end
    if not found then state.items[#state.items+1]={Location=location,Index=#state.items+1,Data=data};state.index=#state.items end
    changed();redraw();notify("Selected from "..location..": "..data.T)
end
local managerOK,manager=pcall(require,RS.Gui.BeequipMenus.BeequipMenuManager)
local tradeOK,trade=pcall(require,RS.Gui.TradeGui)
local observed={}
local function fileStamp(file)
    if type(file)~="table" then return "" end
    local parts={tostring(file.T),tostring(file.S),tostring(file.OS),tostring(file.Q),tostring(file.UC),tostring(file.RC)}
    for _,w in ipairs(file.W or {})do parts[#parts+1]=tostring(w[1])..":"..tostring(w[2])..":"..tostring(w[3])end
    return table.concat(parts,"|")
end
task.spawn(function()
    while state.alive do
        pcall(function()
            if managerOK then
                for _,location in ipairs({"Case","Storage","Inbox"}) do
                    local menu=manager.GetByName("Beequip "..location)
                    local file=menu and menu.BeequipInspector and menu.BeequipInspector.BeequipFile
                    local stamp=fileStamp(file)
                    if not state.busy and (observed[location]~=file or observed[location.."Stamp"]~=stamp) then
                        observed[location]=file;observed[location.."Stamp"]=stamp
                        if file then selectNative(file,location) end
                    end
                end
            end
            if tradeOK then
                local inspector=trade.GetItemInspector()
                local item=inspector and inspector.Tradable
                local pack=item and item.Pack
                local stamp=fileStamp(pack and pack.File)
                if not state.busy and (observed.Trade~=item or observed.TradeStamp~=stamp) then
                    observed.Trade=item;observed.TradeStamp=stamp
                    if pack and pack.Category=="Beequip" then selectNative(pack.File,"Trade") end
                end
            end
        end)
        task.wait(0.15)
    end
end)
reloadItems();redraw()
return "Predictor GUI ready"
