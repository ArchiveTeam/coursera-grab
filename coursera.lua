dofile("urlcode.lua")
dofile("table_show.lua")
JSON = (loadfile "JSON.lua")()

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')

local downloaded = {}
local addedtolist = {}

local abortgrab = false

load_json_file = function(file)
  if file then
    return JSON:decode(file)
  else
    return nil
  end
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if (downloaded[url] ~= true and addedtolist[url] ~= true) and ((string.match(url, "^https?://[^/]*coursera%.org/") and string.match(url, "[^a-zA-Z]"..item_value) and not string.match(url, "[^a-zA-Z]"..item_value.."[a-zA-Z]")) or html == 0 or string.match(url, "/maestro/") or string.match(url, "^https?://[^/]*cloudfront%.net") or string.match(url, "^https?://[^/]*amazonaws%.com")) then
    addedtolist[url] = true
    return true
  else
    return false
  end
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true
  
  local function check(urla)
    --local url = string.gsub(string.match(urla, "^([^#]+)"),"^https?://", "http://")
    local url = string.match(urla, "^([^#]+)")
    if string.match(url, "^https?://.*//") then
      check(string.match(url, "^(https?://)")..string.gsub(string.match(url, "^https?://(.+)"), "//", "/"))
    end
    local url = string.gsub(url, "\\", "")
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and ((string.match(url, "^https?://[^/]*coursera%.org/") and string.match(url, "[^a-zA-Z]"..item_value) and not string.match(url, "[^a-zA-Z]"..item_value.."[a-zA-Z]")) or string.match(url, "/maestro/") or string.match(url, "^https?://[^/]*cloudfront%.net") or string.match(url, "^https?://[^/]*amazonaws%.com")) then
      if string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end

  if string.match(url, "^https?://class%.coursera%.org/"..item_value.."[^/]+") then
    local classname = string.match(url, "^https?://class%.coursera%.org/([^/]+)")
    check("https://class.coursera.org/"..classname.."/api/forum/forums/0")
    check("https://class.coursera.org/"..classname.."/forum/list?forum_id=0")
    check("https://class.coursera.org/"..classname.."/api/forum/forums/0/threads?sort=subscribed&page=1&page_size=25")
    check("https://class.coursera.org/"..classname.."/api/forum/forums/0/threads?sort=lastupdated&page=1&page_size=25")
    check("https://class.coursera.org/"..classname.."/api/forum/forums/0/threads?sort=subscribed")
    check("https://class.coursera.org/"..classname.."/api/forum/forums/0/threads?sort=lastupdated")
    check("https://class.coursera.org/"..classname.."/api/forum/forums/0/threads?sort=null")
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^https?:\\/\\/") then
      check(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^//") then
      check("http:"..newurl)
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^(https?://[^/]+)")..newurl)
    end
  end

  local function checknewshorturl(newurl)
    if string.match(newurl, "^%?") then
      check(string.match(url, "^(https?://[^%?]+)")..newurl)
    elseif not (string.match(newurl, "^https?://") or string.match(newurl, "^/") or string.match(newurl, "^[jJ]ava[sS]cript:") or string.match(newurl, "^[mM]ail[tT]o:") or string.match(newurl, "^%${")) then
      check(string.match(url, "^(https?://.+/)")..newurl)
    end
  end
  
  if string.match(url, "^https?://[^/]*coursera%.org/") and string.match(url, "[^a-zA-Z]"..item_value) and not string.match(url, "[^a-zA-Z]"..item_value.."[a-zA-Z]") then
    html = read_file(file)
    html = string.gsub(html, '\\u002F', '/')
    html = string.gsub(html, '\\u003C', '<')
    html = string.gsub(html, '\\u003E', '>')
    if string.match(html, "the%s+class%s+you%s+were%s+looking%s+for%s+cannot%s+be%s+found") then
      abortgrab = true
    end
    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">([^<]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "%(([^%)]+)%)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, 'href="([^"]+)"') do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, '\\"([^"]+)\\"') do
      newurl = string.gsub(newurl, "\\", "")
      checknewurl(newurl)
    end
    for urldata in string.gmatch(html, '{(%s*\\"[^{}]+\\"%s*)}') do
      if string.match(urldata, "link_data") then
        link_data = string.gsub(string.match(urldata, '\\"link_data\\"%s*:%s*\\"([^"]*)\\"'), ":", "/")
        local classname = string.match(url, "^https?://class%.coursera%.org/([^/]+)")
        check("https://class.coursera.org/"..classname.."/"..link_data)
        if string.match(urldata, "link_type") then
          link_type = string.gsub(string.match(urldata, '\\"link_type\\"%s*:%s*\\"([^"]*)\\"'), ":", "/")
          check("https://class.coursera.org/"..classname.."/"..link_type.."/"..link_data)
        end
      end
    end
    if string.match(url, "forum_id=[0-9]+") then
      local forum_id = string.match(url, "forum_id=([0-9]+)")
      local classname = string.match(url, "^https?://class%.coursera%.org/"..item_value.."([^/]*)")
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/forums/"..forum_id)
      check("https://class.coursera.org/"..item_value..classname.."/forum/list?forum_id="..forum_id)
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/forums/"..forum_id.."/threads?sort=subscribed&page=1&page_size=25")
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/forums/"..forum_id.."/threads?sort=lastupdated&page=1&page_size=25")
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/forums/"..forum_id.."/threads?sort=subscribed")
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/forums/"..forum_id.."/threads?sort=lastupdated")
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/forums/"..forum_id.."/threads?sort=null")
    end
    if string.match(url, "thread_id=[0-9]+") then
      local thread_id = string.match(url, "thread_id=([0-9]+)")
      local classname = string.match(url, "^https?://class%.coursera%.org/"..item_value.."([^/]*)")
      check("https://class.coursera.org/"..item_value..classname.."/forum/thread?thread_id="..thread_id)
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/threads/"..thread_id.."?sort=null")
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/threads/"..thread_id)
      check("https://class.coursera.org/"..item_value..classname.."/forum/thread?thread_id="..thread_id.."&sort=oldest")
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/threads/"..thread_id.."?sort=oldest")
      check("https://class.coursera.org/"..item_value..classname.."/forum/thread?thread_id="..thread_id.."&sort=newest")
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/threads/"..thread_id.."?sort=newest")
      check("https://class.coursera.org/"..item_value..classname.."/forum/thread?thread_id="..thread_id.."&sort=popular")
      check("https://class.coursera.org/"..item_value..classname.."/api/forum/threads/"..thread_id.."?sort=popular")
    end
    if string.match(url, "user_id=[0-9]+") then
      local user_id = string.match(url, "user_id=([0-9]+)")
      local classname = string.match(url, "^https?://class%.coursera%.org/"..item_value.."([^/]*)")
      check("https://class.coursera.org/"..item_value..classname.."/forum/profile?user_id="..user_id)
      check("https://class.coursera.org/"..item_value..classname.."/api/user/information/"..user_id)
      check("https://class.coursera.org/"..item_value..classname.."/api/user/information/"..user_id.."/activities")
    end
    if string.match(url, "https://class.coursera.org/[^/]+/api/forum/forums/[0-9]+/threads") and string.match(url, "page=[0-9]+") then
      local json = load_json_file(html)
      local pages = json["max_pages"]
      while pages > 0 do
        check(string.gsub(url, "page=[0-9]+", "page="..pages))
        print(string.gsub(url, "page=[0-9]+", "page="..pages))
        pages = pages - 1
      end
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  --if downloaded[url["url"]] == true and status_code >= 200 and status_code < 400 then
  --  return wget.actions.EXIT
  --end

  if (status_code >= 200 and status_code < 400) then
    downloaded[url["url"]] = true
  end

  if abortgrab == true then
    return wget.actions.ABORT
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403 and status_code ~= 414) or
    status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    if status_code == 429 then
      os.execute("sleep 600")
    else
      os.execute("sleep 8")
    end
    tries = tries + 1
    if tries >= 10 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if err == "AUTHFAILED" or err == "RETRFINISHED" then
        return wget.actions.EXIT
      elseif (string.match(url["url"], "^https?://[^/]*coursera%.org/") and string.match(url["url"], "[^a-zA-Z]"..item_value) and not string.match(url["url"], "[^a-zA-Z]"..item_value.."[a-zA-Z]")) or string.match(url["url"], "^https?://[^/]*cloudfront%.net") or string.match(url["url"], "^https?://[^/]*amazonaws%.com") then
        return wget.actions.EXIT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end