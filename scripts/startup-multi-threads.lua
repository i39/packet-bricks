-- /usr/bin/lua
---------------------- STARTUP SCRIPT ---------------------------------





-----------------------------------------------------------------------
-- MACROS-&-UTILITY-FUNCS
-----------------------------------------------------------------------
STATS_PRINT_CYCLE_DEFAULT = 2
SLEEP_TIMEOUT = 1
PKT_BATCH=1024
NETMAP_LIN_PARAMS_PATH="/sys/module/netmap_lin/parameters/"
NETMAP_PIPES=64
NO_CPU_AFF=-1
NO_QIDS=-1
BUFFER_SZ=1024


--see if the directory exists

local function directory_exists(sPath)
      if type(sPath) ~= "string" then return false end

      local response = os.execute( "cd " .. sPath )
      if response == 0 then
      	 return true
      end
      return false
end



--sleep function __self-explanatory__

local clock = os.clock
function sleep(n)  -- seconds
	 local t0 = clock()
	 while clock() - t0 <= n do end
end



-- A neat function that reads shell output given a shell command `c'
function shell(c)
	 local o, h
	 h = assert(io.popen(c,"r"))
	 o = h:read("*all")
	 h:close()
	 return o
end


-- check if netmap module is loaded in the system

function netmap_loaded()
	 if string.find((tostring(shell('uname'))), 'Linux') ~= nil then
	    if directory_exists(NETMAP_LIN_PARAMS_PATH) then
	       return true
	    end
	 end
	 if string.find((tostring(shell('uname'), 'FreeBSD'))) ~= nil then
	    if (tostring(shell('sysctl -a --pattern netmap'))) ~= nil then
	       return true
	    end
	 end
	 return false
end


-- enable netmap pipes framework

function enable_nmpipes()
	if string.find((tostring(shell('uname'))), 'Linux') ~= nil then
	 	 shell("echo " .. tostring(NETMAP_PIPES) .. " > " .. NETMAP_LIN_PARAMS_PATH .. "default_pipes")
	end
	if string.find((tostring(shell('uname'))), 'FreeBSD') ~= nil then
	   	 shell("sysctl -w dev.netmap.default_pipes=\"" .. tostring(NETMAP_PIPES) .. "\"")
	end	
end




-- check if you are root
-- XXX This needs to be improved
local function check_superuser()
      if string.find((tostring(shell('whoami'))), 'root') == nil then 
      	 return false
      end
      return true
end

-----------------------------------------------------------------------













-----------------------------------------------------------------------
-- 4 - T H R E A D S - S E T U P
-----------------------------------------------------------------------
--setup_config4	 __sets up a simple load balancing configuration__
--		 __the engine reads from netmap-enabled eth3 and__
--		 __forwards packets to a netmap pipe.	        __
function setup_config4(pe, cnt)
	  local lb = Element.new("LoadBalancer", 4)
	  lb:connect_input("eth3")
	  lb:connect_output("eth3{" .. cnt)
	  pe:link(lb, PKT_BATCH, cnt)
end


--init4 function __initializes 4 pkteng threads and links it with a__
--		 __netmap-enabled interface. collects PKT_BATCH    __
--		 __pkts at a time. "cpu", "batch" & "qid" params   __
--		 __can remain unspecified by passing '-1'	   __
--		 __						   __
--		 ++_____________HOW TO USE H.W QUEUES______________++
--		 ++Please make sure that the driver is initialized ++
--		 ++with the right no. of h/w queues. In this setup,++
--		 ++ cpu_thread=0 is registered with H/W queue 0    ++
--		 ++ cpu_thread=1 is registered with H/W queue 1	   ++
--		 ++ cpu_thread=2 is registered with H/W queue 2	   ++
--		 ++ cpu_thread=3 is registered with H/W queue 3	   ++
--		 ++________________________________________________++

function init4()
	 -- check if netmap module is loaded
	 if netmap_loaded() == false then
	    print 'Netmap module does not exist'
	    os.exit(-1)
	 end

	 -- check if you are root
	 if check_superuser() == false then
	    print 'You have to be superuser to run this function'
	    os.exit(-1)
	 end

	 -- enable underlying netmap pipe framework
	 enable_nmpipes()

	 for cnt = 0, 3 do
	 	 local pe = PktEngine.new("e" .. cnt, "netmap", BUFFER_SZ, cnt)
		 
		 --setup with config 4
		 setup_config4(pe, cnt)		 
	 end
end
-----------------------------------------------------------------------
--start4 function __starts all 4 pktengs and prints overall per sec__
--		  __stats for STATS_PRINT_CYCLE_DEFAULT secs__

function start4()
	 for cnt = 0, 3 do
	     	 local pe = PktEngine.retrieve("e" .. cnt)
	 	 pe:start()
	 end

	 local i = 0
	 repeat
	     sleep(SLEEP_TIMEOUT)
	     BRICKS.show_stats()
	     i = i + 1
	 until i > STATS_PRINT_CYCLE_DEFAULT
end
-----------------------------------------------------------------------
--stop4 function __stops the pktengs before printing the final stats.__
--		 __it then unlinks the interface from the engine and__
--		 __finally frees the engine context from the system__
function stop4()
	 BRICKS.show_stats()
	 for cnt = 0, 3 do
	     	 local pe = PktEngine.retrieve("e" .. cnt)
		 pe:stop()
	 end

	 sleep(SLEEP_TIMEOUT)

	 for cnt = 0, 3 do
	     	 local pe = PktEngine.retrieve("e" .. cnt)
	 	 pe:delete()
	 end

	 --BRICKS.shutdown()
end
-----------------------------------------------------------------------





-----------------------------------------------------------------------
-- S T A R T _ OF _  S C R I P T
-----------------------------------------------------------------------
-- __"main" function (Commented for user's convenience)__
--
-------- __This command prints out the main help menu__
-- BRICKS.help()
-------- __This command shows the current status of BRICKS__
-- BRICKS.print_status()
-------- __This prints out the __pkt_engine__ help menu__
-- PktEngine.help()
-------- __Initialize the system__
-- init()
-------- __Start the engine__
-- start()
-------- __Stop the engine__
-- stop()
-------- __The following commands quits the session__
-- BRICKS.shutdown()
-----------------------------------------------------------------------