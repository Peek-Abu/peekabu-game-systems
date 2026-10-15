-- Supplemental source probe only: deterministic substitute RNG, not native TestEZ/Studio certification.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local root="src/"
local tree={}
local function node(path)
 local at=tree
 for segment in string.gmatch(path,"[^/]+") do
  if at[segment]==nil then at[segment]={Parent=at} end
  at=at[segment]
 end
 return at
end
local function scan(path)
 for _,name in fs.readDir(root..path) do
  local full=root..path..name
  if fs.isDir(full) then scan(path..name.."/")
  elseif string.sub(name,-5)==".luau" then
   local module=node(path..string.sub(name,1,-6))
   module.path=full
  end
 end
end
scan("")
local Random={}
function Random.new(seed)
 local state=(math.abs(seed)%2147483646)+1
 local object={}
 function object:NextNumber()
  state=(state*48271)%2147483647
  return state/2147483647
 end
 function object:NextInteger(a,b) return a+math.floor(self:NextNumber()*(b-a+1)) end
 return object
end
local cache={}
local loadModule
local failures,total={},0
local function expect(actual)
 local result={}
 result.to={equal=function(expected) assert(actual==expected,`expected {tostring(expected)} got {tostring(actual)}`) end}
 result.to.never={equal=function(expected) assert(actual~=expected,`unexpected {tostring(expected)}`) end}
 return result
end
local env={}
env.task=require("@lune/task")
for key,value in getfenv() do env[key]=value end
for key,value in roblox do env[key]=value end
local game={}
function game:GetService(name) return tree[name] end
loadModule=function(module)
 if cache[module]~=nil then return cache[module] end
 local moduleEnv=table.clone(env)
 moduleEnv.game=game
 moduleEnv.script=module
 moduleEnv.Random=Random
 moduleEnv.require=loadModule
 moduleEnv.describe=function(_,fn) fn() end
 moduleEnv.it=function(name,fn)
  total+=1
  local ok,err=pcall(fn)
  if not ok then table.insert(failures,name..": "..tostring(err)) end
 end
 moduleEnv.expect=expect
 local loaded=luau.load(fs.readFile(module.path),{debugName=module.path,environment=moduleEnv})()
 cache[module]=loaded
 return loaded
end
for _,path in {"ServerScriptService/Features/Office/Rules/OfficeLayoutGraphRules.spec","ServerScriptService/Features/Office/Utils/OfficeLayoutRoomUtils.spec","ServerScriptService/Features/Office/Utils/OfficeLayoutGenerationUtils.spec"} do
 loadModule(node(path))()
end
for _,failure in failures do print(failure) end
print(`Supplemental source specs: {total-#failures}/{total} passed (substitute RNG)`)
assert(#failures==0,"source probe failed")
