-- Name: Solar System
-- Description: Our Solar System, scaled to fit and look nice.
-- Type: Basic
-- Author: Mike Mallett <mike@nerdcore.net>

--- Scenario
-- @script scenario_04_solar

require("utils.lua")
require("jump_carriers.lua")

all_systems = {"reactor", "beamweapons", "missilesystem", "maneuver", "impulse", "warp", "jumpdrive", "frontshield", "rearshield"}

-- Scaling factors:
-- Distance from Sol
--scale_far = 1 / 500
-- This is best, for now:
scale_far = 1 / 300
-- DEBUG
--scale_far = 1 / 800
-- Radius
scale_rad = 1
--scale_rad = 2
-- Orbital speed
scale_orb = scale_far * 10
--scale_orb = scale_far / 2200
-- Axial speed
scale_rot = 1 / 100

-- Beam arc colour options
barc_colours = {
   ["red"] = {128, 0, 0, 255, 0, 0},
   ["blue"] = {0, 0, 128, 0, 0, 255},
   ["green"] = {0, 128, 0, 0, 255, 0},
   ["purple"] = {96, 0, 96, 192, 0, 192},
   -- FIXME ?
   ["orange"] = {192, 24, 0, 255, 62, 0},
   ["teal"] = {0, 96, 96, 0, 192, 192}
}
-- Should match the special beam colours (plus white)
unknown_colours = {
   ["white"] = {255,255,255},
   ["yellow"] = {192,192,0},
   ["orange"] = {216,32,0},
   ["green"] = {0,255,0},
   ["purple"] = {192,0,192},
   ["blue"] = {0,0,255}
}

function solScale(meters)
   -- Convert meter value to integer units (0.001U, 1mU) for use in Planet() functions
   -- IDEA: math.log() to scale small distances less and large distances more
   return meters * (100000 / 6378137)
end
function solScaleAU(au)
   -- 1 AU: 149.5979 Gm
   --return solScale(au * 149598023000) / 600
   return solScale(au * 149598023000) * scale_far
end
-- FIXME: These two functions return (sec * 40) for game ticks, not actual seconds.
-- Could be renamed, I guess.
-- NOTE: According to the tutorial site, 60/s:
-- "the game runs any code in the update function every game tick, or about 60 times per second."
function dayToSec(d)
   return d * 86400 * 60
end
function hourToSec(h)
   return h * 3600 * 40
end
function yearToSec(y)
   return dayToSec(y * 365.256363004)
end

-- Scale radii
function solScaleRad(r)
   return solScale(r)
end
-- Scale orbital speeds
function solScaleOrb(o)
   return o * scale_orb
end
-- Scale axial rotation
-- KLUDGE: Earth spins CCW, but positive AxialRotationTime value makes it spin CW
-- so here we reverse (negate) the integer value so Earth and others spin correctly
-- (sorry, Uranus...)
function solScaleRot(a)
   return -a * scale_rot
end

-- IDEA: EE/SP only loads texture PNGs from disk as-needed.
-- Instead, we could create small duplicate planets of all bodies immediately
-- near any new player ship, to ensure the textures are loaded to (V)RAM, then
-- one second later or immediately destroy the dupes. (?)
function makeBody(name)
   local config = bodies[name]
   local b = Planet()
   b:setCallSign(name)
   b:setPlanetRadius(config["radius"])
   if config["texture"] then
      b:setPlanetSurfaceTexture(config["texture"])
   end
   -- FIXME: Uh, oh! Some scales are done in bodies{} and others (rot and orb) here :(
   b:setAxialRotationTime(solScaleRot(config["rotation"]))
   if config["atmo_r"] and config["atmo_g"] and config["atmo_b"] then
      b:setPlanetAtmosphereColor(config["atmo_r"], config["atmo_g"], config["atmo_b"])
   end
   if config["atmo_t"] then
      b:setPlanetAtmosphereTexture(config["atmo_t"])
   end
   if config["clouds"] then
      b:setPlanetCloudTexture(config["clouds"])
      b:setPlanetCloudRadius(b:getPlanetRadius()*1.08)
   end
   -- Here comes the tricky part...
   if config["parent"] == nil then
   --if config["pos_x"] and config["pos_y"] then
      b:setPosition(config["pos_x"], config["pos_y"])
   else
      local p = bodies[config["parent"]]["instance"]
      if p == nil then
	 p = makeBody(config["parent"], bodies[config["parent"]])
      end
      local px, py = p:getPosition()
      local pr = p:getPlanetRadius()
      setCirclePos(b, px, py, config["angle"], pr + config["distance"])
      --setCirclePos(b, px, py, 0, config["distance"]) -- Straight line
      b:setOrbit(p, solScaleOrb(config["orbit"]))
      end
   return b
end

function makeBodies()
   for name,config in pairs(bodies) do
      bodies[name]["instance"] = makeBody(name)
   end
end

-- Wormholes
-- DEBUG: I'd like these to be station-generated and time-limited
-- but for testing we should be able to travel quickly...
-- IDEA: Could be a GMButton?
function makeWormHoles()
   -- TODO: Ensure all distances are such that nothing gets sucked
   -- into a wormhole accidentally
   wormholes = {}
   --wormhole_marks = {}
   local e = bodies["Earth"]["instance"]
   local ex, ey = e:getPosition()
   local er = e:getPlanetRadius()
   for name,config in pairs(bodies) do
      if (name ~= "Earth" and config["parent"] == "Sol") then
	 local d = config["instance"]
	 local dx, dy = d:getPosition()
	 local ar = angleRotation(e, d)
	 local far = distance(e, d) / 200000
	 local w = WormHole()
	 setCirclePos(w, ex, ey, ar, (er*1.5) + far)
	 -- FIXME: Should be angled relative to Earth
	 w:setTargetPosition(dx - (config["radius"] * 1.2), dy)
	 w:setCallSign("To " .. name)
	 table.insert(wormholes, w)
	 --local wx, wy = w:getPosition() -- Gotta call this because we set it with setCirclePos()
	 -- Mark it
	 -- TODO: Decide whether we should know these as Human Navy Stations, or not as Science Buoys
	 --local m = SpaceStation():setPosition(wx, wy-5500):setTemplate("Small Station"):setFaction("Human Navy"):setCallSign(_("To ") .. name)
	 --local m = Artifact():setPosition(wx, wy-5500):setModel("SensorBuoyMKI"):allowPickup(false):setScanningParameters(1,1):setDescriptions(_("scienceDescription-buoy", "Space Message Buoy"),_("scienceDescription-buoy", name)):setCallSign(name)
	 --wormhole_marks[name] = m
      end
   end
end

function broadcastLog(m,c)
   for i,ship in ipairs(ships) do
      ship:addToShipLog(m,c)
   end
end

function init()
   -- Measures as of 2021-12-18
   --+---------+------------+-------------+----------------+--------------+
   --|   Name  |  Distance  |   Radius    |  Orbit Period  | Axial Period |
   --+---------+------------+-------------+----------------+--------------+
   --|   Sun   |     N/A    |   696 Mm    |       N/A      |    25.05 D   |
   --+---------+------------+-------------+----------------+--------------+
   --| Mercury | 0.387098AU |   2.44 Mm   |   87.9691 D    |     176 D    |
   --+---------+------------+-------------+----------------+--------------+
   --|  Venus  | 0.723332AU |  6.0518 Mm  |   224.701 D    |   -116.75 D  |
   --+---------+------------+-------------+----------------+--------------+
   --|  Earth  |    1.0 AU  | 6.378137 Mm | 1Y=31557945.6s |  1D = 86400s |
   --+---------+------------+-------------+----------------+--------------+
   --|  >Luna  | 384.399 Mm |  1.7381 Mm  |     ~28 D     =|     ~28 D    |
   --+---------+------------+-------------+----------------+--------------+
   --|  Mars   | 1.523679AU |  3.3962 Mm  |   686.980 D    | 1.02749125 D |
   --+---------+------------+-------------+----------------+--------------+
   --| >Phobos |  9.376 Mm  |  11.2667 km |  0.31891023 D =| 0.31891023 D | 
   --+---------+------------+-------------+----------------+--------------+
   --| >Deimos | 23.4632 Mm |    6.2 km   |    1.263 D    =|   1.263 D    |
   --+---------+------------+-------------+----------------+--------------+
   --|  Vesta  | 2.36179 AU |  262.70 km  |     3.63 y     |    5.342 h   |
   --+---------+------------+-------------+----------------+--------------+
   --|  Ceres  |   2.77 AU  |  469.73 km  |     1680 D     |  9.074170 h  |
   --+---------+------------+-------------+----------------+--------------+
   --| Jupiter |  5.2044 AU |  71.492 Mm  |    11.862 y    |    9.9258 h  |
   --+---------+------------+-------------+----------------+--------------+
   --|   >Io   | 421.700 Mm |  1.8216 Mm  |  152853.5047s =| 1.769137786 D|
   --+---------+------------+-------------+----------------+--------------+
   --| >Europa | 670.900 Mm |  1.5608 Mm  |   3.551181 D  =|  3.551181 D  |
   --+---------+------------+-------------+----------------+--------------+
   --|>Ganymede| 1.070400Gm |  2.6341 Mm  |  7.15455296 D =| 7.15455296 D |
   --+---------+------------+-------------+----------------+--------------+
   --|>Callisto| 1.882700Gm |  2.4103 Mm  |  16.6890184 D =| 16.6890184 D |
   --+---------+------------+-------------+----------------+--------------+
   --|  Saturn |  9.5826 AU |  60.268 Mm  |    29.4571 Y   |   10.5433 h  |
   --+---------+------------+-------------+----------------+--------------+
   --| >Mimas  | 185.539 Mm |   198.2 km  |  0.942421959 D=| 0.942421959 D|
   --+---------+------------+-------------+----------------+--------------+
   --|>Encelad.| 237.948 Mm |   252.1 km  |   1.370218 D  =|  1.370218 D  |
   --+---------+------------+-------------+----------------+--------------+
   --| >Tethys | 294.619 Mm |   531.1 km  |   1.887802 D  =|  1.887802 D  |
   --+---------+------------+-------------+----------------+--------------+
   --| >Dione  | 377.396 Mm |   561.4 km  |   2.736915 D  =|  2.736915 D  |
   --+---------+------------+-------------+----------------+--------------+
   --|  >Rhea  | 527.108 Mm |   763.8 km  |   4.518212 D  =|  4.518212 D  |
   --+---------+------------+-------------+----------------+--------------+
   --| >Titan  | 1.221870Gm |  2.57473 Mm |    15.945 D   =|    15.945 D  |
   --+---------+------------+-------------+----------------+--------------+
   --|  Uranus | 19.19126 AU|  25.559 Mm  |    84.0205 Y   |  -0.71832 D  |
   --+---------+------------+-------------+----------------+--------------+
   --| Neptune |  30.07 AU  |  24.622 Mm  |     164.8 Y    |   0.67125 D  |
   --+---------+------------+-------------+----------------+--------------+
   --|  Pluto  | 39.482 AU  |  1.1883 Mm  | 247.94Y+90.56D |   −6.3868 D  |
   --+---------+------------+-------------+----------------+--------------+

   -- ----- NOTE ----- --
   -- Starting with the values in the table above,
   -- I tried a lot of values for various radii and distances and orbital periods.
   -- The settings below differ from the values above.
   -- Deal with it.

   -- TODO: Randomize orbital positions, or better yet start the mission
   -- with all celestial bodies in their correct (calculated) positions
   -- For now, all bodies in a straight line (0 Y-axis)

   -- IDEA: Oort cloud ??

   -- Place the Sun approximately 1 AU to the Left, so that we can start near Earth.
   local sun_offset = 0 - solScaleAU(1) + solScaleRad(6378137)
   bodies = {
      -- This is the corona
      ["Corona"] = {
	 parent = nil,
	 pos_x = sun_offset,
	 pos_y = 0,
	 radius = solScaleRad(696000000) / 9.5, -- TODO: Scale with scale_far, to keep near Mercury
	 angle = 0,
	 atmo_r = 0.8,
	 atmo_g = 0.6,
	 atmo_b = 0.1,
	 atmo_t = "planets/star-1.png",
	 rotation = 0,
	 orbit = 0,
	 instance = nil
      },
      -- This "secondary" Sun has a mapped texture
      -- It rotates to look cool. 8-)
      ["Sol"] = {
	 parent = nil,
	 pos_x = sun_offset,
	 pos_y = 0,
	 radius = solScaleRad(696000000) / 18,
	 angle = 0,
	 atmo_r = 1.0,
	 atmo_g = 0.8,
	 atmo_b = 0.2,
	 texture = "planets/hd/sol-1.png",
	 rotation = 36000, -- FAST!
	 orbit = 0,
	 instance = nil
      },
      ["Mercury"] = {
	 parent = "Sol",
	 distance = solScaleAU(0.387098),
	 radius = solScaleRad(2440000),
	 angle = 45,
	 atmo_r = 0.2,
	 atmo_g = 0.1,
	 atmo_b = 0.0,
	 texture = "planets/hd/mercury-1.png",
	 rotation = dayToSec(176),
	 orbit = dayToSec(87.9691),
	 instance = nil
      },
      ["Venus"] = {
	 parent = "Sol",
	 distance = solScaleAU(0.723332),
	 radius = solScaleRad(6051800),
	 angle = 76,
	 atmo_r = 0.96, -- 64
	 atmo_g = 0.64, -- 32
	 atmo_b = 0.24, -- 11
	 atmo_t = "planets/atmosphere.png",
	 texture = "planets/hd/venus-1.png",
	 --clouds = "planets/clouds-thick.png",
	 clouds = "planets/clouds-4.png",
	 rotation = dayToSec(-116.75), -- Spins "backwards" from Earth
	 orbit = dayToSec(224.701),
	 instance = nil
      },
      ["Earth"] = {
	 parent = "Sol",
	 --pos_x = solScale(384399000)/16,
	 --pos_y = 0,
	 distance = solScaleAU(1),
	 radius = solScaleRad(6378137),
	 angle = 0,
	 atmo_r = 0.2,
	 atmo_g = 0.2,
	 atmo_b = 0.7,
	 --atmo_t = "planets/atmosphere.png",
	 --texture = "planets/hd/earth-1.png",
	 texture = "planets/hd/earth-8k.png",
	 --texture = "planets/hd/earth-22k.png", -- https://www.naturalearthdata.com/
	 --clouds = "planets/hd/clouds-4k2.png",
	 clouds = "planets/hd/clouds-8k.png", -- http://www.shadedrelief.com/natural3/pages/clouds.html
	 rotation = dayToSec(1),
	 orbit = yearToSec(1),
	 instance = nil
      },
      -- The term "moon" is generic. This one is named Luna.
      -- Some values here not necessarily to scale; rather to look and play nice.
      ["Luna"] = {
	 parent = "Earth",
	 distance = solScale(384399000) / 16,
	 radius = solScaleRad(1738100),	
	 -- This angle was chosen so that the tidally locked Moon texture
	 -- planets/Moon/luna-1.png looks correct to folks at Earth (rough guess)
	 angle = 100,
	 texture = "planets/hd/luna-1.png",
	 rotation = dayToSec(28),
	 orbit = dayToSec(28), -- Synchronous
	 instance = nil
      },
      ["Mars"] = {
	 parent = "Sol",
	 distance = solScaleAU(1.523679),
	 radius = solScaleRad(3396200),
	 angle = 33,
	 atmo_r = 0.6,
	 atmo_g = 0.4,
	 atmo_b = 0.3,
	 atmo_t = "planets/atmosphere.png",
	 texture = "planets/hd/mars-1.png",
	 --texture = "planets/Mars/mars-terraformed.png",
	 clouds = "planets/hd/clouds-4k.png",
	 rotation = dayToSec(1.02749125),
	 orbit = dayToSec(686.980),
	 instance = nil
      },
      -- IDEA: Phobos and Deimos could be asteroids? They are so small...
      -- Unfortunately Asteroid::setOrbit() is not a function. Make planets for now.
      ["Phobos"] = {
	 parent = "Mars",
	 distance = solScale(9376000),
	 radius = solScaleRad(11266.7),
	 angle = random(0,360),
	 texture = "planets/hd/phobos-1.png",
	 rotation = dayToSec(0.31891023),
	 orbit = dayToSec(0.31891023), -- Synchronous
	 instance = nil
      },
      ["Deimos"] = {
	 parent = "Mars",
	 distance = solScale(23463200),
	 radius = solScaleRad(6200),
	 angle = random(0,360),
	 texture = "planets/hd/deimos-1.png",
	 rotation = dayToSec(1.263),
	 orbit = dayToSec(1.263), -- Synchronous
	 instance = nil
      },
      ["Vesta"] = {
	 parent = "Sol",
	 distance = solScaleAU(2.36179),
	 -- FIXME: Disappears because its so small?
	 --radius = solScaleRad(262.70),
	 radius = solScaleRad(262.70 * 30),
	 angle = 200,
	 --texture = "planets/hd/vesta-1.png", -- This is 26704 x 13352, 8-bit grayscale
	 texture = "planets/hd/vesta-8k.png",
	 rotation = hourToSec(5.342),
	 orbit = yearToSec(3.63),
	 instance = nil
      },
      ["Ceres"] = {
	 parent = "Sol",
	 distance = solScaleAU(2.77),
	 radius = solScaleRad(469730),
	 angle = 199,
	 texture = "planets/hd/ceres-1.png",
	 rotation = hourToSec(9.074170), -- Hours
	 orbit = dayToSec(1680),
	 instance = nil
      },
      ["Jupiter"] = {
	 parent = "Sol",
	 distance = solScaleAU(5.2044),
	 radius = solScaleRad(71492000),
	 angle = 280,
	 --atmo_r = 0.3,
	 --atmo_g = 0.1,
	 --atmo_b = 0.01,
	 --texture = "planets/hd/jupiter-1.png",
	 texture = "planets/hd/jupiter-hubble.png",
	 rotation = hourToSec(9.9258), -- Hours
	 orbit = yearToSec(11.862),
	 instance = nil
      },
      ["Io"] = {
	 parent = "Jupiter",
	 distance = solScale(421700000) / 4, -- Force shrinkage
	 radius = solScaleRad(1821600),
	 angle = random(0,360),
	 atmo_r = 0.5,
	 atmo_g = 0.4,
	 atmo_b = 0.1,	
	 atmo_t = "planets/atmosphere.png",
	 texture = "planets/hd/io-1.png",
	 rotation = dayToSec(1.769137786),
	 orbit = dayToSec(1.769137786), -- Synchronous
	 instance = nil
      },
      ["Europa"] = {
	 parent = "Jupiter",
	 distance = solScale(670900000) / 5, -- Force shrinkage
	 radius = solScaleRad(1560800),
	 angle = random(0,360),
	 atmo_r = 0.3,
	 atmo_g = 0.2,
	 atmo_b = 0.1,
	 texture = "planets/hd/europa-1.png",
	 rotation = dayToSec(3.551181),
	 orbit = dayToSec(3.551181), -- Synchronous
	 instance = nil
      },
      ["Ganymede"] = {
	 parent = "Jupiter",
	 distance = solScale(1070400000) / 6, -- Force shrinkage
	 radius = solScaleRad(2634100),
	 angle = random(0,360),
	 atmo_r = 0.1,
	 atmo_g = 0.1,
	 atmo_b = 0.1,
	 texture = "planets/hd/ganymede-1.png",
	 rotation = dayToSec(7.15455296),
	 orbit = dayToSec(7.15455296), -- Synchronous
	 instance = nil
      },
      ["Callisto"] = {
	 parent = "Jupiter",
	 distance = solScale(1882700000) / 7, -- Force shrinkage
	 radius = solScaleRad(2634100),
	 angle = random(0,360),
	 atmo_r = 0.075,
	 atmo_g = 0.075,
	 atmo_b = 0.075,
	 texture = "planets/hd/callisto-1.png",
	 rotation = dayToSec(16.6890184),
	 orbit = dayToSec(16.6890184), -- Synchronous
	 instance = nil
      },
      ["Saturn"] = {
	 parent = "Sol",
	 distance = solScaleAU(9.5826),
	 radius = solScaleRad(60268000),
	 angle = 110,
	 atmo_r = 0.5,
	 atmo_g = 0.3,
	 atmo_b = 0.01,
	 texture = "planets/hd/saturn-1.png",
	 rotation = hourToSec(10.5433),
	 orbit = yearToSec(29.4571),
	 instance = nil
      },
      ["Mimas"] = {
	 parent = "Saturn",
	 distance = solScale(185539000) / 2, -- Force shrinkage
	 radius = solScaleRad(198200),
	 angle = random(225,360),
	 atmo_r = 0.2,
	 atmo_g = 0.2,
	 atmo_b = 0.12,
	 texture = "planets/hd/mimas-1.png",
	 rotation = dayToSec(0.942421959),
	 orbit = dayToSec(0.942421959), -- Synchronous
	 instance = nil
      },
      ["Enceladus"] = {
	 parent = "Saturn",
	 distance = solScale(237948000) / 2, -- Force shrinkage
	 radius = solScaleRad(252100),
	 angle = random(225,360),
	 atmo_r = 0.3,
	 atmo_g = 0.4,
	 atmo_b = 0.5,
	 texture = "planets/hd/enceladus-1.png",
	 rotation = dayToSec(1.370218),
	 orbit = dayToSec(1.370218), -- Synchronous
	 instance = nil
      },
      ["Tethys"] = {
	 parent = "Saturn",
	 distance = solScale(294619000) / 2, -- Force shrinkage
	 radius = solScaleRad(531100),
	 angle = random(225,360),
	 atmo_r = 0.12,
	 atmo_g = 0.12,
	 atmo_b = 0.1,
	 texture = "planets/hd/tethys-1.png",
	 rotation = dayToSec(1.887802),
	 orbit = dayToSec(1.887802), -- Synchronous
	 instance = nil
      },
      ["Dione"] = {
	 parent = "Saturn",
	 distance = solScale(377396000) / 2, -- Force shrinkage
	 radius = solScaleRad(561400),
	 angle = random(225,360),
	 atmo_r = 0.1,
	 atmo_g = 0.1,
	 atmo_b = 0.09,
	 texture = "planets/hd/dione-1.png",
	 rotation = dayToSec(2.736915),
	 orbit = dayToSec(2.736915), -- Synchronous
	 instance = nil
      },
      ["Rhea"] = {
	 parent = "Saturn",
	 distance = solScale(527108000) / 2.2, -- Force shrinkage
	 radius = solScaleRad(763800),
	 angle = random(225,360),
	 atmo_r = 0.1,
	 atmo_g = 0.08,
	 atmo_b = 0.0,
	 texture = "planets/hd/rhea-1.png",
	 rotation = dayToSec(4.518212),
	 orbit = dayToSec(4.518212), -- Synchronous
	 instance = nil
      },
      ["Titan"] = {
	 parent = "Saturn",
	 distance = solScale(1221870000) / 4, -- Force shrinkage
	 radius = solScaleRad(2574730),
	 angle = random(225,360),
	 atmo_r = 0.6,
	 atmo_g = 0.5,
	 atmo_b = 0.2,
	 atmo_t = "planets/atmosphere.png",
	 texture = "planets/hd/titan-1.png",
	 clouds = "planets/clouds-4.png",
	 rotation = dayToSec(15.945),
	 orbit = dayToSec(15.945), -- Synchronous
	 instance = nil
      },
      ["Uranus"] = {
	 parent = "Sol",
	 --distance = solScaleAU(19.19126 * 0.66), -- Rein it in...
	 distance = solScaleAU(13),
	 radius = solScaleRad(25559000),
	 angle = 355,
	 atmo_r = 0.2,
	 atmo_g = 0.2,
	 atmo_b = 0.3,
	 atmo_t = "planets/atmosphere.png",
	 texture = "planets/hd/uranus-1.png",
	 rotation = dayToSec(-0.71832), -- Negative because why not? Actual rotation axis is 90 degrees or so.
	 orbit = yearToSec(84.0205),
	 instance = nil
      },
      ["Neptune"] = {
	 parent = "Sol",
	 --distance = solScaleAU(30.07 * 0.4), -- Rein it in...
	 distance = solScaleAU(15),
	 radius = solScaleRad(24622000),
	 angle = 333,
	 atmo_r = 0.2,
	 atmo_g = 0.2,
	 atmo_b = 0.3,
	 atmo_t = "planets/atmosphere.png",
	 texture = "planets/hd/neptune-1.png",
	 rotation = dayToSec(0.67125),
	 orbit = yearToSec(164.8),
	 instance = nil
      },
      ["Pluto"] = { -- <3
	 parent = "Sol",
	 --distance = solScaleAU(39.482 / 2.5), -- Rein it in...
	 distance = solScaleAU(17),
	 radius = solScaleRad(1188300),
	 angle = 5,
	 atmo_r = 0.06,
	 atmo_g = 0.0,
	 atmo_b = 0.02,
	 texture = "planets/hd/pluto-1.png",
	 rotation = dayToSec(-6.3868),
	 orbit = yearToSec(247.94) + dayToSec(90.56),
	 instance = nil
      }
   }
   makeBodies()

   ships = {}
   armada = {}
   eships = {}

   solar_flares = {}
   flare_time = 0

   progress = {
      ["whAllow"] = true, -- FOR TESTING
      ["mercury"] = 0,
      ["venus"] = 0,
      ["mars"] = 0,
      ["jupiter"] = 0,
      ["juVisits"] = {},
      ["saturn"] = 0,
      ["belt"] = 0,
      ["outer"] = 0
   }

   -- TODO: Apply these settings directly to the HN-WH object instead
   hnwh = {
      ["whtimer"] = 120,
      ["whtime"] = nil,
      ["wh"] = nil
   }

   spare = nil
   unknown = nil
   another = nil
   zoff = 0

   -- Vesta and Ceres are far apart, so let's make the belt between them.
   belt = {}
   local belt_min = distance(bodies["Sol"]["instance"], bodies["Vesta"]["instance"]) * 1.01
   local belt_max = distance(bodies["Sol"]["instance"], bodies["Ceres"]["instance"]) * 0.99
   local ast_max = bodies["Ceres"]["instance"]:getPlanetRadius()
   for _ = 1, 10000 do
      local a = Asteroid()
      --a:setSize(random(1, 10000))
      a:setSize(random(1, ast_max))
      local dist = random(belt_min, belt_max)
      setCirclePos(a, bodies["Sol"]["pos_x"], bodies["Sol"]["pos_y"], random(0, 360), dist, 0)
      table.insert(belt, a)
   end

   -- Saturn's "Rings"
   local saturn = bodies["Saturn"]["instance"]
   local saturn_x, saturn_y = saturn:getPosition()
   local saturn_radius = saturn:getPlanetRadius()
   saturn_rings = {}
   for __ = 1, (saturn_radius / 100) do
      local a = Asteroid()
      a:setSize(random(1, 50))
      local dist = random(saturn_radius+(saturn_radius*0.2), saturn_radius+(saturn_radius*0.4))
      setCirclePos(a, saturn_x, saturn_y, random(0, 360), dist)
      local adata = {}
      adata["instance"] = a
      adata["distance"] = dist
      adata["angle"] = angleRotation(saturn, a)
      table.insert(saturn_rings, adata)
   end

   -- Saturn Exuari moons
   sexmoons = {"Titan", "Mimas", "Enceladus", "Dione"}
   numex = 24
   for __ = 1, numex do
      local m = bodies[sexmoons[math.ceil(__/(numex/#sexmoons))]]["instance"]
      local mx,my = m:getPosition()
      local mr = m:getPlanetRadius()
      local s = CpuShip():setFaction("Exuari"):setTemplate("Strikeship"):orderDefendTarget(m):onDestroyed(function()
	    numex=numex-1
	    if (numex < 5) and (progress["saturn"] < 100) then makePeace() end
      end)
      setCirclePos(s, mx, my, random(0, 360), random(mr*1.3, mr*1.4))
      table.insert(eships, s)
   end

   -- Stations
   stations = {
      ["Icarus"] = {
	 template = "Small Station",
	 faction = "Independent", -- A bit hidden
	 parent = "Mercury",
	 distance = 1.7,
	 speed = 0.0002,
	 lagrange = "L1",
	 instance = nil
      },
      ["Daedalus"] = {
	 template = "Small Station",
	 faction = "Human Navy",
	 parent = "Mercury",
	 distance = 1.4,
	 speed = 0.0005,
	 instance = nil
      },
      ["VE-IX"] = {
	 template = "Large Station",
	 faction = "Human Navy",
	 parent = "Venus",
	 distance = 1.8,
	 speed = 0.0002,
	 instance = nil
      },
      ["Spooky"] = {
	 template = "Small Station",
	 faction = "Ghosts",
	 parent = "Venus",
	 distance = 1.8,
	 speed = 0.0002,
	 lagrange = "L4",
	 instance = nil
      },
      ["Scary"] = {
	 template = "Medium Station",
	 faction = "Ghosts",
	 parent = "Venus",
	 distance = 1.8,
	 speed = 0.0002,
	 lagrange = "L5",
	 instance = nil
      },
      ["Terrifying"] = {
	 template = "Large Station",
	 faction = "Ghosts",
	 parent = "Venus",
	 distance = 1.8,
	 speed = 0.0002,
	 lagrange = "L2",
	 instance = nil
      },
      ["HN-HQ"] = {
	 template = "Large Station",
	 faction = "Human Navy",
	 parent = "Earth",
	 distance = 1.33,
	 speed = 0.0002,
	 instance = nil
      },
      ["HN-WH"] = {
	 template = "Medium Station",
	 faction = "Human Navy",
	 parent = "Earth",
	 distance = 2.0,
	 speed = 0.0001,
	 instance = nil
      },
      ["HN-RM"] = {
	 template = "Medium Station",
	 faction = "Human Navy",
	 parent = "Earth",
	 distance = 1.66,
	 speed = 0.00015,
	 instance = nil
      },
      ["MOSS"] = {
	 template = "Small Station",
	 faction = "Independent",
	 parent = "Earth",
	 distance = 1.2,
	 speed = 0.0002,
	 instance = nil
      },
      ["LS-1"] = {
	 template = "Large Station",
	 faction = "Human Navy",
	 parent = "Luna",
	 distance = 1.5,
	 speed = 0.0001,
	 instance = nil
      },
      ["Mars-1"] = {
	 template = "Small Station",
	 faction = "Human Navy",
	 parent = "Mars",
	 distance = 1.6,
	 speed = 0.0001,
	 angle = 0,
	 instance = nil
      },
      ["Mars-2"] = {
	 template = "Small Station",
	 faction = "Human Navy",
	 parent = "Mars",
	 distance = 1.6,
	 speed = 0.0001,
	 angle = 120,
	 instance = nil
      },
      ["Mars-3"] = {
	 template = "Small Station",
	 faction = "Human Navy",
	 parent = "Mars",
	 distance = 1.6,
	 speed = 0.0001,
	 angle = 240,
	 instance = nil
      },
      ["BE-HQ"] = {
	 template = "Small Station",
	 faction = "Independent",
	 parent = "Vesta",
	 distance = 30, -- FIXME: Must be excessive, because Vesta's so tiny!
	 speed = 0.0001,
	 instance = nil
      },
      ["JU-HQ"] = {
	 template = "Large Station",
	 faction = "Independent",
	 parent = "Jupiter",
	 distance = 1.3,
	 speed = 0.00001,
	 instance = nil
      },
      ["JU-GA"] = {
	 template = "Medium Station",
	 faction = "Independent",
	 parent = "Ganymede",
	 distance = 1.6,
	 speed = 0.00002,
	 instance = nil
      },
      ["JU-CA"] = {
	 template = "Medium Station",
	 faction = "Independent",
	 parent = "Callisto",
	 distance = 1.9,
	 speed = 0.00001,
	 instance = nil
      },
      ["HN-CA"] = {
	 template = "Medium Station",
	 faction = "Human Navy",
	 parent = "Callisto",
	 distance = 1.6,
	 speed = 0.0001,
	 instance = nil
      },
      ["JU-EU"] = {
	 template = "Small Station",
	 faction = "Independent",
	 parent = "Europa",
	 distance = 1.6,
	 speed = 0.0001,
	 instance = nil
      },
      ["JU-IO"] = {
	 template = "Small Station",
	 faction = "Independent",
	 parent = "Io",
	 distance = 1.6,
	 speed = 0.0001,
	 instance = nil
      },
      ["Titania"] = {
	 template = "Large Station",
	 faction = "Exuari",
	 parent = "Titan",
	 distance = 1.4,
	 speed = 0.001,
	 instance = nil
      },
      ["Oberon"] = {
	 template = "Small Station",
	 faction = "Independent",
	 parent = "Rhea",
	 distance = 2,
	 speed = 0.0001,
	 instance = nil
      },
      ["KR-PL"] = {
	 template = "Large Station",
	 faction = "Kraylor",
	 parent = "Pluto",
	 distance = 2,
	 speed = 0.0001,
	 instance = nil
      }
   }
   for name,config in pairs(stations) do
      local s = SpaceStation()
      s:setCallSign(name)
      s:setTemplate(config["template"])
      s:setFaction(config["faction"])
      if config["faction"] == "Human Navy" then
	 s:setRepairDocked(true)
	 s:setRestocksScanProbes(true)
	 s:setSharesEnergyWithDocked(true)
      end
      local p = bodies[config["parent"]]["instance"]
      local px, py = p:getPosition()
      local pr = p:getPlanetRadius()
      local ar = 0
      if config["angle"] ~= nil then ar=config["angle"] else ar=random(0,360) end
      setCirclePos(s, px, py, ar, pr * config["distance"])
      s:onDestroyed(function()
	    broadcastLog(config["faction"].." station "..name.." destroyed!", "Red")
	    stations[name]["instance"] = nil
      end)
      stations[name]["instance"] = s
   end

   ghost_stns = {}
   table.insert(ghost_stns, stations["Spooky"]["instance"])
   table.insert(ghost_stns, stations["Scary"]["instance"])
   table.insert(ghost_stns, stations["Terrifying"]["instance"])
   for i,stn in ipairs(ghost_stns) do
      stn:onDestroyed(function()
	    --broadcastLog("Ghost station " .. stn:getCallSign() .. " destroyed!", "Red")
	    --table.remove(ghost_stns, i)
	    -- FIXME: If you play for more than 100 days, ghosts will reappear (?)
	    --if #ghost_stns == 0 then
	    -- FIXME? When onDestroyed() gets invoked, is stn:isValid() ?
	    if checkGhosts() == 0 then
	       progress["venus"] = getScenarioTime() + 8640000
	       if stations["VE-IX"]["instance"] ~= nil then
		  if stations["VE-IX"]["instance"]:isValid() then
		     stations["VE-IX"]["instance"]:setCallSign("VENIX") -- lol
		     for i,ship in ipairs(ships) do
			stations["VE-IX"]["instance"]:sendCommsMessage(ship, "Thanks for cleaning up those pesky ghosts!\n\nShipyard Lunar Station One [LS-1] has new upgrades available.")
		     end
		  end
	       end
	    end
      end)
   end

   stations["Icarus"]["instance"]:setCommsFunction(icComms)
   stations["Daedalus"]["instance"]:setCommsFunction(daComms)
   -- TODO: VE-IX needs defenses
   stations["VE-IX"]["instance"]:setCommsFunction(veComms)
   stations["HN-HQ"]["instance"]:setCommsFunction(hqComms)
   stations["HN-HQ"]["instance"]:onDestroyed(function()
	 if (progress["venus"]==0) or (checkGhosts()>0) then
	    victory("Ghosts")
	 elseif progress["saturn"] < 100 then
	    victory("Exuari")
	 else
	    victory("Kraylor")
	 end
   end)
   stations["HN-WH"]["instance"]:setCommsFunction(whComms)
   stations["MOSS"]["instance"]:setCommsFunction(moComms)
   stations["LS-1"]["instance"]:setCommsFunction(lsComms)
   stations["Mars-1"]["instance"]:setCommsFunction(maComms)
   stations["Mars-1"]["instance"].heating = 0
   stations["Mars-2"]["instance"]:setCommsFunction(maComms)
   stations["Mars-2"]["instance"].heating = 0
   stations["Mars-3"]["instance"]:setCommsFunction(maComms)
   stations["Mars-3"]["instance"].heating = 0
   stations["BE-HQ"]["instance"]:setCommsFunction(beComms)
   stations["JU-HQ"]["instance"]:setCommsFunction(juComms)
   stations["JU-CA"]["instance"]:setCommsFunction(juComms)
   stations["JU-GA"]["instance"]:setCommsFunction(juComms)
   stations["JU-EU"]["instance"]:setCommsFunction(juComms)
   stations["JU-IO"]["instance"]:setCommsFunction(juComms)
   stations["Oberon"]["instance"]:setCommsFunction(obComms)
   stations["Titania"]["instance"]:onDestroyed(function()
	 for i,es in ipairs(eships) do if es:isValid() then es:setFaction("Independent") end end
	 progress["saturn"] = progress["saturn"] + 100
	 broadcastLog("Exuari threat neutralized!", "Green")
   end)
   local ttn_x, ttn_y = stations["Titania"]["instance"]:getPosition()
   for __ = 1,5 do
      table.insert(eships, CpuShip():setFaction("Exuari"):setTemplate("Strikeship"):setPosition(ttn_x+random(-3000,3000),ttn_y+random(-3000,3000)):orderDefendTarget(stations["Titania"]["instance"]))
   end
   stations["KR-PL"]["instance"]:onDestroyed(function()
	 for i,ship in ipairs(ships) do
	    stations["HN-HQ"]["instance"]:sendCommsMessage(ship, "Good job eliminating the Kraylor threat!\n\nReturn to HN-HQ for debriefing.")
	    ship:addToShipLog("Kraylor defeated! Return to HN-HQ.", "Green")
	 end
	 stations["KR-PL"]["instance"] = nil
	 progress["outer"] = progress["outer"] + 100
   end)

   --makeWormHoles()
   local ux,uy = bodies["Uranus"]["instance"]:getPosition()
   local ur = bodies["Uranus"]["instance"]:getPlanetRadius()
   local nx,ny = bodies["Neptune"]["instance"]:getPosition()
   local nr = bodies["Neptune"]["instance"]:getPlanetRadius()
   unhole = WormHole():setPosition(ux, uy-ur-100000):setTargetPosition(nx-nr-7000, ny)
   unfact = Artifact():allowPickup(false):setScanningParameters(1,1):setDescriptions("What's that?","Kraylor! HERE!? Better tell HQ about this!"):setPosition(nx+nr+7000,ny):setRadarTraceColor(255, 0, 0):setCallSign("Beacon")

   -- TODO: Make this better, somehow...
   local ds = {"HN-HQ", "HN-WH", "HN-RM", "LS-1", "VE-IX", "HN-CA"}
   for i,dn in ipairs(ds) do
      local d = stations[dn]["instance"]
      local dx,dy = d:getPosition()
      CpuShip():setFaction("Human Navy"):setTemplate("Strikeship"):setPosition(dx+1000,dy+2000):orderDefendTarget(d):setScanned(true)
      CpuShip():setFaction("Human Navy"):setTemplate("Strikeship"):setPosition(dx+2000,dy-1000):orderDefendTarget(d):setScanned(true)
      CpuShip():setFaction("Human Navy"):setTemplate("Strikeship"):setPosition(dx-1000,dy-2000):orderDefendTarget(d):setScanned(true)
   end

   jumpConfig = {
      ["JC-1"] = {
	 destinations = {
	    ["Human Navy HQ [HN-HQ]"] = { stations["HN-HQ"]["instance"]:getPosition() },  -- NOTE: The first jump needs to start near the first listed destination
	    ["Human Navy Worm Hole [HN-WH]"] = { stations["HN-WH"]["instance"]:getPosition() },
	    ["Human Navy Armory [HN-RM]"] = { stations["HN-RM"]["instance"]:getPosition() },
	    ["Lunar Station One [LS-1]"] = { stations["LS-1"]["instance"]:getPosition() },
	    ["Mercury"] =  { stations["Daedalus"]["instance"]:getPosition() },
	    ["Venus"] = { stations["VE-IX"]["instance"]:getPosition() },
	    ["Jupiter"] = { stations["HN-CA"]["instance"]:getPosition() },
	 }
      },
      ["JC-2"] = {
	 destinations = {
	    ["JU-HQ @ Jupiter"] = { stations["JU-HQ"]["instance"]:getPosition() },
	    ["JU-IO @ Io"] = { stations["JU-IO"]["instance"]:getPosition() },
	    ["JU-EU @ Europa"] = { stations["JU-EU"]["instance"]:getPosition() },
	    ["JU-GA @ Ganymede"] = { stations["JU-GA"]["instance"]:getPosition() },
	    ["JU-CA @ Callisto"] = { stations["JU-CA"]["instance"]:getPosition() },
	    ["HN-CA @ Callisto"] = { stations["HN-CA"]["instance"]:getPosition() },
	 }
      }
   }
   local hqx, hqy = stations["HN-HQ"]["instance"]:getPosition()
   jc1 = CpuShip():setFaction("Human Navy"):setTemplate("Jump Carrier"):setCallSign("JC-1"):setScanned(true):setPosition(hqx+random(1000,3000), hqy+random(1000,3000)):orderIdle()
   -- TEST Will it reach HN-CA at Jupiter (Callisto)?
   jc1:setJumpDriveRange(5000, (distance(bodies["Sol"]["instance"], bodies["Mars"]["instance"]) * 2) + 20000)
   jc1:setCommsFunction(jcComms)

   local cax, cay = stations["HN-CA"]["instance"]:getPosition()
   jc2 = CpuShip():setFaction("Human Navy"):setTemplate("Jump Carrier"):setCallSign("JC-2"):setScanned(true):setPosition(hqx+random(1000,3000), hqy+random(1000,3000)):orderIdle()
   jc2:setJumpDriveRange(5000, distance(stations["JU-HQ"]["instance"], stations["JU-CA"]["instance"]))
   jc2:setCommsFunction(jcComms)
end

function update(delta)
   if delta == 0 then	--game paused
      return
   end
   -- Keep stations on their target bodies
   -- FIXME: This doesn't scale with other scaling factors. It should do as planet:setOrbit() et al.
   for name,config in pairs(stations) do
      if config["instance"] ~= nil then
	 local p = bodies[config["parent"]]["instance"]
	 local px, py = p:getPosition()
	 local pr = p:getPlanetRadius()
	 if config["lagrange"] == "L1" then
	    local pp = bodies[bodies[config["parent"]]["parent"]]["instance"] -- Parent's Parent (grandparent)
	    local ar = angleRotation(p, pp)
	    setCirclePos(config["instance"], px, py, ar, (pr*3))
	 elseif config["lagrange"] == "L2" then
	    local pp = bodies[bodies[config["parent"]]["parent"]]["instance"]
	    local ar = (angleRotation(p, pp) + 180)
	    if ar > 360 then ar = ar-360 end
	    setCirclePos(config["instance"], px, py, ar, (pr*3))
	 elseif config["lagrange"] == "L4" then
	    local pp = bodies[bodies[config["parent"]]["parent"]]["instance"]
	    local ar = (angleRotation(p, pp) + 90)
	    if ar > 360 then ar = ar-360 end
	    setCirclePos(config["instance"], px, py, ar, (pr*4))
	 elseif config["lagrange"] == "L5" then
	    local pp = bodies[bodies[config["parent"]]["parent"]]["instance"]
	    local ar = (angleRotation(p, pp) - 90)
	    if ar > 360 then ar = ar-360 end
	    setCirclePos(config["instance"], px, py, ar, (pr*4))
	 else
	    local ar = angleRotation(p, config["instance"])
	    -- The amount of angular increase per tick should be dependent
	    -- on the distance from the object being orbited, so that larger
	    -- distance causes less angular increase (to maintain dockable speeds)
	    local ad = pr * config["distance"]
	    local ari = ar + config["speed"]
	    if ari >= 360 then
	       ari = ari - 360
	    end
	    setCirclePos(config["instance"], px, py, ari, ad)
	 end
      end
   end

   -- Keep Saturn's ring on Saturn as it moves
   local sx, sy = bodies["Saturn"]["instance"]:getPosition()
   for idx,ad in pairs(saturn_rings) do
      setCirclePos(ad["instance"], sx, sy, ad["angle"], ad["distance"])
   end
   -- FIXME: Move the debug wormholes along with Earth.
   --makeWormHoles()

   if #solar_flares > 0 then
      advanceFlares()
   end

   if hnwh["whtime"] ~= nil then
      if getScenarioTime() >= (hnwh["whtime"] + hnwh["whtimer"]) then
	 hnwh["wh"]:destroy()
	 hnwh["whtime"] = nil
      end
   end

   -- Ghosts @ Venus
   if (progress["venus"] > 0) and (getScenarioTime() > (progress["venus"] + 180)) and (checkGhosts() > 0) then
      makeGhostShips()
   end

   if progress["belt"] > 0 then
      sprite()
   end

   for i,ship in ipairs(ships) do
      -- Distance Triggers
      if ((progress["outer"] < 2) and (distance(ship,stations["KR-PL"]["instance"]) < 70000)) or
	 (progress["outer"] < 2) and (unfact:isScannedByFaction("Human Navy")) then
	 progress["outer"] = 2
	 msg = "Kraylor! Here? You better tell someone about this, pronto."
	 -- FIXME: To if or not to if, that is the question
	 --if ship:hasPlayerAtPosition("Science") then
	 --   ship:addCustomMessage("Science","science-kraylor",msg)
	 --end
	 --if ship:hasPlayerAtPosition("Operations") then
	    ship:addCustomMessage("Operations","ops-kraylor",msg)
	 --elseif ship:hasPlayerAtPosition("Single") then
	    ship:addCustomMessage("Single","single-kraylor",msg)
	 --else
	    ship:addCustomMessage("Science","science-kraylor",msg)
	 --end
      --elseif (progress["outer"] == 4) and (distance(ship,bodies["Earth"]["instance"]) < (bodies["Earth"]["instance"]:getPlanetRadius() * 5)) then
      elseif (progress["outer"] == 4) and (distance(ship,bodies["Luna"]["instance"]) < (bodies["Luna"]["instance"]:getPlanetRadius() * 3)) then
	 goTime()
      end
      -- Update status for special beam weapons as needed
      local t = ship:getTarget()
      if ship.beam_counters["blue"] ~= 0 then
	 if ((ship.beam_counters["blue"]-290) < getScenarioTime()) and (ship.beam_distance == 1000) then
	    if another ~= nil then another:destroy() end
	    another = whToPlanet(ship, bodies["Earth"]["instance"])
	    ship.beam_distance = 5000
	 elseif ship.beam_counters["blue"] < getScenarioTime() then
	    if another ~= nil then another:destroy() end
	    another = nil
	 end
      end
      if t == ship.prevTarget then
	 if ship.beam_counters["orange"] > getScenarioTime() then
	    if ship.beam_counters["orange"] < (getScenarioTime()+60) then
	       ship:setSystemHeat("beamweapons", 2.0)
	       ship:setSystemHealth("beamweapons", ship:getSystemHealth("beamweapons")*0.5)
	       ExplosionEffect():setPosition(t:getPosition()):setSize(100):setOnRadar(true)
	       t:destroy()
	       ship.prevTarget = nil
	    end
	 end
	 if ship.beam_counters["green"] > (getScenarioTime()+5) then
	    ship:setSystemHeat("impulse", ship:getSystemHeat("impulse")+0.001)
	    local sx,sy = ship:getPosition()
	    setCirclePos(t, sx, sy, ship.beam_angle, ship.beam_distance)
	 end
      end
   end

   updateJumpCarrierState(jc1)

   marsUpdate()
   if (progress["mars"] == 202) then
      -- Normalize sine waves to range(0,1)
      -- Cycle all rainbow by advancing these at separate rates
      bodies["Mars"]["atmo_r"] = math.sin(bodies["Mars"]["atmo_r"] + getScenarioTime())
      bodies["Mars"]["atmo_g"] = math.sin(bodies["Mars"]["atmo_g"] + (getScenarioTime()/5))
      bodies["Mars"]["atmo_b"] = math.sin(bodies["Mars"]["atmo_b"] + (getScenarioTime()/3))

      bodies["Mars"]["instance"]:setPlanetAtmosphereColor(bodies["Mars"]["atmo_r"], bodies["Mars"]["atmo_g"], bodies["Mars"]["atmo_b"])
   end

   -- Prepare the final battle
   -- checkTotalProgress() returns successes; here check for starts only
   if (progress["mercury"] > 0) and
      (progress["venus"] > 0) and
      (progress["mars"] > 0) and
      (progress["belt"] > 1) and
      (#progress["juVisits"] > 0) and
      (progress["saturn"] > 0) and
      (progress["outer"] > 0) and
      (progress["outer"] < 4) then
      for i,ship in ipairs(ships) do
	 stations["HN-HQ"]["instance"]:sendCommsMessage(ship,"----= URGENT MESSAGE FROM HN-HQ =----\n\nWe've detected a massive energy disturbance at Earth! Get back here immediately!")
      end
      progress["outer"] = 4
   elseif (progress["outer"] >= 5) and (progress["outer"] < 100) and (getScenarioTime() >= stations["KR-PL"]["timer"]) then
      local t = stations["HN-HQ"]["instance"]
      local r = irandom(1,7)
      if r==1 then t = ships[irandom(1,#ships)]
      elseif r==2 then t = stations["LS-1"]["instance"]
      elseif r==3 then t = stations["HN-WH"]["instance"]
      end
      local k = CpuShip():setFaction("Kraylor"):setTemplate("Strikeship"):setPosition(stations["KR-PL"]["instance"]:getPosition()):orderAttack(t)
      -- FIXME? HN only makes 100 ships, Kraylor makes infinite...
      if #armada < 100 then
	 if irandom(1,12) == 1 then k = stations["KR-PL"]["instance"] end
	 table.insert(armada, CpuShip():setPosition(stations["LS-1"]["instance"]:getPosition()):setWarpDrive(true):setWarpSpeed(4000):setFaction("Human Navy"):setTemplate("Strikeship"):orderAttack(k):setScanned(true))
      else
	 armada[irandom(1,#armada)]:orderAttack(k)
      end
      stations["KR-PL"]["timer"] = getScenarioTime()+40
   end
end

function makeDefender(stn)
   if stn.defense == nil then stn.defense = 0 end
   local d = CpuShip():setFaction(stn:getFaction()):setTemplate("Strikeship"):orderDefendTarget(stn)
   local sx, sy = stn:getPosition()
   setCirclePos(d, sx, sy, random(0,360), 3000)
   stn.defense = stn.defense + 1
end

function makeGhostShips()
   -- FIXME: Protect VE-IX somehow
   local v = stations["VE-IX"]["instance"]
   if v == nil then return end
   if not v:isValid() then return end
   if v.defense ~= nil then
      if v.defense < 3 then
	 makeDefender(v)
      end
   end
   for i,stn in ipairs(ghost_stns) do
      if stn:isValid() then
	 local sx, sy = stn:getPosition()
	 local c = CpuShip():setFaction("Ghosts"):setTemplate("Strikeship"):setPosition(sx + 3000, sy + 3000)
	 c:orderAttack(stations["VE-IX"]["instance"])
      end
   end
   progress["venus"] = getScenarioTime()
end

function icComms(s,t)
   -- Otherwise it sells weapons (?)
   if s:isDocked(t) and #solar_flares > 0 then
      setCommsMessage("Download in progress...")
   else
      setCommsMessage("Beep Boop!")
   end
end
function daComms(s,t)
   if s:isDocked(t) then
      if #solar_flares == 0 and progress["mercury"] == 0 then
	 throwFlares()
	 progress["mercury"] = 1
	 local icsec = getSectorName(stations["Icarus"]["instance"]:getPosition())
	 msg = string.format("We've just detected a MASSIVE coronal ejection from Sol headed this way! Science station Icarus in sector %s is not expected to survive this onslaught.\n\nWe need you to get to Icarus NOW and extract as much of its data as you can. Please hurry!", icsec)
	 setCommsMessage(msg)
	 -- FIXME? Someone should get a rolling download status,
	 -- but Science and Operations should see the flares incoming,
	 -- not blocked by the download window constantly. Move to another position?
	 msg = "Get to Icarus in sector "..icsec.." to download its data.\nCheck download status with the \"Download %\" button."
	 s:addCustomButton("Science", "science-download", _("science-downloadbutton", "Download %"), function() checkDownload(s, "Science") end)
	 --if s:hasPlayerAtPosition("Science") then
	    s:addCustomMessage("Science","science-download",msg)
	 --end
	 s:addCustomButton("Operations", "ops-download", _("ops-downloadbutton", "Download %"), function() checkDownload(s, "Operations") end)
	 --if s:hasPlayerAtPosition("Operations") then
	    s:addCustomMessage("Operations","ops-download",msg)
	 --end
	 s:addCustomButton("Single", "single-download", _("single-downloadbutton", "Download %"), function() checkDownload(s, "Single") end)
	 --if s:hasPlayerAtPosition("Single") then
	    s:addCustomMessage("Single","single-download",msg)
	 --end
      elseif progress["mercury"] > 100 then
	 setCommsMessage("Thanks for helping retrieve the data from Icarus station. Shipyard LS-1 will now add a Yellow Beam on your ships.")
      elseif #solar_flares > 0 then
	 setCommsMessage(string.format("What are you waiting for? Get to Icarus in sector [%s] and download its data NOW!!", icsec))
      else
	 setCommsMessage("You failed to reach Icarus station before it was destroyed by a CME. All data has been lost.")
      end
   else
      setCommsMessage("Hello from Daedalus station. Please dock with us if you need anything.")
   end
end

function welcomeComms(ship)
   stations["HN-HQ"]["instance"]:sendCommsMessage(ship, string.format("Welcome home, crew of the %s!\n\nPlease visit Human Navy Headquarters [HN-HQ] in sector %s to get started.", ship:getCallSign(), getSectorName(stations["HN-HQ"]["instance"]:getPosition())))
end
function hqComms(s, t)
   --local hq = stations["HN-HQ"]["instance"]
   setCommsMessage("Hello!\n\nTo purchase ordinance please visit Human Navy Armoury [HN-RM].\nFor all ship upgrades please visit Lunar Station One [LS-1].")
   --addCommsReply("Please send us a Jump Carrier.", askForJC)
   addCommsReply("What to do?", askForHelp)
   addCommsReply("Help us find something.", askForDirections)
   if s:isDocked(t) then
      addCommsReply("Request worm hole clearance.", askForClearance)
   end
   addCommsReply("Progress Report", progressReport)
   if progress["outer"] == 2 then
      addCommsReply("Tell HQ about the Kraylor", askForKraylor)
   end
end
function askForHelp(s,t)
   msg = "Well, let's see here...\n"
   if progress["mercury"] == 0 then  msg = msg.."\nOur solar observation facilities at Mercury could use a hand." end
   if progress["venus"] == 0 then    msg = msg.."\nTourism is down at Venus." end
   if progress["mars"] == 0 then     msg = msg.."\nThe Mars terraforming mission needs some heat." end
   if (checkTotalProgress() > 2) or (#progress["juVisits"]>0) then msg = msg.."\nComms are down at Jupiter." end
   if checkTotalProgress() > 3 then msg = msg.."\nPeace talks with the Exuari of Saturn have broken down." end
   if checkTotalProgress() > 4 then
      msg = msg.."\nWe've been getting mysterious readings from the Belt."
      if progress["outer"] == 0 then
	 msg = msg.."\nPlease have a look around the outer planets."
	 progress["outer"] = 1
      end
   end
   setCommsMessage(msg)
   addCommsReply("Back", hqComms)
end
function askForClearance(s,t)
   -- TODO: Some kind of prerequisite mission to LS-1 (?)
   setCommsMessage("Granted.")
   progress["whAllow"] = true
end
function relayJC(s)
   jc1:sendCommsMessage(s, "Sending you a Jump Carrier now. Please stand by.")
   -- TODO
   local sx,sy = s:getPosition()
   -- HACK
   jc1:setPosition(sx+1000,sy+1000)
end
-- KLUDGE? Relay cannot invoke bidirection communications, only stn:sendCommsMessage(ship, "...") comms (?)
function relayDirs(s)
   local ar = 0
   msg = "Celestial body: [Sector @ Bearing from your current position]\n\n"
   --msg = ""
   ar = math.floor(angleRotation(s,bodies["Mercury"]["instance"])+90)
   if ar >= 360 then ar = ar-360 end
   msg=msg.."Mercury: ["..bodies["Mercury"]["instance"]:getSectorName().." @ "..ar.."]\n"
   ar = math.floor(angleRotation(s,bodies["Venus"]["instance"])+90)
   if ar >= 360 then ar = ar-360 end
   msg=msg.."Venus: ["..bodies["Venus"]["instance"]:getSectorName().." @ "..ar.."]\n"
   ar = math.floor(angleRotation(s,bodies["Earth"]["instance"])+90)
   if ar >= 360 then ar = ar-360 end
   msg=msg.."Earth: ["..bodies["Earth"]["instance"]:getSectorName().." @ "..ar.."]\n"
   ar = math.floor(angleRotation(s,bodies["Luna"]["instance"])+90)
   if ar >= 360 then ar = ar-360 end
   msg=msg.."Luna: ["..bodies["Luna"]["instance"]:getSectorName().." @ "..ar.."]\n"
   ar = math.floor(angleRotation(s,bodies["Mars"]["instance"])+90)
   if ar >= 360 then ar = ar-360 end
   msg=msg.."Mars: ["..bodies["Mars"]["instance"]:getSectorName().." @ "..ar.."]\n"
   if (checkTotalProgress() >= 3) or (#progress["juVisits"] > 0) then
      ar = math.floor(angleRotation(s,bodies["Jupiter"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Jupiter: ["..bodies["Jupiter"]["instance"]:getSectorName().." @ "..ar.."]\n"
      msg=msg.."JUPITER'S MOONS:\n"
      ar = math.floor(angleRotation(s,bodies["Io"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Io: ["..bodies["Io"]["instance"]:getSectorName().." @ "..ar.."], "
      ar = math.floor(angleRotation(s,bodies["Europa"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Europa: ["..bodies["Europa"]["instance"]:getSectorName().." @ "..ar.."], "
      ar = math.floor(angleRotation(s,bodies["Ganymede"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Ganymede: ["..bodies["Ganymede"]["instance"]:getSectorName().." @ "..ar.."], "
      ar = math.floor(angleRotation(s,bodies["Callisto"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Callisto: ["..bodies["Callisto"]["instance"]:getSectorName().." @ "..ar.."]\n"
   end
   if (checkTotalProgress() >= 4) or (progress["saturn"] > 0) then
      ar = math.floor(angleRotation(s,bodies["Saturn"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Saturn: ["..bodies["Saturn"]["instance"]:getSectorName().." @ "..ar.."]\n"
      msg=msg.."SATURN'S MOONS:\n"
      ar = math.floor(angleRotation(s,bodies["Mimas"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Mimas: ["..bodies["Mimas"]["instance"]:getSectorName().." @ "..ar.."], "
      ar = math.floor(angleRotation(s,bodies["Enceladus"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Enceladus: ["..bodies["Enceladus"]["instance"]:getSectorName().." @ "..ar.."], "
      ar = math.floor(angleRotation(s,bodies["Tethys"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Tethys: ["..bodies["Tethys"]["instance"]:getSectorName().." @ "..ar.."], "
      ar = math.floor(angleRotation(s,bodies["Rhea"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Rhea: ["..bodies["Rhea"]["instance"]:getSectorName().." @ "..ar.."], "
      ar = math.floor(angleRotation(s,bodies["Dione"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Dione: ["..bodies["Dione"]["instance"]:getSectorName().." @ "..ar.."], "
      ar = math.floor(angleRotation(s,bodies["Titan"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Titan: ["..bodies["Titan"]["instance"]:getSectorName().." @ "..ar.."]\n"
   end
   if (checkTotalProgress() >= 6) or (progress["outer"] > 1) then
      ar = math.floor(angleRotation(s,bodies["Uranus"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Uranus: ["..bodies["Uranus"]["instance"]:getSectorName().." @ "..ar.."]\n"
      ar = math.floor(angleRotation(s,bodies["Neptune"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Neptune: ["..bodies["Neptune"]["instance"]:getSectorName().." @ "..ar.."]\n"
      ar = math.floor(angleRotation(s,bodies["Pluto"]["instance"])+90)
      if ar >= 360 then ar = ar-360 end
      msg=msg.."Pluto: ["..bodies["Pluto"]["instance"]:getSectorName().." @ "..ar.."]\n"
   end
   stations["HN-HQ"]["instance"]:sendCommsMessage(s, msg)
end
function askForDirections(s,t)
   --s:addCustomButton("Relay", "relayDirs", _("relay-DirButton", "Directions"), function() relayDirs(s) end)
   --s:addCustomButton("AltRelay", "arelayDirs", _("relay-DirButton", "Directions"), function() relayDirs(s) end)
   --s:addCustomButton("Single", "singleDirs", _("relay-DirButton", "Directions"), function() relayDirs(s) end)

   setCommsMessage("The cartography office can tell you where any planet, moon, or Human Navy station is located.\n\nYour Relay (etc) console can also ask for directions via a special button.\n\nTo where?")

   -- Break into submenus just to keep the lists manageable for Comms Officer.
   addCommsReply("Find a planet or moon", askForDirPlanet)
   addCommsReply("Find a station", askForDirStation)
   addCommsReply("Back", hqComms)
end
function askForDirPlanet(s,t)
   setCommsMessage("Which celestial body do you need to locate?")
   for name,config in pairs(bodies) do
      if name ~= "Corona" then -- Hide it
	 addCommsReply(name, function()
			  if config["parent"] ~= "Sol" then
			     setCommsMessage(name .. " is orbiting planet " .. config["parent"] .. ". It is currently located in sector " .. getSectorName(config["instance"]:getPosition()))
			  else
			     setCommsMessage(name .. " is currently located in sector " .. getSectorName(config["instance"]:getPosition()))
			  end
	 end)
      end
   end
   addCommsReply("Back", askForDirections)
end
function askForDirStation(s,t)
   setCommsMessage("Which space station do you need to locate?")
   for name,config in pairs(stations) do
      local f = config["instance"]:getFaction()
      if f == "Human Navy" then
	 addCommsReply(name, function()
			  local sx, sy = config["instance"]:getPosition()
			  setCommsMessage("Human Navy station " .. name .. " is currently located in sector " .. getSectorName(config["instance"]:getPosition()))
	 end)
      elseif f == "Independent" then
	 addCommsReply(name, function()
			  local sx, sy = config["instance"]:getPosition()
			  -- Fudge the numbers a bit
			  sx = random(sx-30000, sx+30000)
			  sy = random(sy-30000, sy+30000)
			  setCommsMessage("Our long range radar suggests you might find the " .. config["faction"] .. " station " .. name .. " at approximately sector " .. getSectorName(sx, sy) .. ".\n\nHowever, please note that because this is not a Human Navy station our records may be a bit off.")
	 end)
      end
   end
   addCommsReply("Back", askForDirections)
end
function askForKraylor(s,t)
   s:addReputationPoints(100)
   setCommsMessage("In response to the Kraylor threat at the outer planets, a Human Navy Armada will be assembled at Earth's moon Luna. Please join them when you are fully prepared.")
   progress["outer"] = 3
   rally = Artifact():allowPickup(false):setScanningParameters(1,1):setDescriptions("Armada Rally Point","This is where the Human Navy Armada will assemble.")
   local m = bodies["Luna"]["instance"]
   local mx, my = m:getPosition()
   local mr = m:getPlanetRadius()
   setCirclePos(rally, mx, my, angleRotation(m, bodies["Earth"]["instance"]), mr * 3)
   for __ = 1,100 do
      table.insert(armada, CpuShip():setPosition(stations["LS-1"]["instance"]:getPosition()):setWarpDrive(true):setWarpSpeed(4000):orderDefendTarget(rally):setFaction("Human Navy"):setTemplate("Strikeship"):setCommsFunction(goComms):setScanned(true))
   end
end
function goComms(s,t)
   setCommsMessage("Are you sure you are ready to face the Kraylor?")
   addCommsReply("Sure, why not?", function() goTime() end)
end
function whComms(s,t)
   if progress["whAllow"] == false then
      setCommsMessage("Sorry but your crew has not been granted clearance to use Human Navy Worm Hole station. Please see the admiral at Human Navy Headquarters station HN-HQ to obtain clearance.")
      return
   end
   if s:isDocked(t) then
      setCommsMessage("Welcome to Human Navy Worm Hole station. From here you may travel to many of the planets in our system. Our worm holes last for " .. hnwh["whtimer"] .. " seconds. How may we assist you?")
      addCommsReply("To Mercury!", function() hnwhManager(t, bodies["Mercury"]["instance"]) end)
      addCommsReply("To Venus!", function() hnwhManager(t, bodies["Venus"]["instance"]) end)
      addCommsReply("To Mars!", function() hnwhManager(t, bodies["Mars"]["instance"]) end)
      if checkTotalProgress() > 2 then
	 addCommsReply("To Jupiter!", function() hnwhManager(t, bodies["Callisto"]["instance"]) end)
      end
      if checkTotalProgress() > 3 then
	 addCommsReply("To Saturn!", function() hnwhManager(t, bodies["Tethys"]["instance"]) end)
      end
      if checkTotalProgress() > 4 then
	 addCommsReply("To The Belt!", function() hnwhManager(t, bodies["Vesta"]["instance"]) end)
	 --if progress["outer"] > 0 then
	    addCommsReply("What's beyond?", function() hnwhManager(t, bodies["Uranus"]["instance"]) end)
	 --end
      end
   else
      setCommsMessage("Human Navy Worm Hole station is operating nominally. Please dock with us to request a worm hole.")
   end
end
-- This handles the variables associated with HN-WH station, then calls whToPlanet
function hnwhManager(s,p)
   if hnwh["whtime"] == nil then
      setCommsMessage("Done! The worm hole will last for " .. hnwh["whtimer"] .. " seconds.")
      local w = nil
      w = whToPlanet(s, p)
      hnwh["wh"] = w
      hnwh["whtime"] = getScenarioTime()
   else
      setCommsMessage("Please wait for the previous worm hole to vanish.")
      addCommsReply("Cancel the current hole", function()
		       hnwh["wh"]:destroy()
		       hnwh["wh"] = nil
		       hnwh["whtime"] = nil
		       setCommsMessage("Done.")
		       addCommsReply("Back", whComms)
      end)
   end
end
-- Creates a static worm hole from source s to planet p.
function whToPlanet(s, p)
   local w = WormHole()
   local sx, sy = s:getPosition()
   local ar = angleRotation(s, p)
   setCirclePos(w, sx, sy, ar, (distance(s, p) / 200000) + 5000)
   -- FIXME: Should be placed relative to source (?)
   local dx, dy = p:getPosition()
   local dr = p:getPlanetRadius()
   w:setTargetPosition(dx, dy-(dr*1.3))
   w:setCallSign("To " .. p:getCallSign())
   return w
end

-- LS-1 Comms
function lsComms(s,t)
   if s:isDocked(t) then
      setCommsMessage("Shipyard Lunar Station One (LS-1) is a busy port. You find it is written in a strange role playing style.\n\nYour crew collect their belongings and lock the ship's docking door. Where to?")
      addCommsReply("Visit the ship service bay.", lsCommsUpgrade)
      addCommsReply("Visit the lounge.", lsCommsLounge)
   end
end
function lsCommsUpgrade(s,t)
   setCommsMessage("The service bay has a pungent odour of grease and sweat. Sparks and metal shrapnel fly as workers toil on the endless backlog of ships in this high traffic area.\n\nYour crew examine the list of available ship mods on the board:")
   addCommsReply("Change warp maximum speed", lsCommsWarp)
--   if (checkTotalProgress() > 3) then
--      addCommsReply("Add Z-Axis Movement", lsCommsMove)
--   end
   addCommsReply("Change beam arc colour", lsCommsBeamColour)
   -- FIXME? Need Heat Beams for Mars terraforming, so allow them even if Mercury is failed.
   if (progress["mercury"] > 100) or ((progress["mercury"] > 0) and (s:getReputationPoints() >= 100)) then
      addCommsReply("Add yellow beam", lsCommsAddYellowBeam)
   end
   if checkGhosts() == 0 then
      addCommsReply("Add green beam", lsCommsAddGreenBeam)
   end
   if progress["mars"] >= 200 then
      addCommsReply("Add blue beam", lsCommsAddBlueBeam)
   end
   if #progress["juVisits"] >= 5 then
      addCommsReply("Add purple beam", lsCommsAddPurpleBeam)
   end
   if (progress["saturn"] >= 100) then
      addCommsReply("Add orange beam", lsCommsAddOrangeBeam)
   end
   addCommsReply("Back", lsComms)
end
function lsCommsMove(s,t)
   s:addCustomButton("Helms", "h-up", "Move Up", function()
			zoff = zoff - 2000
			for i,p in ipairs(bodies) do
			   p["instance"]:setDistanceFromMovementPlane(zoff)
			end
   end)
   s:addCustomButton("Helms", "h-zero", "Z-Center", function()
			zoff = 0
			for i,p in ipairs(bodies) do
			   p["instance"]:setDistanceFromMovementPlane(zoff)
			end
   end)
   s:addCustomButton("Helms", "h-down", "Move Down", function()
			zoff = zoff + 2000
			for i,p in ipairs(bodies) do
			   p["instance"]:setDistanceFromMovementPlane(zoff)
			end
   end)
   setCommsMessage("Your Helms officer (only, for now) can now move in the Z-Axis!")
   addCommsReply("Thanks!", lsComms)
end
function lsCommsWarp(s,t)
   setCommsMessage("How fast would you like to go?")
   addCommsReply("Regular speed", function()
		    s:setWarpSpeed(1000)
		    setCommsMessage("Bon voyage!")
		    s:addToShipLog("Set warp speed to 1x", "Green")
   end)
   addCommsReply("Faster", function()
		    s:setWarpSpeed(4000)
		    setCommsMessage("Bon voyage!")
		    s:addToShipLog("Set warp speed to 4x", "Green")
   end)
   addCommsReply("Very fast", function()
		    s:setWarpSpeed(7500)
		    setCommsMessage("Bon voyage!")
		    s:addToShipLog("Set warp speed to 7.5x", "Green")
   end)
   addCommsReply("Very very fast", function()
		    s:setWarpSpeed(10000)
		    setCommsMessage("Be careful!")
		    s:addToShipLog("Set warp speed to 10x", "Green")
   end)
   addCommsReply("LUDICROUS SPEED!", function()
		    s:setWarpSpeed(100000)
		    setCommsMessage("Good luck!!")
		    s:addToShipLog("Set warp speed to 100x", "Green")
   end)
   addCommsReply("Back", lsComms)
end
function lsCommsBeamColour(s,t)
   if s:getBeamWeaponRange(0) > 0 then
      -- NOTE: setBeamWeaponArcColor() only changes the arc viewed on the consoles,
      -- not the fired beam displayed on the main screen.
      setCommsMessage("This mod is purely cosmetic and will not change the firing of your beams at all.\n\nWhich colour would you like?")
      for name,values in pairs(barc_colours) do
	 addCommsReply("Make it " .. name, function()
			  local bi = 0
			  repeat
			     s:setBeamWeaponArcColor(bi, values[1],  values[2],  values[3],  values[4],  values[5], values[6])
			     bi = bi+1
			  until(s:getBeamWeaponRange(bi) < 1)
			  setCommsMessage("Your tactical views should now display " .. name .. " beam arcs.")
			  addCommsReply("Back", lsComms)
	 end
	 )
      end
      addCommsReply("Back", lsComms)
   else
      setCommsMessage("Your ship has no beams.")
   end
end
-- TODO: Add these buttons to "Single" screen too.
-- Yellow Beam is for Engineering(+) consoles.
-- Dissipates heat from ships' systems into target.
function lsCommsAddYellowBeam(s,t)
   if progress["mercury"] < 100 then
      if s:getReputationPoints() < 100 then
	 setCommsMessage("You failed to save the data from Icarus station during the CME, and now you want free upgrades? Come back later.\n\n(You need at least 100 rep)")
	 return
      else
	 s:takeReputationPoints(100)
      end
   end
   s:addCustomButton("Engineering", "e-yellowBeamButton", "Heat Beam", function() weaponBeamYellow(s) end)
   s:addCustomButton("Engineering+", "ep-yellowBeamButton", "Heat Beam", function() weaponBeamYellow(s) end)
   s:addCustomButton("PowerManagement", "pm-yellowBeamButton", "Heat Beam", function() weaponBeamYellow(s) end)
   s:addCustomButton("Single", "single-yellowBeamButton", "Heat Beam", function() weaponBeamYellow(s) end)
   setCommsMessage("Yellow beam added.\n\nYour Engineering consoles can use the yellow beam to dissipate heat from ship systems.")
   addCommsReply("Back", lsComms)
end
-- Orange Beam is for Weapons and Tactical consoles.
-- Requires 10s warm-up before firing; Causes immense heat to ship systems, but completely destroys target. 60s cooldown.
function lsCommsAddOrangeBeam(s,t)
   s:addCustomButton("Weapons", "w-orangeBeamButton", "Destruct Beam", function() weaponBeamOrange(s) end)
   s:addCustomButton("Tactical", "t-orangeBeamButton", "Destruct Beam", function() weaponBeamOrange(s) end)
   s:addCustomButton("Single", "single-orangeBeamButton", "Destruct Beam", function() weaponBeamOrange(s) end)
   setCommsMessage("Orange beam added.\n\nYour Weapons and Tactical consoles can use the orange beam. It has immense destructive power. Use with caution!")
   addCommsReply("Back", lsComms)
end
-- Blue Beam is for Science and Operations consoles.
-- Fires a single locator beam towards Earth.
function lsCommsAddBlueBeam(s,t)
   s:addCustomButton("Science", "s-blueBeamButton", "Homing beam", function() weaponBeamBlue(s) end)
   s:addCustomMessage("Science","s-blueBeam","Use the \"<\" and \">\" arrows to access the Homing Beam.")
   s:addCustomButton("Operations", "o-blueBeamButton", "Homing beam", function() weaponBeamBlue(s) end)
   s:addCustomMessage("Operations","o-blueBeam","Use the \"<\" and \">\" arrows to access the Homing Beam.")
   s:addCustomButton("Single", "single-blueBeamButton", "Homing beam", function() weaponBeamBlue(s) end)
   setCommsMessage("Blue beam added.\n\nYour Science and Operations consoles can use the blue beam to return to Earth. (HINT: Try clicking the \"<\" and \">\" arrows)")
   addCommsReply("Back", lsComms)
end
-- Purple Beam is for Relay console.
-- Converts target ship: Exuari,Kraylor => Independent, Independent => Ghost
function lsCommsAddPurpleBeam(s,t)
   s:addCustomButton("Relay", "r-purpleBeamButton", "Strange beam", function() weaponBeamPurple(s) end)
   s:addCustomButton("AltRelay", "ar-purpleBeamButton", "Strange beam", function() weaponBeamPurple(s) end)
   s:addCustomButton("Single", "single-purpleBeamButton", "Strange beam", function() weaponBeamPurple(s) end)
   setCommsMessage("Purple beam added.\n\nYour Relay console can use the purple beam. This technology was recently stolen from the Exuari, and we don't know what it does yet. Use with caution.")
   addCommsReply("Back", lsComms)
end
-- Green Beam is for Helm and Tactical consoles.
-- Tractors to target ship, ensuring relative distance.
function lsCommsAddGreenBeam(s,t)
   s:addCustomButton("Helms", "h-greenBeamButton", "Tracking beam", function() weaponBeamGreen(s) end)
   s:addCustomButton("Tactical", "t-greenBeamButton", "Tracking beam", function() weaponBeamGreen(s) end)
   s:addCustomButton("Single", "single-greenBeamButton", "Tracking beam", function() weaponBeamGreen(s) end)
   setCommsMessage("Green beam added.\n\nYour Helm and Tactical consoles can use the green beam to hold the target.")
   addCommsReply("Back", lsComms)
end
function lsCommsLounge(s,t)
   msg = "A colourful variety of ships' crews are enjoying the relaxed atmosphere of the lounge.\n\nYou see a fellow Human Navy crew."
   -- FIXME: When should these appear? Make sure they become possible
   if (progress["mercury"] > 0) and
      (progress["venus"] > 0) and
      (progress["mars"] > 0) and
      (#progress["juVisits"] > 0) and
      (progress["belt"] <= 1) then
      msg = msg .. "\nYou see some Beltians."
   end
   if progress["outer"] == 0 then
      msg = msg .. "\nYou see some tall, slim, shady character hiding in the corner."
   end
   msg = msg .. "\nYou see a crew of maintenance workers."
   setCommsMessage(msg)
   addCommsReply("Buy the HN crew a drink", lsCommsLoungeHN)
   if (progress["mercury"] > 0) and
      (progress["venus"] > 0) and
      (progress["mars"] > 0) and
      (#progress["juVisits"] > 0) and
      (progress["belt"] <= 1) then
      addCommsReply("Approach the Beltians", lsCommsLoungeBelt)
   end
   if progress["outer"] == 0 then
      addCommsReply("Sit with the shady character", lsCommsLoungeShady)
   end
   addCommsReply("Talk to the maintenance crew", lsCommsLoungeWorkers)
   addCommsReply("Back", lsComms)
end
function lsCommsLoungeHN(s,t)
   setCommsMessage("\"WOW! Thanks, friends! If you ever need assistance give us a shout.\"\n\nThey seemed to really appreciate your generosity.")
   addCommsReply("Back", lsCommsLounge)
   s:addCustomButton("Relay", "relayFriends", "Send Backup", function() relayFriends(s) end)
   s:addCustomButton("AltRelay", "arelayFriends", "Send Backup", function() relayFriends(s) end)
   s:addCustomButton("Single", "singleFriends", "Send Backup", function() relayFriends(s) end)
end
function relayFriends(ship)
   if ship:getReputationPoints() >= 100 then
      ship:takeReputationPoints(100)
      local sx,sy = ship:getPosition()
      local rx = random(-7000,7000)
      local ry = random(-7000,7000)
      CpuShip():setTemplate("Strikeship"):setFaction("Human Navy"):setPosition(sx+rx, sy+ry):sendCommsMessage(ship, "We've got your back!"):orderDefendTarget(ship)
      ship:removeCustom("relay-HNButton")
   else
      if ship:hasPlayerAtPosition("Relay") then ship:addCustomMessage("Relay", "relay-unrep", "Not enough reputation.") end
      if ship:hasPlayerAtPosition("AltRelay") then ship:addCustomMessage("AltRelay", "arelay-unrep", "Not enough reputation.") end
   end
end
function lsCommsLoungeBelt(s,t)
   setCommsMessage("The Beltians do not always trust Human Navy officers, and your uniforms are a dead giveaway. They seem a bit apprehensive.\n\n\"What do you want, Earthling?\"")
   addCommsReply("Tell us about the Belt", lsCommsLoungeBeltBelt)
   addCommsReply("What is your name?", lsCommsLoungeBeltName)
   addCommsReply("You don't like us?", lsCommsLoungeBeltLike)
end
function lsCommsLoungeBeltBelt(s,t)
   setCommsMessage("\"We Beltians are proud of our accomplishments in establishing ourselves in the lifeless asteroid belt. It's been hard work and I doubt you Earthlings have the strength for what we do.\"\n\nThe Beltians chuckle a little, in your direction.\n\n\"Still, we invite you to visit our colonies. There's lots of fun to be had.\"")
   addCommsReply("What is your name?", lsCommsLoungeBeltName)
   addCommsReply("Back", lsCommsLounge)
end
function lsCommsLoungeBeltName(s,t)
   setCommsMessage("The lead Beltian puts his mug of ale down, and stares your captain in the eye for a moment.\n\n\"My name is Bagu. What's yours?\"")
   addCommsReply("Joey Jo-Jo Jr. Shabadu", lsCommsLoungeBeltNameJoey)
   addCommsReply("<Remain Silent>", lsCommsLoungeBeltNameSilent)
end
function lsCommsLoungeBeltNameJoey(s,t)
   progress["belt"] = 1
   setCommsMessage("The Beltians all laugh histerically!\n\n\"That's a stupid name!\"\n\nYou met the Beltians.")
   s:addToShipLog("You met the Beltians.", "Green")
   addCommsReply("Back", lsCommsLounge)
end
function lsCommsLoungeBeltNameSilent(s,t)
   setCommsMessage("The Beltians all stand up slowly, as if looking to pick a fight with you.")
   addCommsReply("Pick a fight!", lsCommsLoungeBeltFight)
   addCommsReply("Back", lsCommsLounge)
end
function lsCommsLoungeBeltLike(s,t)
   setCommsMessage("Your blunt manner does not go over well with the Beltians, it seems.\n\n\"No, Earthling, we don't! The Human Navy thinks it can come tell us what to do, and treat us like garbage. Frankly, it's disrepectful. Are you any different?\"")
   addCommsReply("Just walk away", lsCommsLoungeBeltWalk)
   addCommsReply("<Remain Silent>", lsCommsLoungeBeltLikeSilent)
   addCommsReply("\"You are garbage\"", lsCommsLoungeBeltFight)
end
function lsCommsLoungeBeltWalk(s,t)
   setCommsMessage("You turn to walk away, but the Beltians block your path!")
   addCommsReply("Fight 'em!", lsCommsLoungeBeltFight)
   addCommsReply("Sit back down", lsCommsLounge)
end
function lsCommsLoungeBeltLikeSilent(s,t)
   setCommsMessage("The Beltian engineer spits on the floor at your feet.\n\n\"We have nothing to say to you, either.\"")
   addCommsReply("Back", lsCommsLounge)
end
function lsCommsLoungeBeltFight(s,t)
   local players = {}
   -- NOTE: These can be used case-insensitively
   local seats = {"helms", "weapons", "engineering", "science", "relay", "tactical", "engineering+", "operations", "single", "damagecontrol", "powermanagement", "database", "altrelay", "commsonly", "shiplog"}
   for i,p in ipairs(seats) do
      if s:hasPlayerAtPosition(p) then
	 table.insert(players,p)
      end
   end
   -- KLUDGE? Assume that there is at least one element in players now,
   -- otherwise who is doing the Comms??
   local beltians = irandom(math.floor(#players / 2), #players * 2)
   local rp = irandom(1,#players)
   local bp = irandom(1,#players)
   --local msg = "Your " .. players[rp] .. " officer takes a swing at the Beltian " .. seats[bp] .. " officer! A massive brawl erupts!!\n\nYou have " .. #players .. " officers.\nThe Beltians have " .. beltians .. ".\n\nYou are "
   if #players > beltians then
      progress["belt"] = 1
      setCommsMessage("Your " .. players[rp] .. " officer takes a swing at the Beltian " .. seats[bp] .. " officer! A massive brawl erupts!!\n\nYou have " .. #players .. " officers.\nThe Beltians have " .. beltians .. ".\n\nYou are victorious! The Beltians lie in a heap on the floor. You take one of their identity badges as a trophy.")
      s:addToShipLog("You met the Beltians.", "Green")
      addCommsReply("Awesome!", lsCommsLounge)
   elseif #players == beltians then
      setCommsMessage("Your " .. players[rp] .. " officer takes a swing at the Beltian " .. seats[bp] .. " officer! A massive brawl erupts!!\n\nYou have " .. #players .. " officers.\nThe Beltians have " .. beltians .. ".\n\nYou are locked in a fierce but equal struggle! Brew bottles fly in every direction, as the entire lounge descends into violent chaos.\n\nAfter a few minutes, things calm down and the band starts up again.")
      addCommsReply("Oh, well...", lsCommsLounge)
   else
      setCommsMessage("Your " .. players[rp] .. " officer takes a swing at the Beltian " .. seats[bp] .. " officer! A massive brawl erupts!!\n\nYou have " .. #players .. " officers.\nThe Beltians have " .. beltians .. ".\n\nYou are pummeled! The Beltians overwhelm your crew and leave you lying in a heap on the floor.\n\nLater, you wake up feeling confused.")
      addCommsReply("OUCH!", lsComms)
   end
end
function lsCommsLoungeShady(s,t)
   setCommsMessage("The slim figure seems twitchy as you approach in your Human Navy uniforms.\n\n\"Uhhh, what can I do for you, officers?\"")
   addCommsReply("Heard any rumours?", lsCommsLoungeShadyRumours)
   addCommsReply("Whatever", lsCommsLounge)
end
function lsCommsLoungeShadyRumours(s,t)
   progress["outer"] = 1
   setCommsMessage("The tall being stands up, towering over your crew.\n\n\"Okay but you didn't hear this from me... The last time I passed by Neptune, I met some Kraylor. Did you know they are in your system already? I've said too much already. I must depart.\"\n\nThe person turns towards the shadows, walks into them, and disappears.")
   addCommsReply("How odd...", lsCommsLounge)
end
function lsCommsLoungeWorkers(s,t)
   setCommsMessage("You sit down with the crew of maintenance workers. A strange odour causes your crew some mild discomfort.\n\n\"What brings yer fancy coats down here with us plebs?\"")
   addCommsReply("What are you working on?", lsCommsLoungeWorkersJob)
end
function lsCommsLoungeWorkersJob(s,t)
   setCommsMessage("\"We've been cleanin' up ole junk from those olden days of space exploration. Our current job is decommissioning MOSS station at LEO. It's a dirty job, too dirty for you fancy coats!\"\n\nThe other workers laugh at you a little.")
   addCommsReply("We could help", lsCommsLoungeWorkersMoss)
   addCommsReply("You're probably right", lsCommsLounge)
end
function lsCommsLoungeWorkersMoss(s,t)
   setCommsMessage("You offer your assistance to the lead worker. They all seem shocked by your generosity.\n\n\"Hah, okay fancy coat! But it smells some aweful on that musky olde sewage scow! Don't say we didn't warn y'all.\"\n\nThe lead worker hands you a key to the station.")
   addCommsReply("Take the key", lsCommsLoungeWorkersMossKey)
   addCommsReply("On second thought", lsCommsLounge)
end
function lsCommsLoungeWorkersMossKey(s,t)
   progress["mars"] = 1
   setCommsMessage("\"Here ya go. Just sweep all that crap out the airlock. Thanks again!\"")
   addCommsReply("Back", lsCommsLounge)
end

function moComms(s,t)
   if s:isDocked(t) == false then
      setCommsMessage("There is no one on this abandoned station to hear your calls.")
   else
      msg = "As the dock sealing completes, a foul stench begins to woft through your ship's air circulation system. Everyone feels a bit queazy...\n\n"
      if progress["mars"] == 0 then
	 msg = msg .. "The door is locked."
	 setCommsMessage(msg)
	 return
      else
	 msg = msg .. "You unlock the docking door and step inside. The inside is musky and foul. A damp humidity permeates the air, and you see moss and algae and weird plants growing all over the place."
      end
      setCommsMessage(msg)
      addCommsReply("Search the station", moCommsSearch)
      addCommsReply("Just leave", moCommsLeave)
   end
end
function moCommsSearch(s,t)
   progress["mars"] = 2
   local bi = 0
   repeat
      local values = barc_colours[irandom(1,#barc_colours)]
      s:setBeamWeaponArcColor(bi, values[1],  values[2],  values[3],  values[4],  values[5], values[6])
      bi = bi+1
   until(s:getBeamWeaponRange(bi) < 1)
   setCommsMessage("As you walk about, you realize that the mouldy spores are everywhere, in the air, and on your clothes. This place is disgusting.")
   addCommsReply("Best leave, then", moCommsLeave)
end
function moCommsLeave(s,t)
   setCommsMessage("You seal the docking doors, then throw up a little.")
end

-- FIXME: Beams should originate from the ship's beam[1] position if exists, otherwise (0,0,0)
--function findBeamSpot(ship)
--   if ship:getBeamWeaponRange(1) > 0 then
      -- TODO: Locate the source for Beam(0), otherwise
      -- fire the beam from (0,0,0)
--   end
--   return nil
--end
-- Blue Beam is for Science, to locate the path to Earth
function weaponBeamBlue(ship)
   if ship.beam_counters["blue"] > getScenarioTime() then
      return
   end
   --local bsx, bsy, bsz = findBeamSpot(ship)
   --BeamEffect():setSource(ship,bsx, bsy, bsz):setTarget(Earth,0,0):setDuration(1):setRing(false):setTexture("texture/beam_blue.png")
   if (unknown ~= nil) and (distance(ship, unknown) <= 3000) then
      BeamEffect():setSource(ship,0,0,0):setTarget(unknown,0,0):setDuration(1):setRing(false):setTexture("texture/beam_blue.png")
      spriteHit(ship, "blue")
   else
      local sx,sy = ship:getPosition()
      --local sh = ship:getHeading()
      local sh = angleRotation(ship, bodies["Earth"]["instance"])
      if another ~= nil then another:destroy() end
      another = Artifact():allowPickup(false):setScanningParameters(1,1):setDescriptions("Wormhole","Wait for it...")
      setCirclePos(another, sx, sy, sh, 1000)
      BeamEffect():setSource(ship,0,0,0):setTarget(another,0,0):setDuration(5):setRing(false):setTexture("texture/beam_blue.png")
      ship:setSystemHeat("Warp", ship:getSystemHeat("Warp") + 1.0)
      ship.beam_counters["blue"] = getScenarioTime() + 300
      ship.beam_angle = sh
      ship.beam_distance = 1000
   end
end
-- DOC: ESystem: "reactor", "beamweapons", "missilesystem", "maneuver", "impulse", "warp", "jumpdrive", "frontshield", "rearshield"
function weaponBeamYellow(ship)
   if ship.beam_counters["yellow"] > getScenarioTime() then
      return
   end
   if (unknown ~= nil) and (distance(ship, unknown) <= 3000) then
      BeamEffect():setSource(ship,0,0,0):setTarget(unknown,0,0):setDuration(1):setRing(false):setTexture("texture/beam_yellow.png")
      spriteHit(ship, "yellow")
   else
      local t = ship:getTarget()
      if (t ~= nil) and (getScenarioTime() > ship.beam_counters["yellow"]) then
	 --local bsx, bsy, bsz = findBeamSpot(ship)
	 local th = 0
	 for i,sys in ipairs(all_systems) do
	    if ship:hasSystem(sys) then
	       th = th + ship:getSystemHeat(sys)
	       ship:setSystemHeat(sys, 0)
	    end
	 end
	 local dobeam = false
	 if ((t == stations["Mars-1"]["instance"]) or (t == stations["Mars-2"]["instance"]) or (t == stations["Mars-3"]["instance"])) and (th >= 0.5) then
	    dobeam = true
	    marsHeat(t)
	 elseif (distance(ship, t) <= 2600) then
	    dobeam = true
	    t:setHull(t:getHull() - (th*100))
	 end
	 if dobeam then
	    ship.beam_counters["yellow"] = (getScenarioTime() + 15)
	    t.beam = BeamEffect():setSource(ship,0,0,0):setTarget(t,0,0):setDuration(0.3):setRing(false):setTexture("texture/beam_yellow.png")
	 end
      end
   end
end
function weaponBeamOrange(ship)
   if ship.beam_counters["orange"] > getScenarioTime() then
      return
   end
   if (unknown ~= nil) and (distance(ship, unknown) <= 3000) then
      BeamEffect():setSource(ship,0,0,0):setTarget(unknown,0,0):setDuration(1):setRing(true):setTexture("texture/beam_orange.png")
      spriteHit(ship, "orange")
   else
      local t = ship:getTarget()
      if (t ~= nil) then
	 if (getScenarioTime() > ship.beam_counters["orange"]) and (distance(t,ship) <= 3000) then
	    --local bsx, bsy, bsz = findBeamSpot(ship)
	    BeamEffect():setSource(ship,0,0,0):setTarget(t,0,0):setDuration(5):setRing(false):setTexture("texture/beam_orange.png")
	    ship.beam_counters["orange"] = (getScenarioTime() + 65)
	    ship.prevTarget = t
	 end
      end
   end
end
function weaponBeamPurple(ship)
   if ship.beam_counters["purple"] > getScenarioTime() then
      return
   end
   if (unknown ~= nil) and (distance(ship, unknown) <= 3000) then
      BeamEffect():setSource(ship,0,0,0):setTarget(unknown,0,0):setDuration(1):setRing(false):setTexture("texture/beam_purple.png")
      spriteHit(ship, "purple")
   else
      local t = ship:getTarget()
      local tf = t:getFaction()
      if t ~= nil then
	 BeamEffect():setSource(ship,0,0,0):setTarget(ship:getTarget(t),0,0):setDuration(1):setRing(true):setTexture("texture/beam_purple.png")
	 --local bsx, bsy, bsz = findBeamSpot(ship)
	 -- Factions: "Independent", "Kraylor", "Arlenians", "Exuari", "Ghosts", "Ktlitans", "TSN", "USN", "CUF" (factionInfo.lua)
	 if tf == "Independent" then t:setFaction("TSN")
	 elseif tf == "TSN" then t:setFaction("CUF")
	 elseif tf == "CUF" then t:setFaction("USN")
	 elseif tf == "USN" then t:setFaction("Ktlitans")
	 elseif tf == "Ktlitans" then t:setFaction("Ghosts")
	 elseif tf == "Ghosts" then t:setFaction("Exuari")
	 elseif tf == "Kraylor" then t:setFaction("Human Navy") -- !!
	 elseif t == stations["Titania"]["instance"] then makePeace()
	 elseif tf == "Exuari" then
	    for i,es in ipairs(eships) do
	       if t==es then
		  numex=numex-1
		  if (numex < 5) and (progress["saturn"] < 100) then makePeace() end
	       end
	    end
	    t:setFaction("Independent")
	 elseif tf == "Human Navy" then t:sendCommsMessage(ship, "Hey, watch it with that thing!")
	 end

	 ship.beam_counters["purple"] = (getScenarioTime() + 30)
      end
   end
end
function weaponBeamGreen(ship)
   if ship.beam_counters["green"] > getScenarioTime() then
      return
   end
   if (unknown ~= nil) and (distance(ship, unknown) <= 3000) then
      BeamEffect():setSource(ship,0,0,0):setTarget(unknown,0,0):setDuration(1):setRing(false):setTexture("texture/beam_green.png")
      spriteHit(ship, "green")
   else
      local t = ship:getTarget()
      if t ~= nil then
	 ship.prevTarget = t
	 --local bsx, bsy, bsz = findBeamSpot(ship)
	 BeamEffect():setSource(ship,0,0,0):setTarget(t,0,0):setDuration(10):setRing(false):setTexture("texture/beam_green.png")
	 ship.beam_counters["green"] = (getScenarioTime() + 15)
	 ship.beam_angle = angleRotation(ship,t)
	 ship.beam_distance = distance(ship,t)
      end
   end
end

-- TODO: Venus Mission is to clean up a few Ghost stations
-- Reward is Orange Destruction Beam
-- TODO: Add beam turrets to VE-IX or enclose it in orbital beam turrets
-- TODO: Warn player ships if VE-IX damaged.
function veComms(s,t)
   if checkGhosts() == 0 then
      setCommsMessage("Thanks for helping us eliminate those bothersome ghosts. Business is booming once again!\n\nShipyard LS-1 has new upgrades for your ships.")
   elseif s:isDocked(t) then
      setCommsMessage("Welcome to Venus 9, the HOTTEST tourist destination this side of Mercury!\n\nWe hope you enjoy your stay!")
      addCommsReply("What news?", veStart)
   elseif (progress["venus"] > 0) and (checkGhosts() > 0) then
      setCommsMessage("Yes?")
      addCommsReply("Any idea where?", veDirections)
   else
      setCommsMessage("Hello from Venus 9. Please dock if you need anything.")
   end
end
function veStart(s,t)
   makeGhostShips()
   progress["venus"] = 1
   setCommsMessage("For weeks we've been getting bothered by some nasty ghost ships. Our station is secure but our sales have slumped this quarter!\n\nPlease track down and eliminate the ghost stations for us. You will be rewarded.")
   addCommsReply("Any idea where?", veDirections)
end
function veDirections(s,t)
   local where = ""
   for i,stn in ipairs(ghost_stns) do
      if stn:isValid() then
	 local ar = math.floor(angleRotation(stations["VE-IX"]["instance"], stn)) + 90
	 if ar >= 360 then ar = ar - 360 end
	 where = where .. "We've seen them come from " .. ar .. " degrees.\n"
      end
   end
   setCommsMessage("We're not too sure, but it's probably where these pests are coming from.\n\n" .. where)
end

-- TODO: Mars mission is to terraform the planet. Requires Heat Beam to hit each orbital platform,
-- causing heat release to core of planet. When all platforms heated, planet shakes, adjusts
-- atmosphere colour, and then swaps surface texture to terraformed image.
function maComms(s,t)
   if t.heating ~= 0 then
      setCommsMessage("Mars Terraforming Platform " .. t:getCallSign() .. " is active.")
   else
      setCommsMessage(t:getCallSign() .. " is cold.")
   end
end
function marsHeat(stn)
   if stations["Mars-1"]["instance"].heating > 0 then stations["Mars-1"]["instance"].heating = getScenarioTime()+180 end
   if stations["Mars-2"]["instance"].heating > 0 then stations["Mars-2"]["instance"].heating = getScenarioTime()+180 end
   if stations["Mars-3"]["instance"].heating > 0 then stations["Mars-3"]["instance"].heating = getScenarioTime()+180 end
   stn.heating = getScenarioTime() + 180
   BeamEffect():setSource(stn,0,0,0):setTarget(bodies["Mars"]["instance"],0,0):setDuration(180):setRing(false):setTexture("texture/beam_yellow.png")
   for i,ship in ipairs(ships) do
      if ship:hasPlayerAtPosition("Science") then
	 ship:addCustomMessage("Science","science-mars","Mars Terraforming Heaters: " .. marsUpdate() .. "\n\nYou have 3 minutes to engage the next Heater.")
      end
      if ship:hasPlayerAtPosition("Operations") then
	 ship:addCustomMessage("Operations","science-mars","Mars Terraforming Heaters: " .. marsUpdate() .. "\n\nYou have 3 minutes to engage the next Heater.")
      end
   end
end
function marsUpdate()
   local heaters = 0
   local ms = stations["Mars-1"]["instance"]
   if ms == nil then return 0 end
   if (ms.heating ~= 0) and ms.heating > getScenarioTime() then heaters = heaters + 1 else ms.heating = 0 end
   local ms = stations["Mars-2"]["instance"]
   if ms == nil then return 0 end
   if (ms.heating ~= 0) and ms.heating > getScenarioTime() then heaters = heaters + 1 else ms.heating = 0 end
   local ms = stations["Mars-3"]["instance"]
   if ms == nil then return 0 end
   if (ms.heating ~= 0) and ms.heating > getScenarioTime() then heaters = heaters + 1 else ms.heating = 0 end
   if heaters == 3 then marsForm() end
   return heaters
end
-- This is where the magic happens
function marsForm()
   if progress["mars"] > 200 then return end
   if progress["mars"] < 100 then
      progress["mars"] = progress["mars"] + 100
      for i,ship in ipairs(ships) do
	 if ship:hasPlayerAtPosition("Science") then
	    ship:addCustomMessage("Science","science-mars","Mars Terraforming has begun!!")
	 end
	 if ship:hasPlayerAtPosition("Operations") then
	    ship:addCustomMessage("Operations","science-mars","Mars Terraforming has begun!!")
	 end
      end
   end
   local m = bodies["Mars"]["instance"]
   local mx,my = m:getPosition()
   local mr = m:getPlanetRadius()
   -- FIXME: Fancy gfx!
   if (spare == nil) and (progress["mars"] < 200) then
      spare = makeBody("Mars")
      spare.created = getScenarioTime()
   elseif (progress["mars"] < 200) and ((spare.created+20) > getScenarioTime()) then
      local xo = irandom(-1000,1000)
      local yo = irandom(-1000,1000)
      local zo = irandom(-1000,1000)
      local co = random(mr*1.01, mr*1.1)
      spare:setPosition(mx+xo, my+yo)
      spare:setDistanceFromMovementPlane(zo)
      spare:setPlanetCloudRadius(co)
      -- FIXME: Gradual atmo gradient towards that of Earth
      --local diff = ((spare.created+20) - getScenarioTime()) / 20 -- 0 => 1
      --local r = bodies["Mars"]["atmo_r"] + ((bodies["Mars"]["atmo_r"] - bodies["Earth"]["atmo_r"]) * diff)
      --local g = bodies["Mars"]["atmo_g"] + ((bodies["Mars"]["atmo_g"] - bodies["Earth"]["atmo_g"]) * diff)
      --local b = bodies["Mars"]["atmo_b"] + ((bodies["Mars"]["atmo_b"] - bodies["Earth"]["atmo_b"]) * diff)
      spare:setPlanetAtmosphereColor(r,g,b)
   elseif spare ~= nil then -- Done terraforming!
      progress["mars"] = progress["mars"] + 100
      msg = "Mars Terraforming completed!"
      if progress["mars"] == 202 then msg=msg.." ... But something seems odd." end
      for i,ship in ipairs(ships) do
	 if ship:hasPlayerAtPosition("Science") then
	    ship:addCustomMessage("Science","science-mars",msg)
	 end
	 if ship:hasPlayerAtPosition("Operations") then
	    ship:addCustomMessage("Operations","ops-mars",msg)
	 end
	 if ship:hasPlayerAtPosition("Single") then
	    ship:addCustomMessage("Single","single-mars",msg)
	 end
	 stations["HN-HQ"]["instance"]:sendCommsMessage(ship, msg.."\n\nShipyard Lunar Station One [LS-1] has new upgrades available.")
      end
      broadcastLog(msg)
      -- FIXME: Try everything...
      spare:setPlanetRadius(1)
      local sx,sy = bodies["Sol"]["instance"]
      setCirclePos(spare, sx, sy, 225, 100)
      spare:destroy()
      --spare = nil

      bodies["Mars"]["radius"] = solScaleRad(3400000) -- KLUDGE: Slightly larger !!
      bodies["Mars"]["angle"] = angleRotation(bodies["Earth"]["instance"], bodies["Mars"]["instance"])
      bodies["Mars"]["texture"] = "planets/hd/mars-2.png"
      bodies["Mars"]["atmo_r"] = bodies["Earth"]["atmo_r"]
      bodies["Mars"]["atmo_g"] = bodies["Earth"]["atmo_g"]
      bodies["Mars"]["atmo_b"] = bodies["Earth"]["atmo_b"]
      bodies["Mars"]["instance"] = makeBody("Mars")

      -- KLUDGE? Swapping Mars surface texture failed; Recreate it instead (?)
      --bodies["Mars"]["texture"] = "planets/Mars/mars-2.png"
      --bodies["Mars"]["atmo_r"] = bodies["Earth"]["atmo_r"]
      --bodies["Mars"]["atmo_g"] = bodies["Earth"]["atmo_g"]
      --bodies["Mars"]["atmo_b"] = bodies["Earth"]["atmo_b"]
      --m:setPlanetSurfaceTexture("planets/Mars/mars-2.png")
      --bodies["Mars"]["instance"]:setPlanetSurfaceTexture("planets/Mars/mars-2.png")
      ---m:setPlanetAtmosphereColor(bodies["Earth"]["atmo_r"], bodies["Earth"]["atmo_g"], bodies["Earth"]["atmo_b"])

      -- KLUDGE
      --local ppx,ppy = bodies["Phobos"]["instance"]:getPosition()
      --local dpx,dpy = bodies["Deimos"]["instance"]:getPosition()
      --m:setPlanetRadius(1)
      --m:destroy()
      --m = nil
      --bodies["Mars"]["instance"]:setPlanetRadius(1)
      --bodies["Mars"]["instance"]:destroy()
      --bodies["Mars"]["instance"] = nil
      --bodies["Mars"]["instance"] = makeBody("Mars")
      -- KLUDGE? Dunno if this is needed but it seems like a good idea (?)
      --bodies["Phobos"]["instance"] = makeBody("Phobos")
      --bodies["Phobos"]["instance"]:setPosition(ppx,ppy)
      --bodies["Deimos"]["instance"] = makeBody("Deimos")
      --bodies["Deimos"]["instance"]:setPosition(dpx,dpy)
   end
end

-- TODO: On arrival at Belt, spawn the sprite. It will jump around to a few locations every few seconds
-- but will stop moving if any player ship is nearby. Hit with special Beams to advance towards
-- the other Belt body. On arrival, Prizes! (collectable upgrades)
-- Each hit with coloured Beam should add to ships log such as "Teehee! That tickles!" in the appropriate colour.
function beComms(s,t)
   if progress["belt"] == 0 then
      setCommsMessage("What do you want, Earthling?")
      addCommsReply("Directions", beDirs)
   elseif progress["belt"] < 100 then
      setCommsMessage("You know Bagu? Then I can tell you something.\n\nFollow the sprite to make your way to Ceres.")
      addCommsReply("Thanks!", beComms)
      addCommsReply("Directions", beDirs)
   else
      setCommsMessage("Seems you've already toured what the belt has to offer.")
      addCommsReply("Okay", beComms)
   end
end
function beDirs(s,t)
   if progress["belt"] == 0 then
      setCommsMessage("There's nothing for you here, Earthling. Go home.")
      addCommsReply("Back", beComms)
   else
      setCommsMessage(string.format("Ceres is located in sector [%s], at bearing %f from here", getSectorName(bodies["Ceres"]["instance"]:getPosition()), angleRotation(bodies["Vesta"]["instance"], bodies["Ceres"]["instance"])+90))
      addCommsReply("Back", beComms)
   end
end

function sprite()
   if (progress["belt"] > 0) and (unknown == nil) then
      unknown = Artifact():allowPickup(false):setScanningParameters(1,1):setDescriptions("Something odd.","TEE-HEE! Bring me colours!!"):setModel("artifact1"):setRadarSignatureInfo(1,1,1)
      progress["belt"] = progress["belt"] + 1
      unknown.timer = getScenarioTime()
      unknown.hitwith = {}
   elseif (progress["belt"] > 1) and (progress["belt"] < 8) and (unknown.timer+3 < getScenarioTime()) then
      local vx,vy = bodies["Vesta"]["instance"]:getPosition()
      local vr = bodies["Vesta"]["instance"]:getPlanetRadius()
      local closest = distance(bodies["Sol"]["instance"], bodies["Neptune"]["instance"]) -- HACK
      for i,ship in ipairs(ships) do
	 local d = distance(ship, unknown)
	 if d < closest then closest = d end
      end
      if (closest > 7000) then
	 local p = progress["belt"] - 1
	 -- FIXME: Should match the special beam colours
	 --local c = unknown_colours[irandom(1,$unknown_colours)]
	 --unknown:setRadarTraceColor(c[1], c[2], c[3])
	 unknown:setRadarTraceColor(irandom(0,255), irandom(0,255), irandom(0,255))
	 setCirclePos(unknown, vx, vy, (60 * p), 10000)
	 progress["belt"] = progress["belt"] + 1
	 if progress["belt"] == 8 then progress["belt"] = 2 end
      end
      unknown.timer = getScenarioTime()
   end
end
function spriteHit(ship, bc)
   for i,seen in ipairs(unknown.hitwith) do
      if seen == bc then
	 --progress["belt"] = 1
	 ship:addToShipLog("OUCH!", "Red")
	 --unknown.hitwith = {}
	 if (#unknown.hitwith < 5) then
	    return
	 end
      end
   end
   table.insert(unknown.hitwith, bc)
   if progress["belt"] < 10 then
      progress["belt"] = 10
   end
   if progress["belt"] < 15 then
      -- FIXME: Colours
      local logc = "Green"
      if bc == "blue" then       logc = "Cyan"
      elseif bc == "yellow" then logc = "Yellow"
      elseif bc == "orange" then logc = "#ff8000"
      elseif bc == "purple" then logc = "White"   -- "Magenta" came out blackish
      elseif bc == "green" then	 logc = "Green"
      end
      ship:addToShipLog("Tee hee! That tickles!", logc)
      local vx,vy = bodies["Vesta"]["instance"]:getPosition()
      local vcr = angleRotation(bodies["Vesta"]["instance"], bodies["Ceres"]["instance"])
      local vcd = distance(bodies["Vesta"]["instance"], bodies["Ceres"]["instance"])
      setCirclePos(unknown, vx, vy, vcr, ((vcd/5)*(progress["belt"]-9)-(bodies["Ceres"]["instance"]:getPlanetRadius()*2)))
      local c = unknown_colours[bc]
      unknown:setRadarTraceColor(c[1], c[2], c[3])
      if ship:hasPlayerAtPosition("Science") then
	 ship:addCustomMessage("Science","science-sprite","Tee hee! Pretty colours!")
      end
      if ship:hasPlayerAtPosition("Operations") then
	 ship:addCustomMessage("Operations","ops-sprite","Tee hee! Pretty colours!")
      end
      if ship:hasPlayerAtPosition("Single") then
	 ship:addCustomMessage("Single","single-sprite","Tee hee! Pretty colours!")
      end
      progress["belt"] = progress["belt"] + 1
   else
      unknown:setCallSign("Friendly Sprite")
      unknown:sendCommsMessage(ship, "I like your pretty beams! Please enjoy this Ceres bounty.")
      ship:addToShipLog("Ceres Secrets Discovered!", "Green")
      local c = bodies["Ceres"]["instance"]
      local cx,cy = c:getPosition()
      local cr = c:getPlanetRadius()
      -- FIXME: This should sprinkle bounty all around Ceres
      --local na = Artifact():setModel("ammo_box"):allowPickup(true):onPickUp(function(a,s)
--      na = Artifact()
--      setCirclePos(na, cx, cy, random(0, 360), cr*1.5)
--      na:allowPickup(true):setScanningParameters(1,1):setDescriptions("Big ammo crate","20 Nukes")
--      na:onPickUp(function(na,s) s:setWeaponStorage("Nuke", s:getWeaponStorage("Nuke")+20); s:addToShipLog("Added 20 Nukes!", "Green") end)
--      ea = Artifact():setModel("ammo_box"):allowPickup(true):setScanningParameters(1,1):setDescriptions("Big ammo crate","20 EMPs")
--      ea:onPickUp(function(a,s)
--	    s:setWeaponStorage("EMP", s:getWeaponStorage("EMP")+20)
--	    s:addToShipLog("Added 20 EMPs!", "Green")
--      end)
--      setCirclePos(na, cx, cy, random(0, 360), cr*1.5)
--      local na = Artifact():setModel("ammo_box"):allowPickup(true):onPickUp(function(a,s)
--	    s:setWeaponStorage("Homing", s:getWeaponStorage("Homing")+50)
--	    s:addToShipLog("Added 50 Homing Missiles!", "Green")
--								end)
--      na:setScanningParameters(1,1):setDescriptions("Big ammo crate","50 Homing Missiles")
--      setCirclePos(na, cx, cy, random(0, 360), cr*1.5)
--      local na = Artifact():setModel("ammo_box"):allowPickup(true):onPickUp(function(a,s)
--	    s:setWeaponStorage("Mine", s:getWeaponStorage("Mine")+20)
--	    s:addToShipLog("Added 20 Mines!", "Green")
--								end)
--      na:setScanningParameters(1,1):setDescriptions("Big ammo crate","20 Mines")
--      setCirclePos(na, cx, cy, random(0, 360), cr*1.5)
--      local na = Artifact():setModel("ammo_box"):allowPickup(true):onPickUp(function(a,s)
--	    s:setWeaponStorage("HVLI", s:getWeaponStorage("HVLI")+100)
--	    s:addToShipLog("Added 100 HVLI!", "Green")
--								end)
--      na:setScanningParameters(1,1):setDescriptions("Big ammo crate","100 HVLI")
--      setCirclePos(na, cx, cy, random(0, 360), cr*1.5)


      -- HACK because the stuff above doesn't work :(
      -- Explane from 08_atlantis
      -- supply_drop = SupplyDrop():setFaction("Human Navy"):setPosition(29021, 114945):setEnergy(500):setWeaponStorage("Homing", 12):setWeaponStorage("Nuke", 4):setWeaponStorage("Mine", 8):setWeaponStorage("EMP", 6):setWeaponStorage("HVLI", 20)

--      bounty_n = SupplyDrop():setWeaponStorage("Nuke", 20):setFaction("Human Navy")
--      setCirclePos(bounty_n, cx, cy, random(0, 360), cr*1.5)
--      bounty_p = SupplyDrop():setWeaponStorage("EMP", 20):setFaction("Human Navy")
--      setCirclePos(bounty_p, cx, cy, random(0, 360), cr*1.5)
--      bounty_o = SupplyDrop():setWeaponStorage("Homing", 50):setFaction("Human Navy")
--      setCirclePos(bounty_o, cx, cy, random(0, 360), cr*1.5)
--      bounty_m = SupplyDrop():setWeaponStorage("Mine", 20):setFaction("Human Navy")
--      setCirclePos(bounty_m, cx, cy, random(0, 360), cr*1.5)
--      bounty_h = SupplyDrop():setWeaponStorage("HVLI", 100):setFaction("Human Navy")
--      setCirclePos(bounty_h, cx, cy, random(0, 360), cr*1.5)
--      bounty_e = SupplyDrop():setEnergy(1000):setFaction("Human Navy")
--      setCirclePos(bounty_e, cx, cy, random(0, 360), cr*1.5)

      -- Because other stuff doesn't work
      ship:setWeaponStorageMax("Nuke",20)
      ship:setWeaponStorage("Nuke",20)
      ship:setWeaponStorageMax("EMP",20)
      ship:setWeaponStorage("EMP",20)
      ship:setWeaponStorageMax("Homing",50)
      ship:setWeaponStorage("Homing",50)
      ship:setWeaponStorageMax("Mine",20)
      ship:setWeaponStorage("Mine",20)
      ship:setWeaponStorageMax("HVLI",100)
      ship:setWeaponStorage("HVLI",100)
      ship:setMaxEnergy(ship:getMaxEnergy()*4)
      ship:setEnergy(ship:getMaxEnergy())
      ship:setMaxCoolant(ship:getMaxCoolant()*4)
      ship:setMaxScanProbeCount(ship:getMaxScanProbeCount()*4)
      ship:setScanProbeCount(ship:getMaxScanProbeCount())
   end
end

-- Jupiter Union mission
-- Visit each JU station to deliver mail.
-- Reward is Purple Conversion Beam
-- TODO: On first visit, add custom Relay button to locate all JU stations by sector name.
function juComms(s,t)
   if s:isDocked(t) ~= true then
      setCommsMessage("Hello from the Jupiter Union. Please dock if you need anything.")
   else
      local tn = t:getCallSign()
      local been = false
      for i,stn in ipairs(progress["juVisits"]) do
	 if stn == tn then
	    been = true
	 end
      end
      if been and (#progress["juVisits"] < 5) then
	 setCommsMessage("Messages collected from " .. tn)
      else
	 if (#progress["juVisits"] == 0) then
	    setCommsMessage("Welcome to the Jupiter Union!\n\nWe've had a communications network antenna failure and are having difficulties reaching our other stations. Could you deliver some messages for us?")
	    addCommsReply("Sure, we can do that!", juAck)
	    --addCommsReply("Sorry, not right now.", juComms)
	 elseif (#progress["juVisits"] == 1) then
	    setCommsMessage("Thanks for delivering these messages for us! Here's a few more to deliver.")
	    addCommsReply("Collect messages.", juAck)
	 elseif (#progress["juVisits"] == 2) then
	    setCommsMessage("Wow, you've already picked up the messages from two other stations, thank you so much!\n\nHere's a few more messages.")
	    addCommsReply("Collect messages.", juAck)
	 elseif (#progress["juVisits"] == 3) then
	    setCommsMessage("You've been a huge help to the Union! We just need these last messages delivered, which should allow the restarting of our comms network.")
	    addCommsReply("Okay, last trip.", juAck)
	 elseif (#progress["juVisits"] == 4) then
	    setCommsMessage("Thanks for delivering all our backlogged emails. We should have the comms network back shortly.\n\nShipyard Lunar Station One [LS-1] has new upgrades available.")
	    addCommsReply("Our pleasure.", juAck)
	 end
      end
   end
   addCommsReply("Ask for directions.", juDirections)
end
function juAck(s,t)
   local n = #progress["juVisits"]
   local stnName = t:getCallSign()
   --if stnName in progress["juVisits"] then
   --   setCommsMessage("Hello again.")
   --end
   if n == 0 then
      setCommsMessage("Okay, we need you to collect and to deliver messages at each of the Jupiter Union stations.\n\nThey are at Callisto, Ganymede, Io, Europa, and Jupiter itself.")
      s:addToShipLog("Collected messages from " .. stnName, "Yellow")
   elseif n == 1 then
      setCommsMessage("Delivered messages to two stations.")
      s:addToShipLog("Collected messages from " .. stnName, "Yellow")
   elseif n == 2 then
      setCommsMessage("Delivered messages to three stations.")
      s:addToShipLog("Collected messages from " .. stnName, "Yellow")
   elseif n == 3 then
      setCommsMessage("Delivered messages to four stations.")
      s:addToShipLog("Collected messages from " .. stnName, "Yellow")
   elseif n == 4 then
      setCommsMessage("Delivered messages to all five stations!")
      --s:addToShipLog("Collected messages from " .. stnName, "Yellow")
      s:addReputationPoints(100)
   end
   table.insert(progress["juVisits"], stnName)
end
function juDirections(s,t)
   local where = ""
   if stations["JU-HQ"]["instance"] ~= nil then
      where = where .. "Jupiter Union Headquarters [JU-HQ] orbits Jupiter itself. It is currently in sector " .. getSectorName(stations["JU-HQ"]["instance"]:getPosition()) .. "\n"
   end
   if stations["JU-IO"]["instance"] ~= nil then
      where = where .. "JU-IO orbits Io. It is currently in sector " .. getSectorName(stations["JU-IO"]["instance"]:getPosition()) .. "\n"
   end
   if stations["JU-EU"]["instance"] ~= nil then
      where = where .. "JU-EU orbits Europa. It is currently in sector " .. getSectorName(stations["JU-EU"]["instance"]:getPosition()) .. "\n"
   end
   if stations["JU-GA"]["instance"] ~= nil then
      where = where .. "JU-GA orbits Ganymede. It is currently in sector " .. getSectorName(stations["JU-GA"]["instance"]:getPosition()) .. "\n"
   end
   if stations["JU-CA"]["instance"] ~= nil then
      where = where .. "JU-CA orbits Callisto. It is currently in sector " .. getSectorName(stations["JU-CA"]["instance"]:getPosition()) .. "\n"
   end
   setCommsMessage("Jupiter Union stations orbit the four Gallilean moons and Jupiter itself.\n\n" .. where)
   addCommsReply("Back", juComms)
end

-- TODO: Saturn mission is to destroy, make peace, or convert the Exuari.
-- Destruction of Titania achieves the goal.
-- Finding Armistice Station and engaging in peace talks makes Exuari => Independent, achieves goal.
-- Firing Purple Conversion Beam on Titania makes Exuari => Independent, achieves goal.
function obComms(s,t)
   if s:isDocked(t) then
      setCommsMessage("Inside you find no one. The empty hallways have only a silent chill.")
      addCommsReply("Look around",obTrail)
   else
      setCommsMessage("Hello from Oberon, home of impartial relations among all inhabitants of the Sol system. Please dock with us if you need anything.")
   end
end
function obTrail(s,t)
   progress["saturn"] = progress["saturn"] + 1
   local go = {"Go left","Go right","Go North","Go South","Go around","Double back","Next door","Next hallway","Next room","Go back","Search more","Cotinue farther","Keep looking","What's over here?","What's over there?","What's that?","Where are we?"}
   local see = {"You see nothing.","Nothing there.","Nothing here.","This place seems lonely.","A chill fills the air, nothing more.","Here lies nothing.","Lights flicker in the lifeless halls.","Empty rooms with conference tables.","Empty rooms.","Nada.","Empty.","The only footsteps are your own."}
   msg = see[irandom(1,#see)]
   if (progress["saturn"] >= 5) and (progress["saturn"] < 100) then msg=msg.."\n\nYou see a lit room." end
   setCommsMessage(msg)
   local goes = {}
   repeat
      local g = go[irandom(1,#go)]
      local have = false
      for i,gg in ipairs(goes) do
	 if g == gg then have = true end
      end
      if have == false then table.insert(goes,g) end
   until(#goes>5)
   for i,g in ipairs(goes) do
      addCommsReply(g, obTrail)
   end
   if (progress["saturn"] >= 5) and (progress["saturn"] < 100) then addCommsReply("Examine the lit room", obRoom) end
end
function obRoom(s,t)
   setCommsMessage("One room stands out with its door slightly ajar and all the lights on. Inside you find a dusty old computer with a keyboard and mouse; Super vintage!")
   addCommsReply("Turn it on.",obBoot)
   addCommsReply("Leave it alone.",obComms)
end
function obBoot(s,t)
   setCommsMessage("It beeps once. That's good.\n\nThe bootup screen informs you that this station has been available for the humans to engage Peace Talks with the Exuari for over 300 years. A 3-D communications panel lights up, and you are presented with two buttons:")
   addCommsReply("Attend Peace Talks",obPeace)
   addCommsReply("Declare War",function() -- TODO ??
		    setCommsMessage("You are already at war with the Exuari.")
		    progress["saturn"] = 0
   end)
end
function obPeace(s,t)
   if numex<12 then
      progress["saturn"] = 0
      setCommsMessage("Negotiations seem to be progressing when suddenly one of the Exuari points at you through the viewscreen and screams!\n\n\"I recognize that crew! Those are merchants of DEATH!\"\n\nYou seem to have a (bad) reputation...")
      addCommsReply("Oh, well...",obComms)
   else
      setCommsMessage("Your crew settle in for negotiations, despite having no such authority.\n\nIt seems to go well! You've made peace with the Exuari.")
      for i,ship in ipairs(ships) do
	 addCommsReply("Awesome!",obComms)
      end
   end
end
function makePeace()
   if stations["Titania"]["instance"] ~= nil then
      local t = stations["Titania"]["instance"]
      -- FIXME: can't change faction?
      --stations["Titania"]["instance"]:setFaction("Independent")
      local p = bodies["Titan"]["instance"]
      --local ar = angleRotation(p,t)
      --local ar = angleRotation(bodies["Titan"]["instance"], stations["Titania"]["instance"])
      local tx,ty = t:getPosition()
      if t:isValid() then t:destroy() end
      local s = SpaceStation()
      s:setCallSign("Titania")
      s:setTemplate(stations["Titania"]["template"])
      s:setFaction("Independent")
      s:setPosition(tx,ty)
      --stations["Titania"]["instance"] = s
      stations["Titania"]["instance"] = nil
   end
   for i,es in ipairs(eships) do
      es:setFaction("Independent")
   end
   progress["saturn"] = progress["saturn"] + 100
   for i,ship in ipairs(ships) do
      ship:addReputationPoints(math.ceil(progress["saturn"]))
      ship:addToShipLog("You've settled the situation with the Exuari!", "Green")
      stations["HN-HQ"]["instance"]:sendCommsMessage(ship, "The Exuari threat has been neutralized. Good work!\n\nShipyard Lunar Station One [LS-1] has new upgrades available.")
   end
end

-- TODO: Outer Planets mission is to find way from Uranus to Neptune (wormhole on orbit?),
-- learn of Kraylor invasion fleet, warn HN-HQ and fleet jumps to Pluto for epic battle.
-- Otherwise if Kraylor fleet undiscovered and other missions complete, Kraylor fleet jumps PLUTO
-- and all its forces to Luna for epic battle at Earth-Luna-Pluto system.
function goTime()
   progress["outer"] = 5
   local hq = stations["HN-HQ"]["instance"]
   for i,ship in ipairs(ships) do
      hq:sendCommsMessage(ship, "What the ... !? Is that PLUTO???\n\nWe've detected incoming Kraylor! Scramble all fighters! Repeat, scramble all fighters!\nFind and destroy the Kraylor station [KR-PL]!\nProtect Human Navy Headquarters [HN-HQ] at all costs!!!")
   end
   local e = bodies["Earth"]["instance"]
   local m = bodies["Luna"]["instance"]
   local ex,ey = e:getPosition()
   local emr = angleRotation(e, m)
   local emd = distance(e, m)
   emr = emr - 45
   if emr < 0 then emr = emr + 360 end
   -- FIXME: Does this work? If so, KR-PL should come along with it
   --setCirclePos(bodies["Pluto"]["instance"], ex, ey, emr, emd)
   bodies["Pluto"]["parent"] = "Earth"
   bodies["Pluto"]["angle"] = emr
   bodies["Pluto"]["distance"] = emd
   bodies["Pluto"]["instance"] = makeBody("Pluto", bodies["Pluto"])
   local px,py = bodies["Pluto"]["instance"]:getPosition()
   local per = angleRotation(bodies["Pluto"]["instance"], e)
   -- KLUDGE? Just jam it on L1
   setCirclePos(stations["KR-PL"]["instance"], px, py, per, bodies["Pluto"]["instance"]:getPlanetRadius()*3)
   stations["KR-PL"]["lagrange"] = "L1"
   stations["KR-PL"]["timer"] = getScenarioTime()
   local hqx,hqy = hq:getPosition()
   CpuShip():setFaction("Human Navy"):setTemplate("Dreadnought"):setPosition(hqx + 2000, hqy + 2000):orderDefendTarget(hq)
end

function throwFlares()
   flare_time = getScenarioTime()
   local sun = bodies["Corona"]["instance"]
   --local mercury = bodies["Mercury"]["instance"]
   local mercury = stations["Icarus"]["instance"]
   local sx, sy = sun:getPosition()
   local sr = sun:getPlanetRadius()
   local mx, my = mercury:getPosition()
   local ar = angleRotation(sun, mercury)
   for __ = 1, 20 do
      local f = Nebula()
      setCirclePos(f, sx, sy, random(ar-0.2, ar+0.2), random(sr-2000, sr+5000))
      local fdata = {}
      fdata["instance"] = f
      local fa = angleRotation(f, mercury)
      fdata["angle"] = random(fa-0.2, fa+0.3)
      fdata["speed"] = random(300,320)
      table.insert(solar_flares, fdata)
   end
   -- HACK
   solar_flares[1]["speed"] = 305
end
function advanceFlares()
   local m = bodies["Mercury"]["instance"]
   local s = bodies["Sol"]["instance"]
   local mr = m:getPlanetRadius()
   local dtm = distance(s, m)
   local stn = stations["Icarus"]["instance"]
   local docked = {}
   if stn ~= nil then
      for i,ship in ipairs(ships) do
	 if ship:isDocked(stn) then
	    progress["mercury"] = progress["mercury"] + ((getScenarioTime() - flare_time) / 4000000)
	    table.insert(docked, ship)
	    local msg = "Download: " .. progress["mercury"] .. " %"
	    if ship:hasPlayerAtPosition("Engineering") then ship:addCustomInfo("Engineering","download-progress",msg) end
	    if ship:hasPlayerAtPosition("Engineering+") then ship:addCustomInfo("Engineering+","download-progress",msg) end
	 end
      end
      -- FIXME: Should never reach "100%"
      --if #docked > 0 then
	 --progress["mercury"] = progress["mercury"] + ((getScenarioTime() - flare_time) / 4000000)
      --end
      --if #docked > 0 then progress["mercury"] = progress["mercury"] + ((100/dtm)*distance(solar_flares[1],s)) end
   end
   for i,fdata in pairs(solar_flares) do
      local f = fdata["instance"]
      local fx, fy = f:getPosition()
      -- This is to ensure at least one specific flare will in fact hit the station
      if (i==1) and (stn ~= nil) then
	 setCirclePos(fdata["instance"], fx, fy, angleRotation(f, stn), fdata["speed"])
	 if distance(f, stn) < 3000 then
	    local sx, sy = stn:getPosition()
	    stn:destroy()
	    stations["Icarus"]["instance"] = nil
	    ExplosionEffect():setPosition(sx, sy):setSize(400):setOnRadar(true)
	    if #docked > 0 then
	       progress["mercury"] = (progress["mercury"]+100)
	       for i,ship in ipairs(docked) do
		  ship:setHull(60)
	       end
	    end
	    if progress["mercury"] <= 1 then
	       broadcastLog("Icarus station data not downloaded! :-( " .. progress["mercury"], "Red")
	    elseif progress["mercury"] < 100 then
	       broadcastLog("Icarus station data downloaded: " .. progress["mercury"] .. " %", "Cyan")
	    else
	       broadcastLog("Icarus station data downloaded: " .. progress["mercury"]-100 .. " %. Download complete.", "Green")
	       for i,ship in ipairs(docked) do
		  stations["Daedalus"]["instance"]:sendCommsMessage(ship, "WOW! It really blew the heck up! Hope your crew's okay.\n\nThanks for saving as much data as you could. Shipyard LS-1 has additional upgrades now.")
		  ship:addReputationPoints(math.ceil(progress["mercury"]))
	       end
	    end
         end
      else
	 setCirclePos(fdata["instance"], fx, fy, fdata["angle"], fdata["speed"])
      end
      --setCirclePos(fdata["instance"], fx, fy, fdata["angle"], 300)
      for i,ship in ipairs(ships) do
	 if ship:isValid() then
	    if distance(fdata["instance"], ship) < 3000 then
	       -- NOTE: Ships hit by the CME will get hit by a few (random) flares
	       local sys = irandom(1,#all_systems)
	       local s = all_systems[sys]
	       ship:setSystemHeat(s, (ship:getSystemHeat(s))+0.1)
	       if ship:getSystemHeat(s) >= 1.8 then
		  ship:setSystemHealth(s, ship:getSystemHealth(s)*2/3)
	       end
	    end
	 end
      end
      if (distance(bodies["Corona"]["instance"], f) > (dtm + (mr * stations["Icarus"]["distance"]) + 50000)) or (distance(m,f)<mr) then
	 fdata["instance"]:destroy()
	 table.remove(solar_flares, i)
      end
   end
end
function checkDownload(ship, pos)
   ship:addCustomMessage(pos,"science-download","Downloaded: " .. progress["mercury"] .. " %")
end
function checkGhosts()
   local valids = 0
   for i,stn in ipairs(ghost_stns) do
      if stn:isValid() then valids = valids + 1 end
   end
   return valids
end
function checkTotalProgress()
   local tp = 0
   if progress["mercury"] > 1 then tp = tp + 1 end
   if (progress["venus"] > 1) and (checkGhosts() == 0) then tp = tp + 1 end
   if progress["mars"] >= 200 then tp = tp + 1 end
   if progress["belt"] >= 100 then tp = tp + 1 end
   if #progress["juVisits"] >= 5 then tp = tp + 1 end
   if progress["saturn"] >= 100 then tp = tp + 1 end
   if progress["outer"] >= 100 then tp = tp + 1 end
   return tp
end

function progressReport(s,t)
   local tp = checkTotalProgress()
   local pcc = 0
   if tp==7 then pcc = 100 else pcc = (100/7)*tp end
   --local m = progress["mars"]
   --if m>100 then m=m-100 end
   --if m>100 then m=m-100 end -- Do not remove
   --pcc=pcc+m

   msg = "----= PROGRESS REPORT =----\n\n"
   msg=msg..pcc.."% complete.\n"

   -- MERCURY
   msg=msg.."\nMercury: "
   if progress["mercury"] == 0 then
      msg=msg.."Visit Daedalus station to get started."
   elseif (progress["mercury"] == 1) and stations["Icarus"]["instance"] ~= nil then
      msg=msg.."What are you doing here!? Download Icarus data NOW!"
   elseif (progress["mercury"] == 1) and stations["Icarus"]["instance"] == nil then
      msg=msg.."You failed to save any data from Solar observatory Icarus. :-("
   elseif (progress["mercury"] < 100) then
      msg=msg..string.format("Downloaded %s %%. You could have done better.", progress["mercury"]-100)
   elseif (progress["mercury"] >= 100) then
      msg=msg..string.format("Downloaded %s %%. You did your best! Beams available at LS-1.", progress["mercury"]-100)
   end

   -- VENUS
   local pv = progress["venus"]
   msg=msg.."\nVenus: "
   if stations["VE-IX"]["instance"] == nil then msg=msg.."VE-IX destroyed, "
   elseif stations["VE-IX"]["instance"]:isValid() == false then msg=msg.."VE-IX destroyed, "
   elseif pv==0 then msg=msg.."Nada."
   elseif checkGhosts()>0 then msg=msg.."Go to Venus and destroy the pesky Ghosts."
   else msg=msg.."Ghosts eliminated! Beams available at LS-1." end

   -- MARS
   msg=msg.."\nMars: "
   if progress["mars"] < 100 then msg=msg.."Mars terraformers need heat."
   elseif progress["mars"] == 202 then msg=msg.."Terraformed! But something weird happened... Beams available at LS-1."
   else msg=msg.."Terraformed! Beams available at LS-1."
   end

   -- JUPITER
   if #progress["juVisits"] > 0 then
      msg=msg.."\nJupiter: "
      if #progress["juVisits"] < 5 then
	 msg=msg.."Incomplete. Visit stations "
	 local missing = {"JU-HQ","JU-IO","JU-EU","JU-GA","JU-CA"}
	 for i = 1,5 do
	    local done = false
	    for j,ju in ipairs(progress["juVisits"]) do
	       if missing[i] == ju then done = true end
	    end
	    if done == false then msg=msg..missing[i].." " end
	 end
      else
	 msg=msg.."Messages delivered! Beams available at LS-1."
      end
   end

   -- SATURN
   if progress["saturn"] > 0 then
      msg=msg.."\nSaturn: "
      if progress["saturn"] < 100 then msg=msg.."Incomplete. Neutralize the Exuari inhabiting the Saturn system."
      else msg=msg.."Exuari neutralized! Beams available at LS-1."
      end
   end

   -- BELT
   if (progress["belt"] > 0) and (checkTotalProgress() >= 4) then
      msg=msg.."\nBelt: "
      if progress["belt"] < 100 then
	 msg=msg.."Explore the Belt."
      else
	 msg=msg.."Fully explored!"
      end
   end

   -- OUTER PLANETS
   if progress["outer"] > 0 then
      msg=msg.."\nOuter planets: "
      if progress["outer"] < 2 then msg=msg.."Unexplored."
      elseif progress["outer"] == 2 then msg=msg.."Tell HQ about the Kraylor you discovered."
      elseif progress["outer"] == 3 then msg=msg.."Inform the armada when you are ready to attack the Kraylor."
      elseif progress["outer"] == 4 then msg=msg.."Strange energies detected at Earth!"
      elseif (progress["outer"] >= 5) and (stations["KR-PL"]["instance"] ~= nil) then msg=msg.."What are you doing here!? Destroy Kraylor HQ [KR-PL] immediately!!"
      else msg=msg.."Earth saved!"
      end
      msg=msg.."\n"
   end

   if tp >= 7 then
      setCommsMessage(msg.."\nCONGRATULATIONS! You've completed everything there is to do.")
      addCommsReply("Declare Victory!", function() victory("Human Navy") end)
   else
      setCommsMessage(msg)
   end
   addCommsReply("Back", hqComms)
end

-- DEBUG: Show heat values
function showHeat(ship)
   for i,sys in ipairs(all_systems) do
      ship:setCustomMessage("Engineering","heatwindow",sys .. ": " ..ship:getSystemHeat(sys))
   end
end

-- UNTESTED
function makeSquadron(faction, size, hdg, pos_x, pos_y)
   local dim = 1
   if size < 15 then dim = 2
   elseif size < 28 then dim = 3
   else dim = math.ceil(math.sqrt(size))
   end 
   local row = math.ceil(size/dim)
   local squad = {}
   for y = 0,dim-1 do
      for x = 0,row-1 do
	 table.insert(squad, CpuShip():setFaction(faction):setHeading(hdg):setPosition(pos_x + (x*500), pos_y + (y*500)))
      end
   end
   return squad
end

-- Set callback function
onNewPlayerShip(
   function(ship)
      -- DEBUG: Set ship start location as needed
      --ship:setPosition(bodies["Callisto"]["instance"]:getPosition())
      --print(startx .. "\n" .. starty)
      -- PLANET
      --local start = bodies["Mars"]["instance"]
      --local startoffset = start:getPlanetRadius()
      -- STATION
      local start = stations["HN-HQ"]["instance"]
      local startoffset=100

      local startx, starty = start:getPosition()
      ship:setPosition(startx-(startoffset*3), starty)
      --ship:setHeading(0)

      -- DEBUG
      --print(ship, ship.typeName, ship:getTypeName(), ship:getCallSign())

      ship:setWarpDrive(true)
      --ship:setWarpSpeed(7500)
      ship:setWarpSpeed(4000)

      -- FIXME: Work with existing beams, instead of blindly replacing beam(0)
      -- void ShipTemplate::setBeamWeapon(int index, float arc, float direction, float range, float cycle_time, float damage)
      --ship:setBeamWeapon(0, 30, 0, 1000, 6, 4)
      -- FIXME: Doesn't work :(
      -- Given the grand distances here, we allow Relay to contact Human Navy Headquarters at all times.
      ship:addCustomButton("Relay", "relayDirs", _("relay-DirButton", "Directions"), function() relayDirs(ship) end)
      ship:addCustomButton("AltRelay", "arelayDirs", _("relay-DirButton", "Directions"), function() relayDirs(ship) end)
      ship:addCustomButton("Single", "singleDirs", _("relay-DirButton", "Directions"), function() relayDirs(ship) end)

      ship:addCustomButton("Relay", "relayCallJC", _("relay-JCButton", "Jump Carrier"), function() relayJC(ship) end)
      ship:addCustomButton("AltRelay", "arelayCallJC", _("relay-JCButton", "Jump Carrier"), function() relayJC(ship) end)
      ship:addCustomButton("Single", "singleCallJC", _("relay-JCButton", "Jump Carrier"), function() relayJC(ship) end)

      -- DEBUG: Testing heat values
      --ship:addCustomButton("Engineering", "showHeat", "Show Heat Values", function() showHeat(ship) end)
      --ship:addCustomInfo("engineering","show_coolant_max","Coolant Max: " .. ship:getMaxCoolant(),0)

      -- TODO: Advance range as the scenario progresses
      --ship:setLongRangeRadarRange(50000)
      ship:setLongRangeRadarRange(100000)

      ship.beam_counters = {
	 ["blue"] = 0,
	 ["green"] = 0,
	 ["purple"] = 0,
	 ["orange"] = 0,
	 ["yellow"] = 0
      }
      ship.prevTarget = nil

      -- DEBUG Advance progress here to be able to test later missions
      --progress["whAllow"] = true
      --progress["mercury"] = 200
      --progress["venus"] = 100
      --ghost_stns = {}
      --progress["mars"] = 200
      --progress["belt"] = 1
      --progress["juVisits"] = {"JU-HQ","JU-IO","JU-EU","JU-GA","JU-CA"}
      --progress["saturn"] = 1000
      --progress["outer"] = 1

      -- DEBUG Special Beams needed to test other missions
      --ship:addCustomButton("Helms", "h-greenBeamButton", "Tracking beam", function() weaponBeamGreen(ship) end)
      --ship:addCustomButton("Weapons", "w-BeamButton", "Destruct beam", function() weaponBeamOrange(ship) end)
      --ship:addCustomButton("Engineering", "e-yellowBeamButton", "Heat Beam", function() weaponBeamYellow(ship) end)
      --ship:addCustomButton("Science", "s-blueBeamButton", "Homing beam", function() weaponBeamBlue(ship) end)
      --ship:addCustomButton("Operations", "o-blueBeamButton", "Locator beam", function() weaponBeamBlue(ship) end)
      --ship:addCustomButton("Relay", "r-purpleBeamButton", "Strange beam", function() weaponBeamPurple(ship) end)

      welcomeComms(ship)

      ship:addReputationPoints(checkTotalProgress() * 100)

      table.insert(ships, ship)
      --ship:destroy()
   end
)
